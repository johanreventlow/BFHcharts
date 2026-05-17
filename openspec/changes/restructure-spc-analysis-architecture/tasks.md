# Tasks

Modulær slice-baseret implementering. Hver modifier-slice (3+) har
**🟡 BRUGER-BESLUTNING** før implementation — markér `INCLUDE` / `SKIP` /
`DEFER` baseret på klinisk relevans i din kontekst.

**Faser uden beslutnings-gate (1-2)** er obligatoriske for at refactoren
giver mening. Faser med gate kan vælges fra uden at blokere de øvrige.

---

## Phase 0: Foundation (NO OPT-OUT)

### 0.1 Arkitektur-dokumentation

- [ ] 0.1.1 Færdiggør `design.md` (ADR-kandidat) — review af bruger
- [ ] 0.1.2 Bekræft `spec.md`-delta dækker contract korrekt
- [ ] 0.1.3 Identificér eventuel cross-repo impact (biSPCharts thin
       wrapper-lag)

### 0.2 Feature-objekt schema (Model A: key-only)

- [ ] 0.2.1 Definér formelt `bfh_spc_analysis` S3-class:
       - `features` (12 ortogonale akser, raw values)
       - `aux` (incl. `analysis_date` for determinisme)
       - `render_context` (target_display, y_axis_unit, formaterede
         strings, operator_unicode, outliers_word_key, effective_window,
         chart_type)
       - `conclusions` (i18n-nøgler: stability_key, target_key, action_key)
       - `caveats` (named list af nøgler, NULL hvis inaktiv)
       - `suggested_actions` (character-vektor af nøgler)
- [ ] 0.2.2 Definér `schema_version` semver-policy (eller drop hvis
       JSON-export ej er kerne-mål — beslutning M1)
- [ ] 0.2.3 Skriv `print.bfh_spc_analysis()` + `format.bfh_spc_analysis()`
- [ ] 0.2.4 Skriv `as.list.bfh_spc_analysis()` for JSON-serialisering

### 0.3 Composition-contract

- [ ] 0.3.1 Dokumentér modifier-prioritets-rækkefølge (kanonisk liste)
- [ ] 0.3.2 Dokumentér budget-allokerings-regler (base/modifier/tail) —
       skal kalibreres mod corpus i Phase 1.4
- [ ] 0.3.3 Dokumentér sprog-parity-krav

### 0.4 Determinisme + analysis_date-injection

- [ ] 0.4.1 Definér 3-vejs præcedens-resolution:
       1. `metadata$analysis_date` (eksplicit)
       2. `getOption("BFHcharts.analysis_date")` (global override)
       3. `Sys.Date()` (production-default)
- [ ] 0.4.2 Skriv `.resolve_analysis_date(metadata)`-helper
- [ ] 0.4.3 Dokumentér i roxygen + audit-replay-use-case

---

## Phase 1: Core refactor — parallel implementation (NO OPT-OUT)

### 1.1 Feature-extraction-lag (`R/spc_features.R`)

- [ ] 1.1.1 Skriv `bfh_extract_spc_features(x, metadata)` — pure
       deterministisk funktion
- [ ] 1.1.2 Implementér detektion for **eksisterende** akser:
       - `stability_pattern` (10 værdier inkl. no_variation,
         not_evaluable; fra `.detect_signal_flags()`)
       - `target_relation` (4 værdier, fra `.evaluate_target_arm()`)
       - `confidence_tier` (3 værdier, **chart-type-aware**):
         - `high`: n ≥ 20 AND finite spredning-estimat
         - `med`: n ∈ [12, 19] AND finite spredning-estimat
         - `low`: n < N_MIN OR ingen centerline OR both sigma_hat+sigma_data NA
         - **Vigtigt:** Run-charts har sigma_hat=NA by design — brug
           sigma_data + n_points + Anhøj-stats. Brug IKKE
           `is.na(sigma_hat)` alene som low-trigger.
- [ ] 1.1.3 Definér ny konstant `N_MIN = 12L` i `R/globals.R` med
       litteratur-reference (Anhøj & Olesen 2014)
- [ ] 1.1.4 Aux-felter: `sigma_hat`, `sigma_data`, `n_points`,
       `centerline`, `effective_window`, `latest_obs_date`,
       `analysis_date` (resolvet via 3-vejs præcedens)
- [ ] 1.1.5 `render_context`-felter: ekstraher target_display,
       y_axis_unit, formaterede strings, operator_unicode,
       outliers_word_key (fra eksisterende `format_target_value()`,
       `pluralize_da()`)
- [ ] 1.1.6 Returnér default-værdier for nye akser (3+) der ikke
       endnu detekteres — sikrer schema-stabilitet
- [ ] 1.1.7 Tests: `tests/testthat/test-spc-features.R` — én test
       pr. akse-værdi + determinisme-test + chart-type-aware
       confidence-test (run-charts er `high` confidence ved n=24
       trods `is.na(sigma_hat)`)

### 1.2 Composition-lag (`R/spc_compose.R`)

- [ ] 1.2.1 Skriv `bfh_analyse(x, metadata, language)` — komposerer
       feature-objekt til `bfh_spc_analysis` (**ingen texts_loader-
       parameter** — Model A key-only)
- [ ] 1.2.2 Conclusions-mapping (features → conclusion-keys via
       eksisterende `.select_stability_key()` /
       `.select_action_key()`-pattern)
- [ ] 1.2.3 Caveats-liste (NULL'er for ikke-aktive caveats; nøgler
       for aktive — render-lag resolverer tekst)
- [ ] 1.2.4 Suggested-actions afledt af action-key + modifikatorer
       (character-vektor af i18n-nøgler)
- [ ] 1.2.5 Tests: `test-spc-compose.R` — verificér key-only-output
       (ingen resolverede tekst-strenge i features/caveats/
       suggested_actions)

### 1.3 Render-lag (`R/spc_render.R`)

- [ ] 1.3.1 Skriv `bfh_render_analysis(analysis, max_chars,
       texts_loader = NULL)` — fra struktureret objekt til character.
       texts_loader respekterer eksisterende default-pattern
       (`load_spc_texts(analysis$language)` hvis NULL).
- [ ] 1.3.2 Resolvér i18n-nøgler fra `analysis$conclusions`,
       `analysis$caveats`, `analysis$suggested_actions` til tekst
- [ ] 1.3.3 Brug `analysis$render_context` (target_display,
       y_axis_unit, centerline_formatted, operator_unicode,
       outliers_word_key) — re-deriver IKKE fra features/aux
- [ ] 1.3.4 Implementér modifier-cascade-orchestrator (uden faktiske
       modifikatorer aktiveret endnu — kun base + target + action)
- [ ] 1.3.5 Budget-allokering med prioritets-trimming (kalibreres
       mod corpus i 1.4)
- [ ] 1.3.6 Tests: `test-spc-render.R`

### 1.4 Parity-test mod eksisterende output (coverage-matrix)

- [ ] 1.4.1 Definér coverage-matrix (mekanisk parameter-sweep):
       - 10 stability-keys × {target, no-target}                  → 20
       - no_variation + majority_at_centerline + not_evaluable    → 6
       - target-direction-grene: numeric + operator (higher/lower) → 6
       - Sprog: da + en                                            → ×2
       - y_axis_unit: percent + non-percent                        → +12
       - Trim-boundary: max_chars 100, 200, 375                    → +12
       Total: ~50-60 cases via systematisk sweep
- [ ] 1.4.2 Build golden-corpus i
       `tests/testthat/golden/spc_analysis/matrix/` via
       parameter-sweep-script (`tests/scripts/build_golden_corpus.R`)
- [ ] 1.4.3 Tilføj **10-15 kuraterede klinisk-validerede cases** i
       `tests/testthat/golden/spc_analysis/clinical/` (real bfh_qic_result
       fra biSPCharts-brug + klinisk reviewer-input på forventet output)
- [ ] 1.4.4 Snapshot-test med **semantisk match**:
       - Eksakt tekst-equality efter whitespace-normalisering
       - Tegnbudget-trim acceptabel inden for ±5 tegn fra base
       - Decimal-separator-tolerance kun ved intenderet sprog-skift
       - Helper: `expect_semantic_text_equal(actual, expected,
         tolerance_chars = 5)`
- [ ] 1.4.5 Hver case pinner `metadata$analysis_date` eksplicit
       (sikrer reproduktbar golden-snapshot)
- [ ] 1.4.6 Bevar parity-test som regression-gate gennem cut-over
- [ ] 1.4.7 Budget-allokering kalibreres mod corpus: dokumentér final
       ratio (afløser midlertidigt 60/25/15) som spec-final efter
       empirisk fit. Mål: 0% action-arm-truncation, modifier-pool-
       truncation acceptabel hvis caveat-prioritet bevares.

---

## Phase 2: Cut-over (NO OPT-OUT — efter 1.4 grøn)

### 2.1 Rebind `bfh_generate_analysis()`

- [ ] 2.1.1 `bfh_generate_analysis()` kalder internt
       `bfh_render_analysis(bfh_analyse(x, metadata, language))`
- [ ] 2.1.2 AI-fallback-path bevares — `bfh_analyse()`-output bruges som
       `baseline_analysis` til BFHllm
- [ ] 2.1.3 Parity-test stadig grøn

### 2.2 Cleanup af legacy-funktioner

- [ ] 2.2.1 `.detect_signal_flags()`, `.select_stability_key()`,
       `.select_action_key()`, `.evaluate_target_arm()`,
       `.allocate_text_budget()`, `build_fallback_analysis()` →
       markeres `@keywords internal @noRd` eller refactores til
       interne helpers af nye lag
- [ ] 2.2.2 Undgå hård sletning indtil mindst ét full release-cycle —
       reducerer risiko for at downstream-tests overser regression

### 2.3 Public API udvidelse

- [ ] 2.3.1 Eksportér `bfh_analyse()` (NAMESPACE-update via
       `devtools::document()`)
- [ ] 2.3.2 Roxygen-dokumentation med `@return` schema-beskrivelse
- [ ] 2.3.3 Eksempler dækker både PDF-tekst-output og struktureret
       JSON-export

---

## Phase 3+: Modifier-slices (BESLUTNINGS-GATE pr. slice)

> Hver slice tilføjer én feature-akse + tilhørende modifier-clauses +
> i18n-keys + tests. Cascade-rækkefølgen er fast; aktivering pr. slice
> bestemmer om feature-aksen reelt påvirker prose-output.

---

### Slice 3: Magnitude modifier (sigma-shift)

> **🟡 BRUGER-BESLUTNING:**
> Magnitude-modifier tilføjer fraseringer som "svarende til ~2 sigma"
> eller "et fald på ~30%" til stability-tekster der ellers kun siger
> "skift i niveau".
>
> **Include hvis:** Klinikere skal kunne skelne små vs. store skift
> uden at læse selve plottet.
> **Skip hvis:** Sigma-formuleringer forvirrer ej-statistisk-trænede
> brugere; kvantitativ magnitude vises tilstrækkeligt i plot-labels.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 3.1 Tilføj `magnitude`-akse til feature-objekt (small/medium/large/NA)
- [ ] 3.2 Detektion: baseret på `|CL_current - CL_baseline| / sigma_hat`
       (kun ved part >= 2 ELLER outliers_only-pattern)
- [ ] 3.3 i18n: `analysis.modifier.magnitude.{small,medium,large}` i
       `da.yaml` + `en.yaml`
- [ ] 3.4 Render-integration: appendes til stability efter base-sentence
       hvis `magnitude != NA && confidence_tier != low`
- [ ] 3.5 Golden-corpus: +5 cases
- [ ] 3.6 Klinisk review: validér formuleringer

---

### Slice 4: Direction modifier (uden target)

> **🟡 BRUGER-BESLUTNING:**
> Aktuel `target_direction` virker kun når target er sat. Mange charts
> (mortalitet, infektion, ventetid) har implicit klinisk retning.
> Slice tilføjer `metadata$direction = c("higher_better", "lower_better",
> "neutral")` + chart-class-defaults.
>
> **Include hvis:** Klinikere bruger plots uden eksplicit target og
> behøver "til det bedre"/"til det værre"-formuleringer.
> **Skip hvis:** Næsten alle jeres charts har target sat eksplicit
> (target_direction dækker case'en).
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 4.1 Tilføj `direction`-akse til feature-objekt
       (favorable/unfavorable/neutral/unknown)
- [ ] 4.2 Detektion: `metadata$direction` (eksplicit) → chart-class
       default (mortalitet/infektion → lower_better) → "unknown"
- [ ] 4.3 i18n: `analysis.modifier.direction.{favorable,unfavorable}`
- [ ] 4.4 Render-integration: appendes hvis
       `direction %in% c("favorable", "unfavorable") && stability != stable`
- [ ] 4.5 Chart-class default-lookup tabel
- [ ] 4.6 Golden-corpus: +4 cases (favorable/unfavorable × stable/unstable)
- [ ] 4.7 Klinisk review

---

### Slice 5: Baseline-delta + phase-intervention (post-intervention)

> **🟡 BRUGER-BESLUTNING:**
> Slice tilføjer kvantitativ baseline-vs-nuværende-fase sammenligning
> ("Niveauet er faldet fra 8,2 til 5,7 — 30% fald siden interventionen").
> Aktiveres når `part >= 2`.
>
> **Include hvis:** Klinikere bruger ofte `part`/`freeze` til at vise
> intervention-effekt og forventer eksplicit før/efter-formulering.
> **Skip hvis:** I bruger ikke part-feature i praksis, eller
> baseline-formuleringer er forvirrende for jeres målgruppe.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 5.1 Tilføj `phase_context`-akse
       (single/multi/post_intervention) + `baseline_centerline`,
       `baseline_delta`, `baseline_delta_pct` til aux
- [ ] 5.2 Detektion: filtrér `x$summary` til alle parts, sammenlign
       seneste vs. forrige part
- [ ] 5.3 i18n: `analysis.modifier.baseline_delta.{improvement,deterioration,no_change}`
       og `analysis.modifier.phase_intervention.{...}`
- [ ] 5.4 Render-integration: appendes når
       `phase_context == "post_intervention"`
- [ ] 5.5 Golden-corpus: +6 cases (2 parts × 3 delta-typer)
- [ ] 5.6 Klinisk review

---

### Slice 6: Chart-class modifier

> **🟡 BRUGER-BESLUTNING:**
> Slice tilføjer chart-type-specifik fortolkning. Eksempler:
> - **Rate (u-chart):** "per {denominator}-enheder"
> - **Proportion (p-chart):** "andel" + denominator-noter
> - **Rare-events (g-/t-chart):** "X dage mellem hændelser",
>   "ingen hændelser i seneste periode"
> - **Run-chart:** ingen kontrolgrænse-prose
>
> **Include hvis:** I bruger flere chart-typer end blot i-charts.
> **Skip hvis:** Jeres app/PDF næsten udelukkende viser i-charts/p-charts;
> chart-type-specifik prose giver lille gevinst.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 6.1 Tilføj `chart_class`-akse
       (run/individuals/rate/proportion/count/rare_events)
- [ ] 6.2 Mapping: `chart_type` → `chart_class`
       (i/mr → individuals, p/pp → proportion, u/up → rate, c → count,
       g/t → rare_events, run → run)
- [ ] 6.3 i18n: `analysis.modifier.chart_class.{class}.{variant}`
- [ ] 6.4 Render-integration: chart_class-specifik prose-elementer
       (denominator-prefix på rate/proportion, 0-event-tekst på rare_events)
- [ ] 6.5 Golden-corpus: +12 cases (1-2 pr. chart_class)
- [ ] 6.6 Klinisk review pr. chart_class

---

### Slice 7: Variable kontrolgrænser (caveat)

> **🟡 BRUGER-BESLUTNING:**
> Når p/u/xbar-charts har varierende stikprøvestørrelse, varierer
> kontrolgrænserne. Slice tilføjer caveat:
> "Kontrolgrænserne varierer pga. svingende stikprøvestørrelse. Fortolk
> afvigelser med blik for n i hver periode."
>
> **Include hvis:** I bruger rate/proportion-charts med variabel
> denominator (almindeligt i klinisk kvalitet).
> **Skip hvis:** Næsten konstant n, eller variation håndteres allerede
> i metadata-tekst.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 7.1 Tilføj `data_quality$variable_cl`-flag
- [ ] 7.2 Detektion: `sd(qic_data$ucl - qic_data$lcl) / mean(...)` over
       konfigurerbar threshold
- [ ] 7.3 i18n: `analysis.modifier.variable_cl_caveat.{short,standard,detailed}`
- [ ] 7.4 Render-integration: tail-caveat
- [ ] 7.5 Golden-corpus: +2 cases
- [ ] 7.6 Klinisk review

---

### Slice 8: Few-obs / not-evaluable sektion (NY DETEKTION + DISPATCH)

> **🟡 BRUGER-BESLUTNING:**
> Når n < 12, er Anhøj-vurdering upålidelig. I dag bruger pipeline
> alligevel stability-templates uden eksplicit usikkerheds-markør.
> Slice introducerer `confidence_tier = "low"` der **erstatter**
> base-sentence med dedikeret not-evaluable-tekst.
>
> **Note:** Dette er **ny feature**, ej refactor af eksisterende
> `anhoej_not_evaluable`-label (som er ubrugt i nuværende R/-kode,
> kun en i18n-streng). Slice introducerer ny detektion,
> ny `N_MIN`-konstant (default 12 baseret på Anhøj 2014), og ny
> override-dispatch-vej.
>
> **Include hvis:** I oplever ofte korte serier (n < 12) og vil have
> eksplicit "for tidligt at konkludere"-budskab.
> **Skip hvis:** Jeres typiske brug har altid n >= 15-20; intern
> data-validering filtrerer korte serier fra.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 8.1 Tilføj `confidence_tier`-akse (low/medium/high) til
       features-schema. Bemærk: Phase 1.1.2 implementerer allerede
       chart-type-aware detektion; denne slice **aktiverer** brugen
       af `low` som override-trigger.
- [ ] 8.2 i18n: `analysis.base.not_evaluable.{short,standard,detailed}`
       som ny sektion i `da.yaml` + `en.yaml` (separate fra eksisterende
       label-string `anhoej_not_evaluable`)
- [ ] 8.3 Render-integration: `confidence_tier == "low"` erstatter
       stability-base med `not_evaluable`-tekst; target+action gøres
       kortere/eksplicit hedged
- [ ] 8.4 Golden-corpus: +3 cases (n=5, n=10, n=11) + 1 case for
       run-chart med n=24 (verificér IKKE markeret low trods
       is.na(sigma_hat))
- [ ] 8.5 Klinisk review

---

### Slice 9: CL-disclosure i prose

> **🟡 BRUGER-BESLUTNING:**
> Eksisterende `caveats.cl_user_supplied` + `caveats.cl_auto_mean` er
> wired til Typst-PDF + export-helpers men IKKE til
> `bfh_generate_analysis()`-output. Konsumenter ud over PDF (app-UI,
> AI-prompt) mister informationen.
>
> Slice integrerer caveat i prose. Bevarer PDF-sidebar-rendering
> uændret — caveat står begge steder.
>
> **Include hvis:** Tekst-only-konsumenter (UI badge, AI-prompt-anker)
> skal kunne se CL-disclosure.
> **Skip hvis:** PDF-sidebar er eneste kanal hvor CL-source er
> klinisk relevant.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 9.1 Tilføj `cl_source`-akse
       (data_estimated/user_supplied/auto_mean)
- [ ] 9.2 Detektion: eksisterende `attr(.., "cl_user_supplied")` +
       `cl_auto_mean`
- [ ] 9.3 i18n: Genbrug eksisterende `labels.caveats.cl_*` (samme tekst,
       ny rendering-kontekst)
- [ ] 9.4 Render-integration: tail-caveat (mid-prioritet)
- [ ] 9.5 Test: PDF-sidebar bevarer eksisterende caveat (ingen
       dubletter); biSPCharts-UI får ny prose-caveat-information
- [ ] 9.6 Klinisk review

---

### Slice 10: Data-freshness caveat

> **🟡 BRUGER-BESLUTNING:**
> Når seneste obs er gammel (> threshold måneder), tilføjes:
> "Seneste observation er fra {dato} — analysen afspejler ikke nyere
> udvikling."
>
> **Include hvis:** Klinikere kører rapporter med varierende
> data-friskhed; gamle dataset uden caveat kan misforstås som
> "current state".
> **Skip hvis:** Jeres data-pipeline garanterer aktuelle data ved
> hver kørsel.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 10.1 Tilføj `freshness`-akse (current/stale/very_stale)
- [ ] 10.2 Detektion: `max(x_dato) - analysis_date` hvor analysis_date
       er **resolvet via 3-vejs præcedens** (Phase 0.4.1):
       - `metadata$analysis_date` (eksplicit per-call) — vinder altid
       - `getOption("BFHcharts.analysis_date")` — global override
       - `Sys.Date()` — production-default
- [ ] 10.2.1 Threshold via `getOption("BFHcharts.freshness_threshold_days",
       default = 90L)` for stale; `* 2` for very_stale
- [ ] 10.2.2 Lagre `analysis_date` + `data_age_days` i `bfh_spc_analysis$aux`
       for replay-sporbarhed
- [ ] 10.3 i18n: `analysis.modifier.freshness_caveat.{stale,very_stale}`
- [ ] 10.4 Render-integration: tail-caveat
- [ ] 10.5 Golden-corpus: +2 cases — hver case pinner `analysis_date`
       eksplicit så snapshot er reproduktbar
- [ ] 10.6 Klinisk review
- [ ] 10.7 Determinisme-test: kald `bfh_extract_spc_features()` to gange
       med samme `analysis_date` på samme dato vs forskellig dato →
       output identisk når `analysis_date` pinned, forskelligt når
       Sys.Date()-fallback bruges

---

### Slice 11: Historic outliers clause

> **🟡 BRUGER-BESLUTNING:**
> Aktuel logik bruger `outliers_recent_count` (seneste 6 obs).
> Historiske outliers ignoreres bevidst. Slice tilføjer clause:
> "Tidligere outliers ses i diagrammet (n=X) men er uden for det
> aktuelle vurderingsvindue."
>
> **Include hvis:** Klinikere forventer at se eksplicit reference til
> visualiserede historiske outliers de kan se i plottet.
> **Skip hvis:** Det visuelle plot er tilstrækkeligt; tekst-redundans
> uønsket.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 11.1 Tilføj `outlier_history`-akse
       (current_only/historic_only/both/none)
- [ ] 11.2 Detektion: `outliers_actual - outliers_recent_count > 0`
- [ ] 11.3 i18n: `analysis.modifier.historic_outliers.{historic_only,both}`
- [ ] 11.4 Render-integration: tail-caveat
- [ ] 11.5 Golden-corpus: +2 cases
- [ ] 11.6 Klinisk review

---

### Slice 12: Trend vs step detektion

> **🟡 BRUGER-BESLUTNING:**
> Anhøj-runs flag'er både gradvise trends og pludselige step-skift som
> "lang serie". Slice tilføjer slope-fit-baseret skelnen:
> - **Step:** Pludselig ændring (ofte event-baseret intervention)
> - **Gradual:** Gradvis trend (akkumulerende drift)
>
> **Include hvis:** Klinikere skal kunne skelne reaktion på diskret
> intervention vs. gradvis ændring (forskellige PDSA-implikationer).
> **Skip hvis:** Skelnen er svær at validere klinisk; risiko for
> overfortolkning.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 12.1 Tilføj `trend_form`-akse (step/gradual/none)
- [ ] 12.2 Detektion: changepoint-detection (simpel rolling-mean) +
       slope-fit på seneste segment
- [ ] 12.3 i18n: `analysis.modifier.trend_form.{step,gradual}`
- [ ] 12.4 Render-integration: erstatter generisk "skift i niveau" når
       runs_only er aktivt og confidence_tier >= medium
- [ ] 12.5 Golden-corpus: +4 cases (step × klar/uklar, gradual × klar/uklar)
- [ ] 12.6 Klinisk review — vigtig kalibrering af thresholds

---

### Slice 13: Seasonality educational caveat

> **🟡 BRUGER-BESLUTNING:**
> SPC fanger ikke periodiske mønstre (sæson, ugedag, måned). Lange
> serier (n > 24) kan have skjult cyklicitet. Slice tilføjer educational
> caveat på detailed-varianter:
> "Vurder om periodiske mønstre (sæson, ugedag) påvirker fortolkningen."
>
> **Include hvis:** Klinikere har risiko for at fejlfortolke
> sæsoneffekter som special cause.
> **Skip hvis:** For meta; kan distrahere fra core-fortolkning.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 13.1 Detektion: `n_points > 24`
- [ ] 13.2 i18n: `analysis.modifier.seasonality_caveat.detailed`
- [ ] 13.3 Render-integration: tail-caveat på detailed-variant only
- [ ] 13.4 Golden-corpus: +1 case
- [ ] 13.5 Klinisk review

---

### Slice 14: Discrete scale udvidelse

> **🟡 BRUGER-BESLUTNING:**
> Aktuel `majority_at_centerline` (>=50% punkter på CL) er binær.
> Slice udvider til 3-tier (mild/moderate/extreme) baseret på ratio +
> tilføjer specifik anbefaling om måleskala-revision når extreme.
>
> **Include hvis:** I oplever ofte diskret-skala-problemer (fx små
> tællere divideret med store nævnere).
> **Skip hvis:** Eksisterende binær flag dækker behovet tilstrækkeligt.
>
> **Beslutning:** `[ ] INCLUDE  [ ] SKIP  [ ] DEFER`

- [ ] 14.1 Udvid `data_quality$discrete_scale`-flag til 3-tier
- [ ] 14.2 Detektion: ratio-baserede thresholds
- [ ] 14.3 i18n: `analysis.modifier.discrete_scale.{mild,moderate,extreme}`
- [ ] 14.4 Render-integration: extreme erstatter base; mild/moderate
       som tail-caveat
- [ ] 14.5 Golden-corpus: +3 cases
- [ ] 14.6 Klinisk review

---

## Phase 99: Validation infrastructure (ANBEFALES, beslutning anbefalet `INCLUDE`)

> **🟡 BRUGER-BESLUTNING:**
> Klinisk validerings-loop er fundamentet for at de aktiverede slices
> rent faktisk producerer korrekt klinisk prose. Uden dette risikerer
> tilføjelse af modifikatorer at producere imponerende, men forkert,
> tekst.
>
> **Beslutning:** `[ ] INCLUDE  [ ] DEFER (med konkret follow-up-plan)`

### 99.1 Golden-corpus build-out

- [ ] 99.1.1 Final corpus: ~50-100 reelle SPC-cases dækkende alle
       aktiverede feature-kombinationer
- [ ] 99.1.2 Hver case: `bfh_qic_result` + metadata + forventet
       feature-vector + forventet tekst (da + en)
- [ ] 99.1.3 Klinisk reviewer-runde — fagligt verificeret som ground
       truth
- [ ] 99.1.4 Versionér corpus (`tests/testthat/golden/spc_analysis/
       VERSION`); ændringer kræver review

### 99.2 Klinisk reviewer-loop

- [ ] 99.2.1 Definér rolle/proces for klinisk validering
- [ ] 99.2.2 Logging-format for staging: features → tekst-valg
- [ ] 99.2.3 Mismatch-flagging workflow (klinikere → corpus-revision)
- [ ] 99.2.4 Cadence: månedligt review af nye mismatches

### 99.3 Bilingual parity CI-gate

- [ ] 99.3.1 Test: placeholder-paritet (samme `{...}` sæt i begge sprog)
- [ ] 99.3.2 Test: alle nøgler i `da.yaml` har modstykke i `en.yaml`
- [ ] 99.3.3 Test: magnitude-formatering (decimaltegn) respekterer
       sprog
- [ ] 99.3.4 CI-job aktiveret; failure blokerer merge

### 99.4 Schema-stability tests

- [ ] 99.4.1 Test: `bfh_spc_analysis$schema_version` matcher pakke-
       version
- [ ] 99.4.2 Test: `as.list()` returnerer stabil struktur
- [ ] 99.4.3 Downstream-konsumenter (biSPCharts) verificeret mod
       schema-output

---

## Phase 100: Documentation + release

- [ ] 100.1 ADR kopieres fra `design.md` til
       `docs/adr/ADR-XXX-structured-spc-analysis.md`
- [ ] 100.2 `NEWS.md` entry (MINOR bump)
- [ ] 100.3 `DESCRIPTION` Version bump
- [ ] 100.4 Roxygen2 + `devtools::document()` for nye exports
- [ ] 100.5 `bfh_analyse()` migration-vejledning til biSPCharts-team
- [ ] 100.6 Cross-repo bump-PR til biSPCharts (`DESCRIPTION` lower-bound)
       hvis biSPCharts vælger at adoptere `bfh_analyse()`-output i UI

---

## Beslutnings-sammenfatning

Når bruger har gennemgået alle slices, opdatér her:

| Slice | Title | Status | Note |
|-------|-------|--------|------|
| 3 | Magnitude modifier | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 4 | Direction (uden target) | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 5 | Baseline-delta + phase | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 6 | Chart-class modifier | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 7 | Variable CL caveat | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 8 | Few-obs / not-evaluable | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 9 | CL-disclosure i prose | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 10 | Data-freshness | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 11 | Historic outliers | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 12 | Trend vs step | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 13 | Seasonality caveat | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 14 | Discrete scale ext. | `[ ] INCLUDE / [ ] SKIP / [ ] DEFER` | |
| 99 | Validation infra | `[ ] INCLUDE / [ ] DEFER` | Anbefales INCLUDE |
