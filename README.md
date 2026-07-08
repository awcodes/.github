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
  callers/                  Example caller workflows
    ci-filament-5.yml
    ci-filament-4.yml
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

`--type` (default `filament-5`) selects the tooling profile and caller workflow:

| `--type`      | Caller                | Tooling profile                             |
| ------------- | --------------------- | ------------------------------------------- |
| `filament-5`  | `ci-filament-5.yml`   | Laravel/Filament (larastan, testbench, Pest)|
| `filament-4`  | `ci-filament-4.yml`   | Laravel/Filament                            |
| `laravel`     | `ci-laravel.yml`      | Laravel/Filament                            |
| `php-library` | `ci-php-library.yml`  | Plain PHP (phpstan, Pest — no Laravel deps) |

It copies the config templates, merges the canonical `require-dev` / `scripts` /
`allow-plugins` into `composer.json`, and drops in the caller workflow. Existing files are
left alone unless you pass `--force`. Then finish the judgement-heavy steps by hand (steps
1–2 and 4–5 below).

### Manually

1. Copy `templates/pint.json`, `rector.php`, `phpstan.neon.dist`, `phpstan-baseline.neon`
   (for a plain PHP library use `templates/phpstan-php-library.neon.dist` instead).
2. Merge the `require-dev` + `scripts` from `templates/composer-snippets.md`.
3. Drop a caller from `templates/callers/` into `.github/workflows/`, adjust the matrix.
4. Delete the old `tests.yml` / `lint.yml` / static-analysis workflows.
5. Update branch-protection required checks to the intent names.

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
   filament/filament -> filament-5 (or filament-4), laravel/illuminate deps but no
   Filament -> laravel, otherwise -> php-library.

3. Apply the mechanical steps — either run
   `/tmp/awcodes-github/bin/bootstrap-package.sh . --type <type>` or do it by hand:
   - Copy the config templates (use phpstan-php-library.neon.dist for a plain PHP library).
   - Merge the canonical require-dev / scripts / config.allow-plugins into composer.json,
     preserving existing package-specific dev deps. Do NOT change the runtime `require` block.
   - Add the matching caller workflow under .github/workflows/, referencing @v1.

4. Tune the caller matrix to the versions this package actually supports.

5. Run `composer update`, then `vendor/bin/phpstan analyse --generate-baseline`; commit the
   baseline and set `run-static-analysis: true`. Confirm `composer test` passes.

6. Delete the old tests.yml / lint.yml / static-analysis workflows.

7. If updating an existing setup, treat step 3 as a reconcile: refresh templates, bump dep
   versions to the canonical set, and align the caller matrix — show me the diffs first.

8. Summarize what changed and flag anything needing my decision (matrix rows; branch-
   protection required checks: Tests, Lint, Static Analysis, Reformat). Open a PR.
```
