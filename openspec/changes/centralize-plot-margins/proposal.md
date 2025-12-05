## Why

Aktuelt anvendes plot margins (5mm) og blank axis title removal kun ved eksport via `bfh_export_pdf()` og `bfh_export_png()`. Brugere ønsker samme visuelle konsistens ved interaktiv visning direkte fra `bfh_qic()`.

Ved at centralisere denne logik i `apply_spc_theme()` (som kaldes af `bfh_qic()`):
- Alle plots får automatisk optimerede margins og clean axis titles
- Eksportfunktionerne simplificeres (undgår duplikeret logik)
- Konsistent udseende uanset output-kontekst

## What Changes

### Centraliser i `apply_spc_theme()`:
- Tilføj default 5mm margins til alle bfh_qic() plots
- Tilføj blank axis title removal (fjern NULL/tomme titles med element_blank())
- Bevar eksisterende plot_margin override-mulighed

### Simplificer eksportfunktioner:
- `bfh_export_png()`: Fjern prepare_plot_for_export() kald (default 5mm kommer fra bfh_qic)
- `bfh_export_pdf()`: Behold kun margin override til 0mm (axis titles allerede håndteret)
- `prepare_plot_for_export()`: Simplificer til kun margin-håndtering

## Impact

- Affected specs: pdf-export (MODIFIED)
- Affected code:
  - `R/themes.R` (apply_spc_theme)
  - `R/export_pdf.R` (prepare_plot_for_export, bfh_export_pdf)
  - `R/export_png.R` (bfh_export_png)

## Related

- GitHub Issue: #72
- Relateret ændring: add-export-plot-margins (implementeret)
