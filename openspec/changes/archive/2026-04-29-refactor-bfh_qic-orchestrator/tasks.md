## 1. Helper extraction

- [ ] 1.1 Create `validate_bfh_qic_inputs()` consolidating all `validate_*` calls (currently scattered across `bfh_qic()` lines 484-650)
- [ ] 1.2 Create `build_qic_args()` consolidating `qic_args` list construction (lines 652-701)
- [ ] 1.3 Create `invoke_qicharts2()` wrapping `do.call(qicharts2::qic, qic_args, envir = parent.frame())` + `add_anhoej_signal()`
- [ ] 1.4 Create `compute_viewport_base_size()` consolidating `convert_to_inches()`, `calculate_base_size()`, axis-label normalization
- [ ] 1.5 Create `render_bfh_plot()` consolidating plot_config + viewport_dims + bfh_spc_plot + warning handler
- [ ] 1.6 Create `apply_spc_labels_to_export()` consolidating compute_label_size_for_viewport + add_spc_labels
- [ ] 1.7 Update `bfh_qic()` to call helpers in sequence — target ≤ 80 lines body

## 2. Helper tests

- [ ] 2.1 Extend `tests/testthat/test-bfh_qic_helpers.R`
- [ ] 2.2 Test `validate_bfh_qic_inputs()` with valid + invalid inputs per parameter
- [ ] 2.3 Test `build_qic_args()` produces correct argument lists per chart type
- [ ] 2.4 Test `invoke_qicharts2()` wrapping correctly handles parent.frame() lookup
- [ ] 2.5 Test `compute_viewport_base_size()` with all unit-detection paths
- [ ] 2.6 Test `render_bfh_plot()` with minimal qic_data fixtures
- [ ] 2.7 Test `apply_spc_labels_to_export()` with viewport + no-viewport paths

## 3. Regression verification

- [ ] 3.1 Run full `devtools::test()` — all pre-existing tests pass without modification
- [ ] 3.2 Run `devtools::check()` — no new WARN/ERROR
- [ ] 3.3 Diff plot outputs against vdiffr snapshots — no rendering changes

## 4. Documentation

- [ ] 4.1 Add Roxygen `@details` to `bfh_qic()` referencing the helper map
- [ ] 4.2 Roxygen for each new helper (internal, `@noRd`)
- [ ] 4.3 NEWS entry under `## Interne ændringer`

## 5. Release

- [ ] 5.1 PATCH bump (refactor only, no behavior change)
- [ ] 5.2 Tests pass
- [ ] 5.3 Visual regression snapshots unchanged

Tracking: GitHub Issue #211
