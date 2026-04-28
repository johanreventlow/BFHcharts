## 1. Helper extraction

- [ ] 1.1 Create `validate_bfh_export_pdf_inputs()` (lines 174-286) — class, path, metadata, dpi, font_path, inject_assets, batch_session
- [ ] 1.2 Create `prepare_export_metadata()` (lines 290-307) — auto-analysis + auto-details + merge_metadata
- [ ] 1.3 Create `prepare_temp_workspace()` (lines 360-400) — tempdir + permissions + UID check + cleanup hook
- [ ] 1.4 Create `prepare_export_plot()` (lines 402-426) — title strip + recalculate_labels + margin
- [ ] 1.5 Create `export_chart_svg()` (lines 431-449) — ggsave with tryCatch
- [ ] 1.6 Create `compose_typst_document()` (lines 451-485) — bfh_create_typst_document + inject_assets + font_path resolution
- [ ] 1.7 Create `compile_pdf_via_quarto()` — wraps `bfh_compile_typst()` with consistent font_path handling
- [ ] 1.8 Update `bfh_export_pdf()` to call helpers in sequence — target ≤ 80 lines body
- [ ] 1.9 Preserve security check ordering: validation → file system → Quarto

## 2. Helper tests

- [ ] 2.1 Extend `tests/testthat/test-export_pdf.R` (or new `test-export_pdf-helpers.R`)
- [ ] 2.2 Test `validate_bfh_export_pdf_inputs()` with all violation cases
- [ ] 2.3 Test `prepare_export_metadata()` auto-analysis + auto-details with mocks
- [ ] 2.4 Test `prepare_temp_workspace()` permissions + cleanup
- [ ] 2.5 Test `prepare_export_plot()` returns correctly-sized plot
- [ ] 2.6 Test `export_chart_svg()` error handling on disk full / readonly path
- [ ] 2.7 Test `compose_typst_document()` font_path resolution from session vs per-export

## 3. Regression verification

- [ ] 3.1 Full `devtools::test()` passes
- [ ] 3.2 `devtools::check()` no new WARN/ERROR
- [ ] 3.3 Live render test (#210 if available) produces identical PDF output
- [ ] 3.4 Security tests still pass (path traversal, metachar rejection, etc.)

## 4. Documentation

- [ ] 4.1 Roxygen `@details` to `bfh_export_pdf()` referencing helper map
- [ ] 4.2 Roxygen for each new helper (`@noRd` if internal)
- [ ] 4.3 NEWS entry under `## Interne ændringer`

## 5. Release

- [ ] 5.1 PATCH bump (refactor only)
- [ ] 5.2 Tests pass

Tracking: GitHub Issue #212
