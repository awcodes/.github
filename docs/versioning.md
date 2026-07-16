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

## Two pinning strategies, on purpose

- **Packages → this repo: moving major tag (`@v1`).** Packages pin the caller to `@v1`, not a
  SHA, so a moved `v1` tag propagates CI fixes to every package at once. Do **not** SHA-pin
  the `awcodes/.github/...` caller ref — that would defeat the model above.
- **This repo → third-party actions: full commit SHA.** Leaf actions
  (`actions/checkout`, `actions/cache`, `actions/setup-node`, `shivammathur/setup-php`) are
  pinned to a full SHA with a trailing `# vX.Y.Z` comment for supply-chain safety. Dependabot
  (`.github/dependabot.yml`) bumps the SHA and keeps the comment current.

### Dependabot must ignore the caller

A package's `.github/dependabot.yml` has to exclude this repo from its `github-actions`
updates — `templates/dependabot.yml` ships that `ignore` rule:

```yaml
ignore:
  - dependency-name: "awcodes/.github/*"
```

Dependabot has no concept of a moving major. It reads `@v1` as version `1` and offers the
newest semver tag, so it opens PRs like *"Bump …/laravel-package.yml from 1 to 1.1.0"*.
Merging one pins the package to a snapshot and silently opts it out of the model above —
and it is often a **downgrade**, because `v1` moves ahead of the older release tags it
suggests. Moving to a new major is a deliberate migration, not a Dependabot bump.
