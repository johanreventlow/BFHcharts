## Why

Når BFHllm genererer analysetekster til SPC charts, kan tekstlængden variere meget. For kort tekst giver utilstrækkelig kontekst, mens for lang tekst fylder for meget i PDF-layoutet.

Ved at indføre minimum og maksimum tegngrænser:
- Sikrer vi at analyser altid har tilstrækkelig substans (min 300 tegn)
- Forhindrer at analyser fylder for meget i PDF-template (max 400 tegn)
- Giver konsistent visuel præsentation på tværs af alle PDF-eksporter

## What Changes

### Opdater `bfh_generate_analysis()` i `R/spc_analysis.R`:
- Tilføj `min_chars` parameter (default: 300)
- Omdøb/behold `max_chars` parameter (default: 400)
- Videregiv begge parametre til `BFHllm::bfhllm_spc_suggestion()`

### Opdater kald i `bfh_export_pdf()`:
- Brug de nye default værdier (300-400 tegn)

### BFHllm integration:
- Forudsætter at `BFHllm::bfhllm_spc_suggestion()` understøtter `min_chars` parameter
- Hvis BFHllm ikke understøtter dette, skal ændringen koordineres med BFHllm pakken

## Eksempel

```r
# Før: kun max_chars
analysis <- bfh_generate_analysis(result, max_chars = 350)

# Efter: min og max
analysis <- bfh_generate_analysis(result, min_chars = 300, max_chars = 400)
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
