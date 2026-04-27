## 1. Implementation

- [ ] 1.1 In `R/utils_qic_summary.R:139-154`, replace silent drop with:
  - Compute `lcl_min`, `lcl_max`, `ucl_min`, `ucl_max` per part
  - Add `kontrolgrænser_konstante` logical column
  - Populate `nedre_kontrolgrænse_min`/`max` and `øvre_kontrolgrænse_min`/`max` columns when limits vary
  - Continue to populate scalar `nedre_kontrolgrænse`/`øvre_kontrolgrænse` when constant (preserve backward compat)
- [ ] 1.2 Verify column ordering preserved per existing tests

## 2. Tests

- [ ] 2.1 Extend `tests/testthat/test-utils_qic_summary.R`
- [ ] 2.2 Test: constant limits → `kontrolgrænser_konstante = TRUE`, scalar columns populated, min/max columns absent or NA
- [ ] 2.3 Test: variable limits (P-chart, varying n) → `kontrolgrænser_konstante = FALSE`, min/max columns populated with sensible values
- [ ] 2.4 Test: per-part with mixed constant/variable → flag correctly per row
- [ ] 2.5 Test: backward compat — existing assertions on scalar `nedre_kontrolgrænse` for constant cases still pass
- [ ] 2.6 Test: P-chart with constant n → constant limits → scalar columns
- [ ] 2.7 Test: P-chart with varying n → variable limits → min/max columns

## 3. Documentation

- [ ] 3.1 Update `bfh_qic()` Roxygen `@return` describing new columns
- [ ] 3.2 Document `kontrolgrænser_konstante` semantics in `format_qic_summary` Roxygen
- [ ] 3.3 NEWS.md entry under `## Nye features` for v0.9.x

## 4. Cross-repo coordination (biSPCharts)

- [ ] 4.1 Grep biSPCharts for `nedre_kontrolgrænse|øvre_kontrolgrænse` usage
- [ ] 4.2 Verify backward compat (constant-limit reads still work)
- [ ] 4.3 Optionally: open biSPCharts enhancement issue for surfacing variable-limit info

## 5. Release

- [ ] 5.1 Bump version (combine with 0.9.0 or follow as 0.9.1)
- [ ] 5.2 Tests pass
- [ ] 5.3 `devtools::check()` clean

Tracking: GitHub Issue #206
