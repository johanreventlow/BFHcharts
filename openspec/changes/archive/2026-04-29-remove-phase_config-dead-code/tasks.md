## 1. Removal

- [ ] 1.1 Remove `phase_config()` function from `R/config_objects.R`
- [ ] 1.2 Remove `print.phase_config()` method from `R/config_objects.R`
- [ ] 1.3 Remove `phase = NULL` parameter from `bfh_spc_plot()` signature in `R/plot_core.R:85`
- [ ] 1.4 Remove `phase_config` from `tests/testthat/test-config_objects.R` (~6 tests)

## 2. Documentation regeneration

- [ ] 2.1 Run `devtools::document()` — NAMESPACE auto-updates removing `S3method(print,phase_config)`
- [ ] 2.2 Remove `man/phase_config.Rd` (auto-removed by document())
- [ ] 2.3 Remove `man/print.phase_config.Rd` (auto-removed by document())
- [ ] 2.4 Update `R/config_objects.R` head Roxygen if it lists phase_config

## 3. Verification

- [ ] 3.1 `grep -rn "phase_config" R/ tests/` returns 0 hits
- [ ] 3.2 `devtools::test()` passes (one or two test files reduced)
- [ ] 3.3 `devtools::check()` clean
- [ ] 3.4 NAMESPACE diff matches expectations

## 4. Cross-repo

- [ ] 4.1 Grep biSPCharts for `phase_config` references
- [ ] 4.2 If hits found: companion PR to remove

## 5. Documentation

- [ ] 5.1 NEWS entry under `## Interne ændringer` (or `## Code cleanup`)
- [ ] 5.2 Note in changelog that phase_config was scaffolded but never wired in

## 6. Release

- [ ] 6.1 PATCH bump (internal-only removal)
- [ ] 6.2 Tests pass

Tracking: GitHub Issue #216
