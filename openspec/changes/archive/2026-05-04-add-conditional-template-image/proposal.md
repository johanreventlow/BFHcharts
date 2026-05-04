## Why

`bfh_export_pdf()` fails out-of-the-box on a clean install because the
production Typst template (`inst/templates/typst/bfh-template/bfh-template.typ`,
line 67) hard-references a hospital logo image that is NOT bundled with
the package:

```typst
foreground: (
   place(
     image("images/Hospital_Maerke_RGB_A1_str.png",
     height: 19.8mm
   ),
   ...
```

The `images/` subdirectory is intentionally excluded from the public
distribution (proprietary BFH branding asset). The companion package
`BFHchartsAssets` injects the image at runtime via `inject_assets`, but
users without the companion (e.g. anyone installing
`pak::pkg_install("johanreventlow/BFHcharts")` without GitHub-private
access) hit a hard Typst-compile failure:

```
error: file not found (searched at images/Hospital_Maerke_RGB_A1_str.png)
```

ADR-001 already documents the gap as the highest-severity remaining
issue from the asset-policy work
(`openspec/changes/2026-05-01-fix-pdf-template-asset-contract/tasks.md`
task 2.5, marked `[-]`). The font-fallback graceful-degradation path is
in place; only the image reference still aborts the render.

The font story is **degrade gracefully** by design (Mari -> Roboto ->
Arial -> Helvetica -> sans-serif). The image story should match that
contract: render without the logo when assets are not injected, render
with the logo when they are.

This is the last remaining FIX NOW blocker from the production-readiness
review (item 1.2) and the only outstanding task in the `fix-pdf-template-asset-contract`
OpenSpec change.

## What Changes

**Slice A -- Conditional image rendering in template (BREAKING for callers
who relied on the implicit failure mode):**

- Replace the unconditional `image("images/Hospital_Maerke_RGB_A1_str.png", ...)`
  call in `bfh-template.typ` with a conditional branch driven by a new
  template parameter `logo_path` (default `none`).
- When `logo_path` is `none` (default): no foreground image, layout is
  preserved (same `place()` slot, just empty). Header bar + title still
  render at the calibrated dimensions.
- When `logo_path` is a string: image is placed at the existing
  coordinates (`dy: 39.6mm, dx: 0mm, height: 19.8mm`).
- Companion packages (BFHchartsAssets) populate `logo_path` via
  `inject_assets` callback OR via the `metadata` argument to
  `bfh_export_pdf()`.

**Slice B -- R-side wiring:**

- `R/utils_typst.R::build_typst_content()` adds optional `logo_path`
  parameter; only emitted in the Typst params block when non-NULL.
- `R/export_pdf.R::bfh_export_pdf()` adds `logo_path` to the metadata
  contract (documented under `@param metadata`). Also: when an
  `inject_assets` callback creates an `images/` subdirectory in the
  staged template, the wrapper auto-detects the standard logo filename
  and populates `logo_path` (mirrors the `--font-path` auto-detect
  pattern in `bfh_compile_typst()`).
- `R/utils_metadata.R::bfh_merge_metadata()` accepts and forwards
  `logo_path`.

**Slice C -- Documentation + tests:**

- Update `inst/adr/ADR-001-pdf-asset-policy.md` "Negative / Remaining
  gaps" section: image-gap is closed via this change.
- New test `tests/testthat/test-template-image-conditional.R`:
  - Renders without `logo_path` -> PDF compiles successfully, no logo
    visible (asserts via `pdftools::pdf_text()` that page renders).
  - Renders with valid `logo_path` -> PDF compiles, image embedded.
  - Renders with invalid `logo_path` -> Typst error captured + surfaced
    with informative message (not a silent fallback to `none`).
- Update `tests/testthat/test-production-template-renders.R` test 1
  (the "no inject_assets" path) to assert PDF compiles successfully
  rather than skipping when images/ missing.
- Update `tests/testthat/helper-fixtures.R` if it has a fixture that
  builds metadata for tests.
- NEWS.md entry under `## Bug fixes`: "PDF export now renders
  successfully without a hospital logo when assets are not injected
  (graceful degradation matching the font-fallback contract from
  ADR-001)."

**Cross-cutting:**

- No version bump required: this is a bug fix that closes a known
  graceful-degradation gap. Patch-level bump (0.15.0 -> 0.15.1) at next
  release cadence.
- Ship in same release as `cleanup-test-artifacts-and-repo-hygiene` if
  ready, otherwise standalone PATCH.

## Capabilities

### Modified Capabilities

- `pdf-export`: `bfh_export_pdf()` no longer fails when no logo image is
  available. Default rendering produces a logo-less PDF; companion-injected
  assets restore branding. Reference: `openspec/specs/pdf-export/spec.md`
  (will need delta entry under `## ADDED Requirements` for the
  conditional image rendering).

## Impact

**Code (3 files):**
- `inst/templates/typst/bfh-template/bfh-template.typ` -- replace
  unconditional `image()` with conditional branch on `logo_path`
  parameter (~10 lines).
- `R/utils_typst.R` -- add `logo_path` to template params emission +
  auto-detect packaged image (~15 lines).
- `R/export_pdf.R` + `R/utils_metadata.R` -- forward `logo_path` through
  metadata contract (~10 lines + Roxygen update).

**Tests (2 files):**
- `tests/testthat/test-template-image-conditional.R` -- new file, 3
  test_that blocks (~40 lines).
- `tests/testthat/test-production-template-renders.R` -- update test 1
  to assert success rather than skip (~5 lines changed).

**Docs:**
- `inst/adr/ADR-001-pdf-asset-policy.md` -- close known-gap section.
- `NEWS.md` -- bug-fix entry.
- `R/export_pdf.R` Roxygen `@param metadata` -- add `logo_path` field.

**Public API surface:**
- `bfh_export_pdf(metadata = list(logo_path = ...))` is a new accepted
  metadata field. Backward-compatible: callers who do not supply it get
  the new (working) default behaviour.
- `bfh_create_typst_document()` (exported) gains the new field via its
  `metadata` parameter.

**Risk:**
- Visual-regression risk: the foreground `place()` slot will be empty
  in default render. Layout calibration assumed the image was present.
  Mitigation: smoke-test renders (no logo + with logo) confirm that
  removal does not shift other elements (header bar, title block use
  fixed offsets, not relative-to-image positioning).
- Companion-package compat: `BFHchartsAssets` currently relies on
  staging the image via `inject_assets` callback, which writes to
  `<staged-template>/images/`. After this change the callback-only
  path still works (auto-detect picks up the staged image). Companion
  package does NOT need an immediate update.

**Out of scope:**
- Replacing the BFH logo with a placeholder asset (license decision +
  bundle-size tradeoff).
- Bundling Roboto fonts (separate decision per ADR-001 §"Negative").
- Changing the font chain (companion-only Mari remains first priority).
