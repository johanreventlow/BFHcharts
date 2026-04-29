## 1. Constant + helper

- [ ] 1.1 Add `RECENT_OBS_WINDOW <- 6L` to `R/globals.R` with rationale comment
- [ ] 1.2 Reference constant from `R/utils_spc_stats.R:143-150` instead of literal `5`
- [ ] 1.3 Add `stats$effective_window <- min(RECENT_OBS_WINDOW, n_obs)` to outputs

## 2. Tests

- [ ] 2.1 Create or extend `tests/testthat/test-outliers-recent-count.R`
- [ ] 2.2 Test: n_obs = 1 → effective_window = 1, count counts only that single obs
- [ ] 2.3 Test: n_obs = 5 → effective_window = 5, count covers all 5
- [ ] 2.4 Test: n_obs = 6 → effective_window = 6, count covers all 6
- [ ] 2.5 Test: n_obs = 7 → effective_window = 6, count covers last 6
- [ ] 2.6 Test: n_obs = 100, outliers concentrated at start → effective_window = 6, count = 0 (none in last 6)
- [ ] 2.7 Test: empty sigma.signal → outliers_recent_count = 0, effective_window = 0

## 3. i18n templates

- [ ] 3.1 Update `inst/i18n/da.yaml` outlier text variants to use `{effective_window}` placeholder
- [ ] 3.2 Update `inst/i18n/en.yaml` similarly
- [ ] 3.3 Wire `effective_window` into placeholder_data in `R/spc_analysis.R`
- [ ] 3.4 Verify fallback text reads naturally for n=1, n=5, n=6 cases

## 4. Documentation

- [ ] 4.1 Roxygen for `RECENT_OBS_WINDOW` explaining choice and configurability future-direction
- [ ] 4.2 Update `bfh_extract_spc_stats()` Roxygen `@return` describing effective_window
- [ ] 4.3 NEWS entry under `## Bug fixes` (or `## Forbedringer`)

## 5. Cross-repo

- [ ] 5.1 Grep biSPCharts for any hardcoded references
- [ ] 5.2 Verify no breaking impact

## 6. Release

- [ ] 6.1 PATCH bump (additive, non-breaking)
- [ ] 6.2 Tests pass
- [ ] 6.3 `devtools::check()` clean

Tracking: GitHub Issue #207
