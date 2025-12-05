## Why

Når brugere eksporterer SPC charts via `bfh_export_pdf()` eller `bfh_export_png()`, skal plot margins og axis titles optimeres til det pågældende output-format:

- **PDF**: Diagrammet indsættes i en Typst-skabelon, så margins skal være nul for optimal pasform
- **PNG**: Diagrammet bruges standalone, så en lille margin (5mm) giver bedre visuel balance

I begge tilfælde skal axis titles der ikke er sat (blanke/NULL) fjernes helt - ikke bare gøres usynlige med whitespace.

## What Changes

### PDF Export (`bfh_export_pdf()`)
- Sæt `plot.margin = margin(0, 0, 0, 0, "mm")` for optimal Typst-integration
- Fjern blanke axis titles med `element_blank()`

### PNG Export (`bfh_export_png()`)
- Sæt `plot.margin = margin(5, 5, 5, 5, "mm")` for visuel balance
- Fjern blanke axis titles med `element_blank()`

### Fælles logik
- Opret shared helper-funktion `prepare_plot_for_export()` der håndterer:
  - Margin-justering (parameter-styret)
  - Conditional axis title removal (samme logik for begge)
- Bevar bruger-definerede axis titles

## Impact

- Affected specs: pdf-export
- Affected code:
  - `R/export_pdf.R` (linje ~328)
  - `R/export_png.R` (linje ~128)

## Related

- GitHub Issue: #71
