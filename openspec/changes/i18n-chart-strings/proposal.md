# i18n-chart-strings

## Why

Flere centrale hjælpefunktioner har hårdkodede danske strenge (fx i
fallback-analyse, label-tekster, detaljer, resolve_target). Det begrænser
pakkens internationale anvendelse og låser fremtidig engelsk-support til
stor refaktorering.

Gemini review anbefaler lookup-tabeller (YAML eller named lists) og en
`language` parameter.

## What Changes

- Tilføj `language = "da"` parameter til relevante public functions:
  - `bfh_generate_analysis()`
  - `bfh_generate_details()`
  - `bfh_qic()` (for labels/titler)
- Ekstraher danske strings til `inst/i18n/da.yaml`
- Tilføj `inst/i18n/en.yaml` som skabelon (initial engelsk oversættelse)
- Intern helper `i18n_lookup(key, language)` slår strings op
- Fallback til dansk hvis nøgle mangler i target-sprog
- Breaking? NEJ — default forbliver "da", ingen signaturændringer uden opt-in

## Impact

**Affected specs:**
- `public-api` (ny requirement: language-parameter)
- Potentielt ny capability `internationalization` (overvej ved scaffolding)

**Affected code:**
- `inst/i18n/da.yaml`, `inst/i18n/en.yaml` (ny)
- `R/utils_i18n.R` (ny lookup helper)
- `R/spc_analysis.R`, `R/export_pdf.R`, `R/create_spc_chart.R` (brug lookup)
- Tests: verify alle strings findes i begge sprog

**User-visible changes:**
- Ny `language` parameter på relevante funktioner (default "da" — backward compat)
- Engelsk version initialt via standardoversættelse; kvalitets-review anbefales

## Related

- Gemini review (hårdkodet dansk sprog)
