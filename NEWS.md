# BFHcharts (development)

## Internal changes

* Translate Danish error/warning messages in `R/fct_add_spc_labels.R` to
  English to match standard R-package convention. Affected: input
  validation errors and CL/target fallback warning.
* Add `call. = FALSE` to public-API-boundary `stop()` calls in
  `add_spc_labels()` so internal call stack is not leaked to user.
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
  passere uaendret - de er almindelige tegn i Typst string literals og kan
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
  (validering sker foer `dir.create()`).

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
  udfoert i test-setup -- production-kald af `bfh_qic()` og
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
  propageres uaendret. Fungerer som defense-in-depth efter PR #242
  (font-aliases onLoad) der eliminerer font-warnings ved kilden. (#200)

## Sikkerhed

* **Roxygen-dokumentation eksplicit om trust-grænse for `inject_assets` og
  `template_path`.** Begge parametre i `bfh_export_pdf()` (og
  `inject_assets` i `bfh_create_export_session()`) accepterer
  caller-supplied kode/templates der koerer med fuld proces-privilege.
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
  igennem. Ny `.github/workflows/render-tests.yaml` koerer ugentligt
  (mandage 06:00 UTC) plus on-demand og ved aendringer til
  export-relaterede filer; matrix over ubuntu-latest + macos-latest;
  installerer Quarto 1.5.57 + open fallback-fonts (DejaVu, Liberation,
  Noto, Roboto); aktiverer `BFHCHARTS_TEST_RENDER=true` saa render-gate'd
  tests koerer live; uploader PDF/Typst-artifacts ved fejl for
  remote-debugging.

## Dokumentation

* **Fire kliniske vignettes (#219).** Pakken havde tidligere kun reference-
  dokumentation via roxygen — kliniske brugere manglede end-to-end guidance
  paa hvilke chart-typer der passer til hvilke spoergsmaal, hvordan
  interventioner haandteres, og hvad target-kontrakten dikterer. Fire nye
  Rmd-vignettes i `vignettes/`:

  - **`chart-types`**: Beslutningstrae fra klinisk spoergsmaal til
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
  `Version: 0.10.1`, saa pak's version-resolver afviste downstream-installs
  med `Can't install dependency BFHcharts@v0.10.3 (>= 0.10.3)`).
  Workflow bruger nu `v` + DESCRIPTION's Version som tag-navn og fejler
  hvis tag allerede eksisterer paa anden commit. Konsekvens: udvikler
  skal manuelt bumpe DESCRIPTION i hver release-PR for at faa et nyt tag.
  (Fixer regression introduceret i tidligere commit der tilfoejede
  auto-PATCH-increment.)

* **Spring v0.10.2 og v0.10.3.** Disse tags blev auto-genereret med
  forkert DESCRIPTION-version (0.10.0 og 0.10.1 hhv.) -- v0.10.4 er
  foerste version hvor tag matcher pakke-version igen.

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
