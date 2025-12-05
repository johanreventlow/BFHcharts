## 1. Implementation

- [x] 1.1 Tilføj `format_danish_date_short()` i `R/utils_date_formatting.R`:
  - Formatér dato til kort dansk format (f.eks. "feb. 2019")
  - Brug danske månedsnavne (jan., feb., mar., etc.)
- [x] 1.2 Tilføj `bfh_generate_details()` i `R/export_pdf.R`:
  - Detekter interval type via detect_date_interval()
  - Beregn gennemsnit af tæller/nævner eller værdi
  - Hent seneste periode data
  - Formatér centerline baseret på y_axis_unit
  - Sammensæt med "•" separator
- [x] 1.3 Opdater `bfh_export_pdf()` i `R/export_pdf.R`:
  - Kald bfh_generate_details() hvis metadata$details er NULL
  - Bevar bruger-override mulighed

## 2. Tests

- [x] 2.1 Tilføj tests for `format_danish_date_short()` i `test-export_pdf.R`
- [x] 2.2 Tilføj tests for `bfh_generate_details()` i `test-export_pdf.R`:
  - Test p-chart format (tæller/nævner)
  - Test i-chart format (kun værdi)
  - Test forskellige intervaller (månedlig, ugentlig, daglig)
  - Test y_axis_unit formatering (percent, count, rate)

## 3. Documentation

- [x] 3.1 Opdater roxygen for `bfh_export_pdf()`:
  - Dokumenter auto-generering af details
  - Tilføj eksempler

## 4. Validation

- [x] 4.1 Kør `devtools::test()` - alle tests skal bestå
- [x] 4.2 Kør `devtools::document()`
- [x] 4.3 Manuel test: verificer auto-genererede details i PDF output

Tracking: GitHub Issue #73
