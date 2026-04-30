## Why

`bfh_build_analysis_context()` (`R/spc_analysis.R:221`) reads target only from `metadata$target`. The chart's own configured target — `x$config$target_value`, `x$config$target_text` — is ignored.

Clinical consequence: when a user calls `bfh_qic(... target = "≥ 90%")` and exports with `auto_analysis = TRUE` *without* duplicating the target in the metadata list, the resulting PDF renders the target line on the chart but the analysis text contains no target-fulfilment assessment. A reader sees "level 91%" with the line at 90% but no statement that the goal is met, or worse, contradictory framing.

Codex code review 2026-04-30 (finding #1) flagged this as HIGH severity / clinical correctness.

## What Changes

- **Behavioral fix**: `bfh_build_analysis_context()` SHALL resolve target via fallback chain `metadata$target ?? x$config$target_text ?? x$config$target_value`.
- New internal helper `.resolve_analysis_target(metadata, config)` in `R/spc_analysis.R` encapsulating the fallback.
- The resolved target SHALL flow through the existing `resolve_target()` + `.normalize_percent_target()` pipeline so direction parsing (`≥`, `≤`) and percent-scale normalization remain correct.
- When fallback resolves to numeric `target_value`: target_direction is NULL (matches existing numeric-target behavior).
- When fallback resolves to character `target_text`: full operator parsing applies.
- 6 new tests in `tests/testthat/test-bfh_generate_analysis-mock.R` covering: (1) metadata-only target, (2) config-only numeric target, (3) config-only character target with operator, (4) metadata overrides config, (5) percent-target via config, (6) no target anywhere yields target_value=NULL.

## Impact

**Affected specs:**
- `spc-analysis-api` — MODIFIED requirement: target resolution in analysis context

**Affected code:**
- `R/spc_analysis.R:221` — extract resolution into `.resolve_analysis_target()` and call it
- `R/utils_export_helpers.R:121` — verify auto-PDF callsite forwards both metadata + result so config is reachable
- `tests/testthat/test-bfh_generate_analysis-mock.R` — 6 new test cases
- `NEWS.md` — bug fix entry

**Breaking change scope:** None. This is a clinical correctness fix. Existing callers that DO duplicate target in metadata see identical behavior. Callers that did NOT duplicate target now get a richer (correct) analysis instead of silent omission.

## Cross-repo impact (biSPCharts)

**Verification before release:**
```bash
# In biSPCharts:
grep -rn "auto_analysis\|bfh_export_pdf\|bfh_generate_analysis" R/
```

**Likely behavior change:** biSPCharts auto-PDF flows that pass chart with target but no metadata$target will start producing target-aware analysis text. This is the intended fix — verify text is appropriate.

**biSPCharts version bump:** PATCH. Optionally update biSPCharts metadata-build helpers to remove redundant `target` duplication.

**Lower-bound in biSPCharts/DESCRIPTION:** `BFHcharts (>= 0.12.0)`

## Related

- Source: BFHcharts code review 2026-04-30 (Codex finding #1)
- Combined release with #2026-04-30-tighten-bfh-qic-input-validation if both ready simultaneously (single v0.12.0 minor bump)
