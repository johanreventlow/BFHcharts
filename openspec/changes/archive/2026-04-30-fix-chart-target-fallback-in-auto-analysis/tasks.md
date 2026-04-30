## 1. Implementation

- [x] 1.1 Add `.resolve_analysis_target(metadata, config)` helper in `R/spc_analysis.R` (above `bfh_build_analysis_context`)
- [x] 1.2 Implement fallback chain: `metadata$target` → `config$target_text` → `config$target_value` → NULL
- [x] 1.3 Replace direct `metadata$target` read in `bfh_build_analysis_context()` with helper call
- [x] 1.4 Verify `resolve_target()` + `.normalize_percent_target()` pipeline still receives the resolved value
- [x] 1.5 Confirm `bfh_qic_result$config` carries `target_value` and `target_text` reliably (audit `R/bfh_qic.R` and `R/bfh_qic_result.R`)

## 2. Tests

- [x] 2.1 Test: metadata-only target (regression for existing behavior)
- [x] 2.2 Test: chart target_value (numeric) used when metadata$target NULL
- [x] 2.3 Test: chart target_text (character with `≥`) used when metadata$target NULL — operator direction preserved
- [x] 2.4 Test: metadata$target overrides chart config when both present
- [x] 2.5 Test: percent-target via config flows through `.normalize_percent_target()`
- [x] 2.6 Test: no target anywhere → target_value=NULL, target_direction=NULL

## 3. Documentation

- [x] 3.1 Update Roxygen `@details` for `bfh_build_analysis_context()` — document fallback chain
- [x] 3.2 NEWS entry under `## Bug fixes` for v0.12.0
- [x] 3.3 Note in `vignettes/targets-and-percent.Rmd` that target on chart auto-flows to analysis

## 4. Cross-repo coordination

- [ ] 4.1 Grep biSPCharts for redundant metadata$target duplication
- [ ] 4.2 Open companion biSPCharts issue if cleanup is desirable

## 5. Release

- [x] 5.1 Bump `DESCRIPTION` 0.11.1 → 0.12.0
- [x] 5.2 `devtools::test()` passes
- [ ] 5.3 `devtools::check()` no new WARN/ERROR
- [ ] 5.4 Tag v0.12.0 after merge

Tracking: GitHub Issue #TBD
