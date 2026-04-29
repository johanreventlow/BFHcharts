## Why

Codex code review 2026-04-29 (OPPORTUNISTIC, høj confidence) fandt at `bfh_qic()` Roxygen-dokumentationen ikke beskriver alle gyldige `chart_type`-værdier som validering accepterer.

**Fakta:**

- `R/chart_types.R:21` definerer `CHART_TYPES_EN <- c("run", "i", "mr", "p", "pp", "u", "up", "c", "g", "xbar", "s", "t")` (12 typer)
- `R/utils_bfh_qic_helpers.R:218-223` (`validate_bfh_qic_inputs()`) validerer mod denne fulde liste
- `R/bfh_qic.R:23` (`@param chart_type`) lister kun: `"run", "i", "p", "c", "u", "xbar", "s", "t", "g"` (9 typer)
- `R/bfh_qic.R:75-83` (`@details Chart Types`) lister samme reducerede sæt

**Manglende fra public docs:**
- `mr` — Moving Range chart (paret med I-chart, ikke nævnt isoleret)
- `pp` — P-prime chart (Laney-justeret proportions)
- `up` — U-prime chart (Laney-justeret rates)

**Konsekvens:**
- API-discovery er ufuldstændig — brugere der søger efter "Laney" eller "moving range" via `?bfh_qic` finder ingenting
- Onboarding-friktion: brugere må læse kildekoden for at finde alle typer
- Denominator-validering (`R/utils_helpers.R:269`) refererer korrekt til `pp` og `up`, men deres eksistens er usynlig i public docs

## What Changes

- **NON-BREAKING** — kun dokumentation
- Opdatér `R/bfh_qic.R` `@param chart_type` (linje 23): tilføj `"mr"`, `"pp"`, `"up"` til listen
- Opdatér `@details Chart Types` (linje 75-83): tilføj nye sektioner:
  - **mr**: Moving Range chart (paired with I-chart, measures point-to-point variability)
  - **pp**: P-prime chart (Laney-adjusted proportions for over-dispersion in large samples)
  - **up**: U-prime chart (Laney-adjusted rates for over-dispersion in large samples)
- Tilføj kort note om hvornår Laney-varianter er passende:
  > Use `pp` / `up` instead of `p` / `u` when you have very large denominators (`n > 1000` per subgroup) and standard control limits become artificially tight due to over-dispersion. See qicharts2 documentation for details.
- Opdatér `@details Denominator Contract` (linje 90-105) for at konsistent inkludere `pp`, `up` (allerede listet — verify only)
- Tilføj 2 nye eksempler i `@examples`-sektionen:
  - Eksempel: `chart_type = "pp"` med stort denominator
  - Eksempel: `chart_type = "mr"` paret med en I-chart
- Kør `devtools::document()` for at re-generere `man/bfh_qic.Rd`

**Out of scope:**
- Vignettes / longform-tutorials for nye typer — kan tilføjes separat hvis efterspørgsel
- Ændring af `auto_detect_chart_type()` (hvis funktionen findes) — ingen detection logic ændres

## Impact

**Affected specs:**
- `public-api` — MODIFIED requirement: chart_type documentation reflects all validated types

**Affected code:**
- `R/bfh_qic.R` — Roxygen `@param chart_type`, `@details Chart Types`, `@examples`
- `man/bfh_qic.Rd` — auto-genereret efter `devtools::document()`

**Affected tests:**
- Optional regression: `tests/testthat/test-public-api-contract.R` — verificér at alle entries i `CHART_TYPES_EN` også optræder i Rd-filen

**Risiko:** Ingen runtime-impact.

**Effort estimat:** 30 minutter inkl. nye eksempler + R CMD check.

**Kombinations-mulighed:** Kan committes sammen med proposal #2 (`update-print-summary-removal-docs`) som én docs-cleanup PR.
