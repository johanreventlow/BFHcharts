## Why

`bfh_export_pdf()` in `R/export_pdf.R:161-490` is 330 lines combining:
- Class + path validation
- Metadata validation (type checking, length limits, unknown fields)
- Optional parameter validation (font_path, inject_assets, dpi)
- Batch session validation
- Auto-analysis generation
- Auto-details generation
- Custom template path validation + file checks
- Quarto availability check
- Tempdir creation + permissions + ownership verification (Unix UID check)
- Title extraction + plot stripping
- Label recalculation for export dimensions
- Plot margin preparation
- SVG export via ggsave (with tryCatch)
- SPC stats extraction
- Metadata merge
- Font path resolution
- Typst document creation
- inject_assets callback execution
- Quarto compilation
- Cleanup

Codex finding #5 + Claude finding #4 both flagged this as HIGH severity. Companion to `refactor-bfh_qic-orchestrator` (#211).

## What Changes

- **NON-BREAKING refactor**: split `bfh_export_pdf()` into orchestrator + 7-8 helpers:
  - `validate_bfh_export_pdf_inputs()` — class + path + metadata + optional params + batch session
  - `prepare_export_metadata()` — auto-analysis, auto-details, merge with defaults
  - `prepare_temp_workspace()` — tempdir creation, permissions, ownership check (or reuse session)
  - `prepare_export_plot()` — title strip, label recalc, margin adjustment
  - `export_chart_svg()` — ggsave wrapper with error handling
  - `compose_typst_document()` — bfh_create_typst_document call + inject_assets execution
  - `compile_pdf_via_quarto()` — bfh_compile_typst wrapper
  - Existing `bfh_create_typst_document` + `bfh_compile_typst` unchanged
- Public function signature unchanged
- All existing tests pass
- Add unit tests for each helper

## Impact

**Affected specs:**
- `code-organization` — references requirement from #211 (orchestrator pattern); applies same pattern here

**Affected code:**
- `R/export_pdf.R` — orchestrator reduced to ≤ 80 lines
- `R/utils_export_helpers.R` — new file with extracted helpers (or extend existing utils file)
- `tests/testthat/test-export_pdf.R` — extended with helper-isolation tests

**Non-breaking:**
- Public API identical
- No behavior change
- Security checks ordering preserved (validation before file system ops, before Quarto)

## Cross-repo impact (biSPCharts)

None. Public API unchanged.

## Related

- GitHub Issue: #212
- Companion proposal: `refactor-bfh_qic-orchestrator` (#211)
- Source: BFHcharts code review 2026-04-27 (Codex #5, Claude #4)
