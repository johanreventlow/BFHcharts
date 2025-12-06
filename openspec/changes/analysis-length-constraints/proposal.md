## Why

Når BFHllm genererer analysetekster til SPC charts, kan tekstlængden variere meget. For kort tekst giver utilstrækkelig kontekst, mens for lang tekst fylder for meget i PDF-layoutet.

Ved at indføre konfigurerbare minimum og maksimum tegngrænser:
- Sikrer vi at analyser altid har tilstrækkelig substans
- Forhindrer at analyser fylder for meget i PDF-template
- Giver brugeren kontrol over tekstlængden baseret på behov
- Default værdier (300-400 tegn) passer til standard PDF-layout

## What Changes

### Opdater `bfh_generate_analysis()` i `R/spc_analysis.R`:
- Tilføj `min_chars` parameter (default: 300)
- Behold `max_chars` parameter, opdater default til 400
- Videregiv begge parametre til `BFHllm::bfhllm_spc_suggestion()`
- Tilføj validering: `min_chars` skal være mindre end `max_chars`

### Opdater `bfh_export_pdf()` i `R/export_pdf.R`:
- Tilføj `analysis_min_chars` og `analysis_max_chars` parametre
- Videregiv til `bfh_generate_analysis()` når `auto_analysis = TRUE`

### BFHllm integration:
- Forudsætter at `BFHllm::bfhllm_spc_suggestion()` understøtter `min_chars` parameter
- Hvis BFHllm ikke understøtter dette, skal ændringen koordineres med BFHllm pakken

## Eksempel

```r
# Default værdier (300-400 tegn)
analysis <- bfh_generate_analysis(result)

# Brugerdefinerede grænser
analysis <- bfh_generate_analysis(result, min_chars = 200, max_chars = 500)

# Via PDF eksport
bfh_export_pdf(result, "output.pdf",
               auto_analysis = TRUE,
               analysis_min_chars = 250,
               analysis_max_chars = 350)
```

## Impact

- Affected specs: spc-analysis-api
- Affected code:
  - `R/spc_analysis.R` (bfh_generate_analysis)
  - `R/export_pdf.R` (kald til bfh_generate_analysis)
- Kræver muligvis ændring i BFHllm pakken

## Related

- GitHub Issue: #75
- Relateret pakke: BFHllm (AI-generering)
