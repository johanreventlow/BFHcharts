# BFHcharts 0.26.0

## Nye features

* **`agg_fun` og `return_data` accepteres som snake_case-aliasser** for de
  tilsvarende dot.case-parametre (`agg.fun`, `return.data`) i `bfh_qic()`.
  Begge idiomer virker nu side om side; dot.case forbliver primær API.
  (#483, closes #429)

## Bugfixes

* `bfh_qic()` giver nu en klar fejlbesked med migrationsvejledning naar
  `chart_type = "i'"` bruges -- den deprekerede apostrof-syntaks fra 0.24.0.
  Tidligere var fejlmeddelelsen kryptisk. (#480, closes #430)

* `add_right_labels_marquee()` aabner konsekvent en ny temp-device til
  maaling og rydder altid op bagefter. Den tidligere "device already open"-genvej
  efterlod caller-devicen korrupt. (#489, closes #436)

## Performance

* **Panel-hoejde maales nu aritmetisk** (sum af ikke-null gtable-raekkehoejder)
  fremfor via `grid.newpage() + grid.draw()`. Sparer ca. 30 ms pr. `bfh_qic()`-kald
  og eliminerer 3x-rendering ved PDF-eksport (#437). Maalt afvigelse vs.
  draw-baseret metode: 0.0 %. (#488, closes #435, #437)

## Interne ændringer

* Analysefilen `R/spc_analysis.R` er opdelt i tre fokuserede filer:
  `R/analysis_core.R` (primær indgang), `R/analysis_helpers.R` og
  `R/analysis_signals.R`. Filnavnene afspejler nu indholdet. (#486, #487,
  closes #420, #421)

* `.compute_pref_pos()` er udtrukket som selvstaendig intern funktion fra
  `fct_add_spc_labels.R`. Reducerer funktionens kompleksitet og
  muliggoer isoleret test af label-placement-logik. (#482, closes #427)

* Fontbaserede test-guards fjernet fra adfaerdstest -- tests der validerer
  logik (ikke rendering) sprang fejlagtigt over paa CI. (#484, closes #432)

* `@seealso`-krydsreferencer tilfoejt til alle analyse-indgangspunkter.
  (#478, closes #428)

* ADR-005 dokumenterer distributionsstrategi for BFHcharts (GitHub-only,
  ingen CRAN). (#479, closes #423)

* CI: vdiffr visuel-regressions-workflow tilfoejt (`.github/workflows/vdiffr.yaml`).
  (#485, closes #433)

* Test-README opdateret: `BFHCHARTS_TEST_RENDER`-variablen var fejlagtigt
  markeret som "sat i R-CMD-check". (#481, closes #434)

# BFHcharts 0.25.0

## Breaking changes

* **`chart_type`-værdien for I-prime-kortet er omdøbt fra `"i'"` til `"ip"`.**
  Den nye værdi følger samme mønster som de øvrige prime-kort (`pp` for
  P-prime, `up` for U-prime), og undgår apostroffen der gav unødig friktion
  i string-håndtering. Migration: skift `chart_type = "i'"` til
  `chart_type = "ip"` i alle kald. Det er en hård omdøbning -- `"i'"`
  accepteres ikke længere. (Introduceret i 0.24.0; omdøbt før bred udbredelse.)

* **Kolonnenavnene i `result$summary` er omdøbt til ASCII-translitterationer.**
  Danske UTF-8-navne medfoerte silent NULL naar brugere fulgte dokumentationens
  ASCII-navne. De berorte kolonner: `laengste_loeb` (tidl. `laengste_loeb`
  med UTF-8-bogstaver), `laengste_loeb_max`, `nedre_kontrolgraense`,
  `oevre_kontrolgraense`, `kontrolgraenser_konstante` og de afledte
  min/max/95-varianter. Migration: erstat UTF-8-navne med translittereringerne
  i alle kald til `result$summary$...`. biSPCharts-tilpasning spoeres separat.

# BFHcharts 0.24.0

## Nye features

* **I'-kontrolkort (I-prime) via `chart_type = "i'"`.** Nyt kontrolkort der
  justerer 3-sigma-kontrolgrænser for varierende nævner (subgruppe-størrelse)
  -- nyttigt til måle- og tælledata hvor nævneren skifter mellem punkter.
  Beregningen leveres af `pbcharts::pbc()` (Taylor-metoden) af Jacob Anhøj,
  samme forfatter som `qicharts2`. For `"i'"` er `y` tælleren og `n` nævneren;
  den plottede værdi er `y/n` med nævner-justerede grænser (samme model som
  p/u-kort, modsat `"i"`-kortet hvor `y` plottes råt). Udelades `n`,
  degenererer kortet til et klassisk individuals-kort med konstante grænser.
  `pbcharts` er en valgfri afhængighed (`Suggests`); installeres med
  `remotes::install_github("anhoej/pbcharts")`. Annotationer (`notes`)
  understøttes fuldt. (closes biSPCharts-ønske om I'-kort)

# BFHcharts 0.23.1

## Interne ændringer

* Pinnede sibling-pakker i `Remotes:` til eksakte release-tags
  (`BFHtheme@v0.5.4`, `BFHllm@v0.2.0`). Upinnede Remotes i released tags
  forårsager pak-dependency-konflikter i downstream-pakker der selv pinner
  samme sibling til et tag (#80).

# BFHcharts 0.23.0

## Nye features

* **`bfh_qic(ylim = ...)` -- y-akse-visningsgrænser.** Ny valgfri parameter
  `ylim = c(min, max)` der zoomer y-aksen analogt med
  `ggplot2::coord_cartesian(ylim = ...)`. Værdier er i plottets data-skala
  (proportion-charts `p`/`pp` bruger 0-1-skalaen, fx `c(0, 1)` viser 0%-100%;
  øvrige charts bruger absolut skala). `NA` per ende giver fri grænse
  (`c(0, NA)` = fast bund, datadrevet top). Grænsen sættes på det eksisterende
  `lemon::coord_capped_cart`, så BFH-akse-caps bevares. Da coord *zoomer* og
  ikke *clipper*, droppes datapunkter og kontrolgrænse-segmenter uden for
  range IKKE (modsat `scale_y`-limits) -- charten zoomer blot til vinduet.
  Ugyldig `min >= max` ignoreres med en advarsel. Default `NULL` bevarer
  uændret, datadrevet adfærd.

# BFHcharts 0.22.1

## Behavior change

* **`bfh_subsample_label_indices()` dropper force-last anchor.** I 0.22.0 blev
  `n_labels` altid appendet som sidste anchor selv naar det braed step-rhythmen
  (fx n=24/step=3 endte med diffs `c(3,3,3,3,3,3,3,2)` -- sidste gap=2 stak ud
  visuelt). Nu inkluderes sidste index `n_labels` KUN naar `(n_labels - 1)`
  er delelig med step; ellers slutter sekvensen ved den hoejeste step-alignede
  position <= `n_labels`. Resultat: konstant rhythm hele vejen igennem.

  | n   | step | sidste index | 0.22.0 (force-last)     | 0.22.1 (kun grid)        |
  |-----|------|--------------|-------------------------|--------------------------|
  |  24 | 3    | 22 (ej 24)   | length=9, gap-tail=2    | length=8, alle diffs=3   |
  |  36 | 4    | 33 (ej 36)   | length=10, gap-tail=3   | length=9, alle diffs=4   |
  |  52 | 5    | 51 (ej 52)   | length=12, gap-tail=1   | length=11, alle diffs=5  |
  | 100 | 9    | 100 (grid)   | length=12, alle diffs=9 | uaendret                 |

  Callers der har brug for sidste label som anker skal appende det eksplicit.
  Downstream consumers (biSPCharts) der renderer subsampled labels via helperen
  vil se sidste label droppet for n hvor `(n - 1)` ej er delelig med step.

# BFHcharts 0.22.0

## Breaking changes

* **`bfh_subsample_label_indices()` returnerer faerre indices for moderate n.**
  Algoritmen skifter fra `round(seq(1, n, length.out = max_visible))` til
  deterministisk step-baseret thinning med force-last anchor. Konsekvens:

  | n   | foer (0.21.0)                            | nu (0.22.0)                              |
  |-----|------------------------------------------|------------------------------------------|
  |  24 | 12 indices, gap 11->14 (skjulte 12+13)   |  9 indices, konstant step=3              |
  |  36 | 12 indices                               | 10 indices, konstant step=4              |
  |  52 | 12 indices                               | 12 indices, konstant step=5              |
  | 100 | 12 indices                               | 12 indices, konstant step=9              |

  Downstream consumers (biSPCharts) der renderer x-akse-labels via helperen
  faar sparser men deterministisk label-distribution uden gap-of-3 anti-
  pattern. API-signatur uaendret.

## Bug fixes

* **(#396) Strukturel gap-bug i `bfh_subsample_label_indices()` for n=24.**
  `round(seq.int(1L, n, length.out = max_visible))` producerede ikke-heltals
  positioner som snappede asymmetrisk via R's banker's rounding. For
  n=24/max=12 gav det indices `1 3 5 7 9 11 14 16 18 20 22 24` -- gap 11->14
  skjulte to konsekutive labels (12+13) midt i serien. I biSPCharts SPC-
  eksport ramte dette aarsskifte-labels (dec 25 + jan 26) ved 2-aars
  maaneds-serier.

  Fix: deterministisk integer step
  `ceiling((n_labels - 1) / (max_visible - 1))` + force-last anchor
  garanterer konstant interval i "showing" pattern -- aldrig to konsekutive
  skjulte labels.

# BFHcharts 0.21.0

## Nye features

* **`bfh_subsample_label_indices(n_labels, max_visible = BFH_MAX_X_LABELS_TEXT)`**
  — eksporteret helper der returnerer evenly-spaced indices til
  subsample af kategoriske x-akse-labels. Foerste og sidste indices
  anchored som anker-points, intermediate via
  `round(seq(1, n, length.out = max_visible))`. Skalerer smoothly:
  n <= max_visible giver alle indices, n > max_visible thinner
  progressivt. Designet til tekst-x-data (maanedsnavne, ugedage,
  observation-id) hvor visning af alle labels ville overlappe.

* **`BFH_MAX_X_LABELS_TEXT` konstant** (default 12L) — eksporteret
  styling-default for [bfh_subsample_label_indices()]. Threshold valgt
  til at passe standard A4 PDF eksport-bredde (200mm @ 300dpi) med
  horisontale Roboto Medium labels.

* **`bfh_generate_details(x, language, x_labels = NULL)`** udvidet med
  valgfri `x_labels`-parameter. Naar sat (character vector, length =
  nrow(qic_data)), bruges foerste og sidste label til Periode-felt
  (fx "Periode: januar . december") i stedet for dato-baseret
  formatering paa `qic_data\$x`. Interval-label bliver "kategori".
  Bagudkompatibel: `x_labels = NULL` bevarer eksisterende dato-flow.

  Use case: downstream pipelines (biSPCharts) konverterer tekst-x til
  numerisk sekvens FOER `bfh_qic()`-kald for at stoette ggplot-rendering.
  Tidligere reflekterede Periode-feltet i PDF-eksport den numeriske
  sekvens (fx "Periode: 1970-01-01 . 1970-01-12") frem for original-
  labels.

## Dependency bumps

* `BFHtheme (>= 0.5.1)` — kraever font-detection-fix hvor
  `BFHtheme::font_available()` konsulterer baade `system_fonts()` og
  `registry_fonts()`. Uden bumpet ville downstream konsumenter (fx
  biSPCharts) der registrerer Mari via `systemfonts::register_font()` i
  runtime fortsat se "Mari ikke fundet" og fallback til Roboto/sans paa
  deploy-targets uden OS-installeret Mari (Posit Connect Cloud).

# BFHcharts 0.20.0

## Nye features

* **Struktureret SPC-analyse via `bfh_analyse()` + `bfh_render_analysis()`**
  (ADR-004). Tre-lags arkitektur erstatter monolitisk
  `build_fallback_analysis()`-cascade:

  - `bfh_extract_spc_features(x, metadata)` — pure deterministisk
    feature-extraction af 12 ortogonale fortolknings-akser
  - `bfh_analyse(x, metadata, language)` — komposerer struktureret
    `bfh_spc_analysis` S3-objekt (key-only model: i18n-nøgler, ej
    resolverede strenge)
  - `bfh_render_analysis(analysis, max_chars, texts_loader)` —
    resolverer nøgler til character via texts_loader

  Use-cases: PDF-eksport (eksisterende `bfh_generate_analysis()`
  delegerer til ny pipeline; backward-compatibel), app-UI badge-
  rendering, AI-prompt-anker, audit-replay, JSON-export.

* **7 nye fortolknings-akser** aktiveret via modifier-cascade:

  - **Slice 3 (Magnitude)**: `features$magnitude` lagrer sigma-shift-
    bucket (small/medium/large). Rendres som "(~30% forandring)"-clause
    appendet til stability-text.
  - **Slice 4 (Direction)**: `metadata$direction = higher_better /
    lower_better / neutral` driver favorable/unfavorable-vurdering via
    baseline-delta. Rendres som "i den ønskede retning"-clause.
  - **Slice 5 (Baseline-delta + phase-intervention)**: Ved `part >= 2`
    rendres "Niveauet er flyttet fra X til Y siden tidligere fase".
  - **Slice 7 (Variable kontrolgrænser)**: p/u/xbar-charts med
    svingende stikprøvestørrelse får tail-caveat.
  - **Slice 8 (Few-obs / not-evaluable)**: `n < N_MIN` (= 12 per
    Anhøj 2014) erstatter stability-base med "for kort serie"-tekst.
    Target+action arms skippes ved low-confidence.
  - **Slice 9 (CL-disclosure i prose)**: `cl_user_supplied` +
    `cl_auto_mean` caveats appender til prose (var hidtil kun i
    PDF-sidebar).
  - **Slice 14 (Discrete scale 3-tier)**: `n_on_cl_ratio` mapper til
    4-tier enum (none/mild/moderate/extreme). Mild/moderate som tail-
    caveat; extreme bevarer eksisterende `majority_at_centerline`-base-
    override.

* **Chart-type-aware confidence-tier**: Run-charts har `sigma_hat = NA`
  by design. `is.na(sigma_hat)` alene udløser IKKE `confidence_tier =
  "low"` — bruger `sigma_data` (sd(y)) som spread-estimat for run-
  charts. Tidligere logik ville have fejlmarkeret valide 24-punkt run-
  charts som "for kort serie".

* **analysis_date 3-vejs præcedens** (`R/utils_analysis_date.R`):
  Driver deterministisk freshness-detektion og audit-replay-evne.
  Resolution-order: `metadata$analysis_date` >
  `getOption("BFHcharts.analysis_date")` > `Sys.Date()`. Resolvet
  værdi lagres i `analysis$aux$analysis_date`.

## Bug fixes (cycle 04 + 05 dual-review)

Cycle 04 (final-state branch-review, 2026-05-18) + cycle 05 (user-led
audit efter cycle 04 fixes) identificerede 14 fund. Fixes:

* **H1 (HIGH, cycle 04)**: Mixed decimal-separators ved `language="en"`.
  `render_context$centerline_formatted` pre-computed med hardcoded "da";
  baseline-delta-modifier mixede engelske/danske decimal-tegn. Fix:
  centerline formaters ved render-time med caller-language.

* **H4 (HIGH, cycle 04)**: `features$stability_pattern` advertise
  `"not_evaluable"` men sattes aldrig. Render erstattede template ved
  low-confidence, men feature-key forblev "runs_only" etc. Fix:
  `.resolve_stability_pattern()` returnerer "not_evaluable" naar
  `confidence_tier == "low"`.

* **H5 (MEDIUM, cycle 04)**: Fixed 200L modifier-budget producerede
  brudt prose ved `max_chars=200`. Fix: proportional modifier-budget
  baseret paa `max_chars * 0.25 / n_modifiers`.

* **N1 (MEDIUM, cycle 04)**: `render_context$effective_window`
  spec-required men ikke implementeret. Fix: tilfoejet til render_context
  + validator + schema-test.

* **H2 (MEDIUM, cycle 05)**: `.compute_magnitude` accepterede
  microscopic sigma (`sigma_hat ~ 1e-12` fra near-constant data) ->
  float-noise baseline-delta klassificeret som "large". Fix:
  `MAGNITUDE_RATIO_CAP = 100` returnerer NA ved ratios over cap.

* **H3 (MEDIUM, cycle 05)**: Spec kraevede `aux$data_age_days` men
  Slice 10 (Freshness) SKIP-besluttet -> ingen detection-use-case.
  Fix: spec-konsistens (`data_age_days` fjernet fra required-list).

* **Cycle 05 finding #1 (HIGH)**: `detect_variable_cl()` udloeste falsk
  caveat paa I-charts med phase-split (CL-variation drevet af phase,
  ej n). Fix: chart-class-gate -- caveat aktiv kun paa subgrouped
  chart-classes (proportion/rate/subgrouped).

* **Cycle 05 finding #2 (HIGH)**: Modifier-konkatenering producerede
  grammatisk brudt prose ("... uden tegn paa systematiske aendringer.
  (en betydelig forandring paa ~10%). i den oenskede retning. Fra X
  til Y."). Fix: `.compose_modifier_sentence()` bygger EN sammen-
  haengende saetning. Templates redesignet som clause-form (lowercase,
  ingen trailing period); composer vaelger sentence-frame baseret paa
  hvilke modifiers er aktive.

* **Cycle 05 finding #4 (MEDIUM)**: AI-path `signals_detected` ud-
  ledtes af `stability_pattern != no_signals/no_variation`. Data-
  quality states (`not_evaluable`, `majority_at_centerline`) lekkede
  som "signaler" til BFHllm. Fix: brug runs/crossings/outliers flags
  direkte (sande Anhoej-signaler).

* **Cycle 05 finding #5 (MEDIUM)**: `not_evaluable`-prose sagde altid
  "Med kun {n_points} observationer..." selv naar n >= N_MIN men
  centerline/spread manglede -- klinisk misvisende. Fix: ny
  `low_confidence_reason`-feature-akse (few_obs/no_centerline/
  no_spread) driver template-dispatch. Render-prose matcher faktisk
  aarsag.

* **Cycle 05 finding #6 (LOW)**: `chart_class` mappede xbar/s til
  "individuals". Fix: nu "subgrouped" (matcher hvordan sigma/CL
  beregnes).

* **Cycle 05 tekst-stramninger**:
  - direction.unfavorable: "i forkert retning" -> "i uoenskede retning"
  - stable_near_target.detailed: "accepter den lille difference" ->
    "Vurder om forskellen er praktisk betydende" (mindre normativt)
  - unstable_near_target.standard: "naturlige variation" -> "saerlige
    aarsager til variation" (Anhoej/Shewhart-terminologi)
  - not_evaluable.few_obs.detailed: "detektions-styrke" ->
    "detektionsstyrke" (sammensat ord)

* **Test-cleanup**: `test-spc_parity_phase1.R` tautologisk post Phase 2
  cut-over (bfh_generate_analysis() delegerer internt til samme
  pipeline). 12 sammenligning-tests skip'es med rationale; determinism-
  test bevares som idempotens-gate. Snapshot-tests mod frozen baseline
  er planlagt follow-up.

## Bug fixes (cycle 07 dual-review)

Cycle 07 (post-merge audit via BFHddl-integration, 2026-05-18)
identificerede 4 fund:

* **MEDIUM (priority-aware trim)**: `bfh_render_analysis()` brugte
  blind `ensure_within_max()`-trim fra slutningen. Ved tight budget
  med aktiv modifier-saetning kunne klinisk vigtig action-tekst
  klippes vaek mens optional modifier + tail-caveats bevares. Fix:
  priority-drop af modifier > tail > target FOR blind clip.
  stability + action er klinisk must-keep.

* **LOW (prose-niveauforandring)**: `magnitude.detailed` brugte
  dobbeltkonstruktion "i niveauet i den oenskede retning". Fix:
  "niveauforandring" substantiv (begge locales).

* **LOW (variable_cl hedge)**: "varierer fordi stikproevestoerrelse
  aendrer sig" -> "varierer, typisk fordi naevner/stikproevestoerrelse
  aendrer sig". Koden infererer fra UCL/LCL-spaend, ej direkte fra n.

* **LOW (cl_auto_mean revert)**: Reviewer #3 anbefalede genindfoersel
  af Anhoej-rationale. Bruger-override efter klinisk test via BFHddl:
  kort variant tilstraekkelig (matcher PR #379-fix paa develop).

## Internal changes

* `bfh_spc_analysis` S3-class (`R/bfh_spc_analysis_class.R`):
  constructor + validator + `print` / `format` / `as.list`-methods.
  Schema-version "1.0.0" via `BFH_SPC_ANALYSIS_SCHEMA_VERSION`-konstant,
  bumpes uafhængigt af pakke-version.

* `N_MIN = 12L`-konstant + `BFHCHARTS_OPT_ANALYSIS_DATE`-konstant
  tilføjet til `R/globals.R`.

* Shared helpers i `R/spc_analysis.R`:
  - `.compute_level_keys()` — fælles (direction_key, vs_target_key)-
    triplet for legacy `build_fallback_analysis()` + ny `spc_render.R`.
  - `.normalize_target_operators()` — fælles ASCII >=/<=  →  Unicode
    ≥/≤ konvertering for legacy + ny pipeline.

* `build_fallback_analysis()` markeret som `@keywords internal @noRd`
  backward-compat-layer; vil blive fjernet i næste major release.

## Validation infrastructure

* **Bilingual parity CI-gate** (`tests/testthat/test-i18n_bilingual_parity.R`,
  61 tests): YAML key-paritet + placeholder-paritet (med
  `KNOWN_DIVERGENCES`-whitelist for 11 pre-existing legacy-mismatches) +
  `format_target_value()`-decimal-separator pr. sprog.

* **Schema-stability tests** (`tests/testthat/test-spc_schema_stability.R`,
  23 tests): Top-level fields invariant, JSON-roundtrip,
  `.simulate_downstream_consumer()`-sentry mod breaking changes for
  biSPCharts.

* **Golden-corpus snapshot** (`tests/testthat/test-spc_golden_corpus.R` +
  `tests/testthat/_snaps/spc_golden_corpus.md`, 12 snapshots):
  Parametric sweep over stability × target × language × budget-matrix.
  Regression-gate ved enhver render-output-aendring.

## Test-suite

* 5481 PASS, 0 FAIL, 69 SKIP (+318 nye tests siden 0.19.0).

## Refs

* ADR-004: `inst/adr/ADR-004-structured-spc-analysis-architecture.md`
* Openspec change (archived): `openspec/changes/archive/2026-05-18-
  restructure-spc-analysis-architecture/`
* Dual-review-cycle 03: `docs/reviews/03-structured-spc-analysis-
  proposal-2026-05-17.md`

# BFHcharts 0.19.0

## Bug fixes

* **Auto-substitution af median → gennemsnit håndterer nu multi-phase,
  `exclude=` og Date+multiply korrekt** (cycle 02 dual-review).
  Tidligere version fra 0.18.0 havde tre distinkte bugs:
  - **H1 multi-phase:** evaluerede kun sidste fase. Tidligere faser
    tied til deres median forblev på median-CL med degenererede Anhøj-
    signaler. Fix: per-fase iteration + uafhængig swap.
  - **H3 exclude:** trigger-tæller OG replacement-mean ignorerede
    `qic_data$include`. Excluded outliers forurenede ny CL. Fix:
    include-mask i begge steps.
  - **H4 Date + multiply (user-reported):** qicharts2 upcaster Date
    → POSIXct i probe-output, så `raw_x %in% qd$x` returnerede all-
    FALSE for Date-kolonner. Den nye cl-vektor blev all-NA →
    qicharts2 fallback til median for hele trigger-fasen, men
    `cl_auto_mean`-flag (og PDF-caveat) fyrede alligevel. Samtidig
    multiplicerede qicharts2 vores user-cl med `multiply` så
    percent-skalerede mean-værdier blev 100× for store. Fix: cross-
    class x-normalisering + multiply-divider + guard mod silent-fail
    flag-sætning.

  Cycle 02 review: `docs/reviews/02-cl-auto-mean-validation-2026-05-16.md`.

## Breaking changes

* `validate_denominator_data()` tillader nu `n = 0` for ratio-charts
  (p/pp/u/up). Tidligere kastede funktionen hård fejl; nu beregnes
  værdier af qicharts2 som NaN (punkter tegnes ej i plottet). Klinisk
  fortolkning: `n = 0` = "ingen patienter den periode" = valid input.
  Centerline beregnes fra valide rækker (sum-aggregation), uændret af
  n=0-rækker. Ramt downstream: biSPCharts `fct_spc_plot_generation.R`
  pre-filter (linje 128-148) er nu overflødig og bør fjernes.
* `y > n` for proportion-charts (p/pp) tillades nu. qicharts2 plotter
  proportion > 1 som outlier-signal over ucl-linjen (capped på 1.0).
  Tidligere fejlede valideringen med "y <= n"-besked.

## Internt

* `n = Inf/-Inf` fejler stadig hård — Inf forurener hele plottet med
  cl/ucl=0 (empirisk verificeret).
* `n < 0` fejler stadig hård. Fejlbesked opdateret fra "must be > 0"
  til "must be >= 0, got negative values at row(s): X. Negative
  denominators pollute centerline computation." Negative denominatorer
  forurener cl-beregning globalt: ALL n<0 → cl<0; mixed n<0 → cl
  forurenes af negative bidrag i sum-aggregation.

# BFHcharts 0.18.0

## Nye features

* **Auto-substitution af median → gennemsnit ved diskret run-chart-data.**
  Når mindst 50 % af observationerne i seneste fase af et run chart
  ligger eksakt på medianen (typisk symptom på grov rapportering eller
  diskret målestok), skifter `bfh_qic()` automatisk seneste fases
  centerlinje fra median til gennemsnit. Tidligere faser beholder
  medianen. Anhøj-signalerne rekomputeres mod den nye centerlinje,
  så analysen ikke kollapser i meningsløse tællinger på grund af
  ligheder mellem y-værdier og CL. Detection sker via et
  probe→retry-mønster (to qicharts2-kald) og piggybackbar på
  qicharts2's `cl=NA`-fallback til at bevare tidligere fasers median.
  PDF-caveat-feltet flagger substitutionen som "Niveaulinje skiftet
  til gennemsnit". Eksplicit `cl=`-parameter overruler altid
  auto-substitutionen.



* **Direction-aware "tæt på"-klassifikation for operator-targets.**
  `.evaluate_target_arm()` bruger nu samme proces-variation-cascade
  (`3*sigma_hat` → `sd(y)` → eksakt-match) for retningsbevidste targets
  (`>= 90%`, `<= 5%`) som allerede var aktiv for value-neutral path. Når
  centerlinjen ligger på "forkert" side af målet men inden for processens
  naturlige variation, klassificeres tilstanden som `near_target` i
  stedet for `goal_not_met`. Prioritet: strikt `goal_met` (CL på korrekt
  side) > `near_target` (forkert side + inden for tolerance) >
  `goal_not_met`. **Behavior change**: scenarier hvor `|CL - target| <=
  3*sigma_hat` flipper fra "ikke opfyldt" til "lige under/over målet" i
  output. (OpenSpec: `goal-direction-tolerance`)

* **Nye action-arm-keys `stable_near_target` og `unstable_near_target`.**
  Renderes når `near_target == TRUE` i target-armen. Bruger
  `{level_direction}`-placeholder til at sige "lige under målet"
  (higher-direction-mangel) eller "lige over målet" (lower-direction-
  overskridelse).

* **Ny stability-arm-key `majority_at_centerline`.** Aktiveres når >= 50%
  af datapunkterne ligger eksakt på centerlinjen (`|y - cl| < 1e-9`) men
  ikke alle er identiske (`no_variation` har fortrinsret). Flagger typisk
  diskret rapportering eller grov måleskala der forringer SPC-tolkningen.
  Tilgængelig på dansk og engelsk.

## Bug fixes

* **PDF-font-substitution rettet via BFHchartsAssets 0.1.1.** Mari-fontfilernes
  OS/2-metadata havde forkerte `usWeightClass`-værdier (alle satte til 400
  for Light/Book/Heavy/Poster). Konsekvensen var inkonsistent font-
  substitution på macOS, hvor `MariHeavy` kunne blive valgt som "Mari"-
  regular til brødtekst. Windows og Posit Connect Cloud rendrede korrekt.
  Fix er udført i BFHchartsAssets (v0.1.1) — opdatér til mindst denne
  version for korrekt PDF-rendering på alle platforms. Ingen ændringer
  kræves i BFHcharts-koden eller -templates.

## Nye features

* **`{level_direction}` og `{level_vs_target}` placeholders i analyseteksten.**
  Templates i `analysis.target.*` og `analysis.action.*` kan nu referere
  centerlinjens position relativt til målet via to nye placeholders:
  `{level_direction}` → "over"/"under"/"på" (enkeltord), og
  `{level_vs_target}` → "ligger over målet"/"ligger under målet"/"ligger
  på målet" (forhåndsformuleret klausul). Værdierne er tomme strenge når
  target ikke er sat, så placeholders kun bør bruges i templates der
  allerede er target-betingede. "Ligger på målet" rendres kun ved
  strikt lighed (`|centerline - target| < 1e-9`).

## Interne ændringer

* **Budget-allokering justeret for analyse-tekster med target.** Ratio
  ændret fra 50/25/25 til **50/15/35** (stability/target/action).
  Action-armen får nu plads til de fleste `detailed`-varianter (90-136
  tegn) der tidligere faldt til `short`. Target-armen klarer sig med
  mindre budget da langt de fleste target-varianter er korte (35-46 tegn).
  `max_chars`-default forbliver 375 (matcher Typst-skabelonens
  designgrænse).

* **Padding fjernet fra fallback-analysen.** `pad_to_minimum()` og
  YAML-sektionen `analysis.padding` er slettet — indholdsmæssigt
  intetsigende tekster bidrog ikke til analyseteksten og forstyrrede
  designet. `min_chars` bevares i `bfh_generate_analysis()`-signaturen
  fordi det stadig videreføres til `BFHllm::bfhllm_spc_suggestion()` på
  AI-stien, men har ingen effekt på fallback-tekstgenereringen.

# BFHcharts 0.17.3

## Bug fixes

* **`.validate_inject_assets()` accepterer nu `BFHchartsAssets` som
  default-allowlist.** Tidligere blokerede sikkerheds-guarden
  `BFHchartsAssets::inject_bfh_assets` med fejlen
  `inject_assets must come from a trusted package namespace ... not from
  'BFHchartsAssets'`, selv om BFHchartsAssets er den dokumenterede
  companion-pakke (se threat-model i `export_pdf.R`). Det fik BFHddl-
  pipeline til at fejle i `Flush`-fasen ved PDF-eksport. Default-
  `allowed_namespaces` udvidet til
  `c("BFHcharts", "biSPCharts", "BFHchartsAssets")`. Downstream
  pipelines kan nu kalde `bfh_export_pdf(..., inject_assets =
  BFHchartsAssets::inject_bfh_assets)` uden workaround-options.

# BFHcharts 0.17.2

## Bug fixes

* **PDF-eksport pa Windows virker nu med stier der indeholder mellemrum.**
  `.safe_system2_capture()` quotede tidligere kun path-args pa POSIX baseret
  pa en forkert antagelse om at Windows `system2()` sender argv-tokens direkte
  til child-processen. I virkeligheden paster Windows-versionen alle args
  sammen til en command-line streng som MSVCRT's argv-parser re-splitter pa
  uquotede mellemrum. Stier som `C:/output/Behandling og pleje/foo.pdf` blev
  split saa Typst sa `og` som en uventet positional arg og afbroed med
  `error: unexpected argument 'og' found`. Path-args quotes nu med
  `shQuote(type = "cmd")` pa Windows; flag-args (i `KNOWN_TYPST_FLAGS`)
  forbliver uquotede. Retter regressionen indfoert af commit a528f1b
  (fix(typst): skip shQuote on Windows in .safe_system2_capture, 2026-05-01).

* **`at_target`-klassifikation bruger nu processens variation som
  tolerance-skala** i stedet for en relativ-til-target floor. Den gamle
  regel (`tolerance = max(|target| * target_tolerance, 0.01)`) havde en
  absolut 0.01-floor uden statistisk begrundelse der dominerede når
  target selv var lille -- små targets (f.eks. 1 %) blev fejlagtigt
  klassificeret som "tæt på målet" selv når centerlinjen afveg
  signifikant (f.eks. 0.019 vs target 0.01 = 90 % afvigelse). Den nye
  regel forankrer tolerancen i processens egne kontrolgrænser:
  `|CL - target| <= 3 * sigma_hat` hvor `sigma_hat = mean((UCL - LCL)
  / 6)` over sidste fase. For run charts (ingen kontrolgrænser) falder
  vi tilbage til `sd(y)`; for degenererede tilfælde (konstant y) en
  eksakt-match tolerance. `over_target` / `under_target` er nu rent
  faktuelle (CL vs target uden tolerance). Berører output fra
  `bfh_generate_analysis()` for berørte scenarier; `action_key` skifter
  tilsvarende. Se OpenSpec change `at-target-tolerance-process-variation`.

## Deprecated

* **`bfh_generate_analysis(target_tolerance = ...)` er deprecated.**
  Argumentet bevares i signaturen for backward compatibility men
  ignoreres af value-neutral `at_target`-klassifikation der nu bruger
  processens variation (UCL/LCL eller sd(y)). Eksplicit videregivelse
  fyrer `lifecycle_warning_deprecated`. Parameter fjernes endeligt i
  næste major release.

# BFHcharts 0.17.1

Production-readiness audit (cycle 01, 2026-05-10) drevet af
`dual-review-cycle`-skill med Codex peer-review. 11 PRs merged til
develop. Verdict: APPROVE for produktion (multi-tenant Connect Cloud
+ biSPCharts). Test-baseline: 5022 PASS / 0 FAIL.

## Bug fixes

* **`.normalize_percent_target()` bevarer nu numeriske stretch-targets
  > 1 på proportion-skalaen.** Tidligere heuristik `value > 1`
  fejltolkede legitime stretch-mål som f.eks. `target_value = 1.05`
  (= 105% på multiply=1) som procent-skala-input og dividerede med 100,
  så downstream-narrative i `bfh_generate_analysis()` og PDF-export
  blev semantisk forkert ("centerlinje over maal" når processen
  faktisk lå under 105%-stretch). Tighten til `value > 1.5` (validatorens
  upper bound for multiply=1) -- bryder ingen eksisterende tests, fixer
  både target=1.05 og boundary-case=1.5. Charten selv (qicharts2-output)
  var korrekt; kun den genererede analyse-tekst var forvrænget.
  Empirisk verificeret + Codex peer-review (cycle 01 E1).

* **`bfh_qic(cl = Inf)` afvises nu med klar fejl-besked.** Tidligere
  `validate_numeric_parameter()` admitterede `Inf`/`-Inf` (`is.na(Inf)
  == FALSE`, og `Inf < Inf` / `Inf > Inf` returnerer begge FALSE), saa
  ugyldigt input flød til qicharts2/yA_npc-laget hvor det fejlede
  kryptisk efter user-supplied-cl-warning allerede var udsendt. Tilføjet
  eksplicit `is.finite()`-check (cycle 01 E2).

* **`format_target_value()` bruger nu locale-aware decimal-separator.**
  `bfh_generate_analysis(..., language = "en")` producerede tidligere
  engelsk analyse-tekst med danske decimaler (`"1,5"` i stedet for
  `"1.5"`) fordi formatteren hardcodede `decimal.mark = ","`. Threadet
  `language`-parameter igennem helper + call-sites; default forbliver
  `"da"` (bagudkompatibel). Integer- og percent-paths uændret
  (locale-uafhængige). Cycle 01 E4.

* **`format_qic_summary()` returnerer nu tom data.frame ved tom
  `qic_data` i stedet for en 1-række NA-frame.** `bfh_qic()` blokerer
  `nrow(data) == 0` upstream, men hvis `qicharts2` selv returnerer
  empty (extrem `exclude=`-konfiguration), undgår early-return nu
  NA-propagation til `runs_signal`/`crossings_signal`. Defensive fix
  (cycle 01 E6).

* **`freeze = 1` på 1-række data afvises nu rent.** Tidligere
  `validate_position_indices()` floor `max(nrow(data) - 1, 1L)`
  admitterede `freeze = 1` på 1-row data hvor `freeze == nrow` lod
  nul observationer tilbage efter baseline-split. Drop floor;
  `max = nrow(data) - 1`. NULL-freeze stadig OK via `allow_null=TRUE`
  (cycle 01 E7).

* **Count-style charts (`c`, `g`, `t`, `p`, `pp`, `u`, `up`) afviser
  nu negative y-værdier ved validation.** qicharts2 renderede tidligere
  negative counts uden warning -- charten så valid ud men var
  statistisk meningsløs for klinikere. Chart-type-aware check tilføjes
  i `validate_bfh_qic_inputs()`; i-chart og run-chart accepterer stadig
  negative værdier (continuous metrics som temperaturer/differencer)
  (cycle 01 E8).

## Security

* **Staging-tempdirs oprettes nu atomisk med `mode = "0700"`.** De tre
  staging-dir-creation-sites (`R/utils_typst.R:330`,
  `R/utils_export_helpers.R:341`, `R/export_session.R:89`) brugte
  tidligere to-trins-pattern `dir.create()` -> `Sys.chmod(0700)` der
  efterlod et microsecond TOCTOU-vindue hvor dir var verden-læsbar.
  `dir.create(..., mode = "0700")` lukker vinduet; `Sys.chmod()` bevares
  som belt-and-suspenders for ældre R / Windows hvor `mode=` kan
  honoreres inkonsistent (cycle 01 S1).

* **Filsystem-paths redacteres nu i user-visible `stop()`/`warning()`-
  beskeder.** `stop()`/`warning()`-paths i `R/utils_typst.R` afslørede
  rå absolutte stier (template-cache, chart-staging, font_path) som
  kunne lække home-dir-layout, R-library-install-path og per-session
  tempdir-naming til co-tenants på Connect Cloud hvis biSPCharts
  surfaceer `conditionMessage(e)`. Ny shared `.redact_paths()`-helper
  stripper `tempdir()` (både raw og normalized form), `HOME`, og
  `.libPaths()`-prefixes (cycle 01 S2).

* **`bfh_create_typst_document()` re-validerer `chart_image` post-
  symlink-resolution.** `validate_export_path()` kørte tidligere kun
  på det syntaktiske input før `normalizePath()` resolverede symlinks.
  En symlink fra trusted staging-område til /var/lib/connect/tenant-A/
  PHI-fil ville passere syntaktisk validering, men `file.copy()` følger
  symlinks for source-filer og ville pulle anden tenants data ind i
  output-PDF. Fix: re-validate `chart_image_norm` efter `normalizePath`
  så path-traversal + shell-metachar guards anvendes på det reelle
  target (cycle 01 S3).

## Documentation

* `bfh_qic_result.R` @return-block dokumenterer nu `$summary` korrekt
  som `data.frame` (ikke `tibble`). Implementation har altid returneret
  plain data.frame; doc/code-drift afsløret af Codex peer-review.
  Eksplicit kontrakt-note: klassen er public-API og vil ikke flippe
  til tibble uden deprecation-cycle (cycle 01 E5).

* Nyt review-tracker-konvention etableret i `docs/reviews/` per
  `dual-review-cycle`-skill. Cycle 01 audit-trail tilgængeligt i
  `docs/reviews/01-production-readiness-2026-05-10.md` med Codex
  reconcile-section + 5 dokumenterede læringer.

## Internal changes

* `validate_numeric_parameter()` bypasser `param_msg()` ved
  finiteness-violations så fejl-beskeden ikke falder tilbage paa
  generisk "must be a single numeric value" (Inf ER et single numeric
  value -- problemet er finiteness specifikt).

* Pre-push hook race-conditions ved parallelle pushes dokumenteret i
  memory; sequential push-rytme anbefalet for cycle-merge-driven.

# BFHcharts 0.17.0

## Breaking changes

* `get_plot()` omdøbt til `bfh_get_plot()` for at følge `bfh_*` naming-konvention og undgå namespace-collision med ggplot2/plotly. Migration: erstat `get_plot(result)` med `bfh_get_plot(result)` eller brug `result$plot` direkte.

## Bug fixes

* **Y-akse-expansion bumpet fra 5% til 12.5% (top + bund) for at undgå at
  boundary-labels (target/CL nær akse-grænse) klippes.** SPC-44-style
  scenarier — fx udviklingsmål-label `<1%` på p-chart med y-akse 0–10% —
  klippede tidligere ved nederste plot-kant fordi marquee-label-højden
  ikke fik plads i 5%-expansion-zonen. PR #164 reducerede default fra 20%
  til 5% for at fixe whitespace-overskud (#113), men gik for langt for
  boundary-cases. Ny default placerer data i de midterste ~80% af
  plot-området, jf. SPC-litteraturens anbefaling. Boundary-aware
  label-placement (`fct_add_spc_labels.R:300-348`) er uændret.
  (`Y_AXIS_BASE_EXPANSION_MULT` i `R/globals.R`, refs #164)

## Nye features

* **Native Unicode-tegn (æøå mfl.) tilladt i kolonnenavne.** `bfh_qic()`s
  column-name-validator har tidligere afvist danske tegn i kolonnenavne, hvilket
  tvang downstream-applikationer (biSPCharts) til at ASCII-translit'e kolonnenavne
  før hvert kald. Validator-regex er udvidet fra `[a-zA-Z]` til Unicode-letter-
  klasse (`\p{L}`) via `perl = TRUE`, så `Tæller`, `Nævner`, `Måned` og lignende
  hospital-system-eksporter accepteres nativt. Function-call-, operator- og
  whitespace-detektion er uændret — kun letter-klassen er blevet bredere
  (#327, fix biSPCharts #562).

# BFHcharts 0.16.1

## Security

* **`restrict_template` argument-validering haerdet mod non-logical input.**
  Tidligere `if (isTRUE(restrict_template) && !is.null(template_path))` lod
  `restrict_template = NA`, `1L`, `"TRUE"`, eller en logical-vektor passere
  guarden lydloest (`isTRUE()` returnerer `FALSE` for alt andet end et enkelt
  `TRUE`). Type-validering tilfoejet FOER `isTRUE()`-checket -- ikke-logical
  scalar fejler nu med klar fejl-besked. Vector for Shiny-/API-kontekster hvor
  `restrict_template` kunne flyde fra deserialized JSON eller `as.logical()`-
  coercion. Lukker production-readiness review item 1.1.

* **`metadata$logo_path` faar nu path-traversal + shell-metachar validering**
  (`R/utils_export_helpers.R:153-181`). Tidligere accepterede valideringen
  enhver scalar non-empty character string -- "../../etc/secret.png" eller
  "/home/x/private.png" passerede gennem `escape_typst_string()` direkte til
  Typst's `image()`. Uden `--root`-sandbox (se naeste punkt) kunne dette
  laese vilkaarlige filer paa hosten ind i PDF-output (PHI-eksfiltration i
  multi-tenant deploys) eller fungere som file-existence oracle. Mirror den
  validering som allerede findes paa `font_path` (`utils_typst.R:389-390`).
  Lukker production-readiness review item 1.2.

* **Typst-compileren kører nu med `--root <staged-tempdir>`** (defense in
  depth, `R/utils_typst.R:418-435`). Confiner alle `image()`/`read()`/
  `include` access til den staged template-directory, så selv hvis en
  fremtidig metadata-felt-validering bliver glemt, kan compileren ikke
  laese udenfor tempdir-traeet. Mitigerer hele klassen af path-traversal-
  vektorer paa compiler-niveau. `--root` tilfoejet til
  `KNOWN_TYPST_FLAGS`-allowlist så flag-vaerdien shell-quoteres korrekt.

## Bug fixes

* **`bfh_extract_spc_stats.data.frame()` overfører nu
  `cl_user_supplied`-attributtet.** Tidligere returnerede data.frame-
  dispatch-pathen altid `NULL` for flaget, selv naar `attr(x,
  "cl_user_supplied")` var sat paa input -- så downstream-konsumenter der
  kaldte `bfh_extract_spc_stats(result$summary)` direkte (i stedet for at
  passere hele `bfh_qic_result`-objektet) tabte caveat-rendering i PDF
  lydloest. Nu lazet via `isTRUE(attr(x, "cl_user_supplied"))` paralleelt
  med `bfh_qic_result`-method'en. Lukker production-readiness review item 2.7.

* **`restrict_template`-error-besked vejleder nu om opt-out-pathen.**
  Tidligere besked: "template_path is not allowed when restrict_template =
  TRUE." -- ingen migration-hint. Ny besked tilfoejer eksplicit guidance
  om `restrict_template = FALSE` + warning om compile-niveau trust-model.
  Lukker production-readiness review item 1.4.

## Internal changes

* CI: `auto-release-pr.yaml`-workflow repareret -- shallow-fetch og
  pipefail/SIGPIPE-bug der gav exit 141 ved post-merge runs paa develop.

# BFHcharts 0.16.0

## Breaking changes

* **`bfh_export_pdf(restrict_template = TRUE)` er nu default.** Tidligere
  default `FALSE` tillod stiltigende custom Typst-templates via `template_path`
  -- en silent privilege-escalation-vector hvis en konfigurations-pipeline
  forwarder user-controlled input. Custom Typst-templates kompileres med
  trust-niveau svarende til `source()` (læser/skriver vilkårlige paths under
  compilation). Default-safe posture eliminerer denne vector.

  **Migration:** Callers der eksplicit ønsker custom-template skal nu opt-in:
  ```r
  # Foer (BFHcharts <= 0.15.x): custom template tilladt by default
  bfh_export_pdf(result, "out.pdf", template_path = "/my/template.typ")

  # Efter (BFHcharts >= 0.16.0): eksplicit opt-out paakraevet
  bfh_export_pdf(result, "out.pdf",
                 template_path = "/my/template.typ",
                 restrict_template = FALSE)
  ```
  Migration er mekanisk: tilfoej `restrict_template = FALSE` til eksisterende
  kald. Validation-error-besked nævner eksplicit opt-out parameteren.

  Lukker production-readiness review item 2.1. Se ADR-003 for risk-modellen
  (warning-blind clinical readers).

## Nye features

* **PDF-eksport rendrer nu en caveat-note under SPC-tabellen, naar
  bruger-defineret centerlinje (`cl`) er sat i `bfh_qic()`.** Naar caller
  passerer en non-NULL `cl`, bliver Anhøj run/crossing-signaler beregnet mod
  den brugersatte centerlinje, ikke den data-estimerede process-mean.
  Eksisterende R-side warning (`R/bfh_qic.R:674-682`) er bevaret -- PDF-caveat
  er den ANDEN surface for warning-blind kliniske læsere.

  Caveat-tekst (dansk default): *"Centerlinje fastsat manuelt -- Anhøj-signal
  beregnet mod denne, ikke data-estimeret middelværdi."* Engelsk fallback
  ("Centerline manually specified ...") når `language = "en"`.

  Default-PDFs uden custom `cl` rendres uændret -- caveat-blokken er
  betinget renderet. Lukker production-readiness review item 3.3.

* **`attr(bfh_qic_result$summary, "cl_user_supplied")` er ny stable
  attribute** (logical scalar) som downstream-konsumenter (PDF-template,
  biSPCharts UI, analyse-tekst) kan læse uden at introspektere `config`-slotten.
  Brug `isTRUE(attr(result$summary, "cl_user_supplied"))` for safe-check.
  Attributtens placering bevarer column-iteration patterns (`lapply(summary, ...)`,
  `dplyr::summarise(across(...))`) -- ingen ny kolonne tilføjes.

* **`bfh_extract_spc_stats(result)$cl_user_supplied`** eksponerer flaget for
  power-users der querier SPC-stats via public API, parallelt med
  eksisterende `is_run_chart`-felt.

## Interne ændringer

* `inst/i18n/{da,en}.yaml`: ny noegle `labels.caveats.cl_user_supplied`.
* `inst/templates/typst/bfh-template/bfh-template.typ`: nye parametre
  `cl_user_supplied: false` + `cl_caveat_text: none` med betinget caveat-blok
  under SPC-tabellen.
* `R/utils_typst.R::build_typst_content()`: emitter de nye Typst-parametre
  naar spc_stats indikerer brugersat centerlinje.
* `R/utils_export_helpers.R::compose_typst_document()`: resolver caveat-tekst
  server-side via i18n baseret paa `language`-config.
* **OpenSpec spec-cleanup** (uden API-impact):
  - `caching-system`: refit til at dokumentere de fire active package-private
    caches (`font`, `marquee_style`, `quarto`, `i18n`) og `bfh_reset_caches()`-
    helperen. Fjernet stale references til `configure_grob_cache()` /
    `clear_grob_cache()` (begge fjernet i v0.5.0).
  - `code-organization` requirement #7 (3-layer decomposition): fjernet
    arbitraer 220-line cap. Strukturelle krav (named helpers,
    isolation-testbarhed, cleanup-closures) bevaret. Fil-stoerrelse er ej
    laengere et review-kriterium.
  - `public-api` ↔ `spc-analysis-api`: praeciseret ejerskab. `public-api`
    ejer API-kontrakter (signaturer, return-types, attribute-existence);
    `spc-analysis-api` ejer signal-detection-semantik (Anhoej rules,
    fallback-narrative dispatch, threshold semantics). Cross-references via
    prose -- ingen indholds-duplication.
  - Implementerer OpenSpec change `cleanup-stale-spec-issues`.

## Bug fixes

* **PDF-eksport rendrer succesfuldt uden hospitals-logo, når companion-pakker
  ikke har injiceret assets.** Tidligere fejlede `bfh_export_pdf()` hårdt på et
  rent install fordi Typst-templaten hard-refererede til
  `images/Hospital_Maerke_RGB_A1_str.png` (proprietary BFH-asset, ikke bundlet
  i public package). Templaten har nu en `logo_path: none`-parameter; den
  forreste logo-slot rendres kun når `logo_path` er sat. R-siden auto-detekterer
  staged logos via `.detect_packaged_logo()` parallelt med eksisterende
  `.detect_packaged_fonts()`-mønster, så companion-pakker (BFHchartsAssets)
  fortsat får hospital-branding uden caller-side ændringer. Implementerer
  OpenSpec change `add-conditional-template-image`.

  Migration:
  - **Eksisterende callers uden inject_assets:** ingen ændring nødvendig --
    PDF rendrer nu uden fejl (uden logo). Tidligere fejlede compile.
  - **Eksisterende callers med inject_assets:** ingen ændring nødvendig --
    auto-detect henter staged logo. Layout uændret.
  - **Avancerede callers** kan supply `metadata$logo_path = "/path/to/custom.png"`
    for at overstyre auto-detect.

## Yderligere interne aendringer (logo-conditional)

* `bfh-template.typ` template-signature gains optional `logo_path: none`
  parameter. Foreground `place(image(...))` block er nu konditional.
* `R/utils_typst.R`: ny helper `.detect_packaged_logo()` + `.stage_packaged_template_dir()`.
  `build_typst_content()` emit `logo_path` i Typst-params-blokken når sat.
* `R/utils_export_helpers.R::compose_typst_document()` re-ordret: stager template
  + kører inject_assets FØR `bfh_create_typst_document()` skrives, så logo
  auto-detect kan se injicerede filer.
* `R/utils_metadata.R::bfh_merge_metadata()` accepterer + viderefører `logo_path`.
* `validate_bfh_export_pdf_inputs()`: `logo_path` whitelist + scalar character-validering.

# BFHcharts 0.15.0

## Breaking changes

* **`summary$løbelaengde_signal` erstattet af tre nye signal-kolonner.**
  qicharts2's `runs.signal` er det KOMBINEREDE Anhøj-signal (runs ELLER
  crossings violation, beregnet i `crsignal()`). Det legacy navn
  `løbelaengde_signal` blev læst som "kun runs", hvilket fik klinikere til
  at fejlattribuere crossings-only-mønstre som niveauskift. Migration:

  ```r
  # FOR (BFHcharts <= 0.14.x)
  if (result$summary$løbelaengde_signal[phase]) { ... }

  # EFTER (BFHcharts >= 0.15.0)
  if (isTRUE(result$summary$anhoej_signal[phase])) { ... }     # samme kombinerede flag
  if (isTRUE(result$summary$runs_signal[phase])) { ... }       # kun runs-violation
  if (isTRUE(result$summary$crossings_signal[phase])) { ... }  # kun crossings-violation
  ```

  De nye `runs_signal` og `crossings_signal` er pure derivationer fra
  eksisterende `laengste_loeb`/`laengste_loeb_max` og `antal_kryds`/`antal_kryds_min`
  per fase. NA inheriterer fra inputs (degenererede faser hvor qicharts2
  returnerer NA). biSPCharts #468 sporer downstream-migration.

* **`summary` numeriske kolonner returnerer raw qicharts2-precision** (ej
  længere afrundet til 1-2 decimaler). Påvirker `centerlinje`,
  `nedre_kontrolgraense`, `oevre_kontrolgraense`, `nedre_kontrolgraense_min/max`,
  `oevre_kontrolgraense_min/max`, `nedre_kontrolgraense_95`,
  `oevre_kontrolgraense_95`. Display-formattere (`format_target_value()`,
  `format_centerline_for_details()`) afrunder selv ved string-emission, så
  PDF-output forbliver byte-identisk. Logic-konsumere (target-sammenligning,
  statistisk videreanalyse) får nu korrekte resultater nær afrundings-
  grænser. Migration: konsumenter der bruger `summary$centerlinje` direkte
  i UI-visning skal anvende egen `round()` ved display. biSPCharts #470 har
  allerede migreret væk fra `summary$centerlinje` til `qic_data$cl` for
  logisk vurdering.

## Bug fixes

* Crossings-only data trigger nu `summary$crossings_signal = TRUE` eksplicit
  (ej længere skjult under det misvisende `løbelaengde_signal`-navn).
  Regression-test tilføjet for 4 alternerende fase-blokke a 5 punkter.

## Internal changes

* ADR-002 addendum dokumenterer signal-rename + raw-precision-skift.
* Konstans-detektion (`kontrolgraenser_konstante`) bevarer `decimal_places + 2`-
  tolerance for at absorbere floating-point drift fra qicharts2 -- detektions-
  logikken roundes, men de lagrede værdier forbliver raw.

# BFHcharts 0.14.5

## Internal changes

* Decompose `add_right_labels_marquee()` (`R/utils_add_right_labels_marquee.R`,
  510-line god function with 11 distinct responsibilities) into
  orchestrator (~217 lines) plus 5 named private helpers:
  `.resolve_label_geometry()`, `.acquire_device_for_measurement()`,
  `.measure_label_heights()`, `.detect_x_axis_type()`,
  `.build_label_data()`. Pure refactor; visual regression baselines
  unchanged (zero `.new.svg` files produced by full pre-push test run).
  `.acquire_device_for_measurement()` returns a `cleanup_fn` closure
  that the orchestrator binds via `on.exit(..., add = TRUE)` for
  unwind-safe device cleanup. Implements OpenSpec change
  `decompose-marquee-labels`.

* Decompose `build_fallback_analysis()` (`R/spc_analysis.R`, ~210-line
  boolean cascade) into orchestrator (~98 lines) plus 5 named pure
  helpers: `.detect_signal_flags()`, `.allocate_text_budget()`,
  `.select_stability_key()`, `.select_action_key()`,
  `.evaluate_target_arm()`. Pure refactor; fallback narrative output
  unchanged. Adding a new cascade arm now becomes a single new test
  row + one new key + one new i18n string instead of a multi-place edit.
  Implements OpenSpec change `decompose-fallback-analysis`.

# BFHcharts 0.14.4

## Internal changes

* Extract Danish text-formatting helpers (`pluralize_da()`,
  `ensure_within_max()`, `substitute_placeholders()`, `pick_text()`,
  `pad_to_minimum()`) from `R/spc_analysis.R` into a dedicated
  `R/utils_text_da.R`. Pure relocation; no behavioral change.
  `R/spc_analysis.R` shrinks by ~130 lines. Implements OpenSpec change
  `extract-utils-text-da`.

# BFHcharts 0.14.3

## Breaking changes

* **`print.summary` parameter fully removed from `bfh_qic()`.** The
  parameter was deprecated in v0.11.0: calling with `print.summary = TRUE`
  raised an error, while `print.summary = FALSE` was silently accepted.
  Four versions later the deprecation cycle is complete: the parameter
  is now removed from the function signature and from all internal
  helpers (`validate_bfh_qic_inputs()`, `build_bfh_qic_return()`).

  Migration: drop the `print.summary` argument from your call. The
  default `bfh_qic_result` object exposes the SPC summary directly as
  `result$summary`, and `return.data = TRUE` returns the raw qic data
  with summary fields available on `result$qic_summary`.

* **Option name `bfhcharts.quarto_path` renamed to
  `BFHcharts.quarto_path`** (TitleCase namespace consistent with the rest
  of the package). Option name `spc.debug.label_placement` similarly
  renamed to `BFHcharts.debug.label_placement`. The old names are no
  longer recognised. Migration: replace the legacy name in any
  `options()` call. Both options were internal/dev-only with no
  user-facing documentation.

## Internal changes

* Add named constants for all five package options in `R/globals.R`:
  `BFHCHARTS_OPT_QUARTO_PATH`, `BFHCHARTS_OPT_SUPPRESS_UNIT_AUTO_DETECT`,
  `BFHCHARTS_OPT_DEBUG_LABEL_PLACEMENT` (joining existing
  `BFHCHARTS_OPT_AUDIT_LOG` and `BFHCHARTS_OPT_ALLOW_GLOBALENV_INJECT`).
  All `getOption()` call sites updated to reference the constants for
  grep-ability and single-source-of-truth.

* Extract `resolve_label_size()` helper in `R/utils_label_helpers.R`.
  Three sites (`apply_spc_labels_to_export()`,
  `build_bfh_qic_config()`, `recalculate_labels_for_export()`) had
  identical viewport-size fallback logic; now share the helper.

* Remove unused `safe_min()` helper from `R/utils_helpers.R` (no callers).
* Drop stale 33-line USAGE example comment block from
  `R/utils_npc_mapping.R` (per-function roxygen documents the API).
* Remove orphan `# message(sprintf(` line at `R/utils_panel_measurement.R:170`
  (refactor leftover).
* Replace magic literal `6` with `PDF_LABEL_SIZE` constant at
  `R/utils_add_right_labels_marquee.R:149` and `R/utils_label_helpers.R:254`
  (constant was already defined in `R/globals.R:83`).
* Add `Y_AXIS_UNITS` constant in `R/chart_types.R`; replace 3 hardcoded
  duplicates of `c("count", "percent", "rate", "time")` with the
  constant. Adding a new unit now requires a single edit.
* Drop stale TODO from `tests/testthat/test-bfh_qic_edge_cases.R:193`
  (explicit empty-data check already lives at
  `R/utils_bfh_qic_helpers.R:306`).
* Update `CLAUDE.md` to drop `CHART_TYPES_DA` from the documented
  internal API list (the constant does not exist in the codebase).
* Strengthen `tests/testthat/test-public-api-contract.R` with a
  regression test asserting `print.summary` does not appear in
  `bfh_qic()` formals or in `man/bfh_qic.Rd`.

# BFHcharts 0.14.2

## Breaking changes

* **`inject_assets` from `.GlobalEnv` now errors instead of warning (H1).**
  `.validate_inject_assets()` previously warned when the supplied function
  originated from `.GlobalEnv` or a direct child environment. It now
  hard-errors unless `options(BFHcharts.allow_globalenv_inject = TRUE)` is set.
  Accepted namespaces are `BFHcharts` and `biSPCharts` by default; companion
  packages can pass a custom `allowed_namespaces` vector to the internal helper.
  This prevents privilege-escalation in Shiny deployments where a reactive
  closure can silently bind a `.GlobalEnv` function to `inject_assets`.

  Migration: move your `inject_assets` callback into a version-controlled
  package namespace (e.g. `MyOrgAssets::inject_bfh_assets`), or set
  `options(BFHcharts.allow_globalenv_inject = TRUE)` in development sessions
  where interactive closures are intentional.

## Nye features

* **`bfh_export_pdf()` gains `restrict_template = FALSE` parameter (H2).**
  When set to `TRUE`, any non-`NULL` `template_path` is rejected with an
  error before compilation. Use in deployment contexts where only the packaged
  BFHcharts template should be compiled, preventing custom-template injection
  from misconfigured pipelines. Default `FALSE` preserves backward compatibility.

## Bug fixes

* **M1: Flag-allowlist in `.safe_system2_capture()`.** Replaced the
  `startsWith(arg, "--")` heuristic with an explicit `KNOWN_TYPST_FLAGS`
  allowlist (`c("--ignore-system-fonts", "--font-path")`). Any double-dash
  argument not in the allowlist (e.g. a crafted `--rce` value) is now
  `shQuote()`-d on POSIX systems, preventing command injection via
  flag-shaped strings.

* **M2: Double-quote rejected in output paths.** `"` was missing from
  `SHELL_METACHARS_OUTPUT_PATH`. It is now blocked by `validate_export_path()`.
  Test: `output = 'a".pdf'` is rejected with "disallowed".

* **M3: Packaged-font fallback after invalid `font_path` (silent fallback fixed).**
  When a user-supplied `font_path` fails directory validation, the compiler
  previously fell through to system fonts even with `--ignore-system-fonts` set.
  A new `.detect_packaged_fonts()` helper is now called in both the NULL-input
  branch and the validation-fail-reset branch, ensuring packaged fonts are
  always detected when available.

* **M18: `.is_windows()` helper extracted for cross-platform test coverage.**
  `.Platform$OS.type == "windows"` check moved into a testable `.is_windows()`
  helper. Tests now use `local_mocked_bindings(.is_windows = ...)` to verify
  both the Windows early-return path (no `shQuote`) and the POSIX quoting path
  without requiring a real Windows OS.

## Internal changes

* Translate Danish error/warning messages to English across the package
  to match standard R-package convention. Affected files:
  `fct_add_spc_labels.R`, `utils_bfh_qic_helpers.R`, `spc_analysis.R`,
  `utils_npc_mapping.R`, `utils_label_helpers.R`,
  `utils_label_formatting.R`.
* Add `call. = FALSE` to public-API-boundary `stop()` calls so the
  internal call stack is not leaked to the user.
* Add co-location regression test in `tests/testthat/test-dep-guards.R`
  asserting every `R/*.R` file referencing `BFHtheme::` also calls
  `.ensure_bfhtheme()`. Catches future drift where new BFHtheme call
  sites are added without the corresponding guard.

# BFHcharts 0.14.1

## Bug fixes

* `escape_typst_string()` over-escapede `<` og `>` med backslash i Typst
  string-literal-kontekst. Da `\<` og `\>` ikke er valide Typst-string-escapes,
  bevarede Typst backslashen literalt i PDF-output (fx `p \< 0.05` i stedet
  for `p < 0.05`). Paavirkede metadatafelter `hospital`, `department`,
  `details`, `author` og `data_definition`. Fixet ved at lade `<` og `>`
  passere uændret - de er almindelige tegn i Typst string literals og kan
  ikke terminere strengen.

# BFHcharts 0.14.0

## Nye features

* Eksport af `bfh_create_typst_document()` til public API. Funktionen var
  tidligere kun tilgaengelig via `getFromNamespace()`. Downstream-pakker
  (fx biSPCharts) kan nu kalde den direkte uden at bryde CRAN-konventioner.
  `bfh_extract_spc_stats()` og `bfh_merge_metadata()` var allerede
  eksporteret og er uaendrede. Relateret: biSPCharts #423.

# BFHcharts 0.13.0

## Breaking changes

* **`bfh_generate_analysis(use_ai = TRUE)` kræver nu `data_consent = "explicit"`.**
  Alle kald med `use_ai = TRUE` uden eksplicit samtykke fejler nu med en
  informativ fejlbesked der refererer GDPR/HIPAA-konteksten. Formålet er at
  sikre at klinikdata ikke sendes til et eksternt AI-system uden at kalderen
  eksplicit erkender det.

  Migration:
  ```r
  # Før:
  bfh_generate_analysis(result, use_ai = TRUE)

  # Efter:
  bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit")
  ```

  `use_ai = FALSE` (standard) er uændret og påvirkes ikke.

* **`bfh_generate_analysis()`: `use_rag` defaulter nu til `FALSE`.**
  Tidligere var `use_rag = TRUE` hardcoded i kaldet til
  `BFHllm::bfhllm_spc_suggestion()`. Det er nu ændret til `FALSE` som
  privacy-bevarende standard. RAG (retrieval-augmented generation) lagrer
  forespørgselsdata i et vektor-store — en separat compliance-overvejelse fra
  det engangs-LLM-kald. Kald med `use_rag = TRUE` bevarer den tidligere adfærd.

  Migration for kald der ønsker RAG:
  ```r
  bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit",
                        use_rag = TRUE)
  ```

* **PDF asset-kontrakt dokumenteret og håndhævet (ADR-001, Option A).** Den
  publicerede pakke garanterer nu eksplicit at `bfh_export_pdf()` producerer en
  gyldig PDF med system-tilgængelige fallback-fonts (Roboto, Arial, Helvetica,
  sans-serif) — uden at kræve companion-pakken `BFHchartsAssets` eller
  proprietære Mari-fonts. Font-chain i production-template er uændret
  `("Mari", "Roboto", "Arial", "Helvetica", "sans-serif")`; Mari er stadig
  første prioritet når companion-pakken injecter assets via `inject_assets`.
  Brugere der allerede bruger `inject_assets = BFHchartsAssets::inject_bfh_assets`
  er upåvirkede. Brugere der ikke bruger companion-pakken får nu konsistent
  fallback-rendering i stedet for runtime-fejl ved manglende Mari. (#TBD)

## Nye features

* **`bfh_compile_typst()` auto-detekterer staged fonts/** Funktionen registrerer
  automatisk en `fonts/`-undermappe i det stagede template-tempdir og videregiver
  den som `--font-path` til Typst-compileren — forudsat at `font_path`-argumentet
  ikke er sat eksplicit. Companion-injectede fonts (fx Mari via `inject_assets`)
  opdages dermed uden at kalleren behøver at angive `font_path`. Eksplicit
  `font_path`-argument har stadig forrang. (#TBD)

* **Runtime-guard for `inject_assets`:** `bfh_export_pdf()` og
  `bfh_create_export_session()` advarer nu hvis `inject_assets`-funktionen
  stammer fra `.GlobalEnv` eller et direkte child-environment. Dette er et
  signal om mulig utilsigtet eksponering (fx Shiny-binding af en
  top-level-funktion til parameteren). Advarslen kan undertrykkes med
  `options(BFHcharts.allow_globalenv_inject = TRUE)` i udviklingsflows.

* **Struktureret AI-egress audit-log:** Erstattet `message("[BFHcharts/AI] ...")`
  med `.emit_audit_event()` der producerer et struktureret JSON-objekt. Skrives
  til `getOption("BFHcharts.audit_log")` som JSON-line (append) hvis optionen
  er sat; ellers via `message()` med prefix `[BFHcharts/audit]`. Indeholder:
  timestamp, event-type, package, target-funktion, felter sendt, context-nøgler,
  `use_rag`-værdi, hostname og bruger.

* **`bfh_generate_analysis()`: ny `data_consent`-parameter** (se Breaking
  changes) og ny `use_rag`-parameter (se Breaking changes).

* **Opdateret security-dokumentation:** `@section Security:` i
  `bfh_export_pdf()` og `bfh_create_export_session()` udvider nu med
  eksplicitte acceptable/uacceptable kilder for `inject_assets`, inkl. RCE-
  advarsel. README-sektionen "Branding for Organizational Deployments" har fået
  en prominent security-note.

## Bug fixes

* **`result$summary$sigma_signal` rapporterer nu korrekt `TRUE` for en fase
  når *et vilkårligt punkt* i fasen er et outlier.** Tidligere tog
  `format_qic_summary()` `sigma.signal`-værdien fra den *første* rad i fasen
  frem for at aggregere med `any()` over alle rader. For faser hvor det
  første punkt ikke er et outlier men et eller flere efterfølgende er det,
  ville `sigma_signal` fejlagtigt vise `FALSE`. `runs.signal` var allerede
  korrekt aggregeret med `any()` — `sigma.signal` er nu tilsvarende rettet.
  Downstream-pakker (fx biSPCharts) der viser `result$summary` eller auto-
  genereret analysetekst baseret på `sigma_signal` vil se rettede værdier.
  (OpenSpec 2026-05-01-verify-anhoej-summary-vs-qic-data-consistency, ADR-002)

## Interne ændringer

* **ADR-002 oprettet** (`inst/adr/ADR-002-anhoej-summary-source.md`):
  dokumenterer Anhoej-statistik-proveniens, verifikation af konsistens
  mellem `result$summary` og `result$qic_data`, og baggrund for rettelsen
  af `sigma.signal`-aggregeringen.
* **22 nye konsistenstests** (`tests/testthat/test-summary-anhoej-consistency.R`):
  asserterer at hvert Anhoej-felt i `result$summary` matcher aggregeringen
  af det tilsvarende felt i `result$qic_data` per fase — for alle chart-typer
  og edge cases (enkelt fase, fase med faa punkter, exclude).

# BFHcharts 0.12.2

## Interne ændringer

* **Test-isolation og graphics-device cleanup.** `tests/testthat/setup.R`
  åbner nu en persistent PDF-device via `teardown_env()` så `bfh_qic()`'s
  interne `ggplot_gtable()`-kald aldrig trigger R's default `Rplots.pdf`.
  Ny `helper-graphics.R` eksponerer `with_clean_graphics()` wrapper til
  device-tunge tests. Print/plot-tests i `test-bfh_qic_result.R` bruger
  wrapperen eksplicit.

* **Withr-konvertering af test-cleanup.** `if (file.exists(x)) unlink(x)`
  anti-mønsteret erstattet med `withr::local_tempfile()` i
  `test-export_pdf.R` (6 steder), `test-security-export-pdf.R` (4 steder),
  `test-export_png.R` (4 steder), `test-export-session.R` (1 sted).
  Cleanup sker nu garanteret selv ved test-fejl.

* **Shell-injection test assertion.** `test-quarto-isolation.R` asserter nu
  eksplicit at ingen `output*`-mappe oprettes ved shell-injection-tests
  (validering sker før `dir.create()`).

* **`dev/clean_workdir.R`.** Nyt R-script der idempotent fjerner kendte
  build- og test-artefakter: `BFHcharts.Rcheck/`, tarballs, `doc/`, `Meta/`,
  `Rplots.pdf` (alle niveauer), `tests/testthat/_problems/`.

* **`.gitignore` og `.Rbuildignore` udvidet** med patterns for
  `tests/testthat/_problems/` og `tests/testthat/output; rm -rf `.

* **CI-render-pipeline styrket** (`strengthen-ci-render-pipeline`):
  - Quarto installeres nu i `R-CMD-check.yaml` (pre-release channel, Typst 0.13+
    krævet for `--ignore-system-fonts`). Render-afhængige tests der hidtil
    skippede med `skip_if_no_quarto()` eksekveres nu i hovedjobbet.
  - `pdf-smoke.yaml` anvender nu production-template
    (`inst/templates/typst/bfh-template/bfh-template.typ`) fremfor
    CI-only test-template. `continue-on-error: true` på render-step
    midlertidigt til `fix-pdf-template-asset-contract` er merget.
  - Ny workflow `git-archive-render.yaml`: installerer pakken fra
    `git archive HEAD`-output og renderer smoke-tests. Opdager
    render-afhængigheder af untracked filer tidligt.
  - `tests/smoke/render_smoke.R` understøtter nu
    `BFHCHARTS_SMOKE_USE_PRODUCTION_TEMPLATE`-env-var til eksplicit
    production-template-mode på CI.
  - `CONTRIBUTING.md` oprettet med CI Pipeline-sektion, beskrivelse af
    PR-blocking jobs og manuelt trin til branch protection-konfiguration
    i GitHub UI.
  - README: tilføjet `pdf-smoke`-statusbadge.

* **Label-placement monolith opdelt i 3-lags arkitektur.**
  `place_two_labels_npc()` (520L) er reduceret til en ~90L orkestrator
  ved at ekstrahere tre rene hjælpefunktioner:
  `.validate_placement_inputs()`, `.resolve_placement_config()` og
  `.compute_placement_strategy()`. Den rene strategi-funktion har ingen
  device-kald og kan testes uden et grafik-device.

* **Deterministisk device-håndtering i `add_right_labels_marquee()`.**
  Tre separate `on.exit`-blokke for viewport-device er konsolideret til
  én. Redundant normal-path cleanup (L613-619) fjernet.

* **`with_temporary_device()` tilføjet** (`utils_panel_measurement.R`):
  ren wrapper der åbner Cairo PDF-device, kører kode og lukker
  deterministisk via `on.exit` uanset fejl.

* **`clamp01()` slettet** — aldrig brugt i produktionskode.

* **`height_safety_margin` fallback** alignet med konfigurationsværdi
  (begge nu 1.0, ingen ekstra margin ved korrekte panel-maalinger).

* 27 nye kontrakt-tests dækker placement-strategi-laget isoleret
  (ingen device-krav). Se `tests/testthat/test-placement-strategy-contract.R`.

* **Output-stier med spaces/parens/brackets virker nu også i praksis.**
  v0.12.0 relaxede path-validatoren til at tillade hospital-typiske filnavne
  (`rapport (final).pdf`, `Q1 [2026].pdf`, `Indikator & resultat.pdf`), men
  `bfh_compile_typst()` sendte stadig stier ukvotered til `system2()`.
  `system2(stdout = TRUE, stderr = TRUE)` invoker `/bin/sh` på macOS/Linux
  for stream-capture; parens og brackets i argumenter udløste
  "syntax error near unexpected token '('" og PDF'en blev aldrig skabt.
  Rettes ved ny intern `.safe_system2_capture()`-wrapper der anvender
  `shQuote()` på path-argumenter (men ikke flag-argumenter som
  `--ignore-system-fonts`). `$`-tegn i filnavne (fx `data_$HOME_test.pdf`)
  behandles nu som literals; `shQuote()` single-quote-wrapper forhindrer
  shell-variable-expansion. Verificeret på macOS med live Quarto/Typst.
  Windows-adfærd for UNC-stier og paths >260 tegn er ikke empirisk testet
  i nuværende CI-setup.

* **ADR-001 oprettet** (`inst/adr/ADR-001-pdf-asset-policy.md`): dokumenterer
  valg af Option A (open-fallback default) og konsekvenser for biSPCharts-deploy.
* **CI smoke-test udvidet**: `pdf-smoke.yaml` kører nu også
  `test-production-template-renders.R` via `BFHCHARTS_TEST_RENDER=true` for at
  validere production-template på hver PR. Testen skipper automatisk når
  `images/`-mappen mangler (known gap, se ADR-001).
* **README**: ny sektion "PDF Asset Policy" dokumenterer pakke-kontrakten,
  companion-mønsteret og en verificeringskommando.

* Ny `R/utils_audit.R` med `.emit_audit_event()` og base-R JSON-serialisering
  (ingen jsonlite-afhængighed).

# BFHcharts 0.12.1

## Bug fixes

* **`svglite` flyttet fra `Suggests` til `Imports`.** `bfh_export_pdf()`
  kalder `svglite::svglite()` i `export_chart_svg()` for ggplot→SVG-
  konvertering før Typst-rendering, men pakken var kun erklæret som
  `Suggests`. Konsekvens: downstream-pakker (fx `biSPCharts`) der bruger
  `bfh_export_pdf()` fik ikke `svglite` installeret automatisk via
  `pak`/`renv` deployments. På Posit Connect Cloud (eller andre
  minimal-deps environments) fejlede PDF-eksport med
  `The package "svglite" is required to save as SVG`. PNG-eksport
  (`bfh_export_png`) var upåvirket fordi `grDevices::png()` ej kræver
  svglite. (#268)

# BFHcharts 0.12.0

## Breaking changes

* **PDF-eksport defaulter nu til strict-baseline-mode.**
  `bfh_export_pdf()` og `bfh_create_export_session()` accepterer en ny
  parameter `strict_baseline` (default `TRUE`). I strict-mode afvises
  eksport hvor `config$freeze < MIN_BASELINE_N` (8) eller hvor en fase
  indeholder færre end 8 punkter — fejlen opstår FØR Quarto kaldes og
  refererer eksplicit `strict_baseline = FALSE` som dokumenteret opt-out.
  Begrundelse: PDF'er fra eksport-pipelinen lander på QI-leadership-borde
  hvor R-warnings aldrig når en menneskelig læser. Anhøj & Olesen (2014)
  anbefaler ≥8 baseline-punkter for pålidelig run/crossing-detection.
  `bfh_qic()` selv bevarer warning-only-adfærd (interaktiv default —
  analytiker er til stede). Migration: existing batch-pipelines med korte
  baselines skal enten passere `strict_baseline = FALSE` per kald eller via
  `bfh_create_export_session(strict_baseline = FALSE)`. Per-kald værdi
  overrider session-værdi. (#4 / Codex 2026-04-30)

* **`bfh_qic()` håndhæver strengere input-validering på `part`, `freeze`,
  `exclude` og `metadata$target`.** Kald der tidligere passerede
  validatoren men producerede kryptiske downstream-fejl afvises nu med
  klare beskeder før qicharts2 invokeres:
  - `part` skal være positive heltal, strengt voksende, unikke, i
    `[2, nrow(data)]`. Tidligere accepteredes `3.5`, `c(12, 12)`, `c(12, 6)`
    silently. Hver overtrædelses-type giver sin egen besked
    ("integer", "unique", "increasing").
  - `freeze` skal være ét enkelt heltal i `[1, nrow(data) - 1]`.
    Non-integer afvises med "integer".
  - `exclude` skal være positive heltal, unikke, i `[1, nrow(data)]`
    (sortering ikke krævet).
  - `metadata$target` skal være NULL, ét finit numerisk eller én
    character-streng. Multi-element vektorer, `Inf`, `NaN`, `NA`
    afvises.
  - Tomt `data.frame()` afvises med klar "empty"-besked før qicharts2.
  - Non-numerisk y-kolonne (character/factor) afvises før qicharts2.

  Migration: kontroller at integer-positioner er hele tal (`5L` ikke `5.5`),
  at `part` er sorteret unique, og at `metadata$target` er en enkelt
  scalar-værdi. (#3 / Codex 2026-04-30)

## Forbedringer

* **BFHtheme-afhængighed fanges nu ved load + første brug.** BFHcharts kalder
  `BFHtheme::` funktioner på 17 sites (theme, colors, scale_x/y); manglende
  eller for-gammel BFHtheme producerede tidligere kryptiske
  `could not find function "bfh_cols"`-fejl midt i plot-rendering. Nu:
  - `.onAttach()` udsender en `packageStartupMessage()` ved `library(BFHcharts)`
    hvis BFHtheme er fraværende eller `< 0.5.0`.
  - Ny intern `.ensure_bfhtheme(min_version = "0.5.0")` kaldes ved entry
    af alle 13 funktioner der bruger `BFHtheme::`. Resultatet caches i
    package-private env så kun første kald per session betaler
    `requireNamespace`-omkostningen.
  - Fejlbeskeden indeholder nu version-kravet og den installerede version
    samt et `remotes::install_github()`-install-hint.
  Ingen public-API ændring; korrekt-installerede brugere ser intet nyt.
  (Codex 2026-04-30 #2)

* **Output-stier accepterer nu parentheses, brackets, braces, ampersand,
  dollar og single-quote.** Hospital-filnavne som `rapport (final).pdf`,
  `Q1 [2026].pdf` og `Indikator & resultat.pdf` blev tidligere afvist af
  `validate_export_path()`. Codex code review 2026-04-30 (#10) flaggede
  rejection som over-restriktiv. Empirisk verifikation viste dog at R's
  `system2(... stdout = TRUE, stderr = TRUE)` (som BFHcharts bruger til at
  capture Quarto-output) faktisk invokerer shell — så shell-pipeline-tegn
  (`;`, `|`, `<`, `>`, backtick) **forbliver afvist** for at forhindre
  command-injection. NUL/LF/CR og `..`-traversal afvises også fortsat.
  Binary-stier (Quarto-binary etc.) forbliver strikt validerede via
  `.check_metachars_binary()`. (#8 / Codex 2026-04-30 + advisor-justering)

## Bug fixes

* **`language = "en"` producerer nu korrekt engelsk talnotation på y-aksen.**
  Pakkens dokumenterede engelsk-sprog-support producerede tidligere
  `1.000,5` (dansk format) selvom labels var oversat — formelt forkert
  engelsk talnotation der i grænsetilfælde kunne misforstås (engelsk
  `1.000` betyder ét, ikke ét tusind). Fix: `format_count()`-dispatcher
  router count-formatering til `format_count_english()` (decimal `.`,
  thousand `,`) for `language = "en"` og bevarer `format_count_danish()`
  for `language = "da"`. Percent-formatering bruger nu locale-specifikke
  separatorer og suffix (`12,5 %` for da vs `12.5%` for en).
  X-akse-datoer bruger best-effort locale-swap af LC_TIME for at producere
  engelske månedsforkortelser (`Jan`, `Feb` ...) hhv. danske (`jan`,
  `feb` ...) — afhængig af platformens locale-tilgængelighed. Default
  `language = "da"` bevarer eksisterende output for danske brugere.
  (#6 / Codex 2026-04-30)

* **Auto-analyse respekterer nu chart-target uden duplikering i metadata.**
  `bfh_build_analysis_context()` læste tidligere kun target fra
  `metadata$target` og ignorerede `x$config$target_text` /
  `x$config$target_value`. Konsekvens: PDF-eksport med `auto_analysis = TRUE`
  viste target-linjen på chartet men producerede analysetekst uden
  målfortolkning ("centerlinjen ligger på 91 %") når caller ikke duplikerede
  target i metadata. Fix: ny intern helper `.resolve_analysis_target()`
  implementerer fallback-kæden `metadata$target` →
  `config$target_text` → `config$target_value`. Eksisterende kald der
  duplikerer target i metadata får uændret adfærd; kald uden duplikering får
  nu korrekt målbaseret analyse. (#1 / Codex 2026-04-30)

## Interne ændringer

* **`place_two_labels_npc()` collision-cascade dekomponeret til navngivne helpers.**
  Den 565-linjers funktion havde en NIVEAU 1/2/3-collision-resolution-blok
  med uforklaret magic numbers (0.5/0.3/0.15) og dyb nesting. Refactoreret
  til 3 pure functions + 1 helper:
  - `.try_niveau_1_gap_reduction()` — gap-reduktionsforsøg
  - `.try_niveau_2_flip()` — label-flip i 3 strategier (A, B, BEGGE)
  - `.apply_niveau_3_shelf()` — sidste-udvej shelf placement
  - `.verify_line_gap_npc()` — line-gap predicate
  Magic numbers navngivet i globals.R (`LABEL_PLACEMENT_GAP_REDUCTION_FACTORS`,
  `LABEL_PLACEMENT_TIGHT_LINES_THRESHOLD_FACTOR`,
  `LABEL_PLACEMENT_COINCIDENT_THRESHOLD_FACTOR`,
  `LABEL_PLACEMENT_SHELF_CENTER_THRESHOLD`).
  Hver helper er individuelt testbar; ny test-suite `test-niveau-resolvers.R`
  pinner kontrakt med 14 tests. Refactoren er **byte-equivalent**: visual
  output og warnings er uændrede (verificeret ved direkte sammenligning af
  vdiffr `.new.svg`-filer mellem inline- og helper-version).
  Legacy NPC-only API-signatur (`yA_npc=`, `yB_npc=`, `label_height_npc=`)
  bevaret uændret for biSPCharts-kompatibilitet.
  (Codex 2026-04-30 #1)

* **R/*.R-kildefiler er nu ASCII-rene.** Alle 14 filer med non-ASCII bytes
  (124 forekomster) er konverteret: em-dash `—` → `--`, operator-symboler
  `≥`/`≤` → `>=`/`<=`, danske bogstaver translittereret (æ/ø/å → ae/oe/aa)
  i implementations-kommentarer, og brugervendte streng-literaler (warning-
  beskeder) bruger nu `æ`-escapes så bytes på disk er ASCII men runtime-
  output forbliver dansk UTF-8. Ny test `tests/testthat/test-source-ascii.R`
  håndhæver politikken og rapporterer file:line:char ved fremtidige
  overtrædelser. Begrundelse: `R CMD check --as-cran` advarer om non-ASCII
  i R-kilder, blokerer warning-clean releases og r-universe-distribution.
  Ingen public-API ændring; ingen semantisk ændring.
  (Codex 2026-04-30 #2)

# BFHcharts 0.11.1

## Bug fixes

* **Klinisk korrekthedsfejl i auto-analyse for percent-indikatorer rettet.**
  `bfh_generate_analysis()` med `auto_analysis = TRUE` producerede forkert
  analysetekst ("målet er endnu ikke nået") for p-charts, selvom centerlinjen
  reelt opfyldte et procent-mål. Fejlen opstod fordi `parse_target_input()`
  fjernede `%`-suffixet og returnerede den rå numeriske værdi (fx `90`), mens
  centerlinjerne for p-charts er på proportionsskala (fx `0.91`). Sammenligningen
  `0.91 >= 90` evaluerede til `FALSE`. Fix: `bfh_build_analysis_context()` kalder
  nu `.normalize_percent_target()` og dividerer target-værdien med 100 når
  `y_axis_unit == "percent"` og target-displayet indeholder `%` eller
  `target_value > 1`. `target_display` bevares uændret (fx `">= 90%"`) i
  den genererede tekst. Kald med `auto_analysis = FALSE` (default) er
  upåvirkede. (#fix-percent-target-scale-in-analysis)

## Dokumentation

* **`bfh_qic()` `print.summary`-dokumentation afspejler nu v0.11.0-fjernelsen.**
  `@param print.summary` beskrev fortsat parameteren som "deprecated, will warn",
  selvom runtime hard-errorer siden v0.11.0. Dokumentationen er opdateret til
  at angive at kald med `print.summary = TRUE` giver en fejl, med
  migrationsvejledning til det moderne S3-API (`result$summary`).
  Eksempler 20-22 i `?bfh_qic` er omskrevet til at bruge `bfh_qic_result`-objektet
  direkte fremfor det fjernede `print.summary`-argument.
  (#update-print-summary-removal-docs)

* **`bfh_qic()` `@param chart_type` og `@details Chart Types` dokumenterer nu
  alle 12 validerede charttyper.** `mr` (Moving Range), `pp` (Laney-justeret
  proportioner) og `up` (Laney-justeret rater) var accepteret af validatoren men
  fraværende i public docs. Alle tre er nu dokumenteret med brugsvejledning,
  inkl. hvornår Laney-varianterne (`pp`/`up`) er relevante (store denominatorer,
  n > 1000 per subgruppe). To nye eksempler tilføjet: `pp`-chart og `mr`-chart
  parret med I-chart. (#complete-chart-type-public-docs)

* **Companion-pakke-pattern dokumenteret for proprietær branding.**
  `?bfh_export_pdf`, `?bfh_create_export_session` og `README.md` beskriver
  nu den anbefalede fremgangsmåde for organisationer, der har brug for
  proprietære fonts (Mari, Arial) og hospital-logoer i PDF-eksport:
  distribution via en privat companion R-pakke, der plugger ind via
  `inject_assets`-parameteren. Dette holder proprietære assets ude af den
  offentlige GPL-3-pakke og ud af consumer-applikationers git-historik, mens
  fuld branding understøttes på Posit Connect Cloud, RStudio Connect og Docker.
  For BFH/Region Hovedstaden-deployments implementerer `BFHchartsAssets`
  (privat repo) dette mønster. (#add-bfhcharts-assets-companion-pkg)

# BFHcharts 0.11.0

## CI

* **PDF smoke-render workflow genaktivet (Strategi B — CI-only test-template).**
  `.github/workflows/pdf-smoke.yaml.disabled` er omdobt til `pdf-smoke.yaml`
  og genaktivet som PR-blocking gate paa main og develop. Font-udfordringen
  (proprietaer Mari-font kan ikke distribueres i public repo) loeses med
  en minimal CI-only Typst-template (`tests/smoke/test-template.typ`) der
  kun bruger DejaVu Sans (installeret via apt-get paa GitHub-hosted runners).
  `render_smoke.R` detekterer `CI`-env-var og vaelger automatisk test-template
  paa CI og production bfh-template lokalt. Visuel korrekthed (Mari-fonts)
  haandteres fortsat af `vdiffr` og manuel review.
  (#enable-ci-safe-pdf-smoke-render)

## Breaking changes

* **`print.summary = TRUE` er fjernet.** Parameteren var depreceret siden
  v0.3.0 (7 minor versioner). Kald med `print.summary = TRUE` fejler nu
  med en klar fejlbesked. Migration: brug `return.data = TRUE` og tilgå
  `result$qic_summary`, eller brug det nye default `bfh_qic_result`-objekt
  og tilgå `result$summary` direkte. (#modernize-deprecations-and-deps)

## Forbedringer

* **Advarsel ved for kort baseline.** `bfh_qic()` udsender nu en advarsel
  når `freeze` eller en `part`-fase har færre end 8 observationer
  (`MIN_BASELINE_N`). Anhøj-reglerne og SPC-litteraturen kræver ca. 8+
  punkter for meningsfulde kontrolgrænser — tidligere kørte beregningen
  stille videre med statistisk usikre grænser. Ingen ændring i adfærd
  for normale serier (n ≥ 8). (#enforce-baseline-minimum-and-cl-warnings)

* **Advarsel ved custom `cl` og Anhøj-signaler.** Når `cl` angives manuelt,
  beregnes Anhøj løbe- og krydsningssignaler mod den brugerleverede
  centrallinje frem for den dataestimerede procesmiddel. `bfh_qic()` giver
  nu eksplicit advarsel om dette, så brugere er klar over fortolknings-
  forbeholdet. (#enforce-baseline-minimum-and-cl-warnings)

## Sikkerhed

* **Validering af Quarto binary-overrides (`find_quarto`).** Stier angivet
  via `options(bfhcharts.quarto_path)` og `QUARTO_PATH`-miljøvariablen
  valideres nu fuldt: shell-metakarakter-tjek (ny binary-variant der tillader
  Windows Program Files-parens), path-traversal-tjek, eksistens-tjek og
  eksekverbar-bit-tjek (Unix/macOS). Ugyldige overrides afvises med
  informativ advarsel og falder tilbage til PATH-opdag. Det gyldige override
  har nu prioritet over PATH-fund. Forhindrer potentielt vilkårlig kode-
  eksekvering på multi-bruger-systemer med forgiftet `.Rprofile`.
  (#harden-export-pipeline-security)

* **Kontroltegn strippes i `escape_typst_string()`.** `\n`, `\r`, `\t`
  erstattes med mellemrum og NUL-bytes fjernes inden eksisterende `\`, `"`,
  `<`, `>`-escapes. Metadata-felter (fx afdelingsnavn copy-pastet fra Windows
  med CRLF) producerer nu gyldigt Typst-output i stedet for syntaksfejl.
  (#harden-export-pipeline-security)

* **AI-egress audit signal.** `bfh_generate_analysis(use_ai = TRUE)` emitter
  nu en `message()` med tag `[BFHcharts/AI]` umiddelbart inden kald til
  `BFHllm::bfhllm_spc_suggestion()`. Beskeden navngiver de felter der
  transmitteres og `use_rag`-værdien, så R-level logs kan bekræfte om og
  hvornår AI-stien blev taget — et compliance/governance-krav i hospital
  deployments. Supprimér med
  `options(BFHcharts.suppress_ai_audit_message = TRUE)`. (#add-ai-egress-audit-signal)

## Bug fixes

* **Fix: outliers_recent_count row-order assumption.**
  `bfh_extract_spc_stats.bfh_qic_result()` sorterer nu `qic_data` efter `x`
  inden recency-vinduet beregnes. Tidligere antog koden at input-rækkerne
  allerede lå i kronologisk rækkefølge — omvendt eller scrambled data gav
  forkert `outliers_recent_count`. Rækkefølge er nu ubetydelig; sorted,
  reversed og tilfældigt permuteret input giver identiske resultater.
  (#fix-outliers-recent-count-row-order)

* **Fail-early validering i `bfh_generate_details()` ved ugyldige x-værdier.**
  `min()`/`max()` blev kaldt på `qic_data$x` uden forudgående tjek for
  gyldige værdier, hvilket gav `Inf`/`-Inf` i periodefeltet ved tomme
  eller alle-NA datasæt (fx cleanup-scenarier i batch-eksport). Funktionen
  stopper nu med en informativ `bfhcharts_config_error` hvis x-kolonnen er
  tom, alle-NA eller (for numerisk x) alle-Inf — inden `min`/`max` kaldes.
  Kald med gyldige data påvirkes ikke. (#validate-export-details-edge-cases)

* **Uniform truncering af compile-fejl-output til 500 tegn.** Begge fejl-
  branches i `bfh_compile_typst()` (non-zero exit og "PDF not created")
  afkorter nu output via den fælles helper `.truncate_compile_output()`.
  Tidligere lækkede "PDF not created"-branchen ukortede filsystem-stier
  i fejlbeskeder. (#harden-export-pipeline-security)

* **`shQuote()` fjernet fra argv-vector i `bfh_compile_typst()`.** `system2()`
  med `args = character_vector` bruger ikke shell; `shQuote()` tilføjede
  literale anførselstegn der brød stier med mellemrum på Unix/macOS
  (fx `~/My Files/`). Stier med mellemrum kompilerer nu korrekt.
  (#harden-export-pipeline-security)

* **Indsnævr warning-muffler scope i `.muffle_expected_warnings()`.** Det
  ubundne `"numeric"`-substring-mønster mufler nu ikke længere advarsler som
  `"NAs introduced by coercion to numeric"` (malformerede nævnere) eller
  `"non-numeric argument to binary operator"` (typefejl), der er vigtige
  datakvalitetssignaler i klinisk SPC-brug. Erstattet med eksplicitte,
  forankrede mønstre der kun dækker kendte ufarlige sources:
  `scale_[xy]_(continuous|date|datetime).*` (ggplot2/scales),
  `font family.*not found in PostScript font database` (BFHtheme/grDevices),
  og `Removed [0-9]+ rows containing` (ggplot2 geom-lag). (#tighten-warning-muffling-scope)

* **Konsolidér dobbelt deprecation-advarsel i `build_bfh_qic_return()`.** Kald
  med `print.summary = TRUE, return.data = FALSE` udsendte tidligere to
  advarsler (én generel deprecation + én legacy-format-advarsel). Disse er
  samlet til én konsolideret advarsel der indeholder både deprecation-kontekst
  og migrationsinstruktion. (#tighten-warning-muffling-scope)

## CI

* **PR-blocking PDF smoke-render workflow tilføjet** (`.github/workflows/pdf-smoke.yaml`).
  Kører 3 repræsentative `bfh_export_pdf()`-kald (p-chart, i-chart med metadata,
  run-chart med target) på hver PR til `main` og `develop`. Verificerer at
  Quarto/Typst-pipelinen producerer gyldige PDF-filer (> 0 bytes, >= 1 side).
  Bruger åbne fallback-fonts (DejaVu/Liberation/Noto/Roboto) via `apt-get` så
  pipelinen virker på public GitHub-runners uden proprietær Mari. Fanger
  catastrophic render-regressioner før de lander i main — complement til
  ugentlig `render-tests.yaml`. Manuel follow-up krævet: tilføj
  "pdf-smoke (ubuntu-latest)" til branch-protection required-checks.
  (#add-pr-blocking-pdf-smoke-render)

## Interne ændringer

* **Fjernet ineffektiv ownership-check i temp-dir-staging.** Den døde
  `Sys.getenv("UID")`-baserede ownership-validering i `prepare_temp_workspace()`
  er fjernet — `UID` er shell-intern og eksporteres typisk ikke til
  R-processer (Rscript, RStudio Server, knitr, Shiny, GitHub Actions), så
  checken skippede silently uden reel beskyttelse. Faktisk isolation via
  `tempfile()` (per-bruger `tempdir()`) og `Sys.chmod(0700)` er uændret.
  Tilsvarende forklarende kommentar tilføjet i `bfh_create_export_session()`.
  (#cleanup-temp-dir-ownership-check)

* **vdiffr snapshots re-baseret** (9 snapshots). Font-metric drift opstod da
  Roboto blev registreret som Helvetica-alias i v0.10.5 (`R/zzz.R`). SVG-koordinater
  ændrede sig minimalt (< 5px) — forventet og intentionelt.
  (#add-pr-blocking-pdf-smoke-render)

* **Sync font-alias-sæt i `tests/testthat/setup.R`** med `R/zzz.R`. Roboto tilføjet
  til `c("Mari", "Arial")` → `c("Mari", "Arial", "Roboto")` i setup.R's
  grDevices-registrering. Forhindrer metric-divergens mellem production og test.
  (#add-pr-blocking-pdf-smoke-render)

* **`skip_if_no_pdf_render_deps()` tilføjet til `helper-skips.R`**. Tjekker
  `BFHcharts:::quarto_available()` og `pdftools`-tilgængelighed samlet.
  Til brug i smoke-render og fremtidige PDF-pipeline-tests.
  (#add-pr-blocking-pdf-smoke-render)

* **`test-visual-regression.R` migreret fra fil-scope til per-test skip**.
  Fil-scope `skip_if_fonts_unavailable()` på linje 28 erstattet med
  `skip_if_no_mari_font()` per test. Giver bedre testthat-reporting og
  åbner for fremtidige tests der ikke kræver Mari.
  (#add-pr-blocking-pdf-smoke-render)

## Tests

* **Smoke + boundary tests for g-, t- og mr-chart** tilføjet i
  `tests/testthat/test-chart-types-gtmr.R`. Verificerer S3-klasse,
  UCL/CL/LCL relationer og grænsetilfælde (nul-tæller-rækker for g-chart,
  identiske tider for t-chart). (#expand-test-coverage-gaps)

* **Bidirektionel i18n-paritetskontrol.** `test-i18n.R` tjekker nu begge
  retninger: DA-nøgler manglende i EN og EN-nøgler manglende i DA.
  (#expand-test-coverage-gaps)

* **PDF-indholdsverifikation med pdftools.** Render-gated tests i
  `test-export_pdf.R` verificerer nu at genererede PDF-filer har mindst 1
  side via `pdftools::pdf_info()$pages`. (#expand-test-coverage-gaps)

* **Kørbart eksempel i `bfh_qic()`.** Første `@examples`-blok er konverteret
  fra `\dontrun{}` til kørbart kode med deterministiske inline-data.
  Øvrige eksempler forbliver i `\dontrun{}`. (#expand-test-coverage-gaps)

* **Laney p' håndberegnede referenceværdier.** To uafhængige fixtures med
  kendte UCL/LCL-værdier (beregnet med Laney 2002-formel, verificeret mod
  qicharts2) tilføjet til `test-statistical-accuracy-extended.R`.
  (#expand-test-coverage-gaps)

* **Nye edge-case tests.** `test-bfh_qic_edge_cases.R` dækker nu:
  `part=c(6,9)` kombineret med `freeze=6` (regressiontest), tomt data.frame
  (fejl forventet), og enkelt-rækket data (returnerer gyldigt objekt).
  (#expand-test-coverage-gaps)

* **Bevar NA i `anhoej.signal` fra qicharts2.** Tidligere blev NA i
  `anhoej.signal` tvunget til `FALSE`, hvilket maskerede "for kort serie
  til evaluering" som "ingen signal". NA bevares nu og repræsenterer
  "ikke evaluerbar (for kort serie)". `plot_core.R` håndterer NA ved
  rendering ved at behandle det som `FALSE` (solid linje) — ingen
  visuel ændring for eksisterende charts. (#enforce-baseline-minimum-and-cl-warnings)

## API

* **Fjern 16 orphan Rd-sider for interne funktioner.** Interne funktioner
  i `utils_typst.R`, `utils_quarto.R`, `utils_bfh_qic_helpers.R`,
  `utils_path_policy.R`, `cache_reset.R` og `config_objects.R` manglede
  `@noRd`-tag. `devtools::document()` genererede Rd-sider for funktioner
  der aldrig var i NAMESPACE. Rettet ved at tilføje `@noRd` til alle
  relevante interne blocks. (#align-public-api-documentation)

* **Dokumentér `$qic_data` kolonnekontrakt.** `new_bfh_qic_result()`
  har nu en `@section qic_data columns:` der lister de kanoniske kolonner
  fra qicharts2 (x, y, n, cl, ucl, lcl, sigma.signal, runs.signal,
  anhoej.signal m.fl.) med semantik og version-bound (qicharts2 >= 0.7.0).
  (#align-public-api-documentation)

* **Tilføj stabilitetserklæring til `new_bfh_qic_result()`.** Ny
  `@section Stability:` dokumenterer at feltnavne (plot, summary,
  qic_data, config) er stabile siden v0.10.0 og ikke fjernes uden
  deprecation-cyklus. (#align-public-api-documentation)

* **Fjern `@keywords internal` fra `bfh_qic_result` klasse-topic.**
  Klassen er offentlig (returneres af enhver `bfh_qic()`-kald).
  (#align-public-api-documentation)

* **README: fjern "Low-Level API for Fine Control" afsnit.** `spc_plot_config()`,
  `viewport_dims()` og `bfh_spc_plot()` er interne og må ikke
  dokumenteres som public API. Afsnittet fjernet. Features-bullet opdateret.
  (#align-public-api-documentation)

* **`base_size`-loftet er justeret til 48** (fra 100) for at matche
  `FONT_SCALING_CONFIG$max_size`. Eksplicitte `base_size`-værdier over 48
  gav visuelt ødelagte layouts; loftet er nu konsistent med auto-skaleringslogikken.
  (#modernize-deprecations-and-deps)

* **Unit-auto-detektion udsender nu besked.** Når `width`/`height` angives
  uden eksplicit `units`-parameter, emitterer `bfh_qic()` og `bfh_export_pdf()`
  en `message()` der navngiver den detekterede enhed og opfordrer til eksplicit
  `units`-angivelse. Supprimér med
  `options(BFHcharts.suppress_unit_auto_detect_message = TRUE)`.
  (#modernize-deprecations-and-deps)

* **`bfh_generate_analysis()` dokumenterer nu manuel BFHllm-installation.**
  `BFHllm` er fjernet fra `Remotes:` (den er kun i `Suggests`); Roxygen
  `@details` indeholder nu `remotes::install_github("johanreventlow/BFHllm")`-
  instruktionen til brugere der ønsker AI-analyse (`use_ai = TRUE`).
  (#modernize-deprecations-and-deps)

## Interne ændringer (modernization)

* **`label_config$centerline_value`, `$has_frys_column`, `$has_skift_column`
  er fjernet som statiske kopier** i `build_bfh_qic_config()`. Disse felter
  var duplikater af `config$cl`, `config$freeze` og `config$part` og kunne
  desynkronisere ved mutation. `export_pdf.R` læser nu direkte fra top-niveau
  config-felterne. (#modernize-deprecations-and-deps)

* **`BFHllm` Remotes-status revideret.** Et tidligere forsøg på at fjerne
  `BFHllm` fra `Remotes:` (begrundet i `R CMD check --as-cran` advarsler for
  `Suggests`-pakker) brød GitHub Actions CI: `r-lib/actions/setup-r-dependencies`
  installerer Suggests via pak med `dependencies = "all"`, og uden Remotes-pointer
  kan pak ikke finde BFHllm (privat GitHub-repo, ej på CRAN). `BFHllm` er nu
  igen i `Remotes:` for at sikre CI fungerer; den er stadig kun i `Suggests`,
  så manuel install er ikke længere strengt påkrævet for slutbrugere men er
  dokumenteret i `bfh_generate_analysis()` Roxygen.
  (#modernize-deprecations-and-deps)

# BFHcharts 0.10.5

## Bug fixes

* **Eliminer "font family not found in PostScript font database" warnings
  i production.** Mari/Arial registreres nu som Helvetica-aliaser i
  `grDevices::postscriptFonts()` og `grDevices::pdfFonts()` ved package
  load (ny `.onLoad()` i `R/zzz.R`). Tidligere blev registreringen kun
  udført i test-setup -- production-kald af `bfh_qic()` og
  `ggplot2::ggsave()` producerede ~40-50 harmlose PostScript-warnings per
  kald (fra `grid::C_stringMetric` font-metric-lookup). Registreringen er
  konservativ: eksisterende Mari/Arial-registreringer (fx via
  systemfonts) overskrives ikke. Den interne
  `.muffle_expected_warnings()` helper bevares som defense-in-depth for
  datetime/numeric scale warnings. (#202)

## Interne aendringer

* **Filomdoebning: `R/create_spc_chart.R` -> `R/bfh_qic.R`.** Funktionen
  blev omdoebt fra `create_spc_chart()` til `bfh_qic()` i v0.2.0, men
  filnavnet blev aldrig opdateret. Ingen API-paavirkning -- kun navigation
  forbedret. Live docs (`README.md`, `CLAUDE.md`, `AGENTS.md`,
  `tests/testthat/README.md`, pending OpenSpec-changes) opdateret til
  at referere det korrekte sti. (#217, #204)

* **Repository-hygiene:** Fjernet `geomtextpath` fra `Suggests` (ubrugt --
  kun en stale TODO-kommentar i `R/plot_core.R` refererede pakken). Fjernet
  tracked dev-scripts (`demo_*.R`, `pdf_export_forsoeg.R`,
  `test_labels.R`, `test_date_formatting_debug.R`,
  `09_medicinsikker_*.R`) og `CLAUDE.md.backup`. Strammet `.gitignore`
  med `*.backup` og generic `BFHcharts_*.tar.gz`. (#215)

* **DRY refactor af font-warning handlers i `utils_bfh_qic_helpers.R`.** To
  naesten identiske `withCallingHandlers`-blokke (i `render_bfh_plot()`
  omkring `bfh_spc_plot()` og i `apply_spc_labels_to_export()` omkring
  `add_spc_labels()`) er konsolideret i en intern helper
  `.muffle_expected_warnings()`. Helper'en mufler ggplot2 datetime/numeric
  scale-warnings og BFHtheme PostScript-font-warnings (Mari ikke i
  font-database) -- begge er expected behavior. Genuine warnings
  propageres uændret. Fungerer som defense-in-depth efter PR #242
  (font-aliases onLoad) der eliminerer font-warnings ved kilden. (#200)

## Sikkerhed

* **Roxygen-dokumentation eksplicit om trust-grænse for `inject_assets` og
  `template_path`.** Begge parametre i `bfh_export_pdf()` (og
  `inject_assets` i `bfh_create_export_session()`) accepterer
  caller-supplied kode/templates der kører med fuld proces-privilege.
  De er legitim infrastruktur for proprietaere fonts og custom templates,
  men en naiv Shiny-integration der videresender user-input vil skabe en
  privilege-escalation-vektor. Ny `\\section{Security}` markerer eksplicit
  hvilke parametre der er trusted-code-only og hvordan de skal valideres
  mod allow-lister hvis exposed. Ingen kode-aendring -- kun docs. (#218)

* **Numerisk verifikation udvidet til 7 yderligere chart-typer (#208).**
  Ny test-fil `tests/testthat/test-statistical-accuracy-extended.R` med
  39 tests der verificerer kontrolgrænse-formler for `xbar`, `s`, `mr`,
  `t`, `g`, `pp` og `up`. Fanger regressioner i BFHcharts' wrapping af
  `qicharts2` og detekterer breaking changes ved `qicharts2`-opgraderinger.

  - **xbar/s**: Montgomery 6.1-6.2 formler med `A3`/`B4`-konstanter.
  - **mr**: Montgomery 6.3 (`D4 = 3.267` for n=2).
  - **t**: Nelson `y^(1/3.6)`-transformation med I-chart paa transformerede
    skala, back-transformeret til original.
  - **g**: geometrisk fordeling med median som centerlinje (robust),
    mean-baseret sigma `sqrt(c_bar·(c_bar+1))`.
  - **pp/up**: Laney prime-charts (Wheeler/Laney sigma-Z overdispersion-
    correction). Cross-verificeret mod `qicharts2::qic()` direkte siden
    prime-formlen er non-triviel at reproducere uden duplikering af
    `qicharts2` internals.

  Tests bruger udelukkende deterministiske data (ingen RNG) og
  haandberegnede expected values for robusthed paa tvaers af R-versioner.

* **Ny scheduled CI-workflow til live Quarto/Typst render-tests (#210).**
  `R-CMD-check.yaml` installerer ikke Quarto (Typst-template hardcoder
  proprietaer Mari-font, og Typst fejler exit 1 paa unknown-font warnings).
  Dette efterlod PDF/PNG-eksport-pipelinen uden CI-coverage -- regressioner
  i template-rendering, font-fallback eller chart-embedding kunne slippe
  igennem. Ny `.github/workflows/render-tests.yaml` kører ugentligt
  (mandage 06:00 UTC) plus on-demand og ved aendringer til
  export-relaterede filer; matrix over ubuntu-latest + macos-latest;
  installerer Quarto 1.5.57 + open fallback-fonts (DejaVu, Liberation,
  Noto, Roboto); aktiverer `BFHCHARTS_TEST_RENDER=true` så render-gate'd
  tests kører live; uploader PDF/Typst-artifacts ved fejl for
  remote-debugging.

## Dokumentation

* **Fire kliniske vignettes (#219).** Pakken havde tidligere kun reference-
  dokumentation via roxygen — kliniske brugere manglede end-to-end guidance
  paa hvilke chart-typer der passer til hvilke spoergsmaal, hvordan
  interventioner haandteres, og hvad target-kontrakten dikterer. Fire nye
  Rmd-vignettes i `vignettes/`:

  - **`chart-types`**: Beslutningstrae fra klinisk spoergsmål til
    `chart_type`-valg. Per-type use cases, sample-size guidance,
    anti-patterns. Reference: Provost & Murray (2011).
  - **`phases-and-freeze`**: Distinguere `part` (separate centerlinjer per
    fase) vs `freeze` (fastlaast baseline). Klinisk eksempel: pre/post
    intervention med frosset baseline. Almindelige fejl + migration-pattern.
  - **`targets-and-percent`**: Dokumenterer percent-target-kontrakten fra
    v0.9.0 (#203). Migration-eksempel fra silently misvisende
    `target_value = 2.0` paa percent-akse til korrekt
    `target_value = 0.02` (proportion) eller `multiply = 100`.
  - **`safe-exports`**: Sikkerheds-praksis for `inject_assets` og
    `template_path` (#218). Allow-list-pattern til Shiny-applications,
    pre-deploy security checklist.

  Infrastruktur: `VignetteBuilder: knitr` tilfoejet til DESCRIPTION,
  `knitr` + `rmarkdown` i Suggests, build artifacts i `.gitignore`.

# BFHcharts 0.10.4

## Interne aendringer

* **Auto-tag-workflow respekterer nu DESCRIPTION's Version-felt direkte.**
  Tidligere auto-inkrementerede `tag-release.yaml` PATCH baseret paa
  eksisterende tags uafhaengigt af DESCRIPTION, hvilket fik tag og
  pakke-version ud af sync (fx blev tag `v0.10.3` oprettet paa commit med
  `Version: 0.10.1`, så pak's version-resolver afviste downstream-installs
  med `Can't install dependency BFHcharts@v0.10.3 (>= 0.10.3)`).
  Workflow bruger nu `v` + DESCRIPTION's Version som tag-navn og fejler
  hvis tag allerede eksisterer paa anden commit. Konsekvens: udvikler
  skal manuelt bumpe DESCRIPTION i hver release-PR for at faa et nyt tag.
  (Fixer regression introduceret i tidligere commit der tilfoejede
  auto-PATCH-increment.)

* **Spring v0.10.2 og v0.10.3.** Disse tags blev auto-genereret med
  forkert DESCRIPTION-version (0.10.0 og 0.10.1 hhv.) -- v0.10.4 er
  første version hvor tag matcher pakke-version igen.

# BFHcharts 0.10.1

## Bug fixes

* **PDF-eksport: gendan fast analyse-rakke-hojde i Typst-template (52.8mm,
  26.4mm, 1fr).** Commit 8ff53b1 (#160) skiftede 2. raekke til `auto` for
  dynamisk hojde, men det fjernede den visuelle luft mellem analyse-tekst og
  PERIODE-linjen ved korte analyser (SPC-PDF lookede mere kramped end
  oprindeligt design). Den faste 26.4mm gendanner det oprindelige spacing.
  Lange analyser, der overskrider 26.4mm, faldt tidligere udenfor og
  haandteres bedst ved at korte analyse-teksten ned -- ikke ved at lade row
  flyde. (Reverts #160)

# BFHcharts 0.10.0

## Breaking changes

* **`bfh_export_pdf()` og `bfh_compile_typst()` ignorerer nu system-fonts som
  default (`ignore_system_fonts = TRUE`).** Tidligere faldt Typst tilbage til
  system-installerede font-varianter selv når `font_path` var sat, hvilket
  kunne resultere i forkert weight (fx Mari Heavy med metadata
  `style=Heavy,Regular` matchede regular-weight). Det giver nu konsistent
  rendering på tværs af dev-maskiner og cloud-deployment.
  **Migration:** Hvis eksisterende kode er afhængig af system-fonts ved
  Typst-render, sæt `ignore_system_fonts = FALSE` eksplicit. (#227)

# BFHcharts 0.9.0

## Breaking changes

* **`bfh_qic()` validerer nu `target_value` mod y_axis_unit-skalaen.**
  Når `y_axis_unit = "percent"` (default `multiply = 1`), skal `target_value`
  være i `[0, 1.5]` (proportion). Negative værdier afvises altid.
  Den hyppigste fejl: `target_value = 2.0` til at betyde "2%" —
  brug `target_value = 0.02` eller sæt `multiply = 100`.
  **Migration:**
  ```r
  # Gammel (forkert, plottet target ved 200%):
  bfh_qic(..., y_axis_unit = "percent", target_value = 2.0)

  # Ny — option A (proportion, default multiply=1):
  bfh_qic(..., y_axis_unit = "percent", target_value = 0.02)

  # Ny — option B (procent, multiply=100):
  bfh_qic(..., y_axis_unit = "percent", target_value = 2.0, multiply = 100)
  ```
  (#203)

* **`bfh_qic()` validerer nu indholdet af denominator-kolonnen `n` for
  ratio-charts (`p`, `pp`, `u`, `up`).** Tidligere blev kun kolonnenavnet
  syntakstjekket; rækker med `n = 0`, `n < 0`, `n = Inf` eller `y > n`
  (P-charts) gled igennem og producerede stille misvisende rate-plots
  (NaN/Inf-værdier, proportioner > 1). Nu rejses en hård fejl med
  rækkenumre, så brugeren kan inspicere kildedataene.
  **Kontrakt:**
  - Ratio-charts (`p`, `pp`, `u`, `up`) kræver `n` ikke-NULL.
  - `n` skal være numerisk og endelig (ingen `Inf`/`-Inf`).
  - Alle ikke-`NA` værdier af `n` skal være `> 0`.
  - For proportion-charts (`p`, `pp`): hver række skal opfylde `y <= n`.
  - `NA` i enkelt-rækker af `n` er tilladt (qicharts2 dropper dem).
  - Andre chart-typer (`run`, `i`, `mr`, `c`, `g`, `t`, `xbar`, `s`)
    valideres ikke.

  **Migration:** Pre-filtrér data inden `bfh_qic()`:
  ```r
  data_clean <- data[!is.na(data$denominator) & data$denominator > 0, ]
  bfh_qic(data_clean, ...)
  ```
  (#205)

* **`bfh_generate_analysis()` kræver nu eksplicit `use_ai = TRUE` for
  AI-analyse.** Defaulten er ændret fra `NULL` (auto-detektér BFHllm) til
  `FALSE` (brug altid standardtekster). I healthcare-kontekst er implicit
  ekstern databehandling uacceptabel; tidligere kunne BFHllm aktiveres
  automatisk når pakken var installeret, uden at brugeren vidste det.
  **Migration:** Kald der ønsker AI-analyse skal sætte `use_ai = TRUE`
  eksplicit. Kald der allerede sætter `use_ai = FALSE` er uændrede.
  Det samme gælder `bfh_export_pdf(auto_analysis = TRUE)`, der nu også
  defaulter til `use_ai = FALSE` (#secure-ai-explicit-opt-in).

## Nye features

* **Internationalisering (i18n):** Ny `language`-parameter (`"da"` eller `"en"`) på
  `bfh_qic()`, `bfh_generate_analysis()` og `bfh_generate_details()`. Default er
  `"da"` — alle eksisterende kald er bagudkompatible. Engelsksprogede diagramlabels
  ("TARGET", "CUR. LEVEL") og analysetekster returneres ved `language = "en"`.
  Strings er centraliseret i `inst/i18n/da.yaml` og `inst/i18n/en.yaml`.
  Intern helper `i18n_lookup(key, language)` + language-keyed cache
  (`.i18n_cache`) med reset via `bfh_reset_caches()` (#i18n-chart-strings).

# BFHcharts 0.8.3

## Nye features

* **Batch eksport-session:** Ny funktion `bfh_create_export_session()` opretter
  en genanvendelig eksport-session der kopierer Typst-template-assets én gang og
  deler dem på tværs af multiple `bfh_export_pdf()`-kald. I batch-workflows
  (N eksporter fra løkke) eliminerer dette den rekursive template-copy der
  dominerer I/O-cost. Brug: `session <- bfh_create_export_session()`,
  send `batch_session = session` til hvert `bfh_export_pdf()`-kald, og luk med
  `close(session)`. `inject_assets`- og `font_path`-argumenter overføres til
  session-konstruktøren i stedet for til individuelle kald
  (#reuse-typst-template-assets).

## Interne ændringer

* **Visuel regression stabiliseret:** vdiffr-snapshots re-baselinede efter BFHtheme
  0.5.0 bump (koordinat-skift fra opdateret font-metrics). Testopsætning registrerer
  nu Mari og Arial som PostScript/PDF font-aliaser i `setup.R`, hvilket eliminerer
  ~1600 harmlose "font family not found in PostScript font database" warnings per
  test-kørsel. `.new.svg` filer tilføjet til `.gitignore` (#209).

* **Cache-nøgle reproducerbarhed:** Font-cache i `utils_add_right_labels_marquee.R`
  nøglede kun på device-type — ikke på fontfamily. Kald som
  `.resolve_font_family("Arial")` og `.resolve_font_family("Helvetica")` på
  samme device delte cache-entry (første vinder). Nøgle er nu
  `dev_type + fontfamily` for at forhindre stale cache ved fontskift.
  Ny intern helper `bfh_reset_caches()` tømmer alle package-level caches —
  bruges automatisk i test-setup via `helper-cache.R`
  (#cache-keying-and-reset).

## Sikkerhed

* **AST-baseret markdown → Typst parser:** `markdown_to_typst()` bruger nu
  CommonMark AST-parsing (`commonmark` + `xml2`) i stedet for regex-baseret
  konvertering. Alle Typst markup-tegn (`#`, `$`, `@`, `_`, `*`, `[`, `]`,
  `<`, `>`, `` ` ``, `~`, `^`, `\`) escapes i plain text-noder, hvilket
  forhindrer Typst injection via user-supplied strenge (fx AI-analysetekst).
  Understøttede markdown-elementer: bold, italic, inline code, lister,
  linjeskift. **Potentielle outputforskelle:** (1) `\n\n` (dobbelt newline)
  producerer ét Typst-linjeskift i stedet for to — visuelt identisk da
  Typst collapser consecutive linjeskift; (2) markdown-links
  `[tekst](url)` renderer nu som synlig tekst alene (ikke bracket-notation);
  (3) backtick og `*` i plain text escapes — var ikke escaped i den gamle
  regex-parser (#harden-typst-markdown-parser).

* **Centraliseret path policy for eksport-funktioner:** Duplikeret
  sti-valideringslogik i `bfh_export_png()`, `bfh_export_pdf()` og
  `bfh_compile_typst()` er samlet i en ny intern helper
  `validate_export_path()` i `R/utils_path_policy.R`. Alle tre
  call-sites anvender nu den samme komplette metacharacter-blacklist
  (`; | & $ \` ( ) { } < > \n \r`) og det samme path-traversal-check.
  **Adfærdsændringer:** `bfh_export_png()` afviser nu også `<`, `>`,
  `\n` og `\r` i stier (tidligere tilladt); `bfh_export_pdf()` kræver
  nu `.pdf`-extension på output-stien (tidligere ukontrolleret).
  Ingen ændringer i public API-signaturer
  (#central-export-path-policy).

# BFHcharts 0.8.2

## Breaking changes (internal API)

* **`spc_plot_config()`, `viewport_dims()`, `phase_config()` fejler nu
  ved ugyldigt input** i stedet for at udsende en advarsel og returnere
  en coerced/default-værdi. Alle valideringsfejl kaster en condition med
  class `bfhcharts_config_error`. Dette påvirker kun kode der direkte
  kalder disse interne constructors — `bfh_qic()` er upåvirket
  (#harden-config-validation).

## Interne ændringer

* **Testbarhed af Quarto-pipeline:** `bfh_compile_typst()` og
  `quarto_available()` accepterer nu `.system2 = system2` og
  `.quarto_path = NULL` parametre (dependency injection). Produktionskald
  er uændret; tests kan injicere mocks uden live Quarto-installation
  (#inject-quarto-system2).

* **Testsuite stabilisering:** Kanoniske skip-helpers tilføjet til
  `tests/testthat/helper-skips.R`: `skip_if_no_quarto()` og
  `skip_if_no_mari_font()`. Alle render/PDF-tests migreret fra rå
  `skip_if_not(quarto_available(), ...)` til `skip_if_not_render_test()` +
  `skip_if_no_quarto()` — sikrer at `devtools::test()` kører rent uden
  Quarto installeret og uden render-gate sat (#stabilize-default-test-suite).

* Fjernet biSPCharts-specifik kode fra `chart_types.R` (#119):
  `CHART_TYPES_DA`, `CHART_TYPE_DESCRIPTIONS`, `get_qic_chart_type()`,
  `chart_type_requires_denominator()` og `get_chart_description()` var aldrig
  en del af BFHcharts' pipeline og lå ubrugte i pakken. biSPCharts vedligeholder
  egne versioner i `R/config_chart_types.R`. Kun `CHART_TYPES_EN` er bibeholdt
  da den bruges internt til validering af chart-type input.



* **CI: fuld R CMD check med tests.** Fjernede `--no-tests` workaround fra
  `R-CMD-check.yaml` efter at to pre-existing test-failures blev rettet:
  `test-smoke.R:10` brugte udfasede BFHtheme farvenavne
  (`hospital_grey`/`hospital_dark_grey` → `grey`/`dark_grey`);
  `test-export_pdf.R:423` forventede forældet fejlbesked-regex efter
  `bfh_extract_spc_stats()` blev konverteret til S3 generic. CI fanger nu
  nye test-regressioner.

# BFHcharts 0.8.1

## Bug fixes

* Tilføjet `Remotes:` til `DESCRIPTION` for `BFHtheme` og `BFHllm`. Downstream-
  pakker (fx biSPCharts) kunne tidligere ikke installere `BFHcharts` via pak
  uden eksplicit workaround, fordi pak ikke transitivt fandt `BFHtheme`.
  Fra v0.8.1 er transitiv dep-resolution fixet.

# BFHcharts 0.8.0

## Breaking changes

* Y-akse-formatet for `y_axis_unit = "time"` er skiftet fra enkelt-enhed
  (`"30 minutter"`, `"1,5 timer"`, `"2 dage"`) til **komposit-format**
  (`"30m"`, `"1t 30m"`, `"2d 13t"`). Ændringen løser to konkrete problemer:
  (1) Tidligere kunne y-aksen vise 7-cifrede kommatal som `"0,6666667 timer"`
  når brudværdier ikke var hele enheder (issue #138). (2) Det nye format
  er mere kompakt og matcher nu data-punkt labels (centrallinje, target)
  — pilene fra CL/target rammer præcis samme tekst som y-aksen. Samtidig
  placeres ticks på **tids-naturlige intervaller** (1m, 5m, 15m, 30m, 1t,
  2t, 6t, 12t, 1d, 2d, 7d, 30d) via den nye interne `time_breaks()`,
  så ggplot2's default-breaks ikke længere producerer fraktionelle timer
  (#138). Downstream-pakker (biSPCharts m.fl.) kan fjerne workarounds der
  overlay'er deres eget tidsformat oven på plottet.
* `format_y_value()` ignorerer nu `y_range`-parameteren for `time`-enhed;
  komposit-formatet håndterer selv unit-valg via komponentopdeling.
  Parameteren er bibeholdt for bagudkompatibilitet men har ingen effekt.
* `bfh_interpret_spc_signals()` er fjernet. Funktionen producerede parallel
  Anhøj-tekst via hardcoded `sprintf()`-kald, men dens output
  (`context$signal_interpretations`) blev aldrig læst af
  `build_fallback_analysis()` i praksis. Al analysetekst genereres nu via
  YAML-skabeloner i `inst/texts/spc_analysis.yml`. `bfh_build_analysis_context()`
  returnerer ikke længere `signal_interpretations`-feltet. Downstream-kaldere
  bør bruge `bfh_generate_analysis()` for den samlede analysetekst.

## Bug fixes

* Fiks `0,8541667 timer`-bug på y-aksen ved tids-data: `51 min` formateres
  nu korrekt som `"51m"` i stedet for det 7-cifrede kommatal som
  ggplot2's default `scale_y_continuous` producerede ved fractional-hour-
  værdier (#138).
* Overflow-rounding: værdier lige under en unit-grænse rundes nu til
  næste unit i stedet for at producere komponent-overflow. Eksempelvis
  kollapser `59,7 min` til `"1t"` (ikke `"60m"`), og `1439,7 min` til
  `"1d"` (ikke `"23t 60m"`).

# BFHcharts 0.7.2

## Nye features

* `bfh_generate_details()` er nu eksporteret. Funktionen genererer den
  formaterede detail-tekst (periode, gennemsnit, seneste, niveau) som vises
  over SPC-grafen i PDF-eksporter. Tidligere kun tilgængelig internt — nu
  kan downstream-pakker (fx biSPCharts) sætte `metadata$details` selv,
  så preview-veje (via `bfh_create_typst_document()`) matcher
  `bfh_export_pdf()`-vejen.

# BFHcharts 0.7.1

## Bug fixes

* Analyseteksten formulerer nu eksplicit at outlier-tallet kun omfatter
  **seneste observationer**, f.eks. "2 af de seneste observationer ligger
  uden for kontrolgrænserne". Tidligere skrev teksten blot "2 observation(er)
  uden for kontrolgrænserne", hvilket kunne misforstås som totalen i PDF-
  tabellen (der viser total i seneste part). Nu er det tydeligt at analyse-
  tallet kun afspejler nylige outliers (`outliers_recent_count`, seneste 6 obs),
  mens tabellen fortsat viser totalen (`outliers_actual`).
* Opdatering dækker både fallback-tekster i
  `inst/texts/spc_analysis.yml` (`outliers_only`, `runs_outliers`,
  `crossings_outliers`, `all_signals`) og den hardkodede tekst i
  `bfh_interpret_spc_signals()`.

# BFHcharts 0.7.0

## Nye features

* `bfh_extract_spc_stats()` er nu en S3-generic med methods for `data.frame`,
  `bfh_qic_result` og `NULL`. Kald direkte med et `bfh_qic_result`-objekt for
  at få fyldestgørende outlier-tal — tidligere krævede det den interne funktion
  `extract_spc_stats_extended()`, som nedarvede problemer mellem forskellige
  downstream-pakker.

```r
result <- bfh_qic(data, x = date, y = value, chart_type = "i")

# Nyt (anbefalet): fyldestgørende stats inkl. outliers
stats <- bfh_extract_spc_stats(result)

# Gammelt: kun runs/crossings fra summary — bevares for bagudkompatibilitet
stats_summary_only <- bfh_extract_spc_stats(result$summary)
```

## Bug fixes

* **PDF-tabellen under "OBS. UDEN FOR KONTROLGRÆNSE" viser nu det korrekte
  antal outliers.** Tidligere blev `outliers_actual` begrænset til de seneste
  6 observationer, hvilket medførte uoverensstemmelse mellem diagrammet (alle
  blå punkter) og tabellen (kun de nyeste outliers). Tabellen viser nu TOTAL
  antal outliers i seneste part.

* Analyseteksten (`bfh_interpret_spc_signals()`, `bfh_generate_analysis()`)
  nævner fortsat kun outliers indenfor de seneste 6 observationer, så ældre
  outliers ikke beskrives som aktuelle problemer. Denne adfærd er nu
  eksponeret som et separat stats-felt `outliers_recent_count`.

## Interne ændringer

* Den interne funktion `extract_spc_stats_extended()` er fjernet. Al intern
  brug (`bfh_export_pdf`, `bfh_build_analysis_context`) er skiftet til
  `bfh_extract_spc_stats(x)` med S3-dispatch på `bfh_qic_result`.

# BFHcharts 0.6.2

## Forbedringer

* `spc_analysis.yml` har nu short/standard/detailed varianter for alle tekster,
  hvilket giver bedre kontrol over analysetekst-længde (#115)
* `pick_text()` vælger nu automatisk den længste variant der passer inden for
  tegnbudgettet — erstatter trimning med naturligt variantvalg

## Breaking changes

* `bfh_interpret_spc_signals()` er ikke længere eksporteret. Brug
  `BFHcharts:::` for direkte adgang. Funktionen bruges kun internt af
  `bfh_generate_analysis()` (#115)

# BFHcharts 0.6.0

## Package Size Reduction

* **Removed bundled Mari fonts (~2.7 MB):** Mari font files are copyrighted and cannot be redistributed. The Typst template now uses a font fallback chain: `Mari → Roboto → Arial → Helvetica → sans-serif`.
  - **Internal users** (with Mari installed): Full hospital branding preserved - no visible changes
  - **External users**: Readable fallback fonts used automatically
  - **Package size** reduced by 66% (4.1 MB → 1.4 MB)
  - **Legal compliance**: No copyright issues blocking CRAN/public release

## New Features

* **AI-assisted SPC analysis generation:** Automatically generate analysis text for PDF exports with intelligent fallback to Danish standard texts:
  - `bfh_generate_analysis()` - Generates analysis using AI (BFHllm) or standard texts
  - `bfh_interpret_spc_signals()` - Danish standard texts for Anhøj SPC signals (runs, crossings, outliers)
  - `bfh_build_analysis_context()` - Collects context from `bfh_qic_result` for analysis
  - `bfh_export_pdf()` gains `auto_analysis` and `use_ai` parameters for automatic analysis generation
  - Graceful degradation: Falls back to standard texts if AI unavailable or fails
  - BFHllm added as optional dependency (Suggests, not required)
  - Fixes GitHub issue #69

**Example usage:**
```r
# Auto-generate analysis with AI (if BFHllm installed)
bfh_qic(data, x = month, y = infections, chart_type = "i") |>
  bfh_export_pdf("report.pdf",
    metadata = list(
      data_definition = "Antal infektioner pr. 1000 patientdage",
      target = 2.5
    ),
    auto_analysis = TRUE
  )

# Use standard texts only (no AI)
bfh_generate_analysis(result, use_ai = FALSE)
```

---

# BFHcharts 0.5.1

## New Features

* **Rich text support in PDF export:** Title and analysis fields in PDF exports now support markdown-style formatting that is converted to Typst rich text:
  - `**bold text**` → Typst `#strong[bold text]`
  - `*italic text*` → Typst `#emph[italic text]`
  - Newlines (`\n`) → Typst line breaks
  - Restores functionality that was available in SPCify's previous internal export implementation
  - Adds new internal function `markdown_to_typst()` for CommonMark-to-Typst conversion

---

# BFHcharts 0.5.0

## Breaking Changes

* **Removed complex TTL-based caching system (~1,500 LOC):** The grob height cache and panel height cache have been removed to simplify the codebase. These caches were disabled by default and rarely used in production.
  - **Removed:** `.grob_height_cache`, `.panel_height_cache`, and all related configuration functions
  - **Kept:** Simple marquee style cache (~45 LOC) which is always beneficial
  - **Impact:** No performance regression for typical usage (caches were disabled by default)
  - **Benefit:** Reduced code complexity from ~2,700 to ~1,200 lines in label placement utilities
  - Updated `docs/CACHING_SYSTEM.md` to reflect simplified architecture
  - Fixes GitHub issue #42

## Internal Improvements

* Simplified label height measurement - removed `use_cache` parameters from all measurement functions
* Removed global state management complexity (TTL tracking, stats, purge logic)
* Updated documentation to explain caching removal rationale

---

# BFHcharts 0.4.1

## Improvements

* **Contextual percent precision for centerline labels:** Centerline labels on SPC charts now show one decimal place when the centerline is within 5 percentage points of the target value. This provides better precision where it matters (close to goal) while keeping labels clean when far from target.
  - Example: 88.7% shown as "88,7%" when target is 90%, but shown as "63%" when target is 90% (far from target)
  - Uses Danish comma notation for decimal separator
  - Fixes GitHub issue #68

* **Range-aware y-axis precision:** Y-axis ticks for percent charts now show decimals when the axis range spans less than 5 percentage points, preventing repeated or indistinguishable tick labels on narrow ranges.
  - Example: Range 98%-100% shows "98.5%", "99.0%", "99.5%"
  - Wide ranges continue to show whole percentages

---

# BFHcharts 0.4.0

## New Features

* **Public API for SPC utility functions:** Exported `bfh_extract_spc_stats()` and `bfh_merge_metadata()` as public API functions to support downstream packages (like SPCify) without requiring `:::` accessor.
  - `bfh_extract_spc_stats()` extracts SPC statistics (runs, crossings) from qic summary data frames
  - `bfh_merge_metadata()` merges user-provided metadata with default values for PDF generation
  - Both functions include comprehensive parameter validation and documentation
  - Internal versions maintained as deprecated aliases for backward compatibility
  - Enables SPCify to migrate from `BFHcharts:::function()` to `BFHcharts::bfh_function()`
  - Provides API stability guarantees via semantic versioning
  - Fixes GitHub issue #64

---


# BFHcharts 0.3.5

## Performance Improvements

Significant performance optimizations for PDF export functionality, delivering 40-50% faster export times and 75% smaller temporary files.

### High-Impact Optimizations

* **5-10x faster template copying:** Replaced manual file iteration loop with `file.copy(..., recursive = TRUE)` for dramatically faster template directory operations
* **4x faster PNG generation:** Reduced DPI from 300 to 150, resulting in 75% smaller temporary files without visible quality loss in PDF output
* **25x faster Quarto checks:** Implemented session-level caching for `quarto_available()` with ~2ms cache hits vs ~50ms system calls

### Performance Benchmarks

| Metric | Before (v0.3.4) | After (v0.3.5) | Improvement |
|--------|-----------------|----------------|-------------|
| Single PDF export | ~500-800ms | ~300-400ms | **40-50% faster** |
| Temp file size | ~15-25 MB | ~4-6 MB | **75% smaller** |
| Quarto check (cached) | ~50ms | ~2ms | **96% faster** |

### Implementation Details

* Template copy optimization at R/export_pdf.R:490-499
* PNG resolution reduction at R/export_pdf.R:307
* Quarto caching system at R/export_pdf.R:344-386

**Note:** Visual QA confirms 150 DPI provides excellent quality for PDF output. Temporary files are automatically cleaned up after each export.

---

# BFHcharts 0.3.4

## Code Quality and Error Handling

This release improves internal code organization, error handling, and API clarity.

### API Improvements

* **Reduced exported API surface:** Three internal helper functions (`quarto_available()`, `bfh_create_typst_document()`, `bfh_compile_typst()`) are no longer exported to users. They remain accessible via `BFHcharts:::` for advanced use cases. This change simplifies the public API without affecting functionality.

### Error Handling Enhancements

* **Improved error reporting:** File operations (`ggplot2::ggsave()`, `writeLines()`) now wrapped in `tryCatch()` with informative error messages
* **Better compilation failures:** Quarto/Typst compilation errors now report exit codes and output for easier debugging
* **Fail-safe version checking:** Unparseable Quarto version strings now correctly return `FALSE` (fail-safe) instead of `TRUE`
* **Fixed cleanup timing:** Temporary directory cleanup handler now registered before `dir.create()` to ensure cleanup even if directory creation fails

### Dead Code Removal

* Removed unused internal function `escape_typst_path()` and its tests

### Testing

* Added 4 new error handling tests:
  - ggsave failure handling
  - Unparseable Quarto version handling
  - Malformed input structure validation
  - Quarto compilation failure reporting

**Impact:** No breaking changes. Internal API changes only affect advanced users who directly call helper functions with `:::`.

---

# BFHcharts 0.3.3

## Security Hardening

**IMPORTANT:** This release addresses critical security vulnerabilities in PDF export functionality. Healthcare organizations using BFHcharts in production environments should update immediately.

### Critical Path Validation
* **Path traversal prevention:** All file paths now reject `..` directory traversal attempts
* **Shell injection protection:** Path parameters are validated against shell metacharacters (`;`, `|`, `&`, `$`, etc.) before being passed to system commands
* **Template path validation:** Custom Typst template paths undergo strict security checks before file operations

### Input Validation Strengthening
* **Metadata type checking:** All metadata fields now validate type constraints (string or Date for date field)
* **Length limits:** Metadata fields limited to 10,000 characters to prevent DoS attacks
* **Unknown field warnings:** Unknown metadata fields now trigger warnings to catch typos and misuse
* **Symlink resolution:** Template paths are now resolved through `normalizePath()` to prevent TOCTOU attacks

### Defense in Depth
* **Restrictive temp permissions:** Temporary directories created with mode 0700 (owner-only) to protect sensitive healthcare data
* **Ownership verification:** Temp directory ownership validated on Unix systems to prevent directory substitution attacks
* **File copy integrity:** All file copy operations verified with size checks to detect corruption or tampering
* **Path sanitization:** Error messages use `basename()` to avoid exposing sensitive full paths

### Testing
* Added comprehensive security test suite with 20 tests covering:
  - Path traversal rejection
  - Shell metacharacter validation
  - Metadata type and length validation
  - All tests passing with 0 failures

**Compliance:** These changes strengthen BFHcharts for HIPAA/GDPR compliance requirements in healthcare environments.

---

# BFHcharts 0.3.2

## Bug Fixes

* **Fixed chart path handling regression:** `bfh_create_typst_document()` now correctly handles chart images from any location. Charts are copied to the output directory before Typst generation, fixing the regression where only charts in the same directory worked.

* **Fixed Quarto version parsing:** `check_quarto_version()` now correctly parses version strings in formats like "Quarto 1.4.557" (prefixed) and "1.4" (two-part). Previously, prefixed version strings would bypass the version guard.

* **Strengthened template validation:** `bfh_export_pdf()` now properly rejects directories and non-.typ files as `template_path`. Added validation for file copy success with clear error messages.

* **Consistent path escaping:** All user-provided paths in generated Typst content are now properly escaped, including custom template paths and chart filenames with special characters.

## Improvements

* Added comprehensive content verification tests that check for metadata, chart references, and template imports in generated Typst (not just file existence)
* Tests now verify version parsing with prefixed formats and edge cases
* All 63 tests pass (7 skipped without Quarto)

---

# BFHcharts 0.3.1

## Bug Fixes

* **Fixed Windows path handling:** Typst import and image paths are now properly escaped for Windows paths and paths containing spaces. Previously, Windows-style backslashes would cause invalid Typst escape sequences.

* **Fixed date metadata propagation:** User-supplied `metadata$date` is now correctly forwarded to the Typst template. Previously, the PDF always showed today's date from the template, ignoring user-supplied dates.

* **Enhanced Quarto version checking:** `quarto_available()` now verifies that Quarto version is >= 1.4.0 (required for Typst support). Previously, only binary existence was checked, leading to opaque errors with older Quarto versions.

## New Features

* **Custom template support:** Added `template_path` parameter to `bfh_export_pdf()` allowing users to specify custom Typst template files instead of using the packaged BFH template.

## Improvements

* Added comprehensive unit tests for path escaping, version checking, and metadata propagation
* Improved error messages for Quarto version requirements

---

# BFHcharts 0.3.0

## Breaking Changes

* **Return type changed:** `bfh_qic()` now returns a `bfh_qic_result` S3 object instead of a ggplot object
  - **Rationale:** Enables pipe-compatible export workflows (`bfh_qic() |> bfh_export_pdf()`) and preserves SPC statistics for PDF metadata
  - **Migration:** Access plot with `result$plot` - see Migration Guide below
  - Print method maintains backwards-compatible console display (plot still shows when printing result)

* **Deprecated parameter:** `print.summary` parameter is deprecated
  - Summary is now always included in `bfh_qic_result$summary`
  - Using `print.summary = TRUE` will trigger a deprecation warning but still works (legacy behavior)
  - This parameter will be removed in a future version

## New Features

### Export Functionality

* **PNG Export:** `bfh_export_png()` - Export charts to PNG with configurable dimensions
  - MM-based dimensions (Danish/European standard)
  - Configurable DPI resolution (96-600)
  - Pipe-compatible workflow
  - Title rendered in PNG image

* **PDF Export:** `bfh_export_pdf()` - Export charts to PDF via Typst templates
  - Hospital-branded PDF reports with BFH styling
  - SPC statistics table (runs, crossings, outliers)
  - Customizable metadata (department, analysis, data definition)
  - Title in PDF template (not in chart image)
  - **Requires:** Quarto CLI (>= 1.4.0)

* **Low-level Functions:**
  - `bfh_create_typst_document()` - Generate Typst documents
  - `bfh_compile_typst()` - Compile Typst to PDF
  - `quarto_available()` - Check Quarto CLI availability

### S3 Class System

* **New S3 class:** `bfh_qic_result`
  - Components: `$plot`, `$summary`, `$qic_data`, `$config`
  - Print method: Displays plot for backwards compatibility
  - Plot method: Extracts and displays ggplot
  - Helper functions: `is_bfh_qic_result()`, `get_plot()`

### Typst Templates

* **Hospital branding templates** included in `inst/templates/typst/`
  - BFH-diagram2 template for A4 landscape reports
  - Mari and Arial fonts bundled
  - Hospital logos and branding assets

## Migration Guide (0.2.0 → 0.3.0)

### Basic Usage (Plot Display)

If you only display plots in console/viewer, no changes needed:

```r
# Works exactly the same in 0.3.0
bfh_qic(data, x = date, y = value, chart_type = "i")
```

### Accessing the ggplot Object

If you need to customize the plot with ggplot2 layers:

```r
# Before (0.2.0):
plot <- bfh_qic(data, x = date, y = value, chart_type = "i")
plot + labs(caption = "Source: EPJ")

# After (0.3.0):
result <- bfh_qic(data, x = date, y = value, chart_type = "i")
result$plot + labs(caption = "Source: EPJ")
```

### Getting Summary Statistics

```r
# Before (0.2.0):
result <- bfh_qic(data, x, y, chart_type = "i", print.summary = TRUE)
summary_stats <- result$summary

# After (0.3.0) - Recommended:
result <- bfh_qic(data, x, y, chart_type = "i")
summary_stats <- result$summary  # Always available

# After (0.3.0) - Legacy (with deprecation warning):
result <- bfh_qic(data, x, y, chart_type = "i", print.summary = TRUE)
summary_stats <- result$summary  # Still works but warns
```

### Using return.data Parameter

```r
# Backwards compatible - no changes needed
qic_data <- bfh_qic(data, x, y, chart_type = "i", return.data = TRUE)
```

### New Export Workflows

```r
# PNG export
bfh_qic(data, x, y, chart_type = "i", chart_title = "Infections") |>
  bfh_export_png("infections.png", width_mm = 200, height_mm = 120, dpi = 300)

# PDF export (requires Quarto CLI)
bfh_qic(data, x, y, chart_type = "i", chart_title = "Infections") |>
  bfh_export_pdf(
    "infections_report.pdf",
    metadata = list(
      hospital = "BFH",
      department = "Kvalitetsafdeling",
      analysis = "Signifikant fald observeret",
      data_definition = "Antal infektioner per måned"
    )
  )
```

## System Requirements

* **New dependency:** Quarto CLI (>= 1.4.0) for PDF export
  - Install from: https://quarto.org
  - Only required for PDF export; PNG export works without Quarto
  - Check availability with `BFHcharts::quarto_available()`

## Documentation

* Added comprehensive README examples for export workflows
* Added Typst template documentation in `inst/templates/typst/README.md`
* Updated function documentation for new S3 class

---

# BFHcharts 0.2.0

## Breaking Changes

* **Function renamed:** `create_spc_chart()` has been renamed to `bfh_qic()`
  - **Rationale:** Shorter, more memorable name (7 vs 17 characters) with clear BFH branding and connection to qicharts2
  - **Migration:** Simple find-and-replace - function signature is unchanged (drop-in replacement)
  - All parameters, defaults, and behavior remain identical

## Migration Guide

Update your code by replacing `create_spc_chart` with `bfh_qic`:

```r
# Before (0.1.0):
plot <- create_spc_chart(
  data = my_data,
  x = date,
  y = value,
  chart_type = "i"
)

# After (0.2.0):
plot <- bfh_qic(
  data = my_data,
  x = date,
  y = value,
  chart_type = "i"
)
```

No other changes required - all parameters work exactly the same.

# BFHcharts 0.1.0

* Initial release
* SPC chart visualization with BFH branding
* Support for multiple chart types (run, i, p, c, u, etc.)
* Intelligent label placement system
* Responsive typography
