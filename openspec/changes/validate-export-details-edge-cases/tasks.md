## 1. Validation gate

- [ ] 1.1 In `bfh_generate_details()` (`R/export_details.R:51`), add validation before `min`/`max` calls:
  ```r
  finite_x <- x[is.finite(x) | (inherits(x, "Date") & !is.na(x))]
  if (length(finite_x) == 0) stop("bfh_generate_details(): qic_data$x has no finite values")
  ```
- [ ] 1.2 Compute range only on validated subset
- [ ] 1.3 Apply same gate to any other columns used for date-range or numeric-range in details (verify with grep)

## 2. Tests

- [ ] 2.1 Test: `qic_data$x = numeric(0)` → `bfh_generate_details()` errors with informative message
- [ ] 2.2 Test: `qic_data$x = c(NA, NA, NA)` → errors
- [ ] 2.3 Test: `qic_data$x = c(NA, NA, NA, Inf)` → errors (Inf is not finite/parseable for date)
- [ ] 2.4 Test: `qic_data$x = c(NA, as.Date("2025-01-01"))` → succeeds, range = single date
- [ ] 2.5 Test: valid date range → unchanged behavior (regression baseline)
- [ ] 2.6 Test: integration with `bfh_export_pdf()`: empty data frame → error from `bfh_generate_details` propagates with `bfhcharts_*` condition class

## 3. Documentation

- [ ] 3.1 Roxygen `@details` for `bfh_generate_details()`: document the fail-early contract
- [ ] 3.2 NEWS entry under `## Bug fixes`

## 4. Cross-repo

- [ ] 4.1 Verify biSPCharts `bfh_export_pdf()` error-handler catches the new error path cleanly

## 5. Release

- [ ] 5.1 PATCH bump
- [ ] 5.2 `devtools::test()` clean
- [ ] 5.3 `devtools::check()` clean
