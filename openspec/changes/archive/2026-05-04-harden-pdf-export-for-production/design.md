## Context

Production-readiness review (2026-05-04) flagged two FIX SOON items
(2.1 and 3.3) sharing a single risk model: **clinical PDFs reach
quality-improvement leadership where R-side warnings/console output
never surface to a human reader**. The current `bfh_export_pdf()`
defaults optimize for backward compatibility; the proposed defaults
optimize for clinical-production safety with explicit opt-out for
existing power-user patterns.

This change combines both items in a single OpenSpec cycle because:
- Both target the same threat model (warning-blind PDF readers)
- Both touch `bfh_export_pdf()` defaults
- Both require coordinated cross-repo bumps (biSPCharts pin or
  migration)
- Bundling avoids two MINOR breaking-change cycles

Stakeholders:
- BFHcharts maintainer (Johan Reventlow) -- owns API contract.
- biSPCharts (downstream Shiny app) -- primary clinical-production
  consumer; must verify no `template_path` exposure to user input
  (slice A) and may opt-in to consume `cl_user_supplied` attribute
  (slice B).
- Healthcare clinicians -- read summary indirectly via PDF; subject
  matter benefit from caveat-rendering (slice B).

Constraints:
- Pre-1.0 (`0.15.x`). Per `VERSIONING_POLICY.md` §A, breaking changes
  allowed in MINOR with `## Breaking changes` NEWS marking.
- ASCII-only in `R/*.R` source (per project CLAUDE.md). Danish in
  i18n YAML files allowed.
- Must not regress existing tests (3016 passing as of 0.15.1).
- biSPCharts compatibility: slice A must not require biSPCharts code
  change; slice B must not require it but should enable opt-in
  consumption.

## Goals / Non-Goals

**Goals:**
- Default `bfh_export_pdf()` posture safer for clinical production
  without forcing existing power-user patterns to break silently.
- Surface custom-`cl` semantics in two channels: R warning (existing,
  for interactive users) + PDF caveat (new, for clinical readers).
- Keep API surface small: one parameter default flip + one summary
  attribute + one Typst template parameter.
- Document the "warning-blind clinical reader" risk model so future
  default decisions can reference it (ADR-003).

**Non-Goals:**
- Replacing the R warning with a hard error (over-restrictive for power
  users with external benchmarks).
- Adding `*_user_supplied` flags for `freeze`/`exclude`/`part` (separate
  semantics; if needed, separate change).
- Hardening other `bfh_qic()` defaults (e.g. `multiply`, `agg.fun`).
- Adding new column to `summary` for `cl_user_supplied` (would break
  `lapply(summary, ...)` patterns; attribute is the cleaner choice).
- Migrating biSPCharts (cross-repo coordination is a follow-up PR in
  biSPCharts repo).

## Decisions

### D1 -- Slice A: flip `restrict_template` default to TRUE

`bfh_export_pdf(restrict_template = TRUE)` becomes the new default.
Callers needing custom `template_path` MUST opt in with
`restrict_template = FALSE`.

**Rationale:**
- The existing validation block at `R/export_pdf.R:293-299` already
  raises a clear error when `restrict_template = TRUE` AND
  `template_path` is supplied. No new error path needed.
- The default flip eliminates the silent privilege-escalation vector
  if a configuration pipeline ever forwards user-controlled input to
  `template_path` (e.g. Shiny `input$template`, REST API parameter).
- Power users (BFH internal, advanced templates) opt-in once with
  `restrict_template = FALSE`; this is a self-documenting "I know
  what I'm doing" gesture.

### D2 -- Slice B: attribute, not column, for `cl_user_supplied`

`attr(summary, "cl_user_supplied") <- TRUE/FALSE` rather than
`summary$cl_user_supplied <- TRUE/FALSE`.

**Rationale:**
- `summary` is a tidy data.frame consumed by code patterns like
  `lapply(summary, function(col) ...)` or
  `dplyr::summarise(across(everything(), ...))`. Adding a column
  would invisibly change the iterable surface.
- The flag is a SCALAR property of the entire result, not a per-phase
  observation. Per-phase encoding would be misleading: every phase
  shares the same `cl` value when supplied; the attribute reflects
  the parameter, not the data.
- Attributes are idiomatic R for metadata that travels with an object
  (cf. `attr(x, "names")`, `attr(x, "row.names")`).
- Downstream consumers can check via `isTRUE(attr(x, "cl_user_supplied"))`
  -- safe against absent or unexpected values.

### D3 -- Slice B: PDF caveat as Typst template parameter, not free-form text

Add `cl_user_supplied: false` parameter to
`inst/templates/typst/bfh-template/bfh-template.typ`. Conditionally
render a caveat block (Danish/English text driven by `language`
parameter passed from R).

**Rationale:**
- Template parameter is the existing pattern for similar conditional
  rendering (cf. `is_run_chart`, `analysis`, `data_definition`).
- Free-form text injection in `analysis` field would lose semantic
  structure (callers cannot distinguish "this caveat fired" from "user
  wrote about it manually").
- Caveat-text is i18n-able via existing `inst/i18n/*.yaml` mechanism.
  Default Danish text: `"Centerlinje fastsat manuelt -- Anhøj-signal
  beregnet mod denne, ikke data-estimeret middelværdi"`. English:
  `"Centerline manually specified -- Anhøj signal computed against
  user-supplied centerline, not data-estimated process mean"`.
- Caveat block placement: directly below the SPC table (above
  `data_definition` if present). Visually grouped with the statistics
  it caveats.

### D4 -- Slice B: `bfh_extract_spc_stats()` surfaces attribute as field

`bfh_extract_spc_stats.bfh_qic_result(x)$cl_user_supplied` returns
`TRUE`/`FALSE` mirroring the attribute.

**Rationale:**
- Power users querying SPC stats via the public API SHOULD see the
  flag without having to know about the attribute.
- `is_run_chart` is already exposed at this level for analogous
  reasons (Typst template needs it; consumers may also want it).
- Keeps the attribute as the canonical source of truth (data.frame
  attribute) but provides a discoverable surface.

### D5 -- R warning behaviour unchanged

The existing warning at `R/bfh_qic.R:674-682` remains. PDF caveat is
the SECOND surface; warning is the FIRST surface (interactive users).

**Rationale:**
- Warning serves interactive R users who would NOT see the PDF
  caveat (they may never call `bfh_export_pdf()`).
- Removing the warning would silently change behaviour for
  long-existing scripts.
- Two surfaces increase the chance the issue is noticed without
  forcing escalation to a hard error.

### D6 -- Cross-repo coordination

biSPCharts impact:
- Slice A: review confirms biSPCharts always uses packaged template
  (no `template_path` argument forwarded). No biSPCharts code change
  required. `Imports: BFHcharts (>= 0.16.0)` lower-bound bump in a
  separate PR per `VERSIONING_POLICY.md` §E.
- Slice B: biSPCharts MAY opt-in by reading
  `attr(summary, "cl_user_supplied")` and pre-warning users in the UI
  before PDF export (e.g. tooltip on the cl-input field). Not
  required.

If biSPCharts ever needs custom templates (currently does not), it
will hit the slice A error at deployment and can opt out with
`restrict_template = FALSE`.

## Risks / Trade-offs

**Risk 1: Slice A breaks unknown downstream callers.**
External callers (outside BFHcharts org) using `template_path` without
`restrict_template = FALSE` hit an error at validation time. The error
message is clear and migration is mechanical.
*Mitigation:* `## Breaking changes` NEWS entry with explicit migration
example. Pre-1.0 freedom per VERSIONING_POLICY.

**Risk 2: Slice B caveat-text adds visual clutter to PDFs without
custom cl.**
The caveat only renders when `cl_user_supplied = true`; default
behaviour is unchanged. No clutter for the common case.
*Mitigation:* Conditional rendering in template (mirrors existing
`is_run_chart` pattern).

**Risk 3: Attribute-based design is less discoverable than column.**
Users may not know to check `attr(summary, "cl_user_supplied")`.
*Mitigation:* Document in Roxygen `@return` for `bfh_qic()` AND surface
via `bfh_extract_spc_stats()$cl_user_supplied`. Power users have two
discoverable surfaces.

**Risk 4: i18n overhead for caveat-text.**
Adding new translatable strings touches the i18n pipeline.
*Mitigation:* Two-language scope (da, en) matches existing surfaces.
Add to `inst/i18n/*.yaml` following existing conventions.

**Trade-off: Single combined OpenSpec change vs two separate.**
Combined: one PR, coordinated release notes, single cross-repo bump.
Separate: smaller PRs, easier reviewer attention, but doubles the
breaking-change-cycle overhead.
*Decision:* Combined. Both items share threat model, scope, and
release coordination. Reviewer can request slice-by-slice review if
needed.

## Migration Plan

1. Land in feature branch `feat/harden-pdf-export-for-production`.
2. Open PR mod `develop` per project convention.
3. Verify CI green (R-CMD-check, pdf-smoke, render-tests, lint,
   test-coverage).
4. Manual verification:
   - Slice A: `bfh_export_pdf(result, "out.pdf",
     template_path = "/some/path.typ")` errors with clear message;
     adding `restrict_template = FALSE` allows it.
   - Slice B: `bfh_qic(data, ..., cl = 50) |> bfh_export_pdf("out.pdf")`
     produces PDF with caveat-text below SPC table; `bfh_qic(data,
     ...)` (no `cl`) does not.
5. NEWS entry under `# BFHcharts 0.16.0` with both `## Breaking
   changes` (slice A) and `## New features` (slice B) sections.
6. Merge to develop. Release-cut PR `develop → main` later.
7. Cross-repo: open biSPCharts PR bumping
   `Imports: BFHcharts (>= 0.16.0)` after release tag.

## Open Questions

- **Q1:** Should the caveat-text be configurable via Roxygen
  parameter (e.g. `caveat_text` argument to `bfh_export_pdf()`) so
  organizations can override the default?
  *Tentative answer:* No -- the default text is the safe minimum;
  organizations needing custom phrasing can localize via the i18n
  YAML files (already supported). Adding a parameter would expose
  another vector for callers to drop the caveat entirely.

- **Q2:** Should slice A flip be a 1-version deprecation cycle
  (warn in 0.16.0, error in 0.17.0)?
  *Tentative answer:* No -- pre-1.0 allows direct breaking; the error
  message is self-documenting and migration is one parameter add. A
  deprecation cycle would delay the security improvement.

- **Q3:** Should `cl_user_supplied` be a per-phase attribute (vector
  matching summary nrow) instead of a scalar?
  *Tentative answer:* No -- `cl` argument is global to the
  `bfh_qic()` call. Per-phase semantics would suggest different cl
  values per phase, which the current API does not support.
