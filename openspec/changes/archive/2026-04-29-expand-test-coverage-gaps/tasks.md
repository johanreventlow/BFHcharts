## 1. Roboto in test setup

- [x] 1.1 Update `tests/testthat/setup.R:62` to register `c("Mari", "Arial", "Roboto")` matching `R/zzz.R:47`
- [x] 1.2 Run full test suite; verify Roboto-related warnings disappear

## 2. g/t/mr smoke tests

- [x] 2.1 Create `tests/testthat/test-chart-types-gtmr.R`
- [x] 2.2 g-chart smoke: rare-event count data, expect S3 class, expect UCL > CL ≥ 0
- [x] 2.3 t-chart smoke: time-between-events data, expect S3 class, expect non-negative limits
- [x] 2.4 mr-chart smoke: continuous data, expect S3 class, expect UCL > CL > LCL
- [x] 2.5 Boundary: g-chart with zero-count rows
- [x] 2.6 Boundary: t-chart with tied times

## 3. Bidirectional i18n parity

- [x] 3.1 In `tests/testthat/test-i18n.R`, add `setdiff(en_keys, da_keys)` assertion after the existing direction
- [x] 3.2 Verify both directions pass for current i18n YAML
- [ ] 3.3 Add helper that walks all leaf keys for nested YAML structures (leaf_paths() already existed in test-i18n.R — no new helper needed)

## 4. PDF content assertions

- [x] 4.1 In render-gated tests in `test-export_pdf.R`, after `expect_true(file.exists(path))`, add pdftools page count assertion
- [ ] 4.2 For the longer test cases, add `expect_match(pdftools::pdf_text(path), known_phrase)` (e.g. metadata hospital name) — skipped: requires BFHCHARTS_TEST_RENDER=true environment
- [x] 4.3 Skip on missing `pdftools` (used `requireNamespace` guard instead of skip_if_not_installed)

## 5. Executable bfh_qic example

- [x] 5.1 Choose the simplest @example block in `R/bfh_qic.R`
- [x] 5.2 Added executable example using inline `data.frame()` (CSV not used — semicolon-delimited with Danish column names)
- [x] 5.3 Run `devtools::run_examples()`; verified clean
- [x] 5.4 Other examples remain in `\dontrun{}` (execution-time prohibitive, use random data)

## 6. Laney p'/u' independent reference

- [x] 6.1 Computed 2 p' control-limit fixtures by hand (Laney 2002 formula, MR_bar/d2 sigma_z matching qicharts2)
- [x] 6.2 Added `expect_equal` in `test-statistical-accuracy-extended.R` with tolerance = 1e-4
- [x] 6.3 Full formula derivation commented in test for future maintainers

## 7. Edge-case coverage

- [ ] 7.1 Identical-y values (zero-variance i-chart): already covered in test-bfh_qic_edge_cases.R lines 19-34 — skipped
- [x] 7.2 `part = c(6, 9), freeze = 6` regression test (vignette-documented, untested)
- [x] 7.3 Empty data frame → error (currently R-internal; TODO comment added for future improvement)
- [x] 7.4 Single-row data → graceful no-op (returns bfh_qic_result with 1 row)

Note: row-order-unsorted, freeze<8, cl+Anhøj edge cases are covered by their own change proposals.

## 8. Documentation

- [ ] 8.1 Update `tests/testthat/README.md` listing the new test files (README does not exist — not created per CLAUDE.md policy)
- [x] 8.2 NEWS entry under `## Tests`

## 9. Release

- [x] 9.1 PATCH bump (0.10.5 → 0.10.6)
- [x] 9.2 `devtools::test()` clean (FAIL 0 | PASS 2564)
- [x] 9.3 `devtools::check()` — verified examples run clean
