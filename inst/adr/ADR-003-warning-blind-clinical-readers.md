# ADR-003: Warning-Blind Clinical Readers — Default Posture for PDF Exports

Status: Accepted

Date: 2026-05-04

## Context

BFHcharts produces SPC charts that are routinely rendered to PDF via
`bfh_export_pdf()` and forwarded to quality-improvement leadership and
clinicians. The recipients read the PDF without access to the R session
that produced it. This means **R-side warnings, console output, and
diagnostic messages never reach the clinical reader**.

The production-readiness review (2026-05-04) flagged two FIX SOON items
sharing this risk model:

1. **Item 2.1** -- `bfh_export_pdf(restrict_template = FALSE)` default.
   Custom Typst templates compile with the privileges of the calling R
   session (equivalent to `source()`). A configuration pipeline that
   forwards user-controlled input to `template_path` (e.g. Shiny
   `input$template`, REST API parameter) creates a silent
   privilege-escalation vector. The `restrict_template = TRUE` flag
   exists to block this -- but defaults to `FALSE` for backward
   compatibility.

2. **Item 3.3** -- `bfh_qic()` warns when the caller supplies a custom
   `cl` argument: Anhøj run/crossing signals are computed against the
   user-supplied centerline, not the data-estimated process mean. The
   warning is text-only and emitted at chart-creation time. By the time
   the PDF reaches a clinician, the warning is gone. The PDF shows
   "VIGTIG: Anhøj-signal: TRUE" with no indication that the centerline
   was set manually. Clinicians correctly assume the SPC table reflects
   data-driven analysis and may misattribute signals as clinically
   meaningful when they are artifacts of an arbitrary user-set
   centerline.

Both items targeted the same underlying gap: **defaults that optimized
for backward compatibility at the expense of clinical-production
safety**.

## Decision

**Default postures shift to optimize for warning-blind clinical
readers.** Power users opt-in to the existing behavior with explicit
parameters. Both shifts ship as a single MINOR breaking-change cycle
(0.15.x → 0.16.0; pre-1.0 breaking allowed per `VERSIONING_POLICY.md`
§A) so cross-repo coordination happens once.

### D1 — `restrict_template = TRUE` is the new default

Callers passing `template_path` MUST opt in with
`restrict_template = FALSE`. The validation block at
`R/export_pdf.R:293-299` already raises an informative error; only the
default flips. The error message is self-documenting and migration is
mechanical (one parameter add).

### D2 — PDF caveat for user-supplied centerline

When `bfh_qic()` receives a non-NULL `cl`, the resulting
`bfh_qic_result$summary` carries an attribute
`cl_user_supplied = TRUE`. The PDF template renders an italic, grey,
small-font caveat note below the SPC table:

> *Centerlinje fastsat manuelt — Anhøj-signal beregnet mod denne, ikke
> data-estimeret middelværdi.*

The R-side warning (at `R/bfh_qic.R:674-682`) is **retained** -- it
serves interactive R users who may never call `bfh_export_pdf()`. The
PDF caveat is the SECOND surface for warning-blind clinical readers.
Two surfaces increase the chance the issue is noticed without forcing
escalation to a hard error.

### D3 — Attribute, not column

`attr(summary, "cl_user_supplied")` rather than
`summary$cl_user_supplied`. Adding a column would invisibly change the
iterable surface (`lapply(summary, ...)`, `dplyr::summarise(across(...))`)
for downstream consumers. The flag is a scalar property of the entire
result, not a per-phase observation -- attribute encoding is the
idiomatic R choice.

The attribute is also surfaced via
`bfh_extract_spc_stats(result)$cl_user_supplied` so power users querying
SPC stats via the public API see the flag without needing to know about
the attribute.

## Consequences

**Positive:**
- Default-safe posture: a configuration pipeline forwarding user input
  to `template_path` no longer silently compiles arbitrary Typst code.
- Clinicians reading PDFs see a caveat when SPC signals are computed
  against a non-data-derived centerline -- correct interpretation no
  longer requires console-window access.
- Power users keep both behaviors via explicit opt-in.
- Single MINOR breaking-change cycle for both items keeps cross-repo
  coordination (biSPCharts lower-bound bump) cheap.

**Negative:**
- External callers using `template_path` without explicit
  `restrict_template = FALSE` hit a clear validation error. Migration
  is mechanical.
- Slight visual addition (one italic line) under the SPC table when
  `cl_user_supplied = TRUE`. No clutter for the common case (default
  rendering unchanged).

**Trade-off considered and rejected:**
- *1-version deprecation cycle* (warn in 0.16.0, error in 0.17.0) for
  Slice A: rejected because the error message is self-documenting,
  migration is mechanical, and pre-1.0 breaking is allowed. A
  deprecation cycle would delay the security improvement.
- *Hard error when `cl` is supplied*: rejected as over-restrictive for
  power users with external benchmarks. Warning + PDF caveat is
  sufficient.
- *Per-phase `cl_user_supplied` vector*: rejected because `cl` is a
  global parameter to `bfh_qic()`. Per-phase encoding would imply
  semantics the API does not support.

## References

- `openspec/changes/harden-pdf-export-for-production/` (proposal,
  design, tasks, specs)
- `R/export_pdf.R` (Slice A: `restrict_template` default flip)
- `R/utils_bfh_qic_helpers.R::build_bfh_qic_return()` (Slice B: attribute)
- `R/utils_spc_stats.R::bfh_extract_spc_stats.bfh_qic_result()` (Slice B: surface)
- `inst/templates/typst/bfh-template/bfh-template.typ` (Slice B: caveat block)
- `inst/i18n/{da,en}.yaml` `labels.caveats.cl_user_supplied`
- ADR-001 (PDF asset policy, related but distinct concern)
- `VERSIONING_POLICY.md` §A (pre-1.0 MINOR breaking allowed)
