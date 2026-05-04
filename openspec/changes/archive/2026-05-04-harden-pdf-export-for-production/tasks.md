## 1. Slice A: flip `restrict_template` default to TRUE

- [x] 1.1 In `R/export_pdf.R::bfh_export_pdf()`: change parameter
      default from `restrict_template = FALSE` to
      `restrict_template = TRUE`. Single-line change at line 271.
- [x] 1.2 Update Roxygen `@param restrict_template` (around lines
      32-43): document new default + add migration note for callers
      passing `template_path`. Example:
      ```r
      # Before (BFHcharts <= 0.15.x): custom template silently allowed
      bfh_export_pdf(result, "out.pdf", template_path = "/my/template.typ")

      # After (BFHcharts >= 0.16.0): explicit opt-out required
      bfh_export_pdf(result, "out.pdf",
                     template_path = "/my/template.typ",
                     restrict_template = FALSE)
      ```
- [x] 1.3 Update Roxygen `@section Security` to reflect the new safer
      default; remove the "Default: FALSE (backward-compatible)" note;
      add "Default: TRUE (production-safe)".
- [x] 1.4 Verify validation block at lines 293-299 still fires
      correctly when default flips (no code change needed; just
      verify behaviour).

## 2. Slice B: attach `cl_user_supplied` attribute to summary

- [x] 2.1 In `R/utils_bfh_qic_helpers.R::build_bfh_qic_return()`:
      add logic to detect whether `config$cl` is non-NULL and set
      `attr(summary_result, "cl_user_supplied") <- !is.null(config$cl)`
      before returning the `bfh_qic_result` object.
      Note: applies whether `return.data = FALSE` (S3 path) or
      `return.data = TRUE` (raw qic_data path; attribute on the
      data.frame is harmless and useful).
- [x] 2.2 In `R/utils_spc_stats.R::bfh_extract_spc_stats.bfh_qic_result()`:
      surface the attribute as `stats$cl_user_supplied <- isTRUE(attr(x$summary, "cl_user_supplied"))`.
      Place near `stats$is_run_chart` assignment for consistency.
- [x] 2.3 In `R/utils_spc_stats.R::empty_spc_stats()`: add
      `cl_user_supplied = NULL` to the empty list (so the field is
      always discoverable in the type signature even when absent).

## 3. Slice B: PDF template caveat rendering

- [x] 3.1 Add `cl_user_supplied: false` parameter to
      `inst/templates/typst/bfh-template/bfh-template.typ`
      `bfh-diagram()` signature (next to `is_run_chart`, around
      line 38). Update the parameter doc-comment block at lines 4-21.
- [x] 3.2 Add caveat-text Typst block below the SPC table (after the
      existing `data_definition` block, around line 320). Conditional
      rendering:
      ```typst
      #if cl_user_supplied {
        block(width: 100%, inset: (top: 2mm),
          text(fill: rgb("888888"), size: 9pt, style: "italic",
            "Centerlinje fastsat manuelt -- Anhoej-signal beregnet ",
            "mod denne, ikke data-estimeret middelvaerdi"))
      }
      ```
      Note: ASCII-only in template body for the inline default; i18n
      values (with proper Danish chars) flow via the parameter when
      English/Danish text is computed R-side.
- [x] 3.3 R-side: compute caveat text in `compose_typst_document()`
      based on `language` config + `cl_user_supplied` flag. Pass as
      a NEW Typst parameter `cl_caveat_text` (string) so the template
      renders pre-translated text rather than hard-coded Danish.
- [x] 3.4 Update `R/utils_typst.R::build_typst_content()` to emit the
      new parameters: `cl_user_supplied` (boolean) + `cl_caveat_text`
      (string, only when `cl_user_supplied = TRUE`).

## 4. Slice B: i18n strings

- [x] 4.1 Add to `inst/i18n/da.yaml` (or whichever default-Danish
      file exists):
      ```yaml
      cl_user_supplied_caveat: >
        Centerlinje fastsat manuelt -- Anhoej-signal beregnet
        mod denne, ikke data-estimeret middelvaerdi
      ```
- [x] 4.2 Add to `inst/i18n/en.yaml`:
      ```yaml
      cl_user_supplied_caveat: >
        Centerline manually specified -- Anhoej signal computed
        against user-supplied centerline, not data-estimated
        process mean
      ```
- [x] 4.3 Verify `R/utils_i18n.R` exposes a helper to look up the
      key; if not, extend it minimally to support this single new
      key. (Likely already supports key-based lookup.)

## 5. Tests

- [x] 5.1 New tests in `tests/testthat/test-export_pdf.R`:
      - `test_that("bfh_export_pdf rejects template_path by default", { ... })`
        Asserts default behaviour errors with informative message
        when `template_path` supplied without explicit
        `restrict_template = FALSE`.
      - `test_that("bfh_export_pdf accepts template_path with restrict_template = FALSE", { ... })`
        Asserts opt-out works.
- [x] 5.2 New tests in `tests/testthat/test-utils_qic_summary.R`
      (or new file `test-cl-user-supplied-flag.R`):
      - `test_that("summary has cl_user_supplied attribute = TRUE when cl supplied", { ... })`
      - `test_that("summary has cl_user_supplied attribute = FALSE when cl NULL", { ... })`
      - `test_that("bfh_extract_spc_stats surfaces cl_user_supplied", { ... })`
- [x] 5.3 Extend `tests/testthat/test-export_pdf-content.R` (gated
      by `BFHCHARTS_TEST_RENDER`):
      - Render PDF with `bfh_qic(..., cl = X)`; assert PDF text
        contains caveat string (Danish + English).
      - Render PDF without `cl`; assert PDF text does NOT contain
        caveat string.
- [x] 5.4 Extend `tests/testthat/test-i18n.R` to verify new
      `cl_user_supplied_caveat` key resolves correctly in both
      locales.
- [x] 5.5 Run full test suite + verify no regression in existing PDF
      tests.

## 6. Documentation

- [x] 6.1 Update `R/export_pdf.R` Roxygen (Section: Security): refer
      to new safer default + cross-reference ADR-003.
- [x] 6.2 Update `R/bfh_qic.R` Roxygen `@param cl`: cross-reference
      `attr(result$summary, "cl_user_supplied")` for downstream
      consumers.
- [x] 6.3 NEWS.md `# BFHcharts 0.16.0`:
      - `## Breaking changes` section: slice A migration example.
      - `## New features` section: slice B summary attribute + PDF
        caveat description.
- [x] 6.4 New ADR `inst/adr/ADR-003-warning-blind-clinical-readers.md`
      documenting the risk model that drove both decisions:
      "PDFs reach quality-improvement leadership where R-side warnings
      never surface; defaults must optimize for clinical-production
      safety with explicit power-user opt-outs."

## 7. Cross-repo coordination

- [x] 7.1 Verify biSPCharts source: confirm no `template_path`
      argument is passed to `bfh_export_pdf()`. (Reviewed in design
      D6; re-verify pre-merge.)
- [x] 7.2 Document in this change's PR description that biSPCharts
      requires a follow-up PR bumping `Imports: BFHcharts (>= 0.16.0)`
      per VERSIONING_POLICY §E.

## 8. Release

- [x] 8.1 Bump `DESCRIPTION` Version: 0.15.x -> 0.16.0.
- [x] 8.2 `devtools::check()` clean (no new WARNINGs).
- [x] 8.3 Manual verification:
      - Default `bfh_export_pdf(result, "out.pdf",
        template_path = "/x.typ")` errors as expected.
      - `restrict_template = FALSE` opt-out works.
      - `bfh_qic(data, ..., cl = 50) |> bfh_export_pdf("out.pdf")`
        renders with caveat.
      - `bfh_qic(data, ...) |> bfh_export_pdf("out.pdf")` renders
        without caveat.
- [x] 8.4 Tag `v0.16.0` after `develop -> main` release-PR merges.
