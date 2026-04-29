# Spec: PDF Smoke Render Infrastructure

## Krav

### Smoke-render workflow

- SHALL køre på `pull_request` til `main` og `develop`
- SHALL køre `tests/smoke/render_smoke.R`
- SHALL installere åbne fallback-fonts (DejaVu, Liberation, Noto, Roboto) på Linux-runners
- SHALL installere Quarto pre-release (Typst >= 0.13 for `--ignore-system-fonts`)
- SHALL fejle PR-merge hvis smoke-render fejler (kræver manuelt branch-protection-trin)

### Smoke-render script

- SHALL kalde `bfh_export_pdf()` mindst 3 gange med repræsentative chart-typer
- SHALL bruge `inst/extdata/spc_exampledata_utf8.csv` som primær datakilde
- SHALL assertere: `file.exists()`, `file.size() > 0`, `pdftools::pdf_info()$pages >= 1`
- SHALL rydde temp-filer op via `on.exit()`
- SHALL respektere `BFHCHARTS_SMOKE_FONT_PATH` env-var for CI font-path-override

### Test-infrastruktur

- `skip_if_no_pdf_render_deps()` SHALL tjekke Quarto + pdftools samlet
- `test-visual-regression.R` SHALL bruge per-test `skip_if_no_mari_font()` (ej fil-scope)
- `setup.R` font-alias-sæt SHALL matche `R/zzz.R register_bfh_font_aliases()` (Mari/Arial/Roboto)
