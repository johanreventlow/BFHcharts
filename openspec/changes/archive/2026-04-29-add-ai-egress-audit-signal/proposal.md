## Why

`bfh_generate_analysis()` (`R/spc_analysis.R:354`) supports an `use_ai = TRUE` opt-in path that constructs `spc_result$qic_data = x$qic_data` (the full qicharts2 data frame including patient-context SPC values, baseline data, freeze-period rows) and passes it verbatim to `BFHllm::bfhllm_spc_suggestion()` with `use_rag = TRUE`. `BFHllm` is a `Suggests` dependency installed from a private GitHub remote.

The security note in the docstring is correct (use_ai = FALSE default, opt-in required). However, **no runtime log entry is emitted when the AI path is taken.** In deployments where `auto_analysis = TRUE, use_ai = TRUE` are set as ambient defaults via `options()`, hospital data egress can occur without an audit trail in the package logs.

**Risk:** A maintainer or compliance auditor reading R-level logs cannot determine after-the-fact whether the AI path was exercised, which fields were transmitted, or how often. For production hospital deployments, this is a compliance/governance gap.

This is a low-impact but real defense-in-depth gap. Fixing it costs ~30 minutes and provides a visible audit signal without blocking the feature.

## What Changes

- Emit a `message()` (or structured log call if/when a logging facility is added) at the entry of the AI branch in `bfh_generate_analysis()`
- The message SHALL name:
  - The fact that AI analysis is being invoked
  - The named fields being sent (e.g. `x`, `y`, `n`, `chart_type`, hospital, department)
  - Whether `use_rag = TRUE` (RAG context augments the prompt)
- Add an opt-out: `options(BFHcharts.suppress_ai_audit_message = TRUE)` for callers who want to suppress (e.g. interactive RStudio)
- Document the audit-message contract in `bfh_generate_analysis()` Roxygen and in `vignettes/safe-exports.Rmd`
- Optional future work: structured logging via a new logger helper (out of scope here)

## Impact

**Affected specs:**
- `spc-analysis-api` — ADDED requirement: AI-egress audit-message contract

**Affected code:**
- `R/spc_analysis.R:354` — emit message at AI branch entry
- `tests/testthat/test-bfh_generate_analysis-mock.R` — assert message is emitted on AI branch
- `vignettes/safe-exports.Rmd` — document the audit signal
- NEWS entry under `## Sikkerhed` or `## Forbedringer`

**Not breaking:** Pure additive observability.

## Cross-repo impact (biSPCharts)

biSPCharts may want to suppress the message when surfacing analysis through its own UI (use the opt-out option). Coordinate with maintainer on whether biSPCharts wants its own audit trail at app level instead.

biSPCharts version bump: not required.

## Related

- Claude finding #10 (code review 2026-04)
- Existing AI-egress documentation: `R/spc_analysis.R:246`, `vignettes/safe-exports.Rmd:17`
