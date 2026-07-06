# Branch-Specific Caller Workflows

Some packages keep multiple active branches for different Filament majors:

```
4.x  -> Filament 4
5.x  -> Filament 5
main -> current major
```

The normal flow is to make a change on the older branch (`4.x`) and merge it forward into
the newer branch (`5.x`). The risk: a change to a single `ci.yml` on `4.x` merges forward
and clobbers the `5.x` CI config.

## Solution: one caller file per branch, scoped by branch

Instead of a single `ci.yml`, use separate files scoped to their branch:

```
.github/workflows/ci-filament-4.yml   # on: { branches: [4.x] }
.github/workflows/ci-filament-5.yml   # on: { branches: [5.x, main] }
```

Because each file's `on:` is scoped to its branch, merging `ci-filament-4.yml` forward
into `5.x` is harmless — it will not run there. Code flows forward; workflow execution
stays branch-specific. You no longer have to hand-preserve a single `ci.yml` on every
merge.

See `templates/callers/ci-filament-4.yml` and `ci-filament-5.yml` for starting points.

## Matrix per branch

Each caller declares only the combinations that branch supports (explicit rows, no
`exclude`). Example:

- **`ci-filament-4.yml`** → Filament `4.*` on Laravel `12.*` (PHP 8.3/8.4).
- **`ci-filament-5.yml`** → Filament `5.*` on Laravel `13.*`/`12.*` (PHP 8.3–8.5, with L13
  starting at PHP 8.4).

Laravel 11 is intentionally omitted from CI while remaining installable via
`composer.json` (testbench `^9.0`).
