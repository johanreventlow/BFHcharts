## Why

`bfh_generate_analysis()` har vokset til en monolitisk cascade-dispatch der
forsøger at producere dækkende klinisk tekst for et **multi-dimensionelt
outcome-rum** via en flad nøgle-til-template mapping. Eksisterende corpus
(`inst/i18n/da.yaml`) er teknisk komplet ift. de nøgler kode kan vælge,
men har strukturelle huller mod fagligt nødvendige SPC-fortolkninger:

1. **Retning på forandring** beskrives ikke (forbedring vs forværring).
2. **Fase-/interventionsfortolkning** mangler — `bfh_qic()` understøtter
   `part`/`freeze`, men teksten beskriver kun seneste fase isoleret.
3. **Chart-type-specifik fortolkning** mangler (rate, proportion, count,
   rare-events bruger samme templates).
4. **Datakvalitet/evaluerbarhed** kun delvist dækket (mangler korte serier,
   variable kontrolgrænser, manglende denominatorer, ekskluderede punkter).
5. **Historiske outliers** ignoreres bevidst, men situationen "historiske
   outliers, ingen aktuelle" har ingen tekst.

Ud over disse 5 strukturelle huller findes flere **eksisterende felter der
ikke er wired**:

6. **Baseline-delta ved part >= 2** — `x$summary` har data, ingen template.
7. **Sigma-shift magnitude som prose-modifier** — `context$sigma_hat` bruges
   allerede til target-arm-dispatch (at_target / near_target evaluering), men
   magnitudet (small/medium/large bucket) eksponeres **ej** som prose-modifier
   ("svarende til ~2 sigma" / "~30% ændring").
8. **Direction uden target** — chart-types har implicit retning
   (mortalitet, infektion → lower better; rettidighed → higher better).
9. **CL-disclosure i prose** — `caveats.cl_user_supplied` /
   `caveats.cl_auto_mean` rendres i Typst-PDF + export-helpers, men
   `bfh_generate_analysis()`-output rører dem aldrig. Tekst-only-konsumenter
   (UI, AI-prompt-anker) mister informationen.
10. **Anhøj-not-evaluable som dispatch-sektion (ny detektion)** —
    `analysis.anhoej_not_evaluable` findes som **ubrugt i18n-label** (0 R-
    referencer uden for `inst/i18n/`). Forslag introducerer **ny detektion**
    (n-threshold via ny `N_MIN`-konstant, default 12 per Anhøj-litteratur) +
    **ny override-dispatch-vej** der erstatter stability-arm når
    `confidence_tier == "low"`. Note: dette er ny feature, ikke refactor af
    eksisterende label.
11. **Data-freshness** — ingen caveat når seneste obs er gammel.
12. **Trend vs step** — Anhøj-runs skelner ikke; tekst siger uniformt
    "skift i niveau".

Den principielle løsning er **ikke** at tilføje 12 nye nøgler til
cascade-dispatchen. Dispatch-rummet eksploderer: nuværende dispatch har
**roughly 50+ reachable text paths** (afhænger af counting-method: 10
stability-keys × ~5 effektive action-paths × target-formaterings-varianter).
Multiplicerer til tusinder hvis alle 12 nye dimensioner kodes som flad
cascade. Vedligehold + klinisk validering bliver uigennemførligt.

I stedet: **strukturér analyseteksten som feature-extraction +
composition-lag**. Detektion adskilles fra formulering. Tekst-output
sammensættes af **base-templates + modifier-cascade** (kompositionel
skalering, ej multiplikativ). Et **struktureret analyse-objekt** bliver
primær output; rentekst er én af flere render-views (PDF, UI, AI-prompt,
audit-log, JSON).

**Arkitektur-model: Key-only** — `bfh_analyse()` returnerer struktureret
objekt med **i18n-nøgler** (ej resolverede tekst-strenge), aux-data og
render-context. Al sprog-/tekst-resolution sker i `bfh_render_analysis()`
der modtager `texts_loader` (eksisterende parameter respekteres
bagudkompatibelt). Konsekvenser:

- JSON-export af `bfh_analyse()`-output er **sprog-neutral** (kun nøgler).
- Audit-replay kan re-rendre samme analyse på andet sprog uden
  re-computation.
- Eksisterende `texts_loader`-tests virker uændret gennem
  `bfh_generate_analysis()`-wrapperen.

## What Changes

Refactor af `bfh_generate_analysis()`-pipeline og tilhørende
i18n-corpus. **Bevarer eksisterende public-API-signaturer** —
`bfh_generate_analysis(x, metadata, use_ai, ...)` returnerer fortsat
character-streng inden for tegnbudget.

**Tilføjer** ny eksporteret funktion `bfh_analyse()` der returnerer
struktureret `bfh_spc_analysis`-objekt med named features, **render_context**
(target_display, y_axis_unit, formaterede strenge, pluralization-state),
conclusions som **i18n-nøgler**, caveats som nøgle-liste,
suggested_actions som character-vektor af **nøgler**.
`bfh_generate_analysis()` implementeres som thin wrapper omkring
`bfh_analyse()` + render-lag.

**Determinisme:** `bfh_extract_spc_features()` SHALL være deterministisk —
samme input ⇒ samme output. `analysis_date` (brugt af freshness-detektion)
injiceres via 3-vejs præcedens-resolution:

1. `metadata$analysis_date` (eksplicit per-call) — vinder altid
2. `getOption("BFHcharts.analysis_date")` — global override (typisk i tests)
3. `Sys.Date()` — production-default

Resolvet `analysis_date` lagres i `analysis$aux$analysis_date` for audit-
replay-sporbarhed.

**AI-integration uændret kontrakt:** `bfh_generate_analysis(use_ai = TRUE)`
sender fortsat **rendered character** som `baseline_analysis` til
`BFHllm::bfhllm_spc_suggestion()`. Det strukturerede `bfh_spc_analysis`-
objekt sendes **ej** til AI i denne change — separat fremtidig change kan
introducere `structured_analysis`-felt i BFHllm-context når use-case er
afklaret.

**Arkitektonisk skift:**

- **Feature-extraction-lag** (`R/spc_features.R` — ny):
  Pure deterministisk computation fra `bfh_qic_result` + metadata til
  named feature-objekt med 12 ortogonale akser.
- **Composition-lag** (`R/spc_compose.R` — ny):
  Base-templates + modifier-bibliotek + composition-regler.
  Tegnbudget-allokering opdateres til at håndtere modifier-pool.
- **Render-lag** (`R/spc_render.R` — ny):
  Sprog-aware tekstgenerering fra struktureret objekt;
  bibeholder backward-compat med `texts_loader`-parameter.
- **i18n-corpus omstruktureret** (`inst/i18n/da.yaml`, `en.yaml`):
  Base-templates + modifier-clauses (separate sektioner). Eksisterende
  nøgler bevares som base; nye modifier-sektioner tilføjes.
- **Validerings-infrastruktur**:
  Golden-corpus (`tests/testthat/golden/spc_analysis/`) med kuraterede
  cases. Klinisk reviewer-loop dokumenteret.

**Backward compatibility:**
- `bfh_generate_analysis()`-signatur uændret.
- Eksisterende YAML-nøgler bevares (no key-deletion).
- `bfh_build_analysis_context()` udvides med nye felter (additivt).
- `texts_loader`-parameter respekteres for test/mocking.

**Modulær opt-in pr. feature-akse:** `tasks.md` strukturerer udvidelse af
analyse-rummet som **separate slices**, hver med eksplicit
beslutnings-gate. Bruger kan markere slice som `SKIP` hvis den specifikke
dimension ikke er relevant i deres kontekst — uden at blokere de øvrige.

## Impact

**Affected specs:** `spc-analysis-api`

**Affected code:**
- `R/spc_analysis.R` — refactores til thin orchestrator
- `R/spc_features.R` — NY
- `R/spc_compose.R` — NY
- `R/spc_render.R` — NY
- `R/utils_spc_stats.R` — eventuel udvidelse for sigma-shift /
  baseline-delta computation
- `inst/i18n/da.yaml`, `inst/i18n/en.yaml` — udvides (additivt)
- `NAMESPACE` — ny export `bfh_analyse`
- `tests/testthat/golden/spc_analysis/` — NY golden-corpus
- `tests/testthat/test-spc-features.R` — NY
- `tests/testthat/test-spc-compose.R` — NY
- `tests/testthat/test-spc-render.R` — NY
- `tests/testthat/test-spc-analysis-integration.R` — paritetstest mod
  eksisterende output på golden-corpus

**Affected docs:**
- `NEWS.md` — feature-entry (MINOR bump, pre-1.0 tillader breaking i YAML-
  struktur men eksisterende nøgler bevares)
- `docs/adr/ADR-XXX-structured-spc-analysis.md` — NY ADR
  (kopieres fra `design.md` ved arkivering)

**Consumer impact:**
- biSPCharts (Shiny app): `bfh_generate_analysis()` returnerer **bedre**
  tekst med flere relevante caveats. Ingen API-break. App-UI kan opt-in
  til struktureret `bfh_analyse()`-output for badge/icon-rendering.
- PDF-eksport (`utils_typst.R`, `utils_export_helpers.R`):
  CL-disclosure kan vælge mellem PDF-sidebar (status quo) og
  prose-integration (ny mulighed). Begge muligheder bevares.
- Tredjeparts-kald uden for biSPCharts: backward compatible — output
  bliver længere/rigere men signatur uændret.

**Risk-mitigation:**
- Parity-test mod eksisterende output på golden-corpus før cut-over.
- Modulær opt-in pr. modifier — kan slukkes selektivt hvis
  feedback-skifte indikerer corpus-revision.
- Klinisk reviewer-validering på golden-corpus før release.
