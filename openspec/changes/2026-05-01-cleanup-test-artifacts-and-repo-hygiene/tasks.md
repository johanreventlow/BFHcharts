## 1. Identificér konkrete leaks

- [x] 1.1 Kør `git status` på en clean git-checkout efter `devtools::test()` — list alle untracked artifacts
- [x] 1.2 Identificér hvilken specifik test efterlader `tests/testthat/Rplots.pdf` (kør tests enkeltvis med `testthat::test_file()`)
      Note: bfh_qic() calls ggplot_gtable() internally, which opens the default device when none is open.
      Root cause: test-bfh_qic_result.R tests that call bfh_qic() + print/plot without explicit device.
- [x] 1.3 Verificér `output; rm -rf ` mappe-oprindelse (line `test-quarto-isolation.R:244`)
      Note: validate_export_path() fires BEFORE dir.create() — no directory is actually created.
      The test correctly uses expect_error() and no cleanup is needed, but assertion added.

## 2. Fix `output; rm -rf` cleanup

- [-] 2.1 Indpak `bfh_compile_typst(typst_file, "output; rm -rf /.pdf")`-kald i `withr::local_tempdir()` med `setwd()`-isolation
      Note: Not needed — validation fires before any filesystem operation. No directory is created.
- [-] 2.2 Tilføj `withr::defer(unlink("output; rm -rf ", recursive = TRUE))` umiddelbart efter kald
      Note: Not needed for same reason as 2.1 — but a defensive cleanup defer was added.
- [x] 2.3 Verificér at `ls tests/testthat/` efter test-run ikke viser mappen
- [x] 2.4 Tilføj eksplicit assert i testen: efter test SKAL ingen `output*`-mappe eksistere
      Implementation: Added expect_false(any(dir.exists(...))) assertion at end of test.

## 3. Fix graphics-device-leak

- [x] 3.1 Lokaliser hvilken test åbner uden at lukke (binær søgning)
      Root cause: bfh_qic() → ggplot_gtable() triggers default device (Rplots.pdf) when no device is open.
      Affected: all tests calling bfh_qic() including integration, visual-regression, bfh_qic_result tests.
- [-] 3.2 Tilføj `on.exit({while (!is.null(dev.list())) dev.off()})` til ramt test
      Note: Not a device-leak (device does close), but Rplots.pdf is created on open+close.
      Solution: global device in setup.R prevents R from ever using Rplots.pdf as default device.
- [x] 3.3 Opret `tests/testthat/helper-graphics.R` med `with_clean_graphics()` wrapper
- [x] 3.4 Konvertér device-tunge tests til at bruge wrapperen
      Implementation: print/plot tests in test-bfh_qic_result.R wrapped in with_clean_graphics().
      Global fix: setup.R opens persistent PDF device via teardown_env() pattern.

## 4. Konvertér `if (file.exists()) unlink()` til withr

- [x] 4.1 `grep -rn "if (file.exists" tests/` — list alle forekomster
- [x] 4.2 For hver: udskift med `withr::local_tempfile()` eller `withr::defer()`
      Files modified: test-export_pdf.R (6 instances), test-security-export-pdf.R (4 instances),
      test-export_png.R (4 instances), test-export-session.R (1 instance).
      Note: test-public-api-contract.R:154 uses if(file.exists) in a candidate-search loop — not a cleanup pattern, left as-is.
- [x] 4.3 Verificér at testene stadig består

## 5. `make clean` target

- [x] 5.1 Opret `Makefile` (eller `dev/clean_workdir.R` for cross-platform)
      Implementation: dev/clean_workdir.R (R script, cross-platform).
- [x] 5.2 Implementér: rm `BFHcharts.Rcheck/`, `BFHcharts_*.tar.gz`, `doc/`, `Meta/`, `Rplots.pdf`, `tests/testthat/Rplots.pdf`, `tests/testthat/output; rm -rf `, `tests/testthat/_problems/`
- [-] 5.3 Dokumentér i CONTRIBUTING.md eller README
      Note: CONTRIBUTING.md does not exist. Usage documented in script header comment.

## 6. Repo-hygiejne CI-check

- [-] 6.1 Opret `.github/workflows/repo-hygiene.yaml`
      Note: Out of scope per task brief. Marked as future work.
- [-] 6.2 Job: `git status --porcelain` efter test-suite SKAL være tom for kendte artefakter
- [-] 6.3 Marker som non-blocking i første iteration (warn only)
- [-] 6.4 Efter 1 uge stabil: gør PR-blocking

## 7. Opdatér ignore-filer

- [x] 7.1 `.Rbuildignore`: tilføj eksplicit patterns for test-artefakter
      Added: tests/testthat/_problems, tests/testthat/output; rm -rf
- [x] 7.2 `.gitignore`: bekræft eller tilføj missing patterns
      Added: tests/testthat/_problems/, tests/testthat/output; rm -rf
- [-] 7.3 Verificér at `R CMD build` ikke inkluderer artefakter (inspect resulting tarball)
      Note: Deferred — R CMD build not run in this session to avoid creating tarball artifact.

## 8. Slet eksisterende rester (manuel)

- [x] 8.1 `rm -rf "tests/testthat/output; rm -rf "`
      Note: Directory did not exist in worktree (validation fires before dir.create() in actual code).
- [x] 8.2 `rm -f tests/testthat/Rplots.pdf Rplots.pdf BFHcharts_0.9.0.tar.gz`
      Note: Rplots.pdf removed via dev/clean_workdir.R. Tarball + BFHcharts.Rcheck not present in worktree.
- [x] 8.3 `rm -rf BFHcharts.Rcheck doc Meta`
      Note: Not present in worktree — already absent.
- [-] 8.4 Vurdér + fjern (efter brugerens godkendelse): `BFHLLM_INTEGRATION.md`, `BISPCHARTS_logo*.xcf`, root-PDF'er
      Note: Requires explicit user approval per task constraints. Left for user decision.
- [x] 8.5 Commit cleanup som separat commit `chore(repo): remove test/build artifacts from working dir`

## 9. Release

- [x] 9.1 NEWS-entry under `## Interne ændringer`
- [-] 9.2 PATCH-bump
      Note: Version bump deferred to merge + release step per project workflow.
