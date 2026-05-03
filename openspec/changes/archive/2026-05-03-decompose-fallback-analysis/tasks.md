## 1. Branch + baseline verification

- [x] 1.1 Create branch `refactor/decompose-fallback-analysis` from current develop
- [x] 1.2 Verify pre-push hook passes on baseline (`PREPUSH_MODE=full git push --dry-run`)
- [x] 1.3 Capture baseline narrative output: run all existing `test-spc_analysis.R` scenarios via `Rscript -e 'devtools::test(filter = "spc_analysis")'` and save the test-output snapshot for comparison

## 2. Extract `.detect_signal_flags()`

- [x] 2.1 Add private helper `.detect_signal_flags(spc_stats)` in `R/spc_analysis.R` returning the documented named-logical struct
- [x] 2.2 Replace inline flag-detection block in `build_fallback_analysis()` with call to helper; bind result to local `flags`
- [x] 2.3 Add table-driven unit tests in `tests/testthat/test-spc_analysis.R` (or new file `test-fallback-dispatch.R`) covering all 8 flag combinations currently produced by the cascade
- [x] 2.4 Run targeted tests: `Rscript -e 'devtools::test(filter = "spc_analysis")'`. Must pass.

## 3. Extract `.allocate_text_budget()`

- [x] 3.1 Add private helper `.allocate_text_budget(max_chars, has_target)` returning named-integer struct
- [x] 3.2 Replace inline budget computation in orchestrator with call to helper
- [x] 3.3 Add unit tests covering: with-target budget split, without-target budget split, edge case max_chars=0
- [x] 3.4 Run targeted tests. Must pass.

## 4. Extract `.select_stability_key()`

- [x] 4.1 Add private helper `.select_stability_key(flags)` returning character scalar
- [x] 4.2 Replace stability-cascade arm in orchestrator with call to helper
- [x] 4.3 Add table-driven unit tests with one row per existing stability key (every output the current cascade can produce). Use `tibble` + `purrr::pmap()` pattern.
- [x] 4.4 Run targeted tests. Must pass.

## 5. Extract `.select_action_key()`

- [x] 5.1 Add private helper `.select_action_key(flags)` returning character scalar
- [x] 5.2 Replace action-cascade arm in orchestrator with call to helper
- [x] 5.3 Add table-driven unit tests with one row per existing action key (largest of the four cascades; expect ~10-15 rows)
- [x] 5.4 Run targeted tests. Must pass.
- [x] 5.5 Run integration test: `Rscript -e 'devtools::test(filter = "bfh_generate_analysis")'` — fallback-mode narrative must be byte-identical to baseline

## 6. Final orchestrator simplification

- [x] 6.1 Verify `build_fallback_analysis()` is ≤60 lines (count via `awk` over the function body)
- [x] 6.2 Remove dead inline comments referring to extracted blocks
- [x] 6.3 Run `lintr::lint("R/spc_analysis.R")`. Zero new lint issues vs baseline.
- [x] 6.4 Run `styler::style_file("R/spc_analysis.R")` and inspect diff
- [x] 6.5 Update NEWS.md under next version's `## Internal changes`: "Decompose `build_fallback_analysis()` into orchestrator + 4 named pure helpers (`.detect_signal_flags()`, `.allocate_text_budget()`, `.select_stability_key()`, `.select_action_key()`). Adds table-driven dispatch tests. Pure refactor: fallback narrative output unchanged."

## 7. Verification + PR

- [x] 7.1 Run full test suite with all gating env vars: `Rscript -e 'Sys.setenv(NOT_CRAN="true", BFHCHARTS_TEST_FULL="true"); devtools::test()'`. Zero failures.
- [x] 7.2 Run pre-push hook end-to-end via `git push -u origin refactor/decompose-fallback-analysis` (no `SKIP_PREPUSH` allowed)
- [x] 7.3 Open PR `refactor/decompose-fallback-analysis` → develop with link to OpenSpec change folder
- [x] 7.4 Verify CI green
- [x] 7.5 After merge, archive change: `/opsx:archive decompose-fallback-analysis`
