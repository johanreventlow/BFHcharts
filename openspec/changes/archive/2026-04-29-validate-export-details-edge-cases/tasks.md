## 1. Validation gate

- [x] 1.1 In `bfh_generate_details()` (`R/export_details.R:51`), add validation before `min`/`max` calls:
  Implemented with type-dispatch: Date/POSIXct/POSIXlt → `any(!is.na(x))`, numeric → `any(is.finite(x))`.
  Raises `bfhcharts_config_error` via `stop_config_error()`.
- [x] 1.2 Compute range only on validated subset
  min/max called on original qic_data$x with `na.rm = TRUE` after gate (unchanged happy-path behavior).
- [x] 1.3 Apply same gate to any other columns used for date-range or numeric-range in details (verify with grep)
  Only `bfh_generate_details()` in `R/export_details.R` uses x-range; `format_centerline_for_details()` is single-value (already NA-guarded). No other changes needed.

## 2. Tests

- [x] 2.1 Test: `qic_data$x = numeric(0)` → `bfh_generate_details()` errors with informative message
- [x] 2.2 Test: `qic_data$x = c(NA, NA, NA)` → errors
- [x] 2.3 Test: `qic_data$x = c(NA, NA, NA, Inf)` → errors (Inf is not finite/parseable for date)
- [x] 2.4 Test: `qic_data$x = c(NA, as.Date("2025-01-01"))` → succeeds, range = single date
- [x] 2.5 Test: valid date range → unchanged behavior (regression baseline)
- [x] 2.6 Test: integration with `bfh_export_pdf()`: empty data frame → error from `bfh_generate_details` propagates with `bfhcharts_*` condition class

## 3. Documentation

- [x] 3.1 Roxygen `@details` for `bfh_generate_details()`: document the fail-early contract
- [x] 3.2 NEWS entry under `## Bug fixes`

## 4. Cross-repo

- [ ] 4.1 Verify biSPCharts `bfh_export_pdf()` error-handler catches the new error path cleanly
  (Out of scope for this worktree — requires biSPCharts maintainer coordination)

## 5. Release

- [x] 5.1 PATCH bump (0.10.5 → 0.10.6)
- [x] 5.2 `devtools::test()` clean (FAIL 0 | WARN 0 | SKIP 0 | PASS 41 for generate_details filter)
- [ ] 5.3 `devtools::check()` clean (not run — full check requires more time; run before merge)
