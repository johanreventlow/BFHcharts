# Migration guide: Structured SPC Analysis (BFHcharts 0.20.0)

**Målgruppe:** biSPCharts (Shiny app) + andre downstream-konsumenter af
`BFHcharts::bfh_generate_analysis()`.

**Status:** Optional. `bfh_generate_analysis()`-signaturen er uændret.
Eksisterende kald fortsætter med at virke. Migration er opt-in når
struktureret analyse-objekt giver mervaerdi.

**Refs:** ADR-003, openspec change `restructure-spc-analysis-architecture`.

---

## TL;DR

Ny eksporteret API i BFHcharts 0.20.0:

```r
analysis <- BFHcharts::bfh_analyse(x, metadata, language)
text     <- BFHcharts::bfh_render_analysis(analysis, max_chars, texts_loader)
```

Eksisterende API uændret:

```r
text <- BFHcharts::bfh_generate_analysis(x, metadata, ...)  # uændret
```

`bfh_generate_analysis()` delegerer internt til ny pipeline. Backward-
compatible. Migration er valgfri.

---

## Hvornår migrere

**Opt-in til `bfh_analyse()`** når jeres use-case kan udnytte struktureret
output:

| Use-case | Eksisterende | Med `bfh_analyse()` |
|----------|--------------|---------------------|
| PDF-eksport | `bfh_generate_analysis()` → character | Ingen ændring; PDF-pipeline uændret |
| App-UI badge | Parse character med regex | Læs `analysis$features$stability_pattern` direkte |
| AI-prompt-anker | Pass character til LLM | Pass `as.list(analysis)` for richer context |
| Audit-log | Log character | Log `jsonlite::toJSON(as.list(analysis))` for searchable JSON |
| Re-render på andet sprog | Re-kald `bfh_generate_analysis(language="en")` | `bfh_render_analysis(analysis, language="en")` (sparer re-extraction) |
| Schema-versionering | Pakke-version | `analysis$schema_version` (uafhængigt) |

---

## Cross-repo coordinations-steps

### Trin 1: DESCRIPTION-bump (kun version-pin, ej adoption)

```diff
# biSPCharts/DESCRIPTION
Imports:
-    BFHcharts (>= 0.19.0),
+    BFHcharts (>= 0.20.0),
```

```diff
# biSPCharts/DESCRIPTION
Remotes: johanreventlow/BFHcharts@v0.19.0,
+ Remotes: johanreventlow/BFHcharts@v0.20.0,
```

Forventet impact: ingen. `bfh_generate_analysis()`-signatur uændret.

### Trin 2 (valgfri): Adopter struktureret analyse-objekt

biSPCharts-side: når UI-rendering eller AI-integration kan udnytte
features:

```r
# Før (eksisterende biSPCharts-pattern):
text <- BFHcharts::bfh_generate_analysis(
  result,
  metadata = list(target = ">= 90%"),
  language = "da"
)
ui_text <- text

# Efter (opt-in til struktureret):
analysis <- BFHcharts::bfh_analyse(
  result,
  metadata = list(target = ">= 90%"),
  language = "da"
)

# Stability-badge i UI:
ui_badge_class <- switch(analysis$features$stability_pattern,
  "no_signals"           = "stable",
  "runs_only"            = "shift",
  "no_variation"         = "flat",
  "not_evaluable"        = "uncertain",
  "default-class"
)

# Confidence-indikator:
ui_confidence_icon <- switch(analysis$confidence,
  "high"   = "icon-check",
  "medium" = "icon-warning",
  "low"    = "icon-question"
)

# Renderet tekst til prose-display:
ui_text <- BFHcharts::bfh_render_analysis(analysis, max_chars = 375L)
```

---

## Struktureret objekt schema

`bfh_spc_analysis` har top-level fields:

```r
analysis$schema_version    # "1.0.0" (semver)
analysis$language          # "da" | "en"
analysis$features          # 12 ortogonale akser
analysis$aux               # computed helper-values
analysis$render_context    # render-state (target_display, etc)
analysis$conclusions       # i18n-nøgler (key-only)
analysis$confidence        # "low" | "medium" | "high"
analysis$caveats           # active caveat-nøgler (NULL hvis inaktiv)
analysis$suggested_actions # character-vektor af nøgler
```

### features-aksernes værdier (enums)

```r
features$stability_pattern   # 10 enum: no_signals, runs_only, ..., no_variation, majority_at_centerline
features$target_relation     # 4 enum: met, near, not_met, none
features$confidence_tier     # 3 enum: low, medium, high
features$magnitude           # 4 enum: small, medium, large, NA
features$direction           # 4 enum: favorable, unfavorable, neutral, unknown
features$phase_context       # 3 enum: single, multi, post_intervention
features$cl_source           # 3 enum: data_estimated, user_supplied, auto_mean
features$chart_class         # 6 enum: run, individuals, rate, proportion, count, rare_events
features$data_quality        # list: few_obs, variable_cl, discrete_scale, missing_denominators
# NA-akser (SKIP/DEFER per bruger-beslutning):
features$trend_form          # NA  (Slice 12 DEFER)
features$freshness           # NA  (Slice 10 SKIP)
features$outlier_history     # 4 enum: current_only, historic_only, both, none (Slice 11 DEFER -- ej i prose)
```

### aux-felter (computed values)

```r
aux$sigma_hat              # control-limit-baseret spread; NA for run-charts
aux$sigma_data             # sd(y); fallback for run-charts
aux$n_points               # observation-count i seneste fase
aux$centerline             # current centerline-value
aux$baseline_centerline    # forrige fase centerline (NA hvis single-phase)
aux$baseline_delta         # current - baseline (NA hvis ingen baseline)
aux$baseline_delta_pct     # |delta|/baseline * 100 (NA hvis baseline=0)
aux$analysis_date          # resolvet Date (kraever pinning for audit-replay)
aux$latest_obs_date        # max(x) fra qic_data
aux$target_value           # numerisk target hvis sat
aux$effective_window       # antal obs i recent-window (default 6)
aux$runs_actual            # Anhoej longest run
aux$crossings_actual       # Anhoej crossings count
aux$outliers_actual        # total outliers
aux$outliers_recent_count  # outliers i recent-window
```

---

## Determinisme: pinned analysis_date

For audit-replay (re-rendre arkiveret rapport):

```r
# Gemt med rapport:
saveRDS(
  list(result = result, analysis_date = Sys.Date()),
  "rapport_2026_01_15.rds"
)

# 6 maaneder senere:
rep <- readRDS("rapport_2026_01_15.rds")
analysis <- BFHcharts::bfh_analyse(
  rep$result,
  metadata = list(analysis_date = rep$analysis_date)  # pinned!
)
text <- BFHcharts::bfh_render_analysis(analysis)
# Output identisk med original-render
```

Test-suiter kan globalt pinne via option:

```r
# tests/testthat/setup.R
options(BFHcharts.analysis_date = as.Date("2026-01-15"))
```

---

## JSON-export pattern

For audit-log, AI-prompt, downstream-tools:

```r
analysis <- BFHcharts::bfh_analyse(result, metadata = metadata)
json <- jsonlite::toJSON(
  as.list(analysis),
  auto_unbox = TRUE,
  Date = "ISO8601"
)
# Sprog-neutral output (nøgler, ej tekst)
```

---

## Schema-version-handling

`analysis$schema_version` følger semver. Downstream-konsumenter bør tjekke:

```r
check_schema <- function(analysis) {
  v <- analysis$schema_version
  if (is.null(v)) stop("Missing schema_version")
  major <- as.integer(strsplit(v, "\\.")[[1]][1])
  if (major != 1L) {
    warning(sprintf(
      "bfh_spc_analysis schema_version %s incompatible (expected 1.x.x)",
      v
    ))
  }
}
```

---

## Cross-repo cleanup ved adoption

Når biSPCharts adopterer `bfh_analyse()`-output i UI:

```r
# Søg + erstat ej noedvendig (eksisterende callere virker uændret).
# Tilfoej kun nye call-sites paa stretching UI-paths.

# I biSPCharts/R/utils_server_analysis.R (eller tilsvarende):
analyze_chart <- function(qic_result, metadata) {
  # NEW: cache struktureret objekt for re-brug
  analysis <- BFHcharts::bfh_analyse(qic_result, metadata)

  list(
    text     = BFHcharts::bfh_render_analysis(analysis),
    features = analysis$features,
    badge    = analysis$features$stability_pattern,
    confidence = analysis$confidence
  )
}
```

---

## Backwards-compat-garantier

Følgende kontrakter er **stable**:

- `bfh_generate_analysis()`-signatur (10 parametre, default-værdier uændret)
- `bfh_extract_spc_stats()`-return-struktur uændret
- `bfh_qic()`-public-API uændret
- `bfh_export_pdf()` uændret
- Internal helpers (`.detect_signal_flags`, `.select_stability_key`,
  etc.) bevares som `@keywords internal @noRd` gennem mindst ét major-
  release-cycle for downstream-`:::`-konsumenter

Følgende er **markeret deprecated**:

- `build_fallback_analysis()` — markeret backward-compat-layer. Fjernes i
  næste major release. Migrer til `bfh_render_analysis(bfh_analyse(x))`.

---

## Reference

- ADR-003: `docs/adr/ADR-003-structured-spc-analysis-architecture.md`
- NEWS.md 0.20.0: full slice-liste + breaking-detaljer
- Tests:
  - `tests/testthat/test-spc_compose.R` — bfh_analyse-API
  - `tests/testthat/test-spc_render.R` — bfh_render_analysis-API
  - `tests/testthat/test-spc_schema_stability.R` — schema-invarianter
  - `tests/testthat/test-spc_golden_corpus.R` — reference-outputs
