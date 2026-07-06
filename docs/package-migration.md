# Package Migration Checklist

One PR per package. Normalize the tooling baseline (Layer B) and switch to shared CI
(Layer A) together.

## 1. Classify

- [ ] Package type: Filament plugin · Laravel package · PHP library
- [ ] Needs Node / asset build? (`run-build`)
- [ ] Multiple active Filament branches? (needs branch-scoped callers)
- [ ] Note current branch-protection required checks (to update at the end)

## 2. Normalize tooling (Layer B)

- [ ] Copy `templates/pint.json`, `rector.php`, `phpstan.neon.dist`, `phpstan-baseline.neon`
- [ ] Merge `require-dev` + `scripts` from `templates/composer-snippets.md`
  - [ ] Add `rector/rector` if missing (e.g. `gtm`)
  - [ ] Add `larastan/larastan` if missing
  - [ ] Set `orchestra/testbench` to `^9.0|^10.0|^11.0`
  - [ ] Set `nunomaduro/collision` to `^8.0`
  - [ ] Set Pest + plugins to `^4.0`
- [ ] **Do not** change the runtime `require` block — keep `"php": "^8.2"` so Laravel 11
      stays installable
- [ ] `composer update` locally and generate the baseline:
      `vendor/bin/phpstan analyse --generate-baseline`
- [ ] `composer test` passes locally (refactor + lint + types + unit)

## 3. Switch to shared CI (Layer A)

- [ ] Add branch-scoped caller(s) from `templates/callers/`, referencing `@v1`
- [ ] Set explicit matrix rows for the versions this branch supports
- [ ] Set `run-static-analysis: true` once the baseline is committed (else leave `false`)
- [ ] Set `run-build: true` for asset-building packages
- [ ] Delete old `tests.yml`, `lint.yml`, and any static-analysis workflow
- [ ] Remove the old auto-format-on-merge `lint.yml` (replaced by the `Reformat`/`Lint`
      checks)

## 4. Validate

- [ ] Push a branch; the caller triggers the reusable workflow
- [ ] `Tests`, `Lint`, `Static Analysis`, `Reformat` report as separate checks
- [ ] A README-only change skips CI (path filters)
- [ ] Matrix rows match the intended set; Composer installs; all checks green

## 5. Finalize

- [ ] Update branch-protection required checks to: `Tests`, `Lint`, `Static Analysis`,
      `Reformat`
- [ ] Update `CONTRIBUTING.md` (note the shared CI + local `composer lint` / `refactor`)
- [ ] Merge

## Suggested order

Plain PHP libraries → Laravel packages → simple Filament plugins → complex Filament
plugins → multi-branch Filament plugins.
