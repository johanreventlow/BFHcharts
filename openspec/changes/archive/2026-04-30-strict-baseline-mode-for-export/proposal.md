## Why

`bfh_qic()` warns when `freeze < MIN_BASELINE_N` (8) or any phase has fewer than 8 points (`R/utils_bfh_qic_helpers.R:243-266`). The warning is non-blocking — execution continues and produces a chart with statistically unreliable control limits.

For interactive analysis this is appropriate (analyst sees the warning, makes informed choice). For PDF export the same warning is invisible: the PDF lands on a quality-improvement leadership desk with tight, plausible-looking control limits derived from 5 points of baseline. Misinterpretation as actionable signal is the realistic clinical risk.

Anhøj & Olesen (2014) recommend ≥8 baseline points as a floor for run/crossing detection reliability. For an export pipeline that drives ledelsesrapporter, a default-strict mode is the safer contract.

## What Changes

- New parameter on `bfh_export_pdf()` and `bfh_create_export_session()`: `strict_baseline = TRUE` (default).
- When `strict_baseline = TRUE`:
  - `freeze < MIN_BASELINE_N` SHALL produce a hard error (`stop()`) before qicharts2 is invoked
  - Any phase with size `< MIN_BASELINE_N` SHALL produce a hard error
  - Error message references `MIN_BASELINE_N` constant value (8) and instructs the caller to set `strict_baseline = FALSE` for explicit opt-out
- When `strict_baseline = FALSE`: preserves existing warning behavior. Useful for pilot/exploratory PDFs.
- `bfh_qic()` itself remains warning-only (interactive default).
- Threading: `strict_baseline` parameter SHALL flow through `bfh_create_export_session()` to all subsequent `bfh_export_pdf(session = ...)` calls unless overridden per-call.
- 8 new tests: hard-error paths for export, opt-out path, default-on behavior, batch-session inheritance.

## Impact

**Affected specs:**
- `pdf-export` — ADDED requirement: strict-baseline default for export

**Affected code:**
- `R/export_pdf.R` — new `strict_baseline` parameter, error path before render
- `R/export_session.R` — `strict_baseline` parameter on `bfh_create_export_session()`, propagation to per-export calls
- `R/utils_bfh_qic_helpers.R` — refactor `MIN_BASELINE_N` warnings to support both warning and error modes via internal flag (or move check to wrapping callsite)
- `tests/testthat/test-export_pdf.R` and `test-export-session.R` — 8 new tests
- `NEWS.md` — entry under `## Breaking changes` (PDF export now errors by default)
- `vignettes/phases-and-freeze.Rmd` — document the new `strict_baseline` contract

**Breaking change scope:** Pre-1.0 → MINOR. PDF export with `freeze < 8` was previously possible with warning; now requires explicit opt-out. Existing pipelines that genuinely need short-baseline PDFs add `strict_baseline = FALSE`.

## Cross-repo impact (biSPCharts)

**Verification:**
```bash
# In biSPCharts:
grep -rn "bfh_export_pdf\|bfh_create_export_session" R/
```

**Likely affected:** biSPCharts batch-export flows. Two options:
1. **Recommended**: keep default strict — surface the error to the user as "indicator X has too few baseline points; please configure or skip"
2. **Alternative**: pass `strict_baseline = FALSE` in batch when caller has explicitly accepted short-baseline output

**biSPCharts version bump:** MINOR (UX change — surface the error instead of silently shipping warning-only PDF).

**Lower-bound:** `BFHcharts (>= 0.12.0)`.

## Related

- Source: BFHcharts code review 2026-04-30 (Claude finding #4)
- Builds on `2026-04-29-enforce-baseline-minimum-and-cl-warnings` (interactive warnings — keeps that path intact)
