## Why

`outliers_recent_count` and related "last 6 observations" reporting in `bfh_extract_spc_stats.bfh_qic_result()` (`R/utils_spc_stats.R:147-158`) slices `qd[recent_start:n_obs, ]` on row position. There is no `order(qd$x)` anywhere in the pipeline; `bfh_qic()` passes data to `qicharts2::qic()` as-is, and qicharts2 preserves input row order.

If a caller passes a data frame with rows in non-chronological order — for example after `dplyr::bind_rows()`, a join, a filter-then-reassemble — the "signals in last 6 observations" count silently captures the wrong rows.

**Clinical consequence:** Dashboard narrative reports "2 signaler i seneste 6 observationer" when the actual signaling points are old, or real recent signals are missed. Drives inappropriate intervention or false reassurance. Surfaced in code review 2026-04 (Claude finding #1, both passes).

## What Changes

- Sort `qd` by the x-variable inside `bfh_extract_spc_stats.bfh_qic_result()` before the positional slice
- Apply same sort in any other recency-window code path (verify `R/utils_spc_stats.R` + `R/spc_analysis.R` callers)
- Add regression test with explicitly unsorted input (reverse + scrambled order)
- Document the contract: stats are computed on x-ordered observations regardless of input row order

## Impact

**Affected specs:**
- `spc-analysis-api` — MODIFIED requirement: outliers_recent_count and recency-window stats SHALL be computed on x-sorted observations

**Affected code:**
- `R/utils_spc_stats.R:147-158` — sort by x before slice
- `tests/testthat/test-outliers-recent-count.R` — new test cases for unsorted input
- NEWS entry under `## Bug fixes`

**Not breaking:** Output for already-sorted input is unchanged. Output for previously-unsorted input becomes correct (was wrong).

## Cross-repo impact (biSPCharts)

biSPCharts likely passes pre-sorted data; verify with grep. No version bump expected.

## Related

- Code review 2026-04 (Claude finding #1)
- Severity: high. Confidence: high.
