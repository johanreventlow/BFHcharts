## 1. Validation infrastructure

- [ ] 1.1 Add `validate_denominator_data()` in `R/utils_helpers.R`
- [ ] 1.2 Wire call into `bfh_qic()` after column-name validation, before `do.call(qicharts2::qic, ...)`
- [ ] 1.3 Resolve y_data and n_data from `data` for content checks
- [ ] 1.4 Roxygen documentation for helper

## 2. Tests

- [ ] 2.1 Create `tests/testthat/test-denominator-validator.R`
- [ ] 2.2 Test: p-chart without `n` → error
- [ ] 2.3 Test: i-chart without `n` → succeeds (n not required)
- [ ] 2.4 Test: p-chart with `n = c(100, 0, 100)` → error mentions ">0"
- [ ] 2.5 Test: p-chart with `n = c(100, -5, 100)` → error
- [ ] 2.6 Test: p-chart with `n = c(100, Inf, 100)` → error
- [ ] 2.7 Test: p-chart with `n = c(100, NA, 100)` → succeeds (NA allowed)
- [ ] 2.8 Test: p-chart with `y = c(5, 6, 200)` and `n = c(100, 100, 100)` → error mentions row 3
- [ ] 2.9 Test: p-chart with `y <= n` → succeeds
- [ ] 2.10 Test: u-chart with `n = 0` → error (same rule)
- [ ] 2.11 Test: pp-chart with `y > n` → error (proportion percent variant)
- [ ] 2.12 Test: xbar-chart no n-validation (subgroup mechanism via duplicated x)

## 3. Documentation

- [ ] 3.1 Add `@details` "Denominator Contract" section to `bfh_qic()` Roxygen
- [ ] 3.2 NEWS.md entry under `## Breaking changes` for v0.9.0
- [ ] 3.3 Document the row-number reporting format in helper Roxygen

## 4. Cross-repo coordination (biSPCharts)

- [ ] 4.1 Grep biSPCharts for affected callsites
- [ ] 4.2 Open companion issue in biSPCharts with migration snippet
- [ ] 4.3 Coordinate release timing with #203 (same v0.9.0 bump)

## 5. Release

- [ ] 5.1 Bump `DESCRIPTION` 0.8.3 → 0.9.0 (combined with #203)
- [ ] 5.2 `devtools::test()` passes
- [ ] 5.3 `devtools::check()` no new WARN/ERROR
- [ ] 5.4 Tag v0.9.0 after merge

Tracking: GitHub Issue #205
