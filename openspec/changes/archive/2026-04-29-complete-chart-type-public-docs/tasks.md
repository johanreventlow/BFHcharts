## 1. Roxygen update

- [ ] 1.1 Opdatér `@param chart_type` (`R/bfh_qic.R:23`) til at inkludere alle 12 typer fra `CHART_TYPES_EN`
- [ ] 1.2 Opdatér `@details Chart Types`-blokken (`R/bfh_qic.R:75-83`) — tilføj sektioner for:
  - `mr`: Moving Range chart
  - `pp`: P-prime (Laney-adjusted proportions)
  - `up`: U-prime (Laney-adjusted rates)
- [ ] 1.3 Tilføj kort guidance om Laney-varianter under over-dispersion (~2 linjer)
- [ ] 1.4 Verificér at `@details Denominator Contract`-tabellen allerede dækker `pp` + `up` (den gør)

## 2. Examples

- [ ] 2.1 Tilføj eksempel for `chart_type = "pp"` med stort denominator (n > 1000)
- [ ] 2.2 Tilføj eksempel for `chart_type = "mr"` paret med I-chart (vis hvordan to charts kan kombineres)
- [ ] 2.3 Wrap nye eksempler i eksisterende `\dontrun{}`-blok

## 3. Re-generate Rd

- [ ] 3.1 Kør `devtools::document()`
- [ ] 3.2 Bekræft at `man/bfh_qic.Rd` indeholder alle 12 chart-types
- [ ] 3.3 Commit `man/bfh_qic.Rd` sammen med `R/bfh_qic.R`

## 4. Regression test (optional)

- [ ] 4.1 Tilføj test i `tests/testthat/test-public-api-contract.R`:
  ```r
  test_that("bfh_qic Rd documents all validated chart types", {
    rd_path <- system.file("man", "bfh_qic.Rd", package = "BFHcharts")
    skip_if(nchar(rd_path) == 0)
    rd_content <- paste(readLines(rd_path), collapse = "\n")
    expected_types <- BFHcharts:::CHART_TYPES_EN
    for (t in expected_types) {
      expect_true(
        grepl(paste0("\\b", t, "\\b"), rd_content),
        info = paste("Chart type", t, "missing from Rd")
      )
    }
  })
  ```

## 5. Verification

- [ ] 5.1 `devtools::check()` passes
- [ ] 5.2 Manuel: `?bfh_qic` viser alle chart types
- [ ] 5.3 Manuel: kør nye eksempler interaktivt — bekræft at de fungerer
- [ ] 5.4 Cross-check at biSPCharts-app eksponerer samme chart-type-liste (eller flag mismatch som separat issue)

## 6. Release

- [ ] 6.1 NEWS.md entry under `## Documentation` for næste patch-version (kan kombineres med proposal #2)
- [ ] 6.2 Bump `DESCRIPTION` til næste patch
