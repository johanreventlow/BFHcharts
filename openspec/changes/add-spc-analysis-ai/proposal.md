# add-spc-analysis-ai

## Why

**Problem:** Når brugere eksporterer SPC-charts til PDF via `bfh_export_pdf()`, skal de manuelt:
1. Skrive analysetekst selv
2. Sammensætte kontekst til BFHllm hvis de ønsker AI-genereret analyse
3. Kalde BFHllm direkte og kopiere output

Dette er besværligt og resulterer ofte i tomme `analysis` felter i PDF exports.

**Current situation:**

**Eksisterende funktioner:**
- `bfh_extract_spc_stats()` - Ekstraherer runs/crossings fra summary
- `bfh_export_pdf()` - PDF export med metadata inkl. `analysis` felt
- `bfhllm_spc_suggestion()` (BFHllm) - AI-genereret analyse

**Dataflow i dag:**
```
bfh_qic() → bfh_qic_result
           ├── $summary (Anhøj stats: längste_løb, antal_kryds, etc.)
           ├── $qic_data (raw data med cl, ucl, lcl)
           └── $config (chart_title, chart_type, etc.)
                    ↓
           bfh_export_pdf()
           ├── extract_spc_stats() → runs/crossings
           └── metadata$analysis ← MANUELT ANGIVET (eller AI via BFHllm)
```

**Pain points:**
- **Ingen standardtekster:** Hvis AI ikke bruges, er `analysis` tom
- **Manuel integration:** Bruger skal selv sammensætte kontekst til BFHllm
- **Ingen fallback:** Ingen pre-definerede beskrivelser af SPC-udfaldsrum

## What Changes

**Tilføj tre nye funktioner:**

| Funktion | Formål |
|----------|--------|
| `bfh_interpret_spc_signals()` | Genererer danske standardtekster for Anhøj SPC-signaler |
| `bfh_build_analysis_context()` | Samler kontekst fra `bfh_qic_result` til analyse |
| `bfh_generate_analysis()` | AI-genereret analyse med fallback til standardtekster |

**Opdatér eksisterende funktion:**

| Funktion | Ændring |
|----------|---------|
| `bfh_export_pdf()` | Nye parametre: `auto_analysis`, `use_ai` |

**Standardtekst-katalog (Anhøj-baseret):**

| Signal | Tilstand | Tekst |
|--------|----------|-------|
| Serielængde | Signal | "Længste serie (X) overstiger forventet maksimum (Y)..." |
| Krydsninger | Signal | "Antal krydsninger (X) er under forventet minimum (Y)..." |
| Outliers | Ja | "X observation(er) uden for kontrolgrænserne..." |
| Ingen signaler | - | "Processen viser stabil adfærd uden særlige signaler." |

## Impact

**Affected specs:**
- `spc-analysis-api` (new capability)

**Affected code:**
- `R/spc_analysis.R` - **NEW** - Hovedimplementation
- `R/export_pdf.R` - Tilføj `auto_analysis` parameter
- `DESCRIPTION` - Tilføj BFHllm til Suggests
- `tests/testthat/test-spc_analysis.R` - **NEW** - Tests
- `NEWS.md` - Dokumentér ny funktionalitet

**User-visible changes:**
- Ny `auto_analysis = TRUE` parameter i `bfh_export_pdf()`
- 3 nye eksporterede funktioner
- Automatisk AI-analyse når BFHllm er installeret

**Breaking changes:**
- Ingen - backward compatible

## Alternatives Considered

**Alternative 1: Kun standardtekster (ingen AI)**
```r
bfh_export_pdf(result, "report.pdf",
  metadata = list(analysis = bfh_interpret_spc_signals(...)))
```
**Rejected because:**
- Kræver stadig manuel sammensætning
- Mister AI-genereret kontekstualisering
- Standardtekster alene er for generiske

**Alternative 2: Kun AI-integration (ingen fallback)**
```r
# Kræver BFHllm
analysis <- BFHllm::bfhllm_spc_suggestion(spc_result, context)
```
**Rejected because:**
- Fejler hvis BFHllm ikke installeret
- Ingen graceful degradation
- Kræver internet/API-adgang

**Chosen approach: Layered system med fallback**
- Standardtekster som base layer
- AI-generering som enhancement
- Automatisk fallback ved fejl

## Related

- GitHub Issue: [#69](https://github.com/johanreventlow/BFHcharts/issues/69)
- Depends on: `bfh_extract_spc_stats()` (already exported)
- Integration: BFHllm package (Suggests, not Imports)
