## 1. Roboto in test setup

- [ ] 1.1 Update `tests/testthat/setup.R:62` to register `c("Mari", "Arial", "Roboto")` matching `R/zzz.R:47`
- [ ] 1.2 Run full test suite; verify Roboto-related warnings disappear

## 2. g/t/mr smoke tests

- [ ] 2.1 Create `tests/testthat/test-chart-types-gtmr.R`
- [ ] 2.2 g-chart smoke: rare-event count data, expect S3 class, expect UCL > CL ≥ 0
- [ ] 2.3 t-chart smoke: time-between-events data, expect S3 class, expect non-negative limits
- [ ] 2.4 mr-chart smoke: continuous data, expect S3 class, expect UCL > CL > LCL
- [ ] 2.5 Boundary: g-chart with zero-count rows
- [ ] 2.6 Boundary: t-chart with tied times

## 3. Bidirectional i18n parity

- [ ] 3.1 In `tests/testthat/test-i18n.R`, add `setdiff(en_keys, da_keys)` assertion after the existing direction
- [ ] 3.2 Verify both directions pass for current i18n YAML
- [ ] 3.3 Add helper that walks all leaf keys for nested YAML structures

## 4. PDF content assertions

- [ ] 4.1 In render-gated tests in `test-export_pdf.R`, after `expect_true(file.exists(path))`, add `expect_equal(pdftools::pdf_info(path)$pages, expected_pages)`
- [ ] 4.2 For the longer test cases, add `expect_match(pdftools::pdf_text(path), known_phrase)` (e.g. metadata hospital name)
- [ ] 4.3 Skip on missing `pdftools` (already in Suggests)

## 5. Executable bfh_qic example

- [ ] 5.1 Choose the simplest @example block in `R/bfh_qic.R`
- [ ] 5.2 Replace `\dontrun{}` with executable code using `read.csv(system.file("extdata/spc_exampledata.csv", package = "BFHcharts"))`
- [ ] 5.3 Run `devtools::run_examples()`; verify clean
- [ ] 5.4 Other examples remain in `\dontrun{}` if execution-time prohibitive; document why

## 6. Laney p'/u' independent reference

- [ ] 6.1 Compute 2-3 p' and u' control-limit values by hand (Laney 2002 formula) for fixtures with known overdispersion
- [ ] 6.2 Add `expect_equal(result_ucl, hand_calculated_ucl, tolerance = 0.001)` in `test-statistical-accuracy-extended.R`
- [ ] 6.3 Comment the calculation in the test for future maintainers

## 7. Edge-case coverage

- [ ] 7.1 Identical-y values (zero-variance i-chart): expect graceful behavior (UCL = LCL = CL or warning)
- [ ] 7.2 `part = c(6, 9), freeze = 6` regression test (vignette-documented, untested)
- [ ] 7.3 Empty data frame → informative error
- [ ] 7.4 Single-row data → informative error or graceful no-op

Note: row-order-unsorted, freeze<8, cl+Anhøj edge cases are covered by their own change proposals.

## 8. Documentation

- [ ] 8.1 Update `tests/testthat/README.md` listing the new test files
- [ ] 8.2 NEWS entry under `## Tests`

## 9. Release

- [ ] 9.1 PATCH bump (additive)
- [ ] 9.2 `devtools::test()` clean
- [ ] 9.3 `devtools::check()` clean (especially run-examples now exercising one example)
