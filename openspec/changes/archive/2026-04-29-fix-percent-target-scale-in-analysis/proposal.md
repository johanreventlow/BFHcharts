## Why

Codex code review 2026-04-29 (FIX NOW, høj severity, runtime-verificeret) fandt at `bfh_generate_analysis()` for percent-charts kan producere klinisk misvisende auto-analysis-tekst.

**Bug-mekanisme:**

1. Bruger kalder `bfh_export_pdf(..., metadata = list(target = ">= 90%"))` på p-chart
2. `resolve_target("≥ 90%")` parser numerisk værdi til `90` (fjerner `%`-suffix og operator), `direction = "higher"`, `display = ">= 90%"`
3. `bfh_build_analysis_context()` kopierer `target_value = 90` til kontekst
4. `centerline` for p-chart med `y_axis_unit = "percent"` er på proportionsskala (fx `0.91`)
5. `build_fallback_analysis()` evaluerer `goal_met <- centerline >= target_value` → `0.91 >= 90` → `FALSE`
6. Output: "målet er endnu ikke nået (>= 90%)" — selvom 91% **opfylder** ≥ 90%

**Verificeret runtime (Codex):**

```
centerline=0.91 target=90 direction=higher
→ "Niveauet opfylder endnu ikke målet (>= 90%)"
```

**Klinisk impact:** PDF-rapporter sendt til afdelinger kan vende målvurderingen forkert. En afdeling der reelt opfylder en kvalitetsindikator får automatisk genereret tekst der siger det modsatte. Brugere har ingen synlig indikator om at fejlen findes — analysen ser ud som korrekt narrativ.

**Hvorfor missede statisk review:** Bug findes kun i sammenspil mellem `parse_target_input()` (fjerner `%`), `bfh_build_analysis_context()` (gemmer rå value), og `build_fallback_analysis()` (sammenligner direkte). Hver enkelt funktion er korrekt isoleret. Kræver runtime-tracing eller konkret test-case.

## What Changes

- **NON-BREAKING** for callers der ikke bruger `auto_analysis = TRUE` med percent-targets
- Normaliser `target_value` til proportionsskala i `bfh_build_analysis_context()` når:
  - `y_axis_unit == "percent"` AND
  - `target_display` indeholder literal `"%"` AND
  - parsed `target_value > 1` (heuristik: scale 0-100 ikke 0-1)
  
  Resultat: `target_value` divideres med 100 før lagring. `target_display` bevares uændret ("≥ 90%") til tekst-output.

- Edge cases håndteres eksplicit:
  - Numerisk input `metadata$target = 90` på percent-chart: normaliseres (samme heuristik værdi > 1)
  - Numerisk input `metadata$target = 0.9` på percent-chart: efterlades uændret (allerede proportion)
  - Karakter input `"90%"` uden operator på percent-chart: normaliseres
  - Karakter input `"≥ 0.9"` (ingen `%` i display): efterlades uændret — tillader power-users at angive proportion direkte
  - `y_axis_unit != "percent"`: ingen normalisering (bevarer count/rate/time-semantik)
  - Negative tærskler `target_value <= 0`: ingen normalisering (defensivt — proportions kan ikke være negative; bevar for at fejle synligt et andet sted)

- Tests:
  - Tilføj `tests/testthat/test-spc_analysis.R` test-blokke for alle ovenstående edge cases
  - Regression-test: p-chart med `centerline = 0.91`, `target = ">= 90%"` → output indeholder "opfylder målet" (eller language-equivalent)
  - Regression-test: p-chart med `centerline = 0.85`, `target = "<= 90%"` → "lower" direction goal met
  - Regression-test: I-chart med `target = ">= 90"` (ingen `%`, ej percent) → uændret adfærd

- NEWS.md entry under `## Bug fixes` for næste minor-bump

## Impact

**Affected specs:**
- `spc-analysis-api` — MODIFIED requirement: `bfh_build_analysis_context` SHALL normalize percent targets to proportion scale when context's `y_axis_unit` is `"percent"` and target display contains `%`

**Affected code:**
- `R/spc_analysis.R:157` (`bfh_build_analysis_context`) — tilføj normalisering efter `resolve_target()`-kald, før `target_value` skrives til context
- `tests/testthat/test-spc_analysis.R` — nye regression-tests (estimat: 5-7 nye `test_that`-blokke)
- `NEWS.md` — bug fix entry

**Backwards compatibility:**
- Eksisterende kald med `auto_analysis = FALSE` (default): uændret
- Eksisterende kald med rate/count/time-charts: uændret (heuristik matcher ikke)
- Eksisterende kald med percent-chart + numerisk target på proportion-skala (`target = 0.9`): uændret
- **Adfærdsændring** kun for: percent-chart + percent-formuleret target (string med `%` eller numerisk > 1) + `auto_analysis = TRUE`

**Severity:** Klinisk korrekthed (ikke teknisk gæld). Bør indgå i næste patch-release uden at vente på akkumuleret feature-arbejde.
