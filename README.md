# awcodes - Shared CI

Central reusable GitHub Actions workflows, composite actions, and canonical tooling
config for awcodes packages. Package repos consume these through thin, branch-scoped
caller workflows so CI logic lives in one place.

## Layout

```
.github/workflows/        Reusable workflows (workflow_call)
  filament-plugin.yml       Tests · Lint · Static Analysis · Reformat (+ optional asset build)
  laravel-package.yml       Same, without Filament dependency handling
  php-library.yml           Same, for plain PHP libraries (no Laravel)

actions/                  Composite actions
  setup-php/                shivammathur/setup-php + problem matchers
  install-dependencies/     Pin matrix framework/testbench/filament versions + composer update
  setup-node/               Node setup + npm install (for asset builds)

templates/                Canonical Layer B config to copy into each package
  pint.json
  rector.php
  phpstan.neon.dist            larastan-based (Laravel/Filament packages)
  phpstan-php-library.neon.dist  plain phpstan (no Laravel)
  phpstan-baseline.neon
  composer-snippets.md      require-dev + scripts to merge into composer.json
  dependabot.yml            Copy to .github/dependabot.yml (composer + actions updates)
  callers/                  Example caller workflows
    ci-filament.yml           One branch, combined matrix — the default for plugins
    ci-filament-4.yml         Frozen legacy branch only
    ci-laravel.yml
    ci-php-library.yml

bin/
  bootstrap-package.sh      Scaffold a package onto the shared CI baseline

docs/
  package-migration.md
  versioning.md
  branch-specific-workflows.md
```

## Design principles

- **Intent-based check names** — `Tests`, `Lint`, `Static Analysis`, `Reformat` — stable
  even if the underlying tool changes. These become the branch-protection required checks.
- **Explicit matrix rows, no `exclude`** — each package lists only the combos it supports.
- **`run-*` toggles** — turn individual checks on/off per package (e.g. keep
  `run-static-analysis: false` until a package's phpstan baseline is committed).
- **Version-pinned consumption** — callers reference `@v1`, never `@main`.

## Quick start (per package)

### With the script

`bin/bootstrap-package.sh` scaffolds the mechanical steps:

```
bin/bootstrap-package.sh <package-dir> --type <type>
```

`--type` (default `filament`) selects the tooling profile and caller workflow:

| `--type`      | Lands as              | Tooling profile                              |
| ------------- | --------------------- | -------------------------------------------- |
| `filament`    | `ci.yml`              | Laravel/Filament (larastan, testbench, Pest) |
| `filament-4`  | `ci-filament-4.yml`   | Laravel/Filament — frozen legacy branch only |
| `laravel`     | `ci-laravel.yml`      | Laravel/Filament                             |
| `php-library` | `ci-php-library.yml`  | Plain PHP (phpstan, Pest — no Laravel deps)  |

`filament-5` still works as a deprecated alias for `filament`. It predates the
shared-branch normalization, when each Filament major had its own branch; one branch now
serves them all from a single caller with a combined matrix.

It copies the config templates (including `.github/dependabot.yml`), merges the canonical
`require-dev` / `scripts` / `allow-plugins` into `composer.json`, and drops in the caller
workflow. Existing files are left alone unless you pass `--force`. Then finish the
judgement-heavy steps by hand (steps 5–6 below, plus the matrix/baseline tuning).

### Manually

1. Copy `templates/pint.json`, `rector.php`, `phpstan.neon.dist`, `phpstan-baseline.neon`
   (for a plain PHP library use `templates/phpstan-php-library.neon.dist` instead).
2. Merge the `require-dev` + `scripts` from `templates/composer-snippets.md`.
3. Copy `templates/dependabot.yml` to `.github/dependabot.yml`.
4. Drop a caller from `templates/callers/` into `.github/workflows/`. For a Filament
   plugin, replace the `<active-branch>` placeholder with the repo's active branch, then
   adjust the matrix.
5. Delete the old `tests.yml` / `lint.yml` / static-analysis workflows.
6. Update branch-protection required checks to the intent names.

After either path: `composer update`, run `vendor/bin/phpstan analyse --generate-baseline`,
then flip `run-static-analysis: true` in the caller.

See `docs/package-migration.md` for the full checklist.

## AI-assisted setup

Run an agent (e.g. Claude Code) **from inside a package repo** and paste the prompt below.
It works for both a fresh setup and updating a package already on the shared CI — the agent
reads the canonical templates and checklist straight from `awcodes/.github`.

```text
You are working inside a PHP package repository. Onboard it onto — or update it to — the
shared CI baseline defined in the awcodes/.github repository.

1. Pull the canonical instructions and templates from awcodes/.github
   (`gh repo clone awcodes/.github /tmp/awcodes-github`, or read the raw GitHub files):
   - docs/package-migration.md   the full checklist (source of truth)
   - README.md                   Quick start + package types
   - templates/                  pint.json, rector.php, phpstan configs, composer-snippets.md
   - templates/callers/          example caller workflows
   - bin/bootstrap-package.sh    scaffolds the mechanical steps

2. Determine this package's type from composer.json `require`:
   filament/filament or filament/forms -> filament, laravel/illuminate deps but no
   Filament -> laravel, otherwise -> php-library. Filament plugins are single-branch and
   carry a constraint like "^4.0|^5.0", so they get ONE ci.yml whose matrix pins filament
   per row, not a caller per major.

3. Apply the mechanical steps — either run
   `/tmp/awcodes-github/bin/bootstrap-package.sh . --type <type>` or do it by hand:
   - Copy the config templates (use phpstan-php-library.neon.dist for a plain PHP library),
     including templates/dependabot.yml -> .github/dependabot.yml.
   - Merge the canonical require-dev / scripts / config.allow-plugins into composer.json,
     preserving existing package-specific dev deps. Do NOT change the runtime `require` block.
   - Add the matching caller workflow under .github/workflows/, referencing @v1.

4. Replace <active-branch> in the caller with this repo's active branch (1.x/2.x/3.x/4.x/
   5.x/main — read it, do not assume), and tune the matrix to the versions this package
   actually supports. Check TRANSITIVE dependency constraints, and confirm
   orchestra/testbench allows ^11.0 before keeping the Laravel 13 rows. For a plugin that
   requires filament/forms rather than the panel package, set `filament-package:
   filament/forms` on the caller.

5. Run `composer update`, then `vendor/bin/phpstan analyse --generate-baseline`; commit the
   baseline and set `run-static-analysis: true`. Confirm `composer test` passes.

6. Delete the old tests.yml / lint.yml / static-analysis workflows.

7. If updating an existing setup, treat step 3 as a reconcile: refresh templates, bump dep
   versions to the canonical set, and align the caller matrix — show me the diffs first.

8. Summarize what changed and flag anything needing my decision (matrix rows; branch-
   protection required checks: Tests, Lint, Static Analysis, Reformat). Open a PR.
```
