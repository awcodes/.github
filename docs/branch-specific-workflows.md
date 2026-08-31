# Branch-Specific Caller Workflows

**The default is one caller file, on one branch.** This document covers when that is not
enough — which, since the shared-branch normalization, is the exception rather than the
rule.

## The normal case: one branch, one caller, both majors

A Filament plugin serves every supported major from a single branch, with a constraint
like:

```json
"filament/filament": "^4.0|^5.0"
```

So it gets one caller, scoped to its one active branch, and the matrix pins `filament` per
row:

```
.github/workflows/ci.yml   # on: { branches: [<active-branch>] }
```

```yaml
matrix: |
  [
    {"php":"8.5","laravel":"13.*","filament":"5.*","testbench":"11.*","dependencies":"prefer-stable"},
    {"php":"8.4","laravel":"13.*","filament":"5.*","testbench":"11.*","dependencies":"prefer-stable"},
    {"php":"8.5","laravel":"12.*","filament":"5.*","testbench":"10.*","dependencies":"prefer-stable"},
    {"php":"8.4","laravel":"12.*","filament":"5.*","testbench":"10.*","dependencies":"prefer-stable"},
    {"php":"8.3","laravel":"12.*","filament":"5.*","testbench":"10.*","dependencies":"prefer-stable"},
    {"php":"8.4","laravel":"12.*","filament":"4.*","testbench":"10.*","dependencies":"prefer-stable"},
    {"php":"8.3","laravel":"12.*","filament":"4.*","testbench":"10.*","dependencies":"prefer-stable"}
  ]
```

**The per-row `filament` pin is the whole point.** A matrix without it resolves the newest
major on every row under `prefer-stable`, so the `^4.0` half of the constraint is never
executed and a break against the older major ships unnoticed. This is exactly what a
hand-rolled `tests.yml` that only pins `laravel/framework` and `orchestra/testbench` gets
wrong.

The active branch name varies per package — `1.x` through `5.x`, or `main`. Read it from
the repo; do not assume `main`. Start from `templates/callers/ci-filament.yml` and replace
the `<active-branch>` placeholder.

### Form-only plugins

A plugin that requires `filament/forms` rather than the panel package should set:

```yaml
filament-package: filament/forms
```

Otherwise the matrix pins `filament/filament`, which resolves — the panel package
constrains its components to the same major — but installs the entire panel into the test
app to constrain one component.

## The exception: a frozen legacy branch

Sometimes an older major keeps its own branch after the active branch has moved on — for
example curator's `4.x`, still maintained while `5.x` serves both 4 and 5. A frozen branch
that still needs CI gets its own caller, scoped to it:

```
.github/workflows/ci.yml               # on: { branches: [5.x] }   ← active, both majors
.github/workflows/ci-filament-4.yml    # on: { branches: [4.x] }   ← frozen legacy
```

Because each file's `on:` is scoped to its own branch, a `4.x` → `5.x` forward merge is
harmless: the legacy caller lands on `5.x` but never runs there. That is the only problem
the two-file split ever solved, and it only arises when a forward merge actually happens.

See `templates/callers/ci-filament-4.yml` for a starting point.

## Why the two-caller pattern is no longer the default

It predates the shared-branch normalization, when each Filament major had its own branch
and its own CI config, and a single `ci.yml` had to be hand-preserved across every forward
merge. With one active branch per package there is no forward merge to defend against, and
two callers would give each major *less* coverage than one combined matrix does — each
file would only ever run on the branch it is scoped to.

If you are looking at a package with `ci-filament-4.yml` and `ci-filament-5.yml` side by
side on the same active branch, that is a pre-normalization leftover. Collapse it into one
`ci.yml` with the combined matrix.

## Laravel 11

Laravel 11 is intentionally omitted from CI while remaining installable for consumers via
`orchestra/testbench: ^9.0` in `composer.json`.
