# Proposal: Add Export Functions

## Why

BFHcharts currently only provides visualization capabilities. Users who want to export SPC charts to PDF or PNG must use SPCify (Shiny app), which has ~40+ dependencies including the entire Shiny ecosystem.

**Problem:** There is no way to programmatically export SPC charts without running a Shiny application.

**Primary Motivation:** Enable programmatic export of SPC charts for use in:
- R scripts
- Quarto documents
- R Markdown reports
- Automated reporting pipelines

## What Changes

### New S3 Class: `bfh_qic_result`

`bfh_qic()` will return a `bfh_qic_result` S3 object instead of a plain ggplot. This enables:
- Pipe-compatible export: `bfh_qic() |> bfh_export_pdf()`
- Access to SPC statistics for PDF metadata
- Backwards-compatible console display via print method

### New Export Functions

1. **`bfh_export_png()`** - Export chart to PNG with configurable dimensions
2. **`bfh_export_pdf()`** - Export chart to PDF via Typst templates
3. **`bfh_create_typst_document()`** - Low-level Typst document generation

### Architecture: Lazy Transformation

- **PNG output:** Title rendered in ggplot image
- **PDF output:** Title extracted from chart and rendered in Typst template (not in ggplot)

This allows the same `bfh_qic()` output to be used for both formats with appropriate transformation at export time.

## Impact

### Breaking Changes

- `bfh_qic()` returns `bfh_qic_result` instead of ggplot object
- Migration: Use `result$plot` to access ggplot directly
- Print method maintains backwards-compatible console display

### New Dependencies

**R packages:**
- `pdftools` (>= 3.3.0) - PDF preview generation

**System requirements:**
- Quarto CLI (>= 1.4.0) - Required for PDF compilation via Typst

### Affected Downstream

- **SPCify:** Must update to use new BFHcharts export functions instead of internal implementations

## Version

- BFHcharts: 0.2.0 → 0.3.0 (breaking change in return type)

## Related

- GitHub Issue: #59
- Previous change: `rename-to-bfh-qic` (function renamed in 0.2.0)
