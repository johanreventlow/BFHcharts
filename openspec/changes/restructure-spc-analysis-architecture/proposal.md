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
7. **Sigma-shift magnitude** — `context$sigma_hat` beregnes, bruges ikke.
8. **Direction uden target** — chart-types har implicit retning
   (mortalitet, infektion → lower better; rettidighed → higher better).
9. **CL-disclosure i prose** — `caveats.cl_user_supplied` /
   `caveats.cl_auto_mean` rendres i Typst-PDF + export-helpers, men
   `bfh_generate_analysis()`-output rører dem aldrig. Tekst-only-konsumenter
   (UI, AI-prompt-anker) mister informationen.
10. **Anhøj-not-evaluable som sektion** — `analysis.anhoej_not_evaluable`
    er kort label, ikke fuld erstatning af stability-arm ved n<12.
11. **Data-freshness** — ingen caveat når seneste obs er gammel.
12. **Trend vs step** — Anhøj-runs skelner ikke; tekst siger uniformt
    "skift i niveau".

Den principielle løsning er **ikke** at tilføje 12 nye nøgler til
cascade-dispatchen. Dispatch-rummet eksploderer: nuværende 56
stability×action-kombinationer multiplicerer til tusinder hvis alle
dimensioner kodes som flad cascade. Vedligehold + klinisk validering bliver
uigennemførligt.

I stedet: **strukturér analyseteksten som feature-extraction +
composition-lag**. Detektion adskilles fra formulering. Tekst-output
sammensættes af **base-templates + modifier-cascade** (kompositionel
skalering, ej multiplikativ). Et **struktureret analyse-objekt** bliver
primær output; rentekst er én af flere render-views (PDF, UI, AI-prompt,
audit-log, JSON).

## What Changes

Refactor af `bfh_generate_analysis()`-pipeline og tilhørende
i18n-corpus. **Bevarer eksisterende public-API-signaturer** —
`bfh_generate_analysis(x, metadata, use_ai, ...)` returnerer fortsat
character-streng inden for tegnbudget.

**Tilføjer** ny eksporteret funktion `bfh_analyse()` der returnerer
struktureret `bfh_spc_analysis`-objekt med named features, conclusions,
confidence, caveats, suggested_actions. `bfh_generate_analysis()`
implementeres som thin wrapper omkring `bfh_analyse()` + render-lag.

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
