# awcodes/.github — Shared CI

Central reusable GitHub Actions workflows, composite actions, and canonical tooling
config for awcodes packages. Package repos consume these through thin, branch-scoped
caller workflows so CI logic lives in one place.

> **Local note:** this working copy lives in a folder named `workflows/`, but it is the
> `awcodes/.github` repository. All references use the `awcodes/.github` namespace.

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
  phpstan.neon.dist
  phpstan-baseline.neon
  composer-snippets.md      require-dev + scripts to merge into composer.json
  callers/                  Example branch-scoped caller workflows
    ci-filament-5.yml
    ci-filament-4.yml

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

1. Copy `templates/pint.json`, `rector.php`, `phpstan.neon.dist`, `phpstan-baseline.neon`.
2. Merge the `require-dev` + `scripts` from `templates/composer-snippets.md`.
3. Drop a caller from `templates/callers/` into `.github/workflows/`, adjust the matrix.
4. Delete the old `tests.yml` / `lint.yml` / static-analysis workflows.
5. Update branch-protection required checks to the intent names.

See `docs/package-migration.md` for the full checklist.
