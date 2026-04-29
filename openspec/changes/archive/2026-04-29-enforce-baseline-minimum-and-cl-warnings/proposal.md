## Why

Three closely-related domain-correctness gaps surface in code review 2026-04:

1. **Short baseline silently accepted.** `freeze = 3` is accepted without warning by `bfh_qic()` (`R/bfh_qic.R`) and propagated to qicharts2. A frozen baseline of 3 points produces UCL/LCL with enormous statistical uncertainty. `vignettes/phases-and-freeze.Rmd:133` documents the ≥8-points-per-phase guideline; the code never enforces it. Same applies to phases created by `part`.

2. **Custom centerline (`cl`) silently invalidates Anhøj rules.** When `cl` is supplied (`R/utils_bfh_qic_helpers.R:375`, `R/bfh_qic.R`), qicharts2 computes `runs.signal` and `crossings.signal` against the user-supplied CL rather than the data-estimated process mean. Anhøj rules assume CL = process mean; against a benchmark CL (e.g. national average), run-length and crossing counts are statistically invalid and may declare special-cause for processes that never matched the benchmark.

3. **NA Anhøj signal coerced to FALSE.** `add_anhoej_signal()` (`R/utils_bfh_qic_helpers.R:62-64`) does `ifelse(is.na(anhoej.signal), FALSE, anhoej.signal)`. qicharts2 returns `NA` when the series is too short to evaluate Anhøj criteria (n < ~10). Coercing to FALSE means the summary reports "0 Anhøj signals" rather than "ikke evaluerbar". A 6-point run chart appears to have been evaluated and found stable — clinicians under-scrutinize the chart.

**Clinical consequence:** Wrong control limits drive wrong decisions. False negatives ("no signal" when signal could not be evaluated) are particularly insidious in clinical quality work.

## What Changes

- Emit `warning()` (not stop) when `freeze` < `MIN_BASELINE_N` (default 8); message names the value supplied and the recommended minimum
- Emit `warning()` when any phase created by `part` has fewer than `MIN_BASELINE_N` observations
- Emit `warning()` when `cl` is non-NULL AND the result will report Anhøj signals; message clarifies that runs/crossings are computed against the supplied CL, not the process mean
- Preserve `NA` in `anhoej.signal` (do not coerce to FALSE) and propagate to summary as a distinct "ikke evaluerbar" / "not evaluable" state
- Define `MIN_BASELINE_N <- 8L` in `R/globals.R` with rationale comment referencing Anhøj literature
- Document each warning in `vignettes/phases-and-freeze.Rmd`

## Impact

**Affected specs:**
- `spc-analysis-api` — ADDED requirements for baseline-minimum warnings, cl-override warning, NA-preservation contract

**Affected code:**
- `R/globals.R` — add `MIN_BASELINE_N`
- `R/bfh_qic.R` — input validation calls
- `R/utils_bfh_qic_helpers.R` — anhoej.signal NA-preservation; phase-length computation for warning trigger
- `inst/i18n/da.yaml` + `en.yaml` — "ikke evaluerbar" / "not evaluable" string
- `tests/testthat/test-bfh_qic_edge_cases.R` — add freeze<8, part-phase<8, cl+Anhøj, short-series tests
- NEWS entry under `## Forbedringer` (warnings) and `## Bug fixes` (NA-preservation)

**Behavior change:** Previously-silent calls now emit warnings. Callers that suppress all warnings see no change. Callers that test for `expect_no_warning()` may need to update.

## Cross-repo impact (biSPCharts)

biSPCharts dashboards may now surface warnings to logs. Verify Shiny app's warning-handling does not pollute UI. NA-state in summary requires display logic update if "ikke evaluerbar" should render distinctly from "0 signals". Coordinate with biSPCharts maintainer.

biSPCharts version bump: PATCH (consume new warning state in display logic).

## Related

- Code review 2026-04 (Claude findings #6, #8, #9; Codex finding #9)
- `vignettes/phases-and-freeze.Rmd` (existing documentation of ≥8 guideline)
