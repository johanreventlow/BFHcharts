# Cycle 02 — Auto-mean centerline-substitution validation (2026-05-16)

**Område:** Run-chart median→mean auto-substitution når ≥50 % af obs ligger eksakt på centerlinjen.
**Trigger:** Brugerrapport: "jeg kan generere charts hvor medianen så IKKE bliver ændret til gennemsnittet".
**Baseline-kommit:** `ae5cfd7` (feat run-chart auto-mean, merged via PR #371).

---

## Scope

Validerer:
1. `detect_majority_at_median_lastphase()` (R/utils_bfh_qic_helpers.R:234-260)
2. `build_last_phase_auto_cl()` (R/utils_bfh_qic_helpers.R:288-311)
3. Trigger-betingelser i `bfh_qic()` (R/bfh_qic.R:686-706)
4. Test-suite (tests/testthat/test-cl-auto-mean.R, 19 tests)

---

## H1 [MEDIUM] — Multi-phase: earlier phases beholder median selvom majority-on-median

**Lokation:** R/utils_bfh_qic_helpers.R:244 + R/bfh_qic.R:697-705

**Symptom:** I `part`-baserede multi-phase run-charts evalueres trigger KUN mod sidste fase. Hvis en tidligere fase har ≥50 % obs tied til sin (faseinterne) median, beholder den fase median som CL — Anhøj run/crossing-detection får degenererede tællinger for den fase, og `cl_auto_mean`-flaget bliver `FALSE` overall (intet PDF-caveat).

**Verifikation (empirisk reproduceret 2026-05-16):**
```r
# Phase 1: 12/18 obs (66 %) tied paa median(=1)
# Phase 2: kontinuert normalfordeling
phase1 <- c(rep(1, 12), 2, 2, 3, 3, 4, 4)
phase2 <- rnorm(15, 8, 2)
d <- data.frame(x = 1:33, y = c(phase1, phase2))
r <- bfh_qic(d, x = x, y = y, chart_type = "run", part = 18, return.data = TRUE)
# Phase 1 cl: 1 (median, IKKE swap'et)
# Phase 1 obs on cl: 12/18
# Phase 1 runs.signal: TRUE  -- degenereret Anhoej-output
# Phase 2 cl: median(phase2)
# attr(r, "cl_auto_mean"): FALSE
```

**Konsekvens:**
- Kliniker ser run-chart hvor fase 1 hævder "long run" (runs.signal=TRUE), men signalet er artefakt af diskret skala (12 ud af 18 obs ligger eksakt på CL — Anhøj-rules antager kontinuert data uden ties).
- PDF-caveat surfaces ikke (`cl_auto_mean`-attr afspejler kun sidste fase).
- Bryder den klinisk-statistiske kontrakt: "vi har fjernet tie-degenererings-problemet" — fjernet kun for sidste fase.

**Designintent (eksplicit i kode-kommentar):**
```r
# Detection is scoped to the LAST phase only -- matches the
# filter_qic_to_last_phase() convention used elsewhere in
# bfh_build_analysis_context() and bfh_extract_spc_stats(). Clinically
# the last phase represents current-process state, which is the
# interesting case for auto-substitution.
```

Begrundelsen "last phase = current process" gælder for tekstanalyse + summary-tabel (hvor man kun ser aktuel tilstand). Men for plot-rendering ses alle faser — derfor skal CL-swap pr. fase, ikke kun for last.

**Foreslået fix (Option A — pr.-fase detection):**

Udskift last-phase-scoping med per-phase iteration. Hver fase får sin egen `on_cl_ratio` evalueret; hvis ≥50 %, swap'es den fase's CL til fase-mean. `cl_auto_mean`-attr sættes TRUE hvis MINDST én fase trigger'er. Caveat-tekst tilpasses til at angive evt. fase-nummer.

Skeleton:
```r
detect_majority_at_median_per_phase <- function(qic_data, chart_type,
                                                threshold = 0.5, tol = 1e-9) {
  if (!identical(chart_type, "run")) return(integer(0))
  if (is.null(qic_data) || !all(c("y", "cl") %in% names(qic_data))) return(integer(0))
  if (!"part" %in% names(qic_data)) {
    # single-phase: brug eksisterende last-phase-helper
    if (detect_majority_at_median_lastphase(qic_data, chart_type, threshold, tol)) {
      return(1L)
    } else {
      return(integer(0))
    }
  }
  parts <- sort(unique(qic_data$part))
  trigger_phases <- integer(0)
  for (p in parts) {
    qd_p <- qic_data[qic_data$part == p, , drop = FALSE]
    y <- qd_p$y; cl <- qd_p$cl
    valid <- !is.na(y) & !is.na(cl)
    if (sum(valid) < 2L) next
    if (stats::var(y[valid]) < tol) next       # no_variation-guard
    on_cl <- abs(y[valid] - cl[valid]) < tol
    if (sum(on_cl) / sum(valid) >= threshold) {
      trigger_phases <- c(trigger_phases, as.integer(p))
    }
  }
  trigger_phases
}
```

`build_last_phase_auto_cl()` rebuilder til at acceptere vektor af trigger-phases og skrive fase-mean i hver match.

**Option B (defer):** Dokumentér multi-phase-begrænsning i `?bfh_qic` + NEWS, og lad fix ligge. Klinisk impact er lav for typiske use-cases (folk laver enten single-phase eller phases hvor sidste fase er den interessante).

**Anbefaling:** Option A — fixen er <50 LOC og fjerner et kontrakt-brud. Multi-phase run-charts findes i biSPCharts'  produktion.

---

## H4 [HIGH] — Date x + multiply: cl-vektor all-NA, qicharts2 fallback til median (silent), men flag fyrer (user-reported)

**Lokation:** R/utils_bfh_qic_helpers.R:288-311 + R/bfh_qic.R:686-712

**Symptom:** Bruger leverede konkret xlsx (`data_biSPCharts13.xlsx`) + PDF (`SPC-45.pdf`). PDF viste "NUV. NIVEAU 0,0%" og caveat-tekst "Niveaulinjen er skiftet til gennemsnit" — men 0,0% er medianen, ikke gennemsnittet (mean ≈ 0,45%).

**Root cause (empirisk reproduceret 2026-05-16):**
1. Raw data har `Dato` som `Date`-klasse
2. qicharts2 upcaster internt Date → `POSIXct` (UTC) i probe-call output
3. `build_auto_cl_for_phases()`: `raw_x %in% qd_p$x` matcher Date vs POSIXct → returnerer **all-FALSE** for alle rækker
4. `new_cl` forbliver `rep(NA, nrow(raw_data))`
5. Anden qic-call ser cl=NA per række → `qic.run()`'s `anyNA(x$cl)`-fallback fyrer → median brugt for hele trigger-fasen
6. `cl_auto_mean_substituted <- TRUE` sættes alligevel → PDF-caveat lyver

**Verifikation:**
```r
d <- readxl::read_excel("tmp/data_biSPCharts13.xlsx")
d$Dato <- as.Date(d$Dato, format = "%d-%m-%Y")
probe <- qicharts2::qic(x = Dato, y = Infektioner, n = Opererede.patienter,
                        data = d, chart = "run", part = 12,
                        multiply = 100, return.data = TRUE)
class(d$Dato)   # "Date"
class(probe$x)  # "POSIXct" "POSIXt"
sum(d$Dato %in% probe$x)  # 0   <-- bug
```

**Sekundær bug (afsløret af fix):** qicharts2 multiplicerer user-supplied `cl=` med `multiply`. Vores `phase_mean` beregnes fra post-multiply `qd_p$y` (e.g., percent), så pass-through gav 100×-overskydende cl (45.24% i stedet for 0.45%).

```r
# Empirisk:
qic(..., multiply = 100, cl = 0.025, ...)$cl  # = 2.5  (multiplied)
qic(..., multiply = 100, cl = 2.5, ...)$cl    # = 250  (multiplied again)
```

**Konsekvens:**
- Single-phase OG multi-phase run-charts med Date-x + n= viste median, ikke mean — selvom caveat hævdede swap. Mest klinisk-relevante use-case (månedlige infektions-rater) ramt.
- Bug eksisterede både pre-PR #371 (initial implementation) og post-PR #376 (per-phase rewrite uden klasse-håndtering).
- Test-suite missede bug fordi alle tests bruger `x = 1:N` (integer, ingen klasse-konvertering).

**Foreslået fix:**
1. **Cross-class x-normalisering** i `build_auto_cl_for_phases()`: når `qic_data$x` er POSIXct og `raw_x` er Date, coerce raw_x med `as.POSIXct(., tz = "UTC")` før `%in%`. Symmetrisk for omvendt retning.
2. **Multiply-divider:** `build_auto_cl_for_phases()` tager nu `multiply`-argument; `phase_mean` divideres med multiply før returnering.
3. **Guard:** `bfh_qic()` sætter kun `cl_auto_mean_substituted=TRUE` hvis `any(!is.na(new_cl))` — undgår caveat-løgne ved fremtidige silent-substitution-failures.

**Regression-test:**
```r
test_that("bfh_qic auto-mean works for Date x + n= + multiply", {
  d <- data.frame(
    Dato = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    Infektioner = c(2, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0),
    Opererede = c(124, 118, 130, 126, 135, 120, 108, 125, 131, 127, 133, 122)
  )
  r <- bfh_qic(d, x = Dato, y = Infektioner, n = Opererede,
               chart_type = "run", multiply = 100, return.data = TRUE)
  expect_true(isTRUE(attr(r, "cl_auto_mean")))
  expect_equal(unique(r$cl)[1], mean(r$y), tolerance = 1e-4)
})
```

**Anbefaling:** Critical — denne bug forklarer 100 % af brugerens observation. Fix sammen med H1 + H3 i samme PR.

---

## H3 [MEDIUM] — `exclude=` ignoreres af både trigger-detection og replacement-mean (Codex-found)

**Lokation:** R/utils_bfh_qic_helpers.R:248-259 (detection) + R/utils_bfh_qic_helpers.R:288-311 (replacement)

**Symptom:** `qicharts2::qic(exclude = ...)` markerer rækker med `include = FALSE` i return.data og bruger kun `include=TRUE`-rækker til CL-beregning. Men:

1. **Trigger:** `detect_majority_at_median_lastphase()` tæller `abs(y - cl) < tol` over ALLE last-phase rækker uden at konsultere `qic_data$include`. Excluded rækker tæller med i numerator OG denominator.
2. **Replacement:** `build_last_phase_auto_cl()` beregner `mean(qd_last$y, na.rm = TRUE)` over alle last-phase rækker uden include-filter. Excluded outliers forurener den nye CL.

**Verifikation (empirisk reproduceret 2026-05-16):**
```r
# 10/16 included rows tied at 1, 4 excluded rows = 100 (extreme outliers)
d <- data.frame(x = 1:20, y = c(rep(1, 10), 2, 2, 3, 3, 4, 4, 100, 100, 100, 100))
r <- bfh_qic(d, x = x, y = y, chart_type = "run", exclude = 17:20, return.data = TRUE)
# cl[1]: 21.4   <-- mean af alle 20 vaerdier
# expected: 1.75  <-- mean af kun de 16 included
# auto_mean: TRUE
```

`r$include` viser korrekt `TRUE×16, FALSE×4`, men `cl_auto_mean` ignorerer feltet.

**Konsekvens:**
- Excluded outliers (typisk: ekstreme events, data-rensning) drager CL massivt mod sig selv → kontrakten "excluded points contribute nothing to calculations" brydes.
- Detection-fasen kan også flippe forkert vej: hvis excluded rækker er tied til median, kan ratio kryds 50 %-tærsklen mod brugerens forventning.
- Bryder kontrakt-konsistens med qicharts2's eget include-respektive CL (median for run-charts beregnes kun over included).

**Foreslået fix:**
```r
detect_majority_at_median_lastphase <- function(qic_data, chart_type,
                                                threshold = 0.5, tol = 1e-9) {
  # ... eksisterende guards ...
  y <- qd$y
  cl <- qd$cl
  # NY: include-filter naar feltet findes
  include <- if ("include" %in% names(qd)) qd$include else rep(TRUE, length(y))
  valid <- !is.na(y) & !is.na(cl) & isTRUE_vec(include)
  # ... resten af logik ...
}

build_last_phase_auto_cl <- function(raw_data, qic_data, x_col_name) {
  qd_last <- filter_qic_to_last_phase(qic_data)
  # ... existing guards ...
  # NY: kun included rows i mean-beregning
  include_mask <- if ("include" %in% names(qd_last)) {
    qd_last$include
  } else {
    rep(TRUE, nrow(qd_last))
  }
  last_mean <- mean(qd_last$y[include_mask], na.rm = TRUE)
  # ... resten ...
}
```

Bemærk: `raw_data %in% last_x_values` matching skal også respektere exclude — men exclude er typisk specificeret som row-indices mod ORIGINAL data, så den enkleste path er at lade qicharts2's interne aggregation håndtere det (excluded raw-rows får alligevel ikke ny cl via vores `%in%`-match, fordi de ikke har x-værdi i `qd_last$x`). Verificeret: nuværende matching giver excluded raw-rows den nye mean, men qicharts2 lægger `include = FALSE` på dem efterfølgende, så CL'en for excluded points er kosmetisk irrelevant. **Det er KUN replacement-mean-beregningen der skal include-filtreres**.

**Anbefaling:** Fix sammen med H1 i samme PR — begge rører de samme to helpers.

**Test-gap:** Ingen eksisterende test dækker `exclude` i kombination med auto-mean. Tilføj regression:
```r
test_that("auto-mean respects exclude= for both trigger and replacement", {
  # 10 included tied + 6 included non-tied + 4 excluded extreme outliers
  d <- data.frame(x = 1:20, y = c(rep(1, 10), 2, 2, 3, 3, 4, 4, 100, 100, 100, 100))
  r <- bfh_qic(d, x = x, y = y, chart_type = "run", exclude = 17:20,
               return.data = TRUE)
  expect_true(isTRUE(attr(r, "cl_auto_mean")))
  expect_equal(r$cl[1], mean(c(rep(1, 10), 2, 2, 3, 3, 4, 4)), tolerance = 1e-6)
})
```

---

## H2 [LOW] — Test "respects threshold boundary" matcher ikke real-world qic-output

**Lokation:** tests/testthat/test-cl-auto-mean.R:33-49

**Symptom:** Testen konstruerer `qic_data` med syntetisk `cl = rep(1, 10)`, hvor 5 obs har y=1. Det giver 5/10 = 50 % on-CL → trigger fyrer.

Men i REAL `bfh_qic`-kald med `y = c(rep(1, 5), 2, 3, 4, 5, 6)`, beregner qicharts2 `median(y) = 1.5` (10 obs, even count → mean af 5. og 6. = (1+2)/2). Ingen obs ligger på 1.5 → trigger fyrer IKKE.

**Verifikation:**
```r
d <- data.frame(x = 1:10, y = c(rep(1, 5), 2, 3, 4, 5, 6))
r <- bfh_qic(d, x = x, y = y, chart_type = "run", return.data = TRUE)
# cl[1]: 1.5
# auto_mean: FALSE   (testen passer pga. synthetic cl=1, men real-world: ingen trigger)
```

**Konsekvens:** Testen påstår "respects threshold boundary" med en konstruktion der aldrig kan opstå organisk. 50 % boundary-testen verificerer kun `>=`-vs-`>`-operatoren, ikke real-world boundary-adfærd.

For at konstruere ægte 50 %-on-median kræves at median falder på en obs-værdi der præcis halvdelen af datasæt deler. Codex (2026-05-16-recalibration) påpegede at det er muligt med even-count konstruktioner — fx `y = c(0, 0, 1, 1, 1, 1, 1, 2, 2, 2)`: median = (sort[5]+sort[6])/2 = (1+1)/2 = 1, tied = 5, ratio = 5/10 = 50 %. → trigger fyrer korrekt.

**Foreslået fix:** Erstat den syntetiske test med en real-data testcase ved `y = c(0, 0, 1, 1, 1, 1, 1, 2, 2, 2)` så testen samtidigt verificerer (a) at `>=` ikke `>` bruges, og (b) at real qicharts2-pipeline producerer det forventede ratio.

**Anbefaling:** Lav-prioritet test-quality-fix; ingen produktionsbug. Kan implementeres sammen med H1+H3 eller defer.

---

## M1 [LOW] — qicharts2 NA-fallback-kontrakt udokumenteret som test-invariant

**Lokation:** R/utils_bfh_qic_helpers.R:269-275 (kun roxygen-kommentar)

**Symptom:** `build_last_phase_auto_cl()` afhænger af `qic.run()`'s `anyNA(x$cl)` → fallback til fase-median for NA-rækker. Kontrakten er beskrevet i en kode-kommentar, men der er INGEN test der ville fange en future qicharts2-opdatering der ændrer NA-håndteringen (fx kaster fejl, eller fallbacker til global median).

**Verifikation:** Søg i tests/testthat/ for `anyNA\|NA-fallback\|qic_contract` → ingen matches.

**Konsekvens:** Hvis qicharts2 v0.8.x ændrer kontrakten silently, vil `build_last_phase_auto_cl()` producere forkerte CL'er for tidligere faser uden test-suite-failure.

**Foreslået fix:** Tilføj en kontrakt-test der konstruerer en simpel multi-phase `cl`-vektor med NA i fase 1 og konstant i fase 2, kalder `qicharts2::qic()` direkte, og asserterer:
- Fase 1 returneret cl == median(y[fase 1])
- Fase 2 returneret cl == den konstante værdi vi sendte ind

```r
test_that("qicharts2 NA-cl-fallback-contract (regression guard)", {
  d <- data.frame(x = 1:20, y = c(rnorm(10, 5, 1), rep(10, 10)),
                  cl_in = c(rep(NA_real_, 10), rep(99, 10)))
  out <- qicharts2::qic(x, y, cl = cl_in, data = d, chart = "run",
                       part = 10, return.data = TRUE)
  expect_equal(unique(out$cl[out$part == 1])[1], median(d$y[1:10]),
               tolerance = 1e-6)
  expect_equal(unique(out$cl[out$part == 2])[1], 99, tolerance = 1e-6)
})
```

**Anbefaling:** Tilføj test ved næste mulighed; ej blokerende for H1-fix.

---

## Bekræftet OK

- Single-phase trigger (12/20 = 60 %) → ✅ swap'er korrekt til mean.
- `freeze`-guard → ✅ skip'er som dokumenteret.
- `cl`-user-supplied-guard → ✅ user wins.
- `chart_type != "run"` (i, p, u, c, mr, t, xbar, s, g, pp, up) → ✅ ingen swap.
- `agg.fun = "median"`/`"sum"` → ✅ swap virker efter post-aggregation.
- `multiply` 0.1/100 → ✅ swap respekterer floating-point.
- Counts/proportions med `n=` → ✅ swap virker.
- Last-phase swap i multi-phase når last phase er den ramte → ✅ virker.
- `cl_user_supplied` + `cl_auto_mean` mutually exclusive → ✅ invariant holder.
- PDF-caveat i18n (da/en) → ✅ resolves.

---

## Konklusion (Phase 4 — post Codex-reconcile, 2026-05-16)

Codex adversarial-review (verdict: needs-attention) bekræftede H1 + M1 og recalibrerede H2, OG fandt ny H3 jeg havde overset.

**Verified empirisk i reconcile:**
- **H1 [MEDIUM, confirmed]:** multi-phase tidligere-fase forbliver på median trods majority-on-CL. Reproduceret med phase1 = 12/18 tied → cl=1 retained, runs.signal=TRUE.
- **H3 [MEDIUM, confirmed, Codex-found]:** `exclude=` ignoreres af både trigger-tæller og replacement-mean. Reproduceret: `cl = 21.4` (mean of all 20) i stedet for `1.75` (mean of 16 included).
- **M1 [LOW, confirmed]:** qicharts2 NA-cl-fallback-kontrakt udokumenteret som test-invariant. Lav prioritet.

**Recalibreret:**
- **H2 [LOW]:** Codex korrekt om at exakte 50 %-real-world cases findes (even-count konstruktioner med median på obs-værdi). Mit oprindelige "real-world impossible" var for kategorisk. Test-fix skifter fra "skriv kommentar" til "erstat med real-data konstruktion".

**Impact-bucketing:**
- Hard runtime-saves: 0 (ingen crash-fixes)
- Semantic/silent-corruption-saves: 2 (H1 = phase 1 viser degenererede signaler; H3 = excluded outliers forurener CL)
- False-confidence/process-saves: 1 (M1 = contract-regression-guard)
- Sub-optimal/cleanup: 1 (H2 = test-clarity)

**Forhold til brugerrapport ("kan generere charts hvor median IKKE bliver ændret"):**
- H1 forklarer multi-phase-tilfælde.
- H3 forklarer single-phase med exclude-tilfælde (excluded rows kan trække ratio under 50 % og blokere trigger, ELLER trække ratio over 50 % og fyre trigger forkert).
- Begge er reproducible match til den observerede adfærd.

**Læring (cycle 02):** Codex's empirical-reproduction af exclude-bug viste igen, at cross-contract-claims ("qicharts2 respekterer include") kræver runtime-verification, ikke kun roxygen-kommentar-læsning. Self-review missede H3 fordi jeg fokuserede på "trigger correctness" (chart_type, freeze, cl-user-supplied) og ikke spurgte "hvilke andre data-filtre påvirker beregningen".

**Næste skridt (afventer bruger-approval):**
1. Fix H1 + H3 i samme PR — begge rører `detect_majority_at_median_lastphase()` + `build_last_phase_auto_cl()`.
2. Tilføj regression-tests for begge.
3. Tilføj M1 contract-test som separat lavprio-PR eller bundle med H1/H3.
4. H2 docfix: erstat syntetisk threshold-test med real-data construction.
5. NEWS-entry under v0.18.x: "Auto-mean centerline substitution now respects multi-phase and exclude= correctly."
