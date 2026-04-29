## 1. Implementation

- [ ] 1.1 In `bfh_extract_spc_stats.bfh_qic_result()` (`R/utils_spc_stats.R`), sort `qd` by x before computing recent-window slice: `qd <- qd[order(qd$x), , drop = FALSE]`
- [ ] 1.2 Verify other recency-aware code paths in `R/spc_analysis.R` and `R/utils_qic_summary.R` either already x-sorted or use the sorted `qd` from extract
- [ ] 1.3 Guard against missing `x` column with informative `stop()` (should never happen given S3 contract, but defensive)

## 2. Tests

- [ ] 2.1 Create `tests/testthat/test-outliers-recent-count-rowsort.R` (or extend existing)
- [ ] 2.2 Test: input sorted ascending → result equals current behavior (regression baseline)
- [ ] 2.3 Test: input reversed → `outliers_recent_count` matches the result for sorted input
- [ ] 2.4 Test: input scrambled (random permutation) → `outliers_recent_count` matches sorted result
- [ ] 2.5 Test: signaling concentrated at start of x-range → recent-count = 0 regardless of input row order
- [ ] 2.6 Test: signaling concentrated at end of x-range → recent-count > 0 regardless of input row order

## 3. Documentation

- [ ] 3.1 Add note to `bfh_extract_spc_stats()` Roxygen `@details`: "Stats are computed on x-sorted observations; input row order is not significant."
- [ ] 3.2 NEWS entry under `## Bug fixes`

## 4. Cross-repo

- [ ] 4.1 In biSPCharts, run `grep -rn "bfh_extract_spc_stats\|outliers_recent_count" R/`
- [ ] 4.2 Verify no consumer relies on row-position semantics

## 5. Release

- [ ] 5.1 PATCH bump (bug fix, not breaking)
- [ ] 5.2 `devtools::test()` clean
- [ ] 5.3 `devtools::check()` clean
