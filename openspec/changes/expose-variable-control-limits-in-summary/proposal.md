## Why

`format_qic_summary()` (`R/utils_qic_summary.R:139-154`) silently drops `nedre_kontrolgrænse`/`øvre_kontrolgrænse` from the summary when control limits are non-constant per part:

```r
if (lcl_constant && ucl_constant) {
  formatted$nedre_kontrolgrænse <- round(raw_summary$lcl, decimal_places)
  formatted$øvre_kontrolgrænse <- round(raw_summary$ucl, decimal_places)
}
# If not constant, don't include them in summary
```

For P/U-charts with variable denominators (the **clinically most common case**), control limits vary per observation. The summary then contains no limits at all — without warning. Downstream callers (biSPCharts dashboards, manual reports) get summaries that look complete but lack control bounds.

Both reviews flagged this. Codex called it "correct defensive behavior". I disagree: in healthcare, *invisible omission* is more dangerous than visible imprecision. A summary without limits can be misread as "no signal" rather than "limits vary".

## What Changes

- **NON-BREAKING addition**: When control limits are not constant per part, summary SHALL include four new columns:
  - `nedre_kontrolgrænse_min` — minimum LCL across the part
  - `nedre_kontrolgrænse_max` — maximum LCL across the part
  - `øvre_kontrolgrænse_min` — minimum UCL across the part
  - `øvre_kontrolgrænse_max` — maximum UCL across the part
- **NON-BREAKING addition**: New logical column `kontrolgrænser_konstante` indicating whether limits are constant within the part (TRUE = single value, FALSE = varying)
- **PRESERVED behavior**: When limits are constant, `nedre_kontrolgrænse`/`øvre_kontrolgrænse` columns continue to populate as before. `kontrolgrænser_konstante = TRUE` in this case
- New tests covering both constant and variable-limit cases
- Update `bfh_qic()` Roxygen `@return` to describe new columns
- NEWS entry under `## Nye features` for v0.9.x (additive, no breaking change)

## Impact

**Affected specs:**
- `public-api` — ADDED requirement: control limits exposure for variable denominator charts

**Affected code:**
- `R/utils_qic_summary.R:139-154` — replace silent drop with min/max + constant-flag columns
- `tests/testthat/test-utils_qic_summary.R` — extend with variable-limit tests
- `R/create_spc_chart.R` — update Roxygen `@return` description for `result$summary`

**Non-breaking:** existing callers reading `nedre_kontrolgrænse`/`øvre_kontrolgrænse` continue to work for constant cases. New columns are additive. Pre-1.0 → MINOR bump (safe additive).

## Cross-repo impact (biSPCharts)

**Verification:**
```bash
# I biSPCharts:
grep -rn "nedre_kontrolgrænse\|øvre_kontrolgrænse\|centerlinje" R/
```

**Expected impact:** Low. biSPCharts code reading constant-limit summaries continues to work. New variable-limit summaries can be ignored or surfaced in UI.

**Optional enhancement for biSPCharts:**
```r
# Detect variable-limit case and surface in UI:
if (!summary$kontrolgrænser_konstante[i]) {
  showNotification(
    "Control limits vary per observation; see chart for individual bounds.",
    type = "info"
  )
}
```

**biSPCharts version bump:** PATCH (no required changes; optional enhancement)

**Lower-bound:** can wait until biSPCharts wants to use the new columns.

## Related

- GitHub Issue: #206
- Source: BFHcharts code review 2026-04-27, Claude finding #1 (CRITICAL in initial review)
- Codex finding: noted but classified as "correct defensive" — disagreement resolved by exposing the data instead of hiding it
