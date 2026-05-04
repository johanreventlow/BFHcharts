## 1. Template-side: conditional image rendering

- [ ] 1.1 Add `logo_path: none` parameter to `bfh-diagram()` function
      signature in `inst/templates/typst/bfh-template/bfh-template.typ`
      (next to `footer_content`, around line 41).
- [ ] 1.2 Replace `foreground: (place(image("images/Hospital_Maerke_RGB_A1_str.png", ...), ...))`
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
- [ ] 1.3 Verify Typst syntax compiles standalone: `quarto typst compile`
      a minimal test .typ that imports the template with no logo + with
      a fixture logo.

## 2. R-side: wire `logo_path` through pipeline

- [ ] 2.1 In `R/utils_typst.R::build_typst_content()`: add
      `if (!is.null(metadata$logo_path)) params$logo_path <- ...` block.
      Use `escape_typst_string()` on the path. Treat as Typst string,
      not content block.
- [ ] 2.2 In `R/utils_typst.R::bfh_compile_typst()`: add helper
      `.detect_packaged_logo()` mirroring `.detect_packaged_fonts()`.
      Looks for `<staged-template>/images/Hospital_Maerke_RGB_A1_str.png`
      (or any `.png`/`.svg` in `images/` -- design decision: deterministic
      filename vs glob).
- [ ] 2.3 If `metadata$logo_path` not supplied AND auto-detect finds
      staged logo: populate `metadata$logo_path` automatically before
      calling `build_typst_content()`. Mirrors font-path auto-detect
      semantics.
- [ ] 2.4 In `R/export_pdf.R`: update `@param metadata` Roxygen to
      document new `logo_path` field. Note: companion-injected assets
      auto-populate this; explicit override is for advanced use.
- [ ] 2.5 In `R/utils_metadata.R::bfh_merge_metadata()`: add `logo_path`
      to the recognized metadata fields if the function whitelists.
      Otherwise no change (pass-through).

## 3. Tests

- [ ] 3.1 New file `tests/testthat/test-template-image-conditional.R`
      with three `test_that` blocks:
      - `test_that("PDF compiles without logo when logo_path absent", {...})`
      - `test_that("PDF compiles with logo when logo_path supplied", {...})`
      - `test_that("PDF errors with informative message on invalid logo_path", {...})`
      Use `withr::local_tempdir()` + `BFHCHARTS_TEST_RENDER` gate
      (matches existing `test-production-template-renders.R` pattern).
- [ ] 3.2 Update `tests/testthat/test-production-template-renders.R` test
      1 (no inject_assets) to assert PDF compiles successfully (no
      `skip_if_not()` on missing images/). Test 2 (with inject_assets)
      remains as-is.
- [ ] 3.3 Run full test suite + verify no regression in existing PDF
      tests (`test-export_pdf.R`, `test-export_pdf-content.R`,
      `test-quarto-isolation.R`).

## 4. Documentation

- [ ] 4.1 Update `inst/adr/ADR-001-pdf-asset-policy.md` "Negative /
      Remaining gaps" section: image-gap closed; reference this change.
- [ ] 4.2 NEWS.md: bug-fix entry under next release header (likely
      `# BFHcharts 0.15.1` or `(development)`).
- [ ] 4.3 README.md: update PDF asset policy section if it mentions
      images-as-known-gap.

## 5. Cross-link to existing OpenSpec changes

- [ ] 5.1 Update `openspec/changes/2026-05-01-fix-pdf-template-asset-contract/tasks.md`
      task 2.5 status: mark as `[x]` with note referencing this change
      as resolution.
- [ ] 5.2 Optionally archive `2026-05-01-fix-pdf-template-asset-contract`
      after this change ships, since it becomes complete.

## 6. Release

- [ ] 6.1 Decide release scope: standalone PATCH (0.15.1) or bundle
      with `cleanup-test-artifacts-and-repo-hygiene` (also targeting
      PATCH).
- [ ] 6.2 `devtools::check()` clean (no new WARNINGs).
- [ ] 6.3 Manual verification: clean tarball install in fresh R session
      + `bfh_export_pdf()` on sample data renders PDF without errors.
