## 1. Validation infrastructure

- [x] 1.1 Add `validate_denominator_data()` in `R/utils_helpers.R`
- [x] 1.2 Wire call into `bfh_qic()` after column-name validation, before `do.call(qicharts2::qic, ...)`
- [x] 1.3 Resolve y_data and n_data from `data` for content checks
- [x] 1.4 Roxygen documentation for helper

## 2. Tests

- [x] 2.1 Create `tests/testthat/test-denominator-validator.R`
- [x] 2.2 Test: p-chart without `n` → error
- [x] 2.3 Test: i-chart without `n` → succeeds (n not required)
- [x] 2.4 Test: p-chart with `n = c(100, 0, 100)` → error mentions ">0"
- [x] 2.5 Test: p-chart with `n = c(100, -5, 100)` → error
- [x] 2.6 Test: p-chart with `n = c(100, Inf, 100)` → error
- [x] 2.7 Test: p-chart with `n = c(100, NA, 100)` → succeeds (NA allowed)
- [x] 2.8 Test: p-chart with `y = c(5, 6, 200)` and `n = c(100, 100, 100)` → error mentions row 3
- [x] 2.9 Test: p-chart with `y <= n` → succeeds
- [x] 2.10 Test: u-chart with `n = 0` → error (same rule)
- [x] 2.11 Test: pp-chart with `y > n` → error (proportion percent variant)
- [x] 2.12 Test: xbar-chart no n-validation (subgroup mechanism via duplicated x)

## 3. Documentation

- [x] 3.1 Add `@details` "Denominator Contract" section to `bfh_qic()` Roxygen
- [x] 3.2 NEWS.md entry under `## Breaking changes` for v0.9.0
- [x] 3.3 Document the row-number reporting format in helper Roxygen

## 4. Cross-repo coordination (biSPCharts)

- [x] 4.1 Grep biSPCharts for affected callsites (call site: `R/fct_spc_bfh_invocation.R:113` via `do.call`; data flows from upstream prep — runtime impact only, no static n=0 literals)
- [ ] 4.2 Open companion issue in biSPCharts with migration snippet
- [x] 4.3 Coordinate release timing with #203 (same v0.9.0 bump — already combined in DESCRIPTION/NEWS)

## 5. Release

- [x] 5.1 Bump `DESCRIPTION` 0.8.3 → 0.9.0 (already at 0.9.0 from #203)
- [x] 5.2 `devtools::test()` passes
- [x] 5.3 `devtools::check()` no new WARN/ERROR (0 errors; 4 warnings + 4 notes all pre-existing)
- [ ] 5.4 Tag v0.9.0 after merge

Tracking: GitHub Issue #205
