## Why

`R/spc_analysis.R` is the package's largest single file (929 lines) and mixes four logically distinct concerns: target resolution, Danish text-formatting utilities, analysis-context construction, and fallback-narrative generation. The Danish text-formatting block (`pluralize_da()`, `pick_text()`, `substitute_placeholders()`, `pad_to_minimum()`, `ensure_within_max()`) has no dependency on the SPC analysis pipeline — these are reusable string helpers that happened to be born inside `spc_analysis.R` because that's where they were first needed.

Extracting them into `R/utils_text_da.R` lets `spc_analysis.R` shrink toward its core responsibility, makes the helpers grep-friendly under their own filename, and surfaces them as candidates for reuse from other call sites (e.g. label formatting, summary text) without introducing a circular dependency on the SPC analysis layer.

## What Changes

- Create new file `R/utils_text_da.R` containing the five string helpers extracted from `R/spc_analysis.R`:
  - `pluralize_da(n, singular, plural)` — Danish noun pluralization based on count
  - `pick_text(condition_or_index, ...)` — branched text selection
  - `substitute_placeholders(template, values)` — i18n-template variable substitution
  - `pad_to_minimum(text, min_chars, padding_char = " ")` — string-length padding
  - `ensure_within_max(text, max_chars)` — string-length truncation
- Each helper retains its current `@keywords internal @noRd` annotation (no public-API change).
- Preserve all existing call sites in `spc_analysis.R`; no signature changes.
- `spc_analysis.R` shrinks by approximately 100-150 lines.
- Pure relocation: zero behavioral change.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `code-organization`: refines file-organization boundary. Current spec contains "Single Responsibility per file" guidance; this change demonstrates the principle by extracting the cohesive text-utility group out of the analysis file.

## Impact

- `R/spc_analysis.R`: shrinks ~100-150 lines.
- `R/utils_text_da.R`: new file, ~100-150 lines.
- All existing call sites of the five helpers continue to work unchanged (R sources files alphabetically in `R/`; the new file ordering does not affect resolution since helpers are private and called only from `spc_analysis.R`).
- biSPCharts: no public API change. None of the five helpers are exported.
- No statistical validation needed.
- No tests need to move — existing tests of `pluralize_da`, `pick_text`, etc. continue to invoke the same `BFHcharts:::` paths.
- No NEWS.md user-visible entry; add bullet under `## Internal changes` for next release: "Extract Danish text-formatting helpers (`pluralize_da`, `pick_text`, `substitute_placeholders`, `pad_to_minimum`, `ensure_within_max`) from `R/spc_analysis.R` into a dedicated `R/utils_text_da.R`. Pure relocation."
- This proposal pairs naturally with `decompose-fallback-analysis` (sibling change). They can land in either order; combined effect is a ~250-line reduction in `spc_analysis.R` without behavior change.
