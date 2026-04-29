## Why

`bfh_qic()` validates the `n` argument only as a syntactically valid column name (`R/bfh_qic.R:661`). It does not validate the *content* of the denominator column. Users with `n = 0`, `n = NA`, `n = Inf`, or `y > n` for P/PP-charts pass validation and produce silently misleading charts (NaN/Inf rates, illegal proportions > 1, or empty points where users expect signals).

Codex code review 2026-04-27 (finding #3) flagged this as HIGH severity. Clinical impact: false-clean reports when underlying data is invalid.

## What Changes

- **BREAKING**: `bfh_qic()` validates denominator column content for ratio charts (`p`, `pp`, `u`, `up`).
- New internal helper `validate_denominator_data()` in `R/utils_helpers.R`:
  - Requires `n` for ratio chart types (`p`, `pp`, `u`, `up`); errors if missing
  - Rejects non-numeric `n` column
  - Rejects `Inf` / `-Inf` in `n`
  - Rejects `n <= 0` (zero/negative denominator gives meaningless rate)
  - Allows `NA` in individual rows (qicharts2 drops them)
  - For `p` / `pp` charts: rejects rows where `y > n` (proportion > 1)
  - Reports row numbers in violation messages
- xbar/s/i/run/c/g/t charts: not subject to denominator validation (no `n` semantics or `n` is subgroup grouping)
- Add 10 new tests covering all chart types and violation modes
- Update `bfh_qic()` Roxygen `@details` with denominator contract section
- NEWS entry under `## Breaking changes`, version bump 0.8.3 → 0.9.0 (combined release with #203 percent-target proposal)

## Impact

**Affected specs:**
- `public-api` — ADDED requirement: denominator validation contract for ratio charts

**Affected code:**
- `R/utils_helpers.R` — new internal helper `validate_denominator_data()`
- `R/bfh_qic.R` — wire validation call before `do.call(qicharts2::qic, ...)`
- `tests/testthat/test-denominator-validator.R` — new file
- `NEWS.md` — breaking change entry

**Breaking change scope:**
- Existing callers passing `n = 0`, `n = Inf`, `y > n` (P-chart), or omitting `n` for ratio charts will receive hard errors instead of silent NaN/Inf or kryptisk qicharts2-fejl
- Pre-1.0 → MINOR bump

## Cross-repo impact (biSPCharts)

**Verification before BFHcharts 0.9.0 release:**
```bash
# I biSPCharts:
grep -rn "n\s*=" R/ | grep -E "bfh_qic|create_spc_chart"
```

**Likely affected:** any biSPCharts data flow that may include rows with `n = 0` (e.g., a month with no patients, missing denominator data).

**Migration pattern for biSPCharts:**
```r
# Pre-filter data before bfh_qic call:
data_clean <- data[!is.na(data$denominator) & data$denominator > 0, ]
n_dropped <- nrow(data) - nrow(data_clean)
if (n_dropped > 0) {
  showNotification(
    sprintf("Dropped %d rows with invalid denominator", n_dropped),
    type = "warning"
  )
}
bfh_qic(data_clean, ...)
```

**biSPCharts version bump:** PATCH (input cleaning) or MINOR (if UI surfaces validation feedback).

**Lower-bound in biSPCharts/DESCRIPTION:** `BFHcharts (>= 0.9.0)`

## Related

- GitHub Issue: #205
- Combined release with #203 (`fix-percent-target-scale-contract`) — both are clinical-correctness fixes targeting v0.9.0
- Source: BFHcharts code review 2026-04-27, Codex finding #3
