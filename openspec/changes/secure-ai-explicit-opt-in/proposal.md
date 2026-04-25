# secure-ai-explicit-opt-in

## Why

`bfh_generate_analysis()` aktiverer AI implicit når `BFHllm` tilfældigvis er
installeret (`R/spc_analysis.R:310`: `if (is.null(use_ai)) use_ai <- ai_available`).
Det sender `qic_data`, metadata, baseline, afdeling og hospital videre til
`BFHllm::bfhllm_spc_suggestion()` uden eksplicit bruger-samtykke.

I healthcare-kontekst er implicit ekstern databehandling uacceptabel default.
Hvis `BFHllm` senere bruger netværk, RAG eller tredjepartstjenester, kan
utilsigtet AI-aktivering lække følsomme eller interne driftsdata.

## What Changes

- **BREAKING**: `use_ai` default ændres fra `NULL` (auto-detect) til `FALSE`
- AI-kald kræver nu eksplicit `use_ai = TRUE`
- Ingen auto-detektion af `BFHllm` installation
- Tilføj test: `bfh_generate_analysis()` kalder aldrig `BFHllm` uden eksplicit opt-in
- Opdater roxygen med sikkerhedsnote om dataeksponering

## Impact

**Affected specs:**
- `spc-analysis-api`

**Affected code:**
- `R/spc_analysis.R` (bfh_generate_analysis default)
- `tests/testthat/test-spc-analysis-*.R` (ny opt-in test)
- Roxygen docs + NEWS.md

**User-visible changes:**
- Brugere der tidligere fik AI-analyse "gratis" skal nu sætte `use_ai = TRUE`
- Fallback-analyse (template-baseret) er uændret default

## Related

- Codex review issue #1 (AI auto-aktivering)
