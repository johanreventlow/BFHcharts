# Typst Templates for BFHcharts

This directory contains Typst templates for generating PDF reports with SPC charts.

## Template: bfh-diagram

The main template for SPC chart reports with hospital branding.

### Location

```
inst/templates/typst/bfh-template/bfh-template.typ
```

### Usage

The `bfh_export_pdf()` function uses this template automatically. You can also use it manually with Quarto.

### Template Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `hospital` | string | "Bispebjerg og Frederiksberg Hospital" | Hospital name |
| `department` | string | none | Department/unit name (optional) |
| `title` | string | "Paper Title" | Chart title |
| `analysis` | string | none | Analysis text with findings (optional) |
| `details` | string | none | Period info, averages (optional) |
| `author` | string | none | Author name (optional) |
| `date` | datetime | today | Report date |
| `data_definition` | string | none | Data definition explaining indicator (optional) |
| `runs_expected` | number | none | Expected serielængde (optional) |
| `runs_actual` | number | none | Actual serielængde (optional) |
| `crossings_expected` | number | none | Expected antal kryds (optional) |
| `crossings_actual` | number | none | Actual antal kryds (optional) |
| `outliers_expected` | number | none | Expected outliers (optional) |
| `outliers_actual` | number | none | Actual outliers (optional) |
| `footer_content` | content | none | Additional content below chart (optional) |
| `chart` | content | required | Chart image or content |

### Requirements

- **Quarto CLI** (>= 1.4.0) - Includes Typst compiler
- **Fonts:** Mari (hospital brand font) and Arial

### Font Availability

The template includes Mari font files in `bfh-template/fonts/`:
- `Mari.otf`, `Mari Bold.otf`, `Mari Light.otf`, etc.
- Arial font files (ARIAL.TTF, ARIALBD.TTF, etc.)

Fonts are automatically loaded by Typst from the template directory.

### Template Structure

```
A4 Landscape Layout:
┌─────────────────────────────────────────┐
│ Logo              Hospital Name         │
│                   Department            │
│                                         │
│ Title (Blue header bar)                │
├─────────────────────────────────────────┤
│ Analysis Text (if provided)            │
├────────────────────────┬────────────────┤
│                        │ SPC Statistics │
│ Chart Image            │ Table          │
│                        │                │
│                        │ Data           │
│                        │ Definition     │
├────────────────────────┴────────────────┤
│ Footer Content (if provided)            │
└─────────────────────────────────────────┘
```

### Customization

To customize the template:

1. Copy `bfh-template.typ` to your project
2. Modify colors, fonts, or layout
3. Pass custom template path to `bfh_export_pdf()`

### Color Scheme

| Element | Color | Hex |
|---------|-------|-----|
| Header bar | BFH Blue | #007dbb |
| Text primary | Dark gray | #888888 |
| Background | White | #ffffff |

### Logo Assets

Available in `bfh-template/images/`:
- `Logo_Bispebjerg_og Frederiksberg_RGB.png` - Main logo
- `Hospital_Maerke_RGB_A1_str.png` - Hospital mark
- Other variations for different contexts

## Rendering PDFs

### Via R (Recommended)

```r
# Use bfh_export_pdf()
bfh_qic(data, x, y, chart_type = "i", chart_title = "Infections") |>
  bfh_export_pdf(
    "output.pdf",
    metadata = list(
      hospital = "BFH",
      department = "Kvalitetsafdeling",
      analysis = "Signifikant fald observeret",
      data_definition = "Antal infektioner per måned"
    )
  )
```

### Via Quarto CLI

```bash
quarto render document.qmd --to typst
```

### Direct Typst Compilation

```bash
typst compile document.typ output.pdf
```

## Troubleshooting

### Font Issues

If fonts don't load:
- Verify fonts exist in `bfh-template/fonts/`
- Check Quarto version: `quarto --version`
- Ensure Quarto can access the template directory

### Missing Logo

If hospital logo doesn't appear:
- Check `images/` directory exists
- Verify PNG files are present
- Check image paths in `.typ` file

### Compilation Errors

Common issues:
- **Missing Quarto:** Install from https://quarto.org
- **Typst version:** Update Quarto to get latest Typst
- **Path issues:** Use absolute paths or verify working directory

## Version History

- **2024-12-01:** Initial template migration from SPCify to BFHcharts
- Template compatible with Quarto >= 1.4.0

## License

Fonts and logos are property of Bispebjerg og Frederiksberg Hospital.
Template code is part of BFHcharts package.
