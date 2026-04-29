## Why

Both review passes (Claude + Codex) identified concrete test-coverage gaps that affect production readiness:

1. **Test/production environment divergence (Roboto).** `R/zzz.R:47` registers `c("Mari", "Arial", "Roboto")` as font aliases at package load. `tests/testthat/setup.R:62` registers only `c("Mari", "Arial")`. PR #254 introduced Roboto support; the test setup was not updated. Tests that exercise Roboto code paths emit "font not found" warnings — exactly the warnings setup.R was written to suppress.

2. **g/t/mr chart types: zero test coverage.** `R/chart_types.R:21` includes `"g"` (geometric / rare events), `"t"` (time-between-events), `"mr"` (moving range). These use distinct control-limit formulas (g: negative-binomial; t: Weibull/exponential; mr: derived). No test in any file exercises them. g-charts for rare adverse events (falls, infections) are the package's highest-stakes use case.

3. **i18n parity check is unidirectional.** `tests/testthat/test-i18n.R:26` only checks `setdiff(da_keys, en_keys)`. Keys present in `en.yaml` but absent in `da.yaml` are never flagged. With `utils_i18n.R` falling back to "da" silently on lookup failure, a missing da key surfaces only as a missing translation at runtime.

4. **PDF export tests don't verify content.** `tests/testthat/test-export_pdf.R` checks `file.exists()` + size > 0 only. A Typst compilation that produces a valid-but-empty or corrupted PDF passes all current assertions.

5. **All `bfh_qic()` examples are wrapped in `\dontrun{}`.** `R CMD check` and `devtools::check()` never execute the public-API examples. Broken examples reach users without CI detection.

6. **pp/up Laney prime tests are cross-verified only against qicharts2 itself.** `tests/testthat/test-statistical-accuracy-extended.R` calls `qicharts2::qic()` directly and asserts BFHcharts matches. This catches BFHcharts/qicharts2 divergence but cannot catch a shared upstream formula bug.

7. **Edge cases for SPC behaviour are untested.** Identified in code review:
   - Unsorted x input (enables outliers_recent_count regression)
   - `freeze < 8` and `part`-phase < 8 (silently accepted today)
   - `cl`-override + Anhøj signals (no warning verification)
   - g-chart with 0-count periods, t-chart with tied times, mr end-to-end
   - Identical y values (zero-variance i-chart)
   - `part = c(6, 9) + freeze = 6` (vignette-documented, untested)

## What Changes

For each gap, add a test that exercises the missing surface. The work is bundled into a single change because the gaps share testing-infrastructure context (helpers, fixtures, snapshot files) and should land together for coherent coverage.

- Add "Roboto" to `tests/testthat/setup.R:62`
- Add g/t/mr smoke tests asserting `expect_s3_class(result, "bfh_qic_result")` and `UCL > CL > LCL`
- Add bidirectional i18n parity: `setdiff(en_keys, da_keys)` and `setdiff(da_keys, en_keys)`
- Add `pdftools::pdf_info(path)$pages == expected` assertion to render-gated PDF tests
- Convert at least one `bfh_qic()` `@example` from `\dontrun{}` to executable form (using `inst/extdata/spc_exampledata.csv`)
- Add 2-3 hand-calculated Laney p'/u' reference values to `test-statistical-accuracy-extended.R` (independent cross-check baseline)
- Add edge-case tests listed in (7) above

This change does NOT include the vdiffr CI fallback-font work; that lives in `add-pr-blocking-pdf-smoke-render`.

## Impact

**Affected specs:**
- `test-infrastructure` — MODIFIED requirement: i18n bidirectional parity; ADDED requirements for Roboto setup parity, g/t/mr coverage, PDF content assertion, runnable bfh_qic examples

**Affected code:**
- `tests/testthat/setup.R:62` — add "Roboto"
- `tests/testthat/test-i18n.R` — add reverse-direction setdiff
- `tests/testthat/test-export_pdf.R` + render-gated tests — pdftools assertions
- `tests/testthat/test-statistical-accuracy-extended.R` — Laney reference values
- `tests/testthat/test-bfh_qic_edge_cases.R` — new edge cases (or new file)
- New: `tests/testthat/test-chart-types-gtmr.R` — g/t/mr smoke
- New: `tests/testthat/test-row-order-invariance.R` — covered by `fix-outliers-recent-count-row-order` (cross-reference)
- `R/bfh_qic.R` — convert one example to executable
- NEWS entry under `## Tests`

**Not breaking:** Pure additive coverage.

## Related

- Claude findings B1, B3, B5, B7, B8 (test gaps); D1 (Roboto)
- Codex findings #1, #5 (vdiffr/test gate; warning gaps)
- Cross-references `fix-outliers-recent-count-row-order` for row-order edge cases
