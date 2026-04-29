## 1. Implementation

- [ ] 1.1 Tilføj intern helper `.normalize_percent_target(value, display, y_axis_unit)` i `R/spc_analysis.R` (placeret nær `resolve_target()`)
- [ ] 1.2 Helper-kontrakt:
  - Returnerer normaliseret numerisk værdi
  - Hvis `y_axis_unit == "percent"` AND `display` indeholder `"%"` AND `value > 1`: returner `value / 100`
  - Ellers: returner `value` uændret
- [ ] 1.3 Wire helper-kald ind i `bfh_build_analysis_context()` mellem `resolve_target()` og context-list-konstruktion (`R/spc_analysis.R:163-222`)
- [ ] 1.4 Roxygen for helper med 3-4 examples (percent + display "%", percent + ingen "%", ej percent, allerede proportion)

## 2. Tests

- [ ] 2.1 Test: p-chart, `target = ">= 90%"`, `centerline = 0.91` → analysis indeholder "opfylder målet" (DK) / "goal met" (EN)
- [ ] 2.2 Test: p-chart, `target = ">= 90%"`, `centerline = 0.85` → "endnu ikke nået"
- [ ] 2.3 Test: p-chart, `target = "<= 5%"`, `centerline = 0.03` → "lower"-direction goal met
- [ ] 2.4 Test: p-chart, numerisk `target = 90` → normaliseres til 0.90 internt
- [ ] 2.5 Test: p-chart, numerisk `target = 0.9` → ikke normaliseret (allerede proportion)
- [ ] 2.6 Test: p-chart, `target = "≥ 0.9"` (ingen `%` i display) → ikke normaliseret
- [ ] 2.7 Test: i-chart, `target = ">= 90"` → ingen normalisering (count-skala uændret)
- [ ] 2.8 Test: rate-chart, `target = "<= 2.5"` → ingen normalisering
- [ ] 2.9 Test: u-chart med `y_axis_unit = "rate"`, `target = "5%"` → ingen normalisering (rate ej percent)
- [ ] 2.10 Direkte unit-test af `.normalize_percent_target()` for alle 6 kombinationer (3 input-typer × 2 unit-typer)

## 3. Documentation

- [ ] 3.1 Opdatér `bfh_build_analysis_context()` Roxygen `@details` med "Percent-Target Normalization"-sektion
- [ ] 3.2 NEWS.md entry under `## Bug fixes` med beskrivelse af scope (kun `auto_analysis = TRUE` på percent-charts) og migration-note (ingen handling påkrævet for korrekt fungerende kald)
- [ ] 3.3 Eksisterende `metadata$target`-dokumentation i `bfh_export_pdf()` og `bfh_generate_analysis()` — verificér at den nu beskriver normalisering korrekt

## 4. Verification

- [ ] 4.1 `devtools::test()` passes (alle nye + eksisterende tests)
- [ ] 4.2 `devtools::check()` no new WARN/ERROR
- [ ] 4.3 Manuel verifikation: konstruér p-chart med 91% centerline + ">= 90%" target, generer PDF, læs auto-analysis-tekst — bekræft at output siger "målet opfyldt"
- [ ] 4.4 Cross-check at eksisterende statistical-accuracy-tests fortsat passerer (ingen utilsigtet impact på chart-rendering)

## 5. Release

- [ ] 5.1 Bump `DESCRIPTION` til næste patch-version
- [ ] 5.2 Tag efter merge til main
- [ ] 5.3 Notify biSPCharts-maintainer hvis sister-app bruger `auto_analysis = TRUE` på percent-indikatorer (klinisk relevans-kontrol)
