#!/usr/bin/env bash
#
# Bootstrap a package onto the shared CI baseline.
#
# Automates the mechanical parts of "Quick start (per package)":
#   1. Copy the Layer B config templates (pint, rector, phpstan + baseline).
#   2. Merge the canonical require-dev / scripts / allow-plugins into composer.json.
#   3. Drop a caller workflow into .github/workflows/.
#
# It does NOT do the judgement-heavy steps — you finish those by hand:
#   - Tune the matrix rows in the caller to the versions this package supports.
#   - `composer update`, then `vendor/bin/phpstan analyse --generate-baseline`.
#   - Delete the old tests.yml / lint.yml / static-analysis workflows.
#   - Update branch-protection required checks to Tests / Lint / Static Analysis / Reformat.
#
# Usage:
#   bin/bootstrap-package.sh <package-dir> [--type TYPE] [--force]
#
# TYPE (default: filament-5):
#   filament-5   Filament plugin, Filament 5.x caller
#   filament-4   Filament plugin, Filament 4.x caller
#   laravel      Laravel package (no Filament)
#   php-library  Plain PHP library (no Laravel — leaner tooling profile)
#
# Existing files are left untouched unless --force is passed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$REPO_ROOT/templates"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }
info() { printf '  %s\n' "$1"; }

# --- args -------------------------------------------------------------------
TARGET=""
TYPE="filament-5"
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type)  TYPE="${2:-}"; shift 2 ;;
        --force) FORCE=1; shift ;;
        -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "unknown option: $1" ;;
        *)  [[ -z "$TARGET" ]] || die "unexpected argument: $1"; TARGET="$1"; shift ;;
    esac
done

[[ -n "$TARGET" ]] || die "usage: bin/bootstrap-package.sh <package-dir> [--type TYPE] [--force]"
[[ -d "$TARGET" ]] || die "not a directory: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"
[[ -f "$TARGET/composer.json" ]] || die "no composer.json in $TARGET"

# --- resolve type -> caller template + composer profile ---------------------
# PROFILE is passed to the PHP composer merge below to pick the right dep set.
case "$TYPE" in
    filament-5|filament-4|laravel) PROFILE="laravel" ;;
    php-library)                   PROFILE="php-library" ;;
    *) die "unknown --type '$TYPE' (expected: filament-5, filament-4, laravel, php-library)" ;;
esac

CALLER_SRC="$TEMPLATES/callers/ci-$TYPE.yml"
[[ -f "$CALLER_SRC" ]] || die "no caller template for --type $TYPE (looked for $CALLER_SRC)"

command -v php >/dev/null || die "php is required to merge composer.json"

echo "Bootstrapping $TARGET (type: $TYPE)"

# --- 1. copy config templates -----------------------------------------------
# copy_template <source-basename> [dest-basename]
echo "Config templates:"
copy_template() {
    local src="$TEMPLATES/$1" dst="$TARGET/${2:-$1}"
    if [[ -e "$dst" && $FORCE -eq 0 ]]; then
        info "skip ${2:-$1} (exists — use --force to overwrite)"
    else
        cp "$src" "$dst"
        info "copied ${2:-$1}"
    fi
}
copy_template pint.json
copy_template rector.php
copy_template phpstan-baseline.neon
mkdir -p "$TARGET/.github"
copy_template dependabot.yml .github/dependabot.yml
if [[ "$PROFILE" == "php-library" ]]; then
    copy_template phpstan-php-library.neon.dist phpstan.neon.dist
else
    copy_template phpstan.neon.dist
fi

# --- 2. merge composer.json -------------------------------------------------
echo "composer.json:"
php -r '
$file = $argv[1];
$profile = $argv[2];
$json = json_decode(file_get_contents($file), true);
if ($json === null) { fwrite(STDERR, "  invalid composer.json\n"); exit(1); }

// Laravel/Filament profile — mirrors templates/composer-snippets.md.
$laravel = [
    "require-dev" => [
        "larastan/larastan" => "^3.0",
        "laravel/pint" => "^1.0",
        "nunomaduro/collision" => "^8.0",
        "orchestra/testbench" => "^9.0|^10.0|^11.0",
        "pestphp/pest" => "^4.0",
        "pestphp/pest-plugin-arch" => "^4.0",
        "pestphp/pest-plugin-laravel" => "^4.0",
        "pestphp/pest-plugin-livewire" => "^4.0",
        "rector/rector" => "^2.0",
        "spatie/laravel-ray" => "^1.26",
    ],
    "scripts" => [
        "post-autoload-dump" => "@php ./vendor/bin/testbench package:discover --ansi",
        "lint" => "pint",
        "refactor" => "rector",
        "test:lint" => "pint --test",
        "test:refactor" => "rector --dry-run",
        "test:types" => "phpstan analyse",
        "test:unit" => "pest",
        "test" => ["@test:refactor", "@test:lint", "@test:types", "@test:unit"],
    ],
    "allow-plugins" => [
        "pestphp/pest-plugin" => true,
        "phpstan/extension-installer" => true,
    ],
];

// Plain PHP library — no Laravel/testbench/larastan.
$library = [
    "require-dev" => [
        "laravel/pint" => "^1.0",
        "pestphp/pest" => "^4.0",
        "pestphp/pest-plugin-arch" => "^4.0",
        "phpstan/phpstan" => "^2.0",
        "rector/rector" => "^2.0",
    ],
    "scripts" => [
        "lint" => "pint",
        "refactor" => "rector",
        "test:lint" => "pint --test",
        "test:refactor" => "rector --dry-run",
        "test:types" => "phpstan analyse",
        "test:unit" => "pest",
        "test" => ["@test:refactor", "@test:lint", "@test:types", "@test:unit"],
    ],
    "allow-plugins" => [
        "pestphp/pest-plugin" => true,
    ],
];

$p = $profile === "php-library" ? $library : $laravel;

$json["require-dev"] = $json["require-dev"] ?? [];
foreach ($p["require-dev"] as $pkg => $ver) { $json["require-dev"][$pkg] = $ver; }
ksort($json["require-dev"]);

$json["scripts"] = array_merge($json["scripts"] ?? [], $p["scripts"]);
$json["config"] = $json["config"] ?? [];
$json["config"]["allow-plugins"] = array_merge($json["config"]["allow-plugins"] ?? [], $p["allow-plugins"]);

$out = json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . "\n";
file_put_contents($file, $out);
printf("  merged %s profile: require-dev (%d entries), scripts, config.allow-plugins\n", $profile, count($p["require-dev"]));
if ($profile !== "php-library") {
    printf("  note: pest-plugin-livewire added — drop it if this package has no Livewire tests\n");
}
' "$TARGET/composer.json" "$PROFILE"

# --- 3. caller workflow -----------------------------------------------------
echo "Caller workflow:"
mkdir -p "$TARGET/.github/workflows"
CALLER_DST="$TARGET/.github/workflows/ci-$TYPE.yml"
if [[ -e "$CALLER_DST" && $FORCE -eq 0 ]]; then
    info "skip ci-$TYPE.yml (exists — use --force to overwrite)"
else
    cp "$CALLER_SRC" "$CALLER_DST"
    info "copied .github/workflows/ci-$TYPE.yml"
fi

# --- next steps -------------------------------------------------------------
cat <<'EOF'

Done. Finish by hand (see docs/package-migration.md):
  - Tune the matrix rows in the caller to the versions this package supports.
  - composer update, then vendor/bin/phpstan analyse --generate-baseline
    (then flip run-static-analysis: true in the caller).
  - Delete the old tests.yml / lint.yml / static-analysis workflows.
  - Update branch-protection required checks to: Tests, Lint, Static Analysis, Reformat.
EOF
