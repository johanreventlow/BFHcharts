## 1. Template-side: conditional image rendering

- [x] 1.1 Add `logo_path: none` parameter to `bfh-diagram()` function
      signature in `inst/templates/typst/bfh-template/bfh-template.typ`
      (next to `footer_content`, around line 41).
- [x] 1.2 Replace `foreground: (place(image("images/Hospital_Maerke_RGB_A1_str.png", ...), ...))`
      block (lines 65-78) with conditional:
      ```typst
      foreground: if logo_path != none {
        place(
          image(logo_path, height: 19.8mm),
          dy: 39.6mm,
          dx: 0mm
        )
      } else { none }
      ```
- [x] 1.3 Verify Typst syntax compiles standalone: `quarto typst compile`
      a minimal test .typ that imports the template with no logo + with
      a fixture logo.
      Note: verified end-to-end via `bfh_export_pdf()` smoke tests in
      `test-template-image-conditional.R` and `test-production-template-renders.R`.

## 2. R-side: wire `logo_path` through pipeline

- [x] 2.1 In `R/utils_typst.R::build_typst_content()`: add
      `if (!is.null(metadata$logo_path)) params$logo_path <- ...` block.
      Use `escape_typst_string()` on the path. Treat as Typst string,
      not content block.
      Note: includes scalar non-empty character validation guard in addition
      to the original is.null() check.
- [x] 2.2 In `R/utils_typst.R::bfh_compile_typst()`: add helper
      `.detect_packaged_logo()` mirroring `.detect_packaged_fonts()`.
      Looks for `<staged-template>/images/Hospital_Maerke_RGB_A1_str.png`.
      Note: filename is deterministic (not glob) per design.md D2.
      CRITICAL detail: returned path is RELATIVE TO THE TEMPLATE FILE
      (`images/...`), not relative to the calling document
      (`bfh-template/images/...`), because Typst resolves `#image()` paths
      relative to the .typ that contains the call -- the template, not
      the calling document. Returning a calling-doc-relative path produces
      a double-prefix file-not-found error at compile.
- [x] 2.3 If `metadata$logo_path` not supplied AND auto-detect finds
      staged logo: populate `metadata$logo_path` automatically before
      calling `build_typst_content()`. Mirrors font-path auto-detect
      semantics.
      Note: implemented in `compose_typst_document()` (R/utils_export_helpers.R),
      not in `bfh_compile_typst()`. The detect runs after inject_assets
      so it sees companion-injected files.
- [x] 2.4 In `R/export_pdf.R`: update `@param metadata` Roxygen to
      document new `logo_path` field. Note: companion-injected assets
      auto-populate this; explicit override is for advanced use.
- [x] 2.5 In `R/utils_metadata.R::bfh_merge_metadata()`: add `logo_path`
      to the recognized metadata fields if the function whitelists.
      Otherwise no change (pass-through).
      Note: defaults list now whitelists logo_path: NULL. Without this,
      the intersect() filter in modifyList silently drops the field.

## 3. Tests

- [x] 3.1 New file `tests/testthat/test-template-image-conditional.R`
      with three `test_that` blocks:
      - `test_that("PDF compiles successfully without logo_path (default)", {...})`
      - `test_that("PDF compiles successfully with explicit logo_path", {...})`
      - `test_that("Invalid logo_path surfaces a clear error from Typst", {...})`
      Use `withr::local_tempdir()` + `BFHCHARTS_TEST_RENDER` gate
      (matches existing `test-production-template-renders.R` pattern).
      Note: fixture PNG generated via `ggplot2::ggsave` (avoids raw-byte
      CRC pitfalls + base R graphics-device init issues).
- [x] 3.2 Update `tests/testthat/test-production-template-renders.R` test
      1 (no inject_assets) to assert PDF compiles successfully (no
      `skip_if_not()` on missing images/). Test 2 (with inject_assets)
      remains as-is.
      Note: also fixed pre-existing latent bug in `.make_smoke_result()`
      (quoted NSE-args + nonexistent metadata parameter); surfaced when
      images-skip removed and tests actually executed render path.
- [x] 3.3 Run full test suite + verify no regression in existing PDF
      tests (`test-export_pdf.R`, `test-export_pdf-content.R`,
      `test-quarto-isolation.R`).
      Note: pre-push hook ran full suite -- 3016 pass, 0 fail, 0 err,
      54 skip. Targeted re-runs with `BFHCHARTS_TEST_RENDER=true`:
      template-image-conditional 3/3, production-template-renders 8/8,
      quarto-isolation 65+/0, typst-fonts-autodetect 8/8,
      harden-export-pipeline-security 56/56, export_pdf 200+/0.

## 4. Documentation

- [x] 4.1 Update `inst/adr/ADR-001-pdf-asset-policy.md` "Negative /
      Remaining gaps" section: image-gap closed; reference this change.
      Note: applied with strikethrough on the original gap statement
      plus cross-reference to this change.
- [x] 4.2 NEWS.md: bug-fix entry under next release header (likely
      `# BFHcharts 0.15.1` or `(development)`).
      Note: entry added under `# BFHcharts 0.15.1 (development)` ##
      Bug fixes with migration notes for the three caller cohorts
      (no inject_assets, with inject_assets, advanced explicit logo_path).
- [-] 4.3 README.md: update PDF asset policy section if it mentions
      images-as-known-gap.
      Note: README PDF-asset section does not currently explicitly call
      out the image-gap; no update needed. Re-evaluate at next README
      audit.

## 5. Cross-link to existing OpenSpec changes

- [x] 5.1 Update `openspec/changes/2026-05-01-fix-pdf-template-asset-contract/tasks.md`
      task 2.5 status: mark as `[x]` with note referencing this change
      as resolution.
- [-] 5.2 Optionally archive `2026-05-01-fix-pdf-template-asset-contract`
      after this change ships, since it becomes complete.
      Note: deferred -- separate `/opsx:archive` invocation after PR
      #297 merges. Both changes are now complete.

## 6. Release

- [-] 6.1 Decide release scope: standalone PATCH (0.15.1) or bundle
      with `cleanup-test-artifacts-and-repo-hygiene` (also targeting
      PATCH).
      Note: deferred to maintainer release-cadence decision. NEWS entry
      currently under `# BFHcharts 0.15.1 (development)`.
- [-] 6.2 `devtools::check()` clean (no new WARNINGs).
      Note: full pre-push test suite green (3016 pass, 0 fail). Standalone
      `devtools::check()` deferred to release-cut.
- [-] 6.3 Manual verification: clean tarball install in fresh R session
      + `bfh_export_pdf()` on sample data renders PDF without errors.
      Note: deferred to release-cut. Listed in PR #297 manual-verification
      checklist.
