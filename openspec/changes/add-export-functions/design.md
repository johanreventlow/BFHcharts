# Design: Add Export Functions

## Overview

This document describes the architectural decisions for adding PDF and PNG export functionality to BFHcharts.

## Key Design Decisions

### 1. S3 Class for Pipe Compatibility

**Decision:** `bfh_qic()` returns a `bfh_qic_result` S3 object instead of a plain ggplot.

**Rationale:**
- Enables natural pipe syntax: `bfh_qic() |> bfh_export_pdf()`
- Preserves SPC statistics (runs, crossings, outliers) for PDF metadata
- Print method shows plot, maintaining backwards-compatible console behavior

**Trade-off:** Breaking change in return type. Mitigated by:
- Print method still displays plot
- `result$plot` provides direct ggplot access
- Clear migration guide in NEWS.md

### 2. Lazy Transformation for Output Formats

**Decision:** Generate plot with title, transform at export time based on target format.

**PNG Flow:**
```
bfh_qic() → bfh_qic_result (plot WITH title) → bfh_export_png() → PNG file (title visible)
```

**PDF Flow:**
```
bfh_qic() → bfh_qic_result (plot WITH title) → bfh_export_pdf() → strip title → PNG → Typst → PDF
                                                                    ↓
                                                              metadata extraction
                                                              (title, SPC stats)
```

**Rationale:**
- Single `bfh_qic()` call works for all output formats
- No need for separate "for PDF" or "for PNG" parameters
- Export functions handle format-specific requirements

### 3. Typst Templates in Package

**Decision:** Include Typst templates in `inst/templates/typst/`.

**Rationale:**
- Templates are reusable across users
- Enables programmatic PDF generation without SPCify
- BFH-specific branding can be customized via template parameters

**Template Structure:**
```
inst/templates/typst/
├── bfh-template/
│   ├── bfh-template.typ    # Main template
│   ├── fonts/              # Hospital fonts
│   └── images/             # Logo assets
```

### 4. Quarto CLI Dependency

**Decision:** Require Quarto CLI for PDF compilation.

**Rationale:**
- Quarto bundles Typst (no separate Typst installation)
- Widely available on all platforms
- Already standard in R data science workflows

**Mitigation:**
- Clear error message if Quarto not found
- PNG export works without Quarto
- Document installation in README

## Data Structures

### bfh_qic_result S3 Object

```r
structure(
  list(
    plot = <ggplot>,           # Chart with title
    summary = <tibble>,        # SPC statistics
    qic_data = <list>,         # Raw qicharts2 data
    config = list(             # Original parameters
      chart_type = "i",
      chart_title = "...",
      ...
    )
  ),
  class = c("bfh_qic_result", "list")
)
```

### Summary Tibble Contents

```r
# Accessible via result$summary
tibble(
  runs_expected = 12,
  runs_actual = 10,
  crossings_expected = 8,
  crossings_actual = 6,
  outliers_expected = 0,
  outliers_actual = 1,
  center_line = 50.2,
  ucl = 65.3,
  lcl = 35.1
)
```

## API Design

### bfh_export_png()

```r
bfh_export_png(
  x,                    # bfh_qic_result object
  output,               # Output file path
  width_mm = 200,       # Width in mm
  height_mm = 120,      # Height in mm
  dpi = 300             # Resolution
)
```

**Returns:** `invisible(x)` for pipe chaining.

### bfh_export_pdf()

```r
bfh_export_pdf(
  x,                    # bfh_qic_result object
  output,               # Output file path
  metadata = list(      # Optional metadata
    hospital = "BFH",
    department = NULL,
    analysis = NULL,
    data_definition = NULL,
    author = NULL,
    date = Sys.Date()
  ),
  template = "bfh-diagram2"  # Template name
)
```

**Returns:** `invisible(x)` for pipe chaining.

## Migration from SPCify

### Code to Move

| SPCify File | BFHcharts File | Notes |
|-------------|----------------|-------|
| `fct_export_png.R` | `R/export_png.R` | Rename function, remove Shiny deps |
| `fct_export_typst.R` | `R/export_pdf.R` | Rename functions, remove logging |
| `inst/templates/typst/` | `inst/templates/typst/` | Copy templates |

### Code to Remove from SPCify

- `R/fct_export_png.R`
- `R/fct_export_typst.R`
- `inst/templates/typst/` (keep reference to BFHcharts)

### SPCify Refactoring

```r
# Before (SPCify internal):
result <- generate_png_export(plot, width, height, dpi, output)

# After (BFHcharts delegation):
result <- BFHcharts::bfh_export_png(bfh_result, output, width_mm, height_mm, dpi)
```

## Testing Strategy

### Unit Tests

1. **S3 class tests:**
   - `bfh_qic()` returns `bfh_qic_result`
   - Print method displays plot
   - `$plot`, `$summary`, `$config` accessors work

2. **PNG export tests:**
   - Creates valid PNG file
   - Respects dimension parameters
   - Title visible in output

3. **PDF export tests (conditional):**
   - Skip if Quarto not available
   - Creates valid PDF file
   - Metadata appears in Typst output

### Integration Tests

1. **Pipe workflow:**
   ```r
   bfh_qic(data, x, y) |> bfh_export_png("test.png")
   ```

2. **Full PDF workflow:**
   ```r
   bfh_qic(data, x, y, chart_title = "Test") |>
     bfh_export_pdf("test.pdf", metadata = list(hospital = "BFH"))
   ```

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Quarto not installed | Medium | PDF export fails | Clear error message, graceful degradation |
| Breaking change causes issues | Medium | User code breaks | Migration guide, deprecation period for 0.x |
| Template rendering issues | Low | PDF looks wrong | Test on multiple platforms, include fallback |
| Large file sizes | Low | Slow export | Optimize DPI defaults, document options |
