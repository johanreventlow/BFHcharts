## Why

Claude code review 2026-04-29 (OPPORTUNISTIC, lav severity, høj confidence) fandt at `prepare_temp_workspace()` i `R/utils_export_helpers.R:213-223` indeholder en ownership-check der praktisk talt aldrig udløses:

```r
if (.Platform$OS.type == "unix") {
  dir_info <- file.info(temp_dir)
  current_uid <- suppressWarnings(as.integer(Sys.getenv("UID")))
  if (length(current_uid) > 0 && !is.na(current_uid) && current_uid > 0) {
    if (dir_info$uid != current_uid) {
      unlink(temp_dir, recursive = TRUE)
      stop("Temp directory ownership mismatch (possible security issue)", call. = FALSE)
    }
  }
}
```

**Problem:** `Sys.getenv("UID")` returnerer typisk `""` på Unix-systemer fordi `UID` er en shell-intern variabel der **ikke** automatisk eksporteres til child processes. Verificeret: i en standard non-shell R-session (Rscript, RStudio, knitr, Shiny app, GitHub Actions runner, RStudio Server) er `UID` ikke i environment.

**Konsekvens:**

- `current_uid` bliver `integer(0)` eller `NA_integer_`
- Guard-betingelsen `length(current_uid) > 0 && !is.na(current_uid) && current_uid > 0` udløses ikke
- Ownership-check skipes silently
- Kommentaren over koden ("Forhindrer andre processer adgang til eksportens midlertidige filer") henviser til `Sys.chmod(0700)`-linjen lige ovenfor — som ER den faktiske beskyttelse

**Reel sikkerhed:** `tempfile()` bruger pr-bruger `tempdir()` (typisk `/tmp/RtmpXXX/` med UID-isolation fra OS), kombineret med `Sys.chmod(temp_dir, mode = "0700")` der eksplicit fjerner group/other-permissions. Ownership-checken tilføjer ingen reel beskyttelse oven på dette.

**Hvorfor det er et problem:**

- Misvisende defense-in-depth giver falsk fornemmelse af sikkerhed
- Tester der antager at checken virker (fx fuzz-tests af UID-konfusion) vil aldrig se `stop()`-grenen og kan fejlagtigt mark security-coverage som "tested"
- Vedligeholdelses-byrde: fremtidige reviewers skal genopdage at koden er død

**Hvorfor missede Codex det:** Codex' review fokuserede på runtime-verificeret SPC-logik. Statisk analyse af "død guard" kræver kendskab til Unix env-var-konventioner.

## What Changes

- **NON-BREAKING** — implementations-ændring uden API-impact
- **Foretrukken løsning:** Erstat `Sys.getenv("UID")` med en metode der pålideligt returnerer det effektive UID i R-session, eller fjern ownership-checken hvis den ikke kan implementeres robust:

  **Option 1: Brug `Sys.info()`:**
  ```r
  current_user <- Sys.info()[["effective_user"]]
  if (!is.null(current_user) && nzchar(current_user)) {
    dir_info <- file.info(temp_dir)
    # On Unix, file.info()$uid returns numeric UID; convert via system()
    # eller skip — Sys.info gives username, ikke numeric UID
  }
  ```
  Men `Sys.info()` returnerer username, ikke numeric UID — så vi skal alligevel mappe via fx `system("id -u", intern = TRUE)` for sammenligning. Det indfører subprocess.

  **Option 2 (anbefales): Fjern checken**

  - `tempfile()` + `Sys.chmod(0700)` er den korrekte og tilstrækkelige beskyttelse
  - Erstat det døde branch med en præcis kommentar om hvorfor `tempdir()` + 0700 er sufficient
  - Reducerer kompleksitet uden at miste reel security
  - Symmetrisk med `bfh_create_export_session()` (`R/export_session.R:62`) der allerede kun bruger `Sys.chmod(0700)` uden ownership-check

- Alternativt **Option 3 (compromise): Behold checken men gør den robust:**
  - Brug `system2("id", "-u", stdout = TRUE)` til at hente numeric UID pålideligt
  - Vurder om subprocess-cost er værd at betale for en yderst usandsynlig threat (nogen har UID-spoofet `/tmp/RtmpXXX/`-ejer mellem `tempfile()` og vores check, hvilket ville kræve symlink-race + race-condition-windows)
  - Sandsynligvis ikke værd

**Anbefaling:** Option 2 (fjern død kode + opdatér kommentar)

## Impact

**Affected specs:**
- `pdf-export` — MODIFIED requirement: temp directory protection relies on tempfile + Sys.chmod, not ownership check

**Affected code:**
- `R/utils_export_helpers.R:213-223` — fjern `if (.Platform$OS.type == "unix") { ... }`-blok
- Erstat med kommentar:
  ```r
  # Sikkerhed: tempfile() leverer en per-bruger isoleret sti i tempdir(),
  # og Sys.chmod(0700) fjerner group/other-permissions. Yderligere
  # ownership-validering via Sys.getenv("UID") er upålidelig (UID er
  # shell-intern og typisk ikke eksporteret til R-processer).
  ```

**Affected tests:**
- Fjern eventuelt eksisterende tests der mocker `Sys.getenv("UID")` for at trigger ownership-mismatch-grenen — de tester død kode
- Verificér at `test-harden-export-pipeline-security.R` stadig dækker faktisk beskyttelse (tempfile + 0700)
- Optional ny test: verificér at temp-dir har mode 0700 efter `prepare_temp_workspace()` på Unix:
  ```r
  test_that("temp dir has 0700 permissions on Unix", {
    skip_on_os(c("windows"))
    ws <- prepare_temp_workspace(NULL)
    on.exit(unlink(ws$temp_dir, recursive = TRUE))
    mode <- file.info(ws$temp_dir)$mode
    expect_equal(as.integer(mode) %% 8^3, as.integer(strtoi("700", 8L)))
  })
  ```

**Risiko:** Meget lav. Fjerner død kode, faktisk security uændret.

**Effort estimat:** 15-20 minutter inkl. test-justering.

**Bonus:** Når man alligevel rører området, kan man tilføje en kommentar i `bfh_create_export_session()` der eksplicit forklarer at ownership-check bevidst er udeladt af samme grund.
