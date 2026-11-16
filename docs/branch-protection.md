# Branch protection

The four CI jobs are advisory until a ruleset requires them. This page covers what to
require and how to set it up.

## Require `All Checks`, not the four job names

The reusable workflows expose five jobs. Four are the work; the fifth exists solely to
be the required check:

| Job | Check name | Stable? |
|---|---|---|
| `tests` | `ci / Tests (8.5, 13.*, 5.*, 11.*, prefer-stable)` | **No** — one per matrix row |
| `lint` | `ci / Lint` | Yes |
| `static-analysis` | `ci / Static Analysis` | Yes |
| `reformat` | `ci / Reformat` | Yes |
| `all-checks` | `ci / All Checks` | Yes |

`Tests` runs `strategy.matrix.include: ${{ fromJson(inputs.matrix) }}`, so GitHub
publishes one check per row and names it after the row's values. Those names differ per
package, differ per branch, and change whenever a matrix row is added or dropped —
requiring them by name means re-editing the ruleset after every matrix edit, and a
ruleset naming a check that no longer exists blocks every PR forever.

`all-checks` aggregates the other four with `needs:` and `if: always()`. It is one name,
identical in every package, unaffected by matrix shape. **Require that one.**

A job disabled through its `run-*` input reports `skipped`, which `all-checks` treats as
a pass — so a package with `run-static-analysis: false` still goes green. `failure` and
`cancelled` do not pass.

`ci` in the check names above is the caller's job id. If your caller names its job
something else, the prefix changes with it; keep it `ci`.

## Setting it up

Per repo, on the active branch:

```bash
REPO=awcodes/<remote-name>          # read it, don't guess — folder names differ
BRANCH=$(gh api "repos/$REPO" --jq .default_branch)

gh api -X POST "repos/$REPO/rulesets" \
  -f name='Require CI' -f target=branch -f enforcement=active \
  -F "conditions[ref_name][include][]=~DEFAULT_BRANCH" \
  -f 'rules[][type]=required_status_checks' \
  -F 'rules[][parameters][strict_required_status_checks_policy]=false' \
  -f 'rules[][parameters][required_status_checks][][context]=ci / All Checks'
```

## No Dependabot auto-merge

The fleet used to ship a `dependabot-auto-merge.yml` that queued minor and patch
Dependabot PRs with `gh pr merge --auto`. It was removed in November 2026:

- It merged about five PRs fleet-wide in three months, because grouping and cooldowns
  keep Dependabot volume low.
- It ran on `pull_request_target` with `contents: write` in every package.
- It was only safe while two settings outside the repo held: this ruleset, and
  `allow_auto_merge`. Without the required check it merged Dependabot PRs on arrival,
  with no CI.

Merge Dependabot PRs by hand once `All Checks` passes. Every package's CI path filters
include `.github/dependabot.yml`, so config-only PRs run CI too. Keep the ruleset: it
still blocks a red or unfinished PR from merging. Leave `allow_auto_merge` off.
