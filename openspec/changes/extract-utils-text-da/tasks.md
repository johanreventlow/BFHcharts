## 1. Branch + audit call sites

- [x] 1.1 Create branch `refactor/extract-utils-text-da` from current develop
- [x] 1.2 Enumerate all call sites: `grep -rn "pluralize_da\|pick_text\|substitute_placeholders\|pad_to_minimum\|ensure_within_max" R/ tests/`. Record all hits.
- [x] 1.3 Identify line ranges in `R/spc_analysis.R` for each helper to relocate (function definitions only, not callers)

## 2. Create `R/utils_text_da.R`

- [x] 2.1 Create new file `R/utils_text_da.R` with a brief file-header comment explaining purpose
- [x] 2.2 Copy all five helper definitions verbatim from `R/spc_analysis.R` into the new file, preserving roxygen blocks (`@param`, `@return`, `@keywords internal`, `@noRd`)
- [x] 2.3 Verify the new file passes `Rscript -e 'devtools::load_all()'` (no syntax errors, no missing dependencies)

## 3. Remove helpers from `R/spc_analysis.R`

- [x] 3.1 Delete the five helper definitions from `R/spc_analysis.R` (definitions only; callers remain)
- [x] 3.2 Verify file still parses: `Rscript -e 'parse("R/spc_analysis.R")'`
- [x] 3.3 Re-run `devtools::load_all()` and verify all callers resolve

## 4. Test verification

- [x] 4.1 Run targeted tests: `Rscript -e 'devtools::test(filter = "spc_analysis")'`. All existing tests covering the five helpers must pass without modification.
- [x] 4.2 Run full test suite: `Rscript -e 'Sys.setenv(NOT_CRAN="true"); devtools::test()'`. Zero failures.
- [x] 4.3 Run ASCII compliance: `Rscript -e 'devtools::test(filter = "source-ascii")'`. Pass required.

## 5. Polish + release prep

- [x] 5.1 Run `lintr::lint("R/utils_text_da.R")`. Zero new lint issues.
- [x] 5.2 Run `styler::style_file("R/utils_text_da.R")` and inspect diff
- [x] 5.3 Verify `R/spc_analysis.R` has shrunk by approximately 100-150 lines: `wc -l R/spc_analysis.R`
- [x] 5.4 Update NEWS.md under next version's `## Internal changes`: "Extract Danish text-formatting helpers (`pluralize_da`, `pick_text`, `substitute_placeholders`, `pad_to_minimum`, `ensure_within_max`) from `R/spc_analysis.R` into a dedicated `R/utils_text_da.R`. Pure relocation; no behavioral change."

## 6. Verification + PR

- [ ] 6.1 Run pre-push hook end-to-end: `git push -u origin refactor/extract-utils-text-da` (no `SKIP_PREPUSH` allowed)
- [ ] 6.2 Open PR `refactor/extract-utils-text-da` → develop with link to OpenSpec change folder
- [ ] 6.3 Verify CI green
- [ ] 6.4 After merge, archive change: `/opsx:archive extract-utils-text-da`
