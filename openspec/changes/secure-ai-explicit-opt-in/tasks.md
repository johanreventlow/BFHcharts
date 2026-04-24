# Tasks: secure-ai-explicit-opt-in

## 1. Implementation

- [ ] 1.1 Ændr default `use_ai = NULL` → `use_ai = FALSE` i `bfh_generate_analysis()`
- [ ] 1.2 Fjern `ai_available <- requireNamespace(...)` auto-detect logik
- [ ] 1.3 Valider at `use_ai = TRUE` kun virker hvis `BFHllm` er installeret (ellers informativ fejl)
- [ ] 1.4 Opdater roxygen `@param use_ai` med sikkerhedsnote
- [ ] 1.5 Opdater roxygen `@details` med policy-statement

## 2. Testing

- [ ] 2.1 Test: default `use_ai = FALSE` aldrig kalder `BFHllm`
- [ ] 2.2 Test: `use_ai = TRUE` uden `BFHllm` installeret → informativ fejl
- [ ] 2.3 Test: `use_ai = TRUE` med `BFHllm` → kalder bfhllm_spc_suggestion (mocked)
- [ ] 2.4 Eksisterende tests opdateret til eksplicit `use_ai = FALSE`

## 3. Documentation

- [ ] 3.1 NEWS.md: breaking change entry under "Breaking changes"
- [ ] 3.2 Migration-hint i NEWS: `use_ai = TRUE` kræves nu
- [ ] 3.3 `devtools::document()` kørt
