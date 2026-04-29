## 1. Code cleanup

- [ ] 1.1 Fjern `if (.Platform$OS.type == "unix") { ... }`-blok i `R/utils_export_helpers.R:213-223`
- [ ] 1.2 Erstat med kommentar der forklarer faktisk beskyttelse:
  ```r
  # Sikkerhed: tempfile() leverer en per-bruger isoleret sti i tempdir(),
  # og Sys.chmod(0700) fjerner group/other-permissions. Yderligere
  # ownership-validering via Sys.getenv("UID") er upålidelig (UID er
  # shell-intern og typisk ikke eksporteret til R-processer), så vi
  # forlader os på de to ovenstående mekanismer.
  ```
- [ ] 1.3 Verificér konsistens: `bfh_create_export_session()` (`R/export_session.R:62`) bruger allerede kun `Sys.chmod(0700)` uden ownership-check — tilføj samme inline-kommentar der hvis ikke allerede til stede

## 2. Test cleanup

- [ ] 2.1 Søg efter eksisterende tests der mocker `Sys.getenv("UID")`:
  ```bash
  grep -rn "Sys.getenv.*UID\|UID.*ownership" tests/
  ```
- [ ] 2.2 Hvis fundet: fjern dem (de tester nu fjernet kode)
- [ ] 2.3 Tilføj ny test i `tests/testthat/test-harden-export-pipeline-security.R`:
  ```r
  test_that("prepare_temp_workspace creates 0700-mode temp directory on Unix", {
    skip_on_os(c("windows"))
    ws <- prepare_temp_workspace(NULL)
    on.exit(unlink(ws$temp_dir, recursive = TRUE))
    mode_octal <- as.integer(file.info(ws$temp_dir)$mode) %% (8^3)
    expect_equal(mode_octal, as.integer(strtoi("700", 8L)),
      info = "temp dir must be 0700 to prevent other-user access")
  })
  ```
- [ ] 2.4 Verificér at eksisterende `test-security-*.R` ikke depender på fjernede error-branch

## 3. Verification

- [ ] 3.1 `devtools::test()` — alle tests passerer
- [ ] 3.2 `devtools::check()` — ingen nye WARN/ERROR
- [ ] 3.3 Manuel: kør `prepare_temp_workspace(NULL)` interaktivt på Linux/macOS, verificér mode 0700
- [ ] 3.4 Statisk: `grep -rn "Sys.getenv.*UID" R/` returnerer intet

## 4. Release

- [ ] 4.1 NEWS.md entry under `## Interne ændringer` for næste patch-version (kort note: "Fjernet ineffektiv ownership-check i temp-dir-staging; faktisk beskyttelse via tempfile() + Sys.chmod(0700) uændret")
- [ ] 4.2 Bump `DESCRIPTION` til næste patch (kan kombineres med proposal #2/#3)
