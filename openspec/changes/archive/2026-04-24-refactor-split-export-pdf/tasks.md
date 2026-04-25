## 1. Specification

- [x] 1.1 Beskriv den nye ansvarsopdeling for PDF-export og relaterede
  utilities i `code-organization` spec
- [x] 1.2 Beskriv alias-oprydningen og canonical `bfh_*` call pattern i
  design-noten

## 2. Implementation

- [x] 2.1 Opret `R/utils_spc_stats.R` og flyt
  `bfh_extract_spc_stats()`-generic, methods og helpers
- [x] 2.2 Opret `R/utils_metadata.R` og flyt `bfh_merge_metadata()`
- [x] 2.3 Opret dedikeret helperfil til `bfh_generate_details()` og
  relaterede interne formatteringshelpers
- [x] 2.4 Reducer `R/export_pdf.R` til eksportvalidering, plot-prep,
  Typst-dokumentoprettelse og compile orchestration
- [x] 2.5 Fjern `extract_spc_stats()` og `merge_metadata()` og opdater alle
  interne call sites til `bfh_*` funktioner
  (Note: Aliaserne fandtes ikke i koden — allerede brugte `bfh_*` direkte)

## 3. Verification

- [x] 3.1 Opdater tests så de ikke bruger `BFHcharts:::extract_spc_stats()`
  eller `BFHcharts:::merge_metadata()`
  (Note: Ingen tests brugte disse interne aliaser)
- [x] 3.2 Kør målrettede tests for SPC-statistik, metadata og details-
  generering (60 PASS i extract-spc-stats + generate_details, 266 PASS i export_pdf)
- [x] 3.3 Kør `devtools::document()` og verificér at NAMESPACE/man forbliver
  korrekt
- [x] 3.4 Kør `openspec validate refactor-split-export-pdf --strict`

Tracking: GitHub Issue #116
