## 1. Roxygen update

- [ ] 1.1 Opdatér `@param print.summary` i `R/bfh_qic.R:46`:
  - Fjern "DEPRECATED ... triggers deprecation warning"
  - Erstat med text der reflekterer hard-error i v0.11.0 + migration-instruktion
- [ ] 1.2 Opdatér `@return` (linje 51-60) — fjern entries for `print.summary = TRUE` og `Both TRUE`
- [ ] 1.3 Opdatér `@details` hvis der refereres til `print.summary` i return-routing-beskrivelsen

## 2. Examples cleanup

- [ ] 2.1 Eksempel 20 (linje ~440-450, "Get summary statistics with Danish column names"):
  - Fjern `print.summary = TRUE`-argument
  - Skift til `result <- bfh_qic(...)` (default S3-objekt)
  - Erstat `result$plot` + `result$summary` udtryk forbliver gyldige (samme felt-navne)
- [ ] 2.2 Eksempel 21 (linje ~460-475, "Get both raw data and summary"):
  - Fjern `print.summary = TRUE`-argument
  - Skift til to separate kald: ét med `return.data = TRUE` for data.frame, ét med default for summary; ELLER
  - Vis at default S3-objekt har både `result$qic_data` og `result$summary` (anbefales — illustrerer moderne API)
- [ ] 2.3 Eksempel 22 (linje ~480-490, "Use summary for reporting"):
  - Fjern `print.summary = TRUE`-argument
  - Anvend default S3-objekt + `result$summary` direkte

## 3. Re-generate Rd

- [ ] 3.1 Kør `devtools::document()`
- [ ] 3.2 Verificér at `man/bfh_qic.Rd` ikke længere indeholder strengen "deprecated, will warn"
- [ ] 3.3 Commit `man/bfh_qic.Rd`-ændringen sammen med `R/bfh_qic.R`

## 4. Verification

- [ ] 4.1 `devtools::check()` passes (ingen R CMD check WARN/ERROR)
- [ ] 4.2 Manuel: `?bfh_qic` viser opdateret dokumentation uden "deprecated, will warn"
- [ ] 4.3 Manuel: kør et af de opdaterede eksempler interaktivt — bekræft at det giver forventet output uden fejl
- [ ] 4.4 Optional regression-test (nyt test_that-blok i `tests/testthat/test-public-api-contract.R`):
  ```r
  test_that("bfh_qic Roxygen does not advertise removed print.summary as deprecated", {
    rd_path <- system.file("man", "bfh_qic.Rd", package = "BFHcharts")
    if (nchar(rd_path) > 0 && file.exists(rd_path)) {
      content <- readLines(rd_path)
      expect_false(any(grepl("deprecated, will warn", content, fixed = TRUE)))
    }
  })
  ```

## 5. Release

- [ ] 5.1 NEWS.md entry under `## Documentation` for næste patch-version
- [ ] 5.2 Bump `DESCRIPTION` til næste patch (kan kombineres med proposal #1)
- [ ] 5.3 Tag efter merge
