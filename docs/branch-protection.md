# Branch protection and auto-merge

The four CI jobs are advisory until a ruleset requires them. This page covers what to
require, and why the Dependabot auto-merge template is unsafe without it.

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

gh api -X PATCH "repos/$REPO" -F allow_auto_merge=true
```

Both halves are required, and they do different jobs:

- **The ruleset** is the safety. It is what makes a PR un-mergeable while CI is running
  or red.
- **`allow_auto_merge`** is not a safety switch. It only decides whether a PR that is
  blocked can sit in a queue and merge itself later, instead of the merge attempt
  failing outright.

## Why auto-merge needs the ruleset

`gh pr merge --auto` asks GitHub to merge the PR *once whatever is blocking it clears*.
If nothing is blocking it, that condition is already satisfied when the PR opens, and
the merge happens immediately — no CI, no wait.

So the combinations are:

| `allow_auto_merge` | Required check | Result |
|---|---|---|
| off | none | Merges instantly, ungated |
| on | none | Nothing to wait for — still merges instantly |
| off | yes | Cannot queue; the step fails and the PR stays open |
| on | yes | Queues, waits for green, merges itself |

Only the last row is the intended behaviour. Ship
`templates/dependabot-auto-merge.yml` into a repo only once that repo is in it.

Note that turning `allow_auto_merge` on does not make anything more permissive than it
already is: with no required check, the workflow merges regardless. The ruleset is the
change that matters.
