# Workflow Versioning

Package repos must consume reusable workflows and composite actions by a **major tag**,
never from `main`.

```yaml
# Do NOT do this — a breaking change to main breaks every package at once:
uses: awcodes/.github/.github/workflows/filament-plugin.yml@main

# Do this:
uses: awcodes/.github/.github/workflows/filament-plugin.yml@v1
```

## Tag strategy

- Moving major tags for packages to track: `v1`, `v2`, `v3`.
- Immutable release tags for reference: `v1.0.0`, `v1.1.0`, …

Packages pin the major (`@v1`). When you cut a new release, move the `v1` tag forward to
the new commit so all packages pick it up:

```bash
git tag -f v1
git push origin v1 --force
```

## What counts as breaking

Bump to a new major (`v2`) when a change would fail existing callers, e.g.:

- Renaming or removing a workflow input.
- Renaming a job (changes the required-check name → breaks branch protection).
- Changing a composite action's required inputs.

Additive changes (new optional inputs with defaults, new toggles) stay within the current
major.
