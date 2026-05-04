## Why

Two FIX SOON items from the production-readiness review (2026-05-04, items
2.1 and 3.3) target the same underlying gap: **PDFs from `bfh_export_pdf()`
typically reach quality-improvement leadership where R-side warnings never
surface to a human reader.** The current defaults optimize for backward
compatibility at the expense of clinical-production safety.

### Slice A -- `restrict_template = FALSE` default (item 2.1)

`bfh_export_pdf()` accepts `template_path` (custom Typst template) by
default. The threat-model is already documented in `R/export_pdf.R:36-43`
and equates a custom template with `source()`-equivalent code execution
(Typst can read/write arbitrary paths during compilation). The
`restrict_template = TRUE` flag exists to block this vector but defaults
to `FALSE` for backward compatibility.

In a clinical Shiny deployment (biSPCharts), if a configuration pipeline
ever forwards user-controlled input to `template_path`, the result is a
silent privilege-escalation vector. The author's own design comment
flags this as the reason `restrict_template` exists -- but the safer
default is not the chosen default.

### Slice B -- Custom `cl` parameter SHALL surface in summary + PDF (item 3.3)

`bfh_qic()` warns at `R/bfh_qic.R:674-682` when the user passes a custom
`cl` argument: Anhoej run/crossing signals are computed against the
user-supplied centerline, not the data-estimated process mean. The
warning correctly notes that signal interpretation requires caution.

But the warning is text-only and emitted at chart-creation time. By the
time the PDF reaches a clinician, the warning is gone. The PDF shows
"VIGTIG: Anhoej-signal: TRUE" with no indication that the centerline
was fastsat manuelt (not data-derived). Clinicians correctly assume the
SPC table reflects data-driven analysis and may misattribute signals as
clinically meaningful when they are artifacts of an arbitrary user-set
centerline.

### Combined rationale

Both slices target the same threat: **clinical decision-makers reading
PDFs without access to R warnings/console state**. A single OpenSpec
change covers them because:

1. They share the same risk model (warning-blind clinical readers).
2. They both target `bfh_export_pdf()` defaults.
3. They both require coordinated cross-repo bumps (biSPCharts must
   migrate or pin lower-bound).
4. Bundling avoids two MINOR breaking-change cycles; one release with
   coordinated release notes is cleaner.

## What Changes

**Slice A -- `restrict_template = TRUE` default (BREAKING):**

- **BREAKING** Flip `bfh_export_pdf(restrict_template = FALSE)` ->
  `restrict_template = TRUE`.
- Existing callers passing `template_path` without explicit
  `restrict_template` now hit a clear error at validation time
  (already implemented in `R/export_pdf.R:293-299`). Migration: add
  `restrict_template = FALSE` to opt back into custom templates.
- Update Roxygen `@param restrict_template` to document new default
  + migration note.
- `bfh_create_export_session()` does NOT take `restrict_template` (it
  doesn't accept `template_path`); no change needed there.

**Slice B -- Custom `cl` summary + PDF caveat (BREAKING for downstream
column-iteration consumers; ADDITIVE for typed consumers):**

- Add `attr(summary, "cl_user_supplied")` (logical scalar) on
  `bfh_qic_result$summary` when the caller supplied a non-NULL `cl`
  argument to `bfh_qic()`. Attribute is preferred over a new column
  (column would break downstream `lapply(summary, ...)` patterns).
- `bfh_extract_spc_stats.bfh_qic_result()` reads the attribute and
  surfaces it as `stats$cl_user_supplied`.
- `R/utils_typst.R::build_typst_content()` emits a new template
  parameter `cl_user_supplied: false` (default) and the template
  conditionally renders a caveat note in the SPC table footer:
  "Centerlinje fastsat manuelt -- Anhøj-signal beregnet mod denne, ikke
  data-estimeret middelværdi" (Danish; English fallback when
  `language = "en"`).
- `R/bfh_qic.R` warning at line 674-682 is **retained** -- it surfaces
  to interactive R users; PDF caveat is the SECOND surface for
  warning-blind clinical readers.

**Cross-cutting:**

- Version bump 0.15.x -> 0.16.0 (MINOR, pre-1.0 breaking allowed per
  `VERSIONING_POLICY.md` §A).
- NEWS entry under `## Breaking changes` for slice A; under `## New
  features` for slice B (additive caveat, additive attribute).
- Cross-repo: biSPCharts SHOULD verify it never passes user-controlled
  input to `template_path`. Review of biSPCharts confirms it always
  uses packaged template (no `template_path` argument forwarded). No
  biSPCharts code change required for slice A. For slice B,
  biSPCharts MAY use the attribute to display in-app warnings before
  PDF export.
- Regression tests for slice A (default rejects `template_path`,
  explicit `FALSE` accepts it); slice B (attribute set when `cl`
  supplied, NULL when not, PDF-caveat present in rendered output).

## Capabilities

### Modified Capabilities

- `pdf-export`: `bfh_export_pdf()` default tightened. `restrict_template`
  flips to TRUE. Reference: `openspec/specs/pdf-export/spec.md` (will
  add new requirement under `## ADDED Requirements`).
- `public-api`: `bfh_qic_result$summary` gains a stable attribute
  `cl_user_supplied`. Reference: `openspec/specs/public-api/spec.md`
  (will add new requirement under `## ADDED Requirements`).

## Impact

**Code (Slice A, ~5 lines):**
- `R/export_pdf.R` -- single default flip + Roxygen update.

**Code (Slice B, ~30 lines):**
- `R/utils_bfh_qic_helpers.R` -- attach `cl_user_supplied` attribute to
  summary in `build_bfh_qic_return()`.
- `R/utils_spc_stats.R` -- surface attribute in
  `bfh_extract_spc_stats.bfh_qic_result()`.
- `R/utils_typst.R::build_typst_content()` -- emit
  `cl_user_supplied` parameter when set.
- `inst/templates/typst/bfh-template/bfh-template.typ` -- new
  `cl_user_supplied: false` parameter + conditional caveat block.
- `R/utils_i18n.R` (or new key in `inst/i18n/*.yaml`) -- caveat-text
  translations (da, en).

**Tests:**
- `tests/testthat/test-export_pdf.R` -- assert default rejects
  `template_path`; explicit FALSE accepts it.
- `tests/testthat/test-utils_qic_summary.R` (new file or extend
  existing) -- `attr(summary, "cl_user_supplied")` set when `cl`
  supplied, NULL otherwise.
- `tests/testthat/test-export_pdf-content.R` -- gated PDF render
  asserts caveat-text appears in PDF text content when `cl` supplied;
  absent otherwise.

**Docs:**
- `R/export_pdf.R` Roxygen `@param restrict_template` documents new
  default + migration note.
- `R/bfh_qic.R` Roxygen `@param cl` cross-references the summary
  attribute.
- `NEWS.md` 0.16.0 entry: `## Breaking changes` (slice A) + `## New
  features` (slice B).
- `inst/adr/` -- new ADR (ADR-003) documenting the
  warning-blind-clinical-reader risk model that drove both decisions.

**Public API surface:**
- `bfh_export_pdf(restrict_template = ...)` default value changes.
- `bfh_qic_result$summary` gains attribute `cl_user_supplied`.
- `bfh_extract_spc_stats(...)$cl_user_supplied` is a new returned field
  (NULL when not applicable).
- Typst template `bfh-diagram(cl_user_supplied = ...)` parameter is new
  but defaults to `false` (backward compatible for direct template
  callers).

**Risk:**
- Slice A: callers passing `template_path` without explicit
  `restrict_template = FALSE` hit a clear error at validation. Migration
  is mechanical (`add restrict_template = FALSE` to existing call). Risk
  bounded.
- Slice B: column-iteration consumers (e.g.
  `lapply(summary, function(col) ...)`) are NOT affected because we use
  `attr()` rather than adding a column. Typst template parameter
  defaults preserve back-compat for direct template callers.
- Cross-repo: biSPCharts unaffected by slice A (no custom template).
  biSPCharts can OPT-IN to slice B by reading the attribute and
  pre-warning users before PDF export.

**Out of scope:**
- Adding `cl_user_supplied` for `freeze`/`exclude`/`part` parameters
  (those alter analysis but do not directly substitute the centerline;
  separate change if needed).
- Requiring `data_consent = "explicit"` for PDF rendering when AI is
  not used (already covered by existing `use_ai = TRUE` gate).
- Hardening other `bfh_qic()` defaults (e.g. `multiply`, `agg.fun`).
- Replacing the R warning with a hard error when `cl` is supplied
  (warning + PDF caveat is sufficient; error would be over-restrictive
  for power users who knowingly use external benchmarks).
