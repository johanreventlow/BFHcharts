# Tasks: Rename create_spc_chart() to bfh_qic()

## 1. Core Implementation

- [ ] 1.1 Rename function in R/create_spc_chart.R
  - Change function name from `create_spc_chart` to `bfh_qic`
  - Update @name, @title in roxygen2 docs
  - Keep all parameters and function body identical
  - **Validation:** Function definition starts with `bfh_qic <- function(`

- [ ] 1.2 Update roxygen2 documentation in R/create_spc_chart.R
  - Update @title to "Create BFH-Styled SPC Chart" or similar
  - Update @description to reference `bfh_qic()` instead of `create_spc_chart()`
  - Update @name from `create_spc_chart` to `bfh_qic`
  - Keep all @examples unchanged except function calls
  - **Validation:** All roxygen2 blocks reference `bfh_qic()`

- [ ] 1.3 Update all examples in R/create_spc_chart.R
  - Find-and-replace `create_spc_chart(` → `bfh_qic(` in @examples section
  - Verify examples still make sense and run correctly
  - **Validation:** All example calls use `bfh_qic()`

## 2. Internal Cross-References

- [ ] 2.1 Update R/BFHcharts-package.R
  - Update package documentation examples
  - Update any references to main function
  - **Validation:** `rg "create_spc_chart" R/BFHcharts-package.R` returns no results

- [ ] 2.2 Update R/plot_core.R @seealso
  - Update bfh_spc_plot() @seealso section
  - Change `[create_spc_chart()]` → `[bfh_qic()]`
  - **Validation:** `rg "@seealso" R/plot_core.R` shows `bfh_qic()`

- [ ] 2.3 Update R/fct_add_spc_labels.R @seealso
  - Update add_spc_labels() @seealso section
  - Change reference to main function
  - **Validation:** `rg "@seealso" R/fct_add_spc_labels.R` shows `bfh_qic()`

- [ ] 2.4 Update R/config_objects.R @seealso
  - Update spc_plot_config() @seealso section
  - Update viewport_dims() @seealso section
  - Update phase_config() @seealso section
  - **Validation:** `rg "create_spc_chart" R/config_objects.R` returns no results

- [ ] 2.5 Update R/utils_y_axis_formatting.R @seealso
  - Update apply_y_axis_formatting() @seealso section
  - **Validation:** `rg "create_spc_chart" R/utils_y_axis_formatting.R` returns no results

- [ ] 2.6 Search all R/*.R files for remaining references
  - Run: `rg "create_spc_chart" R/`
  - Update any remaining internal documentation
  - **Validation:** No matches found (except in file name)

## 3. Tests

- [ ] 3.1 Update tests/testthat/test-integration.R
  - Replace all `create_spc_chart(` → `bfh_qic(`
  - **Validation:** All integration tests pass

- [ ] 3.2 Update tests/testthat/test-chart_types.R
  - Replace all function calls if present
  - **Validation:** Chart type tests pass

- [ ] 3.3 Update tests/testthat/test-config_objects.R
  - Replace all function calls if present
  - **Validation:** Config object tests pass

- [ ] 3.4 Update tests/testthat/test-y_axis_formatting.R
  - Replace all function calls if present
  - **Validation:** Y-axis formatting tests pass

- [ ] 3.5 Update tests/testthat/test-themes.R
  - Replace all function calls if present
  - **Validation:** Theme tests pass

- [ ] 3.6 Update tests/testthat/test-utils_label_formatting.R
  - Replace all function calls if present
  - **Validation:** Label formatting tests pass

- [ ] 3.7 Update tests/testthat/test-return-data-summary.R
  - Replace all function calls if present
  - **Validation:** Return data/summary tests pass

- [ ] 3.8 Update tests/testthat/test-unit-conversion.R
  - Replace all function calls if present
  - **Validation:** Unit conversion tests pass

- [ ] 3.9 Update tests/testthat/test-plot_margin.R
  - Replace all function calls if present
  - **Validation:** Plot margin tests pass

- [ ] 3.10 Update tests/testthat/test-arrow-symbols.R
  - Replace all function calls if present
  - **Validation:** Arrow symbol tests pass

- [ ] 3.11 Search all test files for remaining references
  - Run: `rg "create_spc_chart" tests/`
  - **Validation:** No matches found

## 4. Demo Scripts

- [ ] 4.1 Update demo_test.R
  - Replace all `create_spc_chart(` → `bfh_qic(`
  - Test that demo runs successfully
  - **Validation:** `Rscript demo_test.R` runs without errors

- [ ] 4.2 Update demo_performance_test.R
  - Replace all function calls
  - Test performance script
  - **Validation:** Demo runs and produces output

- [ ] 4.3 Search for other demo files
  - Run: `rg "create_spc_chart" demo*.R`
  - **Validation:** No matches found

## 5. Documentation Files

- [ ] 5.1 Update CLAUDE.md
  - Update all code examples
  - Update API Design Principles section
  - Update Package Structure references
  - **Validation:** `rg "create_spc_chart" CLAUDE.md` returns no results

- [ ] 5.2 Update openspec/project.md
  - Update Public API section
  - Update Chart Generation Pattern example
  - Update all code snippets
  - **Validation:** `rg "create_spc_chart" openspec/project.md` returns no results

- [ ] 5.3 Check for README.md
  - If exists, update all examples
  - **Validation:** `rg "create_spc_chart" README.md` returns no results (if file exists)

## 6. Package Regeneration

- [ ] 6.1 Run devtools::document()
  - Regenerate man/*.Rd files
  - Regenerate NAMESPACE
  - **Validation:** NAMESPACE shows `export(bfh_qic)` instead of `export(create_spc_chart)`

- [ ] 6.2 Verify man/bfh_qic.Rd created
  - Check that documentation file exists
  - Check that old create_spc_chart.Rd is gone
  - **Validation:** `ls man/bfh_qic.Rd` exists, `ls man/create_spc_chart.Rd` does not exist

- [ ] 6.3 Run devtools::test()
  - Run full test suite
  - **Validation:** All tests pass (0 failures, 0 warnings, 0 skipped)

- [ ] 6.4 Run devtools::check()
  - Full R CMD check
  - **Validation:** 0 errors, 0 warnings, 0 notes

## 7. Version Management

- [ ] 7.1 Update DESCRIPTION version
  - Bump version from 0.1.x to 0.2.0
  - Update Date field to current date
  - **Validation:** `rg "^Version:" DESCRIPTION` shows "0.2.0"

- [ ] 7.2 Update NEWS.md (if exists) or create it
  - Add section for version 0.2.0
  - Document breaking change
  - Provide migration instructions
  - **Validation:** NEWS.md contains clear migration guide

## 8. Final Validation

- [ ] 8.1 Global search for old function name
  - Run: `rg "create_spc_chart" --type r`
  - Check any remaining references are intentional (e.g., NEWS.md migration notes)
  - **Validation:** Only expected references remain

- [ ] 8.2 Test package installation
  - Run: `devtools::install()`
  - **Validation:** Package installs without errors

- [ ] 8.3 Test basic usage
  - Start fresh R session
  - `library(BFHcharts)`
  - Run example: `bfh_qic(data, x, y, chart_type = "i")`
  - **Validation:** Example runs successfully

- [ ] 8.4 Verify old name fails
  - In fresh R session with new package loaded
  - Try: `create_spc_chart(...)`
  - **Validation:** Error: "could not find function 'create_spc_chart'"

## 9. Documentation and Commit

- [ ] 9.1 Review all changes
  - Use `git diff` to review all modifications
  - Ensure no unintended changes
  - **Validation:** All changes are intentional and related to rename

- [ ] 9.2 Commit changes
  - Use conventional commit format
  - Message: `feat!: rename create_spc_chart() to bfh_qic()`
  - Include BREAKING CHANGE footer in commit body
  - **Validation:** Commit message follows format

- [ ] 9.3 Create git tag
  - Tag: `v0.2.0`
  - Annotated tag with release notes
  - **Validation:** `git tag -l` shows v0.2.0

Tracking: GitHub Issue #58
