## 1. Validation infrastructure

- [x] 1.1 Add internal helper `validate_target_for_unit()` in `R/utils_helpers.R`
- [x] 1.2 Wire validation call into `bfh_qic()` after numeric validation, before `qic_args$target` assignment (`R/create_spc_chart.R:673`)
- [x] 1.3 Document threshold rationale (1.5x slack on upper bound) in helper Roxygen
- [x] 1.4 Run `devtools::document()` to update man pages

## 2. Tests

- [x] 2.1 Create `tests/testthat/test-percent-target-contract.R`
- [x] 2.2 Test: `y_axis_unit="percent"` + `multiply=1` + `target_value=2.0` → error mentions "uden for forventet skala"
- [x] 2.3 Test: `y_axis_unit="percent"` + `multiply=1` + `target_value=0.02` → succeeds, `qic_data$target == 0.02`
- [x] 2.4 Test: `y_axis_unit="percent"` + `multiply=100` + `target_value=2.0` → succeeds, `qic_data$target == 2.0`
- [x] 2.5 Test: `y_axis_unit="percent"` + `target_value=-0.1` → error mentions non-negative
- [x] 2.6 Test: `y_axis_unit="percent"` + `target_value=1.0` → succeeds (boundary, valid 100%)
- [x] 2.7 Test: `y_axis_unit="percent"` + `target_value=1.5` → succeeds (exactly at upper bound)
- [x] 2.8 Test: `y_axis_unit="percent"` + `target_value=1.51` → error
- [x] 2.9 Test: `y_axis_unit="count"` + `target_value=9999` → succeeds (no scale check)
- [x] 2.10 Test: run-chart + `y_axis_unit="percent"` + `target_value=2.0` → error (contract applies)
- [x] 2.11 Test: error message includes actionable hint (e.g., "did you mean 0.02?")

## 3. Documentation

- [x] 3.1 Add Roxygen `@details` section "Percent Target Contract" to `bfh_qic()` (`R/create_spc_chart.R`)
- [x] 3.2 Update `README.md`: change `target_value = 2.0` → `target_value = 0.02` in P-chart example
- [x] 3.3 Add NEWS.md entry under `## Breaking changes` for v0.9.0 with migration snippet

## 4. Cross-repo coordination (biSPCharts)

- [x] 4.1 Grep biSPCharts for affected callsites (record exact paths in this issue thread)
      Finding: biSPCharts already compliant.
      - `fct_spc_bfh_params.R:378` — `normalize_scale_for_bfh()` divides by 100 for p/pp/u/up when value > 1
      - `fct_spc_execute.R:34-36` — run+percent overrides y_axis_unit to "count" before bfh_qic() call
      No callsites pass out-of-contract target_value to bfh_qic().
- [x] 4.2 Open companion issue in biSPCharts with migration checklist + snippet
      Opened: johanreventlow/biSPCharts#337
- [ ] 4.3 After BFHcharts 0.9.0 merged + tagged: bump biSPCharts `DESCRIPTION` lower-bound to `BFHcharts (>= 0.9.0)` in separate PR
- [ ] 4.4 Add migration note to biSPCharts NEWS

## 5. Release

- [x] 5.1 Bump `DESCRIPTION` version 0.8.3 → 0.9.0
- [x] 5.2 Run `devtools::test()` — all pass (no regression in existing tests)
- [x] 5.3 Run `devtools::check()` — no new WARN/ERROR
- [ ] 5.4 Merge to main via approved PR
- [ ] 5.5 Annotated tag `v0.9.0` after merge

Tracking: GitHub Issue #203
