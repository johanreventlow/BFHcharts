## Why

Begge code reviews 2026-04-29 (Claude statisk + Codex runtime, høj confidence i begge) flaggede uoverensstemmelse mellem dokumentation og implementering for `bfh_qic()`'s `print.summary`-parameter.

**Status quo:**

- `R/utils_bfh_qic_helpers.R:101-110` — `build_bfh_qic_return()` **hard-errorer** når `print.summary = TRUE`:
  ```
  print.summary = TRUE has been removed in v0.11.0. ...
  ```
- `NEWS.md` v0.11.0 dokumenterer korrekt fjernelsen under `## Breaking changes`
- `R/bfh_qic.R:46` (Roxygen `@param print.summary`) siger fortsat:
  ```
  \strong{DEPRECATED.} ... When TRUE, triggers deprecation warning and
  returns legacy list(plot, summary) format.
  ```
- `R/bfh_qic.R:58-59` (Roxygen `@return`) lister fortsat:
  ```
  - print.summary = TRUE: list(plot = ggplot, summary = data.frame) (deprecated, will warn)
  - Both TRUE: list(data = data.frame, summary = data.frame) (deprecated, will warn)
  ```
- `@examples` linje 443, 464, 485 demonstrerer aktivt `print.summary = TRUE` (alle wrappet i `\dontrun{}` så R CMD check ikke knækker)
- `man/bfh_qic.Rd` (auto-genereret) reflekterer den forældede Roxygen

**Konsekvens:** Brugere der læser pakke-dokumentation (Roxygen, `?bfh_qic`, online dokumentation, vignettes) får besked om at `print.summary = TRUE` er deprecated men virker. Når de kalder med argumentet får de en hard error. Spild af brugerens tid + dårlig developer experience.

## What Changes

- **NON-BREAKING** — kun dokumentation
- Opdatér `R/bfh_qic.R` Roxygen `@param print.summary`:
  - Fjern "DEPRECATED ... When TRUE, triggers deprecation warning"
  - Erstat med "REMOVED in v0.11.0. Calling with `print.summary = TRUE` raises an error. Use `return.data = TRUE` and access `result$qic_summary`, or use the default `bfh_qic_result` object and access `result$summary` directly."
- Opdatér `@return` (linje 51-60):
  - Fjern entries for `print.summary = TRUE` og `Both TRUE`
  - Behold kun:
    - Default (`return.data = FALSE`): `bfh_qic_result` S3-objekt
    - `return.data = TRUE`: data.frame (legacy)
- Fjern eller opdatér `@examples`:
  - Eksempel 20 (linje ~440-450): Fjern `print.summary = TRUE`-kald. Erstat med `result <- bfh_qic(...)` + `result$summary` for at vise samme funktionalitet via det moderne API.
  - Eksempel 21 (linje ~460-475): Samme — vis at `return.data = TRUE` returnerer data.frame; for at få summary brug `bfh_qic_result$summary`.
  - Eksempel 22 (linje ~480-490): Opdatér til at bruge default S3-objekt + `result$summary`.
- Kør `devtools::document()` for at re-generere `man/bfh_qic.Rd`
- Backwards-compatibility: parameteret bevares stadig i funktionssignaturen (med `print.summary = FALSE` default) for at fange `print.summary = TRUE`-kald og give beskrivende fejl. Det er allerede implementeret korrekt — denne proposal ændrer ikke runtime-adfærden.

**Ud af scope:**
- Fjernelse af `print.summary`-parameteret fra signaturen helt. Det er en breaking change og kan vente til næste major-bump (post-1.0). Den nuværende soft-removal (parameter accepteret men hard-error på `TRUE`) giver klar fejlbesked og er korrekt for pre-1.0.

## Impact

**Affected specs:**
- `public-api` — MODIFIED requirement: documentation reflects removed parameters

**Affected code:**
- `R/bfh_qic.R` — Roxygen-blokken (linje 14-152 og examples-sektion)
- `man/bfh_qic.Rd` — auto-genereret efter `devtools::document()`

**Affected tests:**
- Ingen runtime tests — `print.summary = TRUE` rejser allerede error som forventet
- Optional: tilføj én test der verificerer at `?bfh_qic` (eller hjælpe-tekst) ikke længere indeholder strengen "deprecated, will warn"

**Risiko:** Meget lav. Dokumentationsændring uden adfærdsændring.

**Effort estimat:** 30-45 minutter inkl. `devtools::document()` og R CMD check.
