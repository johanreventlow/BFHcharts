## Why

`bfh_extract_spc_stats.bfh_qic_result()` (`R/utils_spc_stats.R:143-150`) hardcodes "last 6 observations" as the recency window for outlier reporting:

```r
n_obs <- nrow(qd)
recent_start <- max(1, n_obs - 5)
stats$outliers_recent_count <- sum(qd$sigma.signal[recent_start:n_obs], na.rm = TRUE)
```

The constant 6 is undocumented (no rationale comment, no Anhøj literature reference for this specific window) and untested at boundaries. Fallback analysis text (`inst/i18n/da.yaml`, `spc_analysis.yml`) hardcodes the phrasing "seneste 6 observationer" to match.

**Concrete risks:**
- Part with n_obs = 1: returns 1-row window, fallback text still says "seneste 6 observationer" → misleading
- Part with n_obs = 5: returns 5-row window, fallback says "6" → misleading
- No test verifies behavior at n_obs boundaries (1, 5, 6, 7)
- Window cannot be configured by downstream packages with different clinical conventions

## What Changes

- Add named constant `RECENT_OBS_WINDOW <- 6L` in `R/globals.R` with rationale comment
- Replace hardcoded `5` (n_obs - 5) with `RECENT_OBS_WINDOW - 1L` in `bfh_extract_spc_stats.bfh_qic_result()`
- Add `effective_window` field to stats output: equals `min(RECENT_OBS_WINDOW, n_obs)` so downstream callers know the actual window used
- Update fallback text generation (`R/spc_analysis.R` + i18n YAML) to use `{effective_window}` placeholder instead of hardcoded "6"
- Add 5 new boundary tests
- Document constant choice in `globals.R` Roxygen and in `bfh_extract_spc_stats` Roxygen

## Impact

**Affected specs:**
- `spc-analysis-api` — MODIFIED requirement on outliers_recent_count contract; ADDED requirement for effective window reporting

**Affected code:**
- `R/globals.R` — add `RECENT_OBS_WINDOW` constant
- `R/utils_spc_stats.R:143-150` — use constant
- `R/spc_analysis.R` — wire effective_window into placeholder data
- `inst/i18n/da.yaml` + `inst/i18n/en.yaml` — replace hardcoded "6" with `{effective_window}` placeholder in outlier-text variants
- `tests/testthat/test-anhoej-precision.R` or new `test-outliers-recent-count.R` — add boundary tests
- NEWS entry under `## Bug fixes` or `## Forbedringer`

**Not breaking:**
- Behavior unchanged for `n_obs >= 6` (same window)
- Adds `effective_window` field (additive)
- i18n templates take new placeholder; falls back gracefully if not all translations updated

## Cross-repo impact (biSPCharts)

**Verification:**
```bash
# I biSPCharts:
grep -rn "outliers_recent_count\|seneste 6" R/ inst/
```

**Expected impact:** none — biSPCharts likely consumes the field via `bfh_extract_spc_stats()` API. New `effective_window` field is additive.

**biSPCharts version bump:** none required.

## Related

- GitHub Issue: #207
- Source: BFHcharts code review 2026-04-27, Claude finding #5
