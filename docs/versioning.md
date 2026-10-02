# Workflow Versioning

Package repos consume the reusable workflows by a **release commit SHA** with a trailing
`# vX.Y.Z` comment. They never use `main` or the moving `v1` tag.

```yaml
# Do NOT do this — a breaking change to main breaks every package at once:
uses: awcodes/.github/.github/workflows/filament-plugin.yml@main

# Do NOT do this either — anyone who can move the tag changes what every package runs:
uses: awcodes/.github/.github/workflows/filament-plugin.yml@v1

# Do this:
uses: awcodes/.github/.github/workflows/filament-plugin.yml@ad63f1536b965fed92274516cb81f172b1d60e1a # v1.4.3
```

A reference into another repository is not covered by the calling repository's branch
rules: this repo has its own collaborators and its own tag settings. A SHA is the only ref
that cannot be moved under a package, and it is what PlumbPHP's
[actions-sha-pinned](https://plumbphp.dev/checks/security/actions-sha-pinned) check expects.
The caller templates in `templates/callers/` ship with the current pin.

## Tag strategy

- **Immutable release tags: `v1.0.0`, `v1.1.0`, …** Dependabot reads these. It moves each
  package's pin, and its `# vX.Y.Z` comment, to the newest one.
- **Moving major tags: `v1`, `v2`, …** Packages no longer track these, but the reusable
  workflows still do. They call this repo's composite actions as
  `awcodes/.github/actions/<name>@v1`, and that nested ref is resolved on its own: a caller
  pinned to a SHA still gets whatever `v1` points at for the actions. So `v1` has to keep
  moving.

Never delete a release tag or rewrite history that one points into. Packages are pinned to
those commits, and CI breaks if a pinned commit becomes unreachable.

## Cutting a release

Every release needs all three steps:

```bash
# 1. Immutable release tag. This is what Dependabot offers to every package.
git tag -a v1.5.0 -m "…"
git push origin v1.5.0

# 2. Move the major tag the reusable workflows use for the composite actions.
git tag -f v1
git push origin v1 --force

# 3. Update the pin in templates/callers/*.yml to the new commit and `# v1.5.0`. Dependabot
#    does not scan templates/, so new packages would otherwise start on an old release.
```

Skipping step 1 is silent: no package is ever offered the release. Skipping step 2 is also
silent: packages that take the bump run the new workflows with the old composite actions.
Check with:

```bash
git rev-parse v1 v1.5.0   # same commit, or the tag did not move
```

### What reaches packages, and when

- **Workflow changes** reach a package only when it merges the Dependabot bump. The
  package's 7-day cooldown applies, and `dependabot-auto-merge.yml` merges minor and patch
  bumps once `All Checks` passes. A major bump is never auto-merged.
- **Composite-action changes** reach every package as soon as `v1` moves (step 2), whatever
  SHA the package is pinned to. Treat an action change with that in mind.
- **Docs- or template-only changes** need no release. A tag with no workflow change behind
  it still opens a bump PR in every package. That is noise; leave such changes untagged.

## What counts as breaking

Bump to a new major (`v2`) when a change would fail existing callers, e.g.:

- Renaming or removing a workflow input.
- Renaming a job (changes the required-check name → breaks branch protection).
- Changing a composite action's required inputs.

Additive changes (new optional inputs with defaults, new toggles) stay within the current
major.

## Two pinning strategies, both SHA

- **Packages → this repo: release commit SHA.** Pinned with a `# vX.Y.Z` comment and kept
  current by each package's Dependabot (`templates/dependabot.yml`). That template does
  **not** ignore `awcodes/.github/*`. Earlier versions of it did, because the caller then
  tracked `@v1`. If a package still carries that `ignore` rule, remove it, or its pin is
  frozen for good.
- **This repo → third-party actions: full commit SHA.** Leaf actions
  (`actions/checkout`, `actions/cache`, `actions/setup-node`, `shivammathur/setup-php`) are
  pinned to a full SHA with a trailing `# vX.Y.Z` comment for supply-chain safety. Dependabot
  (`.github/dependabot.yml`) bumps the SHA and keeps the comment current.
