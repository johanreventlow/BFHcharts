## Why

Working directory + tests/-mappen er forurenet med artefakter der har konkret risiko og signaleret manglende disciplin:

1. **`tests/testthat/output; rm -rf `** — tom mappe oprettet af `test-quarto-isolation.R:244` der bevidst sender shell-injection-streng som output-path. Validatoren afviser stringen, men mappen oprettes alligevel før afvisningen og **ryddes ikke op**. Mappenavnet ser ud som en faktisk security-incident for nye udviklere. Selvom ikke tracked i git, ligger den på alles disk efter første test-kørsel.

2. **`tests/testthat/Rplots.pdf`** — graphics-device-leak fra en test der ikke lukker device. Genereres ved hver kørsel.

3. **Working dir-rester** der ikke er tracked men forurener `git status`:
   - `BFHcharts_0.9.0.tar.gz` (3.8 MB; DESCRIPTION er nu 0.12.1 → tarball er 3 minor-versioner forældet)
   - `BFHcharts.Rcheck/`, `doc/`, `Meta/` (build-output)
   - 4 PDF-filer i root (`FMK_analyse-kopi*.pdf`, `ventetid_*.pdf`, `Rplots.pdf`)
   - 2 `.xcf`-filer (114 + 167 KB GIMP-source)
   - `BISPCHARTS.png` (44 KB logo-asset uden klar placering)
   - `BFHLLM_INTEGRATION.md` (`-rw-------` perms — privat, formentlig forældet)

4. **`tests/testthat/_problems/test-cache-32.R`** — testthat parallel-failure-artefakt der akkumulerer.

5. **Inkonsistent test-cleanup** — flere tests bruger `if (file.exists()) unlink()` (race-prone) i stedet for `withr::defer()`/`on.exit()`.

Disse problemer er individuelt små men signalerer kollektivt at pakken mangler en disciplineret cleanup-policy.

## What Changes

### 1. Cleanup-mønster i `test-quarto-isolation.R`

Test der bevidst sender shell-injection-strenge SKAL bruge `withr::local_tempdir()` eller eksplicit `on.exit(unlink())`. Mappen `output; rm -rf ` må aldrig overleve testen.

### 2. Cleanup-mønster i alle export-tests

Alle tests der genererer outputs SKAL bruge:
- `withr::local_tempfile()` til enkelte filer
- `withr::local_tempdir()` til arbejdsmapper
- `withr::defer(unlink(...))` til eksisterende patterns der skal beholdes

Anti-pattern `if (file.exists(x)) unlink(x)` SKAL elimineres.

### 3. Stop graphics-device-leaks

Den test der efterlader `tests/testthat/Rplots.pdf` skal identificeres og fixes. Et `helper-graphics.R` med wrapper:

```r
with_clean_graphics <- function(code) {
  before <- dev.list()
  on.exit({
    after <- dev.list()
    new <- setdiff(after, before)
    for (d in new) dev.off(d)
  })
  force(code)
}
```

### 4. `make clean` target

Ny `Makefile`-target eller R-script `dev/clean_workdir.R`:

```bash
# Kører:
rm -rf BFHcharts.Rcheck BFHcharts_*.tar.gz doc Meta Rplots.pdf
rm -f tests/testthat/Rplots.pdf
rm -rf "tests/testthat/output; rm -rf "
find . -name "_problems" -type d -exec rm -rf {} +
```

### 5. Pre-commit hook eller GitHub Action

Workflow der fejler PR hvis `git status --porcelain` indeholder kendte artefakter (Rplots.pdf, tar.gz, etc.).

### 6. Forbedret `.Rbuildignore` og `.gitignore`

- `.Rbuildignore`: tilføj eksplicit `tests/testthat/Rplots\.pdf$`, `tests/testthat/_problems$`, `tests/testthat/output;`
- `.gitignore`: bekræft at alle artefakter er dækket

## Impact

**Affected specs:** `test-infrastructure` — ny kontrakt om test-isolation og cleanup-disciplin.

**Affected code:**
- `tests/testthat/test-quarto-isolation.R` — cleanup-fix
- `tests/testthat/helper-graphics.R` — ny helper
- Multiple tests der bruger `if (file.exists())`-pattern — konvertér til `withr`
- `Makefile` eller `dev/clean_workdir.R` — ny
- `.Rbuildignore`, `.gitignore` — udvid
- `.github/workflows/repo-hygiene.yaml` — ny (valgfri)

**Breaking change:** Nej (kun infrastruktur).

## Cross-repo impact

Ingen.

## Related

- Source: Claude review 2026-05-01 K2 + Codex review test-warnings-finding
- Tracking: GitHub Issue #TBD
