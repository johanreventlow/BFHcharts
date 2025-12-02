# BFHllm Integration Guide

## Overview

`demo_pdf_export.R` demonstrates how to integrate **BFHllm** for AI-generated SPC analysis in BFHcharts PDF exports.

## Prerequisites

1. **BFHllm package** installed:
   ```r
   pak::pkg_install("johanreventlow/BFHllm")
   ```

2. **API key** configured in `.Renviron`:
   ```
   GOOGLE_API_KEY=your_key_here
   # OR
   GEMINI_API_KEY=your_key_here
   ```

3. **Quarto CLI** >= 1.4.0 for PDF export

## How It Works

### 1. Check BFHllm Availability

The demo script checks if BFHllm is available and gracefully falls back to manual analysis if not:

```r
if (!requireNamespace("BFHllm", quietly = TRUE)) {
  use_ai <- FALSE
} else {
  library(BFHllm)
  use_ai <- BFHllm::bfhllm_chat_available()
}
```

### 2. Extract SPC Metadata

After creating the chart with `bfh_qic()`, package the metadata for BFHllm:

```r
spc_metadata <- list(
  metadata = list(
    chart_type = resultat$config$chart_type,
    n_points = nrow(resultat$qic_data),
    signals_detected = sum(resultat$summary$løbelængde_signal,
                         resultat$summary$sigma_signal,
                         na.rm = TRUE),
    anhoej_rules = list(
      longest_run = resultat$summary$længste_løb,
      n_crossings = resultat$summary$antal_kryds,
      n_crossings_min = resultat$summary$antal_kryds_min
    )
  ),
  qic_data = resultat$qic_data
)
```

This extracts from `bfh_qic()` result:
- **Chart type** (run, p, i, etc.)
- **Anhøj rules** (longest run, crossings, signals)
- **QIC data** with centerline, control limits, x/y values

### 3. Define Analysis Context

Provide domain-specific context for the AI:

```r
ai_context <- list(
  data_definition = "Gennemsnitlig ventetid fra ankomst til første lægekontakt, målt ugentligt fra EPJ",
  chart_title = "Ventetid på Akutmodtagelsen",
  y_axis_unit = "minutter",
  target_value = 45  # Mål: max 45 minutter ventetid
)
```

### 4. Generate AI Suggestion

Call BFHllm to generate the analysis:

```r
ai_analyse <- BFHllm::bfhllm_spc_suggestion(
  spc_result = spc_metadata,
  context = ai_context,
  max_chars = 350,
  use_rag = TRUE  # Use SPC knowledge base
)
```

**What happens:**
1. Extracts Anhøj rule violations (runs, crossings, sigma signals)
2. Queries RAG knowledge store for relevant SPC methodology
3. Generates Danish, action-oriented improvement suggestion (max 350 chars)
4. Uses bold (**text**) for key recommendations

### 5. Include in PDF Export

Pass the AI-generated analysis to the PDF export:

```r
resultat |>
  bfh_export_pdf(
    output = "ventetid_rapport.pdf",
    metadata = list(
      hospital = "Bispebjerg og Frederiksberg Hospital",
      department = "Akutmodtagelsen",
      analysis = ai_analyse,  # ✅ AI-generated
      data_definition = "...",
      author = "Kvalitetsafdelingen",
      date = Sys.Date()
    )
  )
```

## Inputs to BFHllm Analysis

The AI suggestion is based on:

### From `ai_context`:
- **Chart title** - used in narrative
- **Data definition** - what the metric measures
- **Y-axis unit** - formatting (minutter, dage, procent, etc.)
- **Target value** - comparison with centerline

### From `spc_metadata` (Anhøj rules):
- **Centerline** - mean process level
- **Longest run** - max consecutive points above/below centerline
- **Number of crossings** - how many times centerline is crossed
- **Expected crossings** - minimum expected under random variation
- **Signals detected** - special cause variation count
- **Process variation** - "naturligt" or "ikke naturligt"
- **Time period** - start and end dates

## Example Output

The AI generates Danish, structured analysis like:

```
I 24 uger er ventetiden på akutmodtagelsen målt fra ankomst til første
lægekontakt. Processen varierer ikke naturligt med 3 særligt afvigende
punkter. Niveauet er under målet på 45 minutter. **Identificér årsager
bag de afvigende målepunkter** og stabilisér processen når forbedringen
er opnået.
```

**Structure:**
1. Context (frequency, what's measured)
2. Process variation (natural/unnatural, special causes)
3. Level vs target (over/under/at)
4. Actionable suggestion (bold)

## Graceful Fallback

If BFHllm is unavailable, the script uses manual analysis:

```r
ai_analyse <- "Lean-projektet har reduceret ventetiden med gennemsnitligt 15 minutter.
                Forbedringen er statistisk signifikant og vedvarende."
```

This ensures the PDF export always works, even without API keys.

## Performance Considerations

### Caching

For repeated calls (e.g., in Shiny apps), use caching:

```r
cache <- BFHllm::bfhllm_cache_create(ttl_seconds = 3600)

ai_analyse <- BFHllm::bfhllm_spc_suggestion(
  spc_result = spc_metadata,
  context = ai_context,
  cache = cache  # ✅ Cache for 1 hour
)
```

**Speedup:** ~50-100x faster on cache hits (0.5s vs 30s)

### RAG vs Non-RAG

**With RAG** (`use_rag = TRUE`):
- Queries SPC knowledge base for methodology
- More authoritative, grounded in SPC literature
- Slightly slower (~1-2s extra)

**Without RAG** (`use_rag = FALSE`):
- Faster generation
- Relies solely on LLM training data
- Still Danish, structured, action-oriented

## Integration in Other Packages

This pattern works for any R package using BFHcharts:

1. Create chart with `bfh_qic()`
2. Package metadata from `resultat$summary` and `resultat$qic_data`
3. Define context (title, definition, unit, target)
4. Generate suggestion with `BFHllm::bfhllm_spc_suggestion()`
5. Use in reports, Shiny apps, or PDF exports

**Note:** BFHcharts exports the convenience function `bfh_extract_spc_stats()` (available in v0.4.0+) which does step 2 automatically. If you have an older version of BFHcharts, manually construct the metadata list as shown in step 2 above.

See `inst/examples/bfhcharts-integration.R` in BFHllm for standalone usage patterns.
