# Cycle 03 — Structured SPC Analysis Architecture Proposal Review (2026-05-17)

**Område:** OpenSpec change `restructure-spc-analysis-architecture` — proposal.md + design.md
**Trigger:** Bruger-anmodet dual-review-cycle på arkitektur-proposal før implementation.
**Baseline:** commit `79315e7` på branch `feat/structured-spc-analysis`.
**Subject:** Documents only — ingen kode implementeret endnu.

---

## Scope

Reviewer to dokumenter:
- `openspec/changes/restructure-spc-analysis-architecture/proposal.md`
- `openspec/changes/restructure-spc-analysis-architecture/design.md`

Verificerer:
1. Empiriske claims om eksisterende kode (counts, locations, behavior)
2. Cross-package contract-claims (biSPCharts, BFHllm)
3. Arkitektoniske konsistens-issues (intern modsigelse, scope-creep, scope-shrink)
4. Implementations-blockere (manglende konstanter, ej-eksisterende felter)

Findings rangeret efter **proposal-impact**: HIGH = misleder implementation / re-design krævet,
MEDIUM = misstatement der påvirker scope/effort, LOW = polish/clarity.

---

## H1 [MEDIUM] — Sigma_hat påstand "beregnes men bruges ikke" er faktuelt forkert

**Lokation:** `proposal.md:38` (hul #7), `design.md:181` ("sigma_hat finite" i confidence-tier-tabel).

**Symptom:** Proposal lister "Sigma-shift magnitude — `context$sigma_hat` beregnes, bruges ikke"
som hul #7. Påstanden er forkert: sigma_hat **bruges aktivt** af eksisterende kode.

**Verifikation (empirisk reproduceret 2026-05-17):**

```r
# R/spc_analysis.R:871-875 — direction-aware near_target evaluation
result$near_target <- if (is_valid_scalar(sigma_hat) &&
  is.finite(sigma_hat) && sigma_hat > 0) {
  delta <= 3 * sigma_hat
}

# R/spc_analysis.R:904-908 — value-neutral at_target classification
is_at_target <- if (is_valid_scalar(sigma_hat) && is.finite(sigma_hat) &&
  sigma_hat > 0) {
  delta <= 3 * sigma_hat
```

sigma_hat driver target-arm-dispatch i begge cascade-grene. Det er **ikke** ubrugt.

**Konsekvens:** Læser af proposal får forkert indtryk af kode-tilstand. Slice 3 (Magnitude
modifier) bliver mis-scoped: gap er **ej** "wire en ubrugt værdi", men "tilføj
sigma-shift-bucket som prose-modifier". To forskellige scopes.

**Foreslået fix:** Reword proposal.md:38 og design.md confidence-tier-rationale:

```
~~Sigma-shift magnitude — context$sigma_hat beregnes, bruges ikke.~~

Sigma-shift magnitude — context$sigma_hat bruges allerede til
target-arm-dispatch (at_target / near_target). Selve magnitudet
(small/medium/large bucket) eksponeres ej som prose-modifier.
```

Slice 3 i tasks.md skal også reworde tasks.md:159-170.

---

## H2 [MEDIUM] — "56 stability×action-kombinationer" arithmetisk forkert

**Lokation:** `proposal.md:40`, `design.md:43-44, 49`.

**Symptom:** Proposal påstår nuværende dispatch er "56 effektive output-kombinationer"
beregnet som "8 stability × 3 target-veje × 7 action-veje".

Multiplikationen er **ej meningsfuld** fordi action-dispatch er **mutually exclusive**
på target-præsens. Faktisk reachable kombinationer ≈ 52, ikke 56:

**Verifikation (R/spc_analysis.R:767-799):**

`.select_action_key()` har tre disjunkte grene:
- `!has_target` → 2 outputs (stable_no_target, unstable_no_target)
- `has_target && !target_direction` → 4 outputs (stable_at, stable_not_at, unstable_at, unstable_not_at)
- `has_target && target_direction` → 6 outputs (stable_goal_met, stable_near, stable_goal_not_met, unstable_goal_met, unstable_near, unstable_goal_not_met)

Hvert stability-mønster paires med præcis én af tre grene, ej alle tre. Stability har
8 base-mønstre + 2 override-cases (no_variation, majority_at_centerline) → 10 stability-paths.
Effektiv combination-tal: 10 × ~6.5 ≈ 52.

**Konsekvens:** "56" optræder også i commit-besked + er load-bearing for argumentet "matrix
eksploderer ved tilføjelse". Argumentet er stadig korrekt (matrix vokser multiplikativt),
men det citerede tal er upræcist + saboterer egen troværdighed når reviewer tjekker.

**Foreslået fix:** Brug "~52 effektive output-kombinationer" eller blot "~50". Erstat
"8 × 3 × 7 ≈ 56" med "10 stability × ~5 effektive action-paths ≈ 50".

Commit-besked skal ikke amendes (allerede merged til worktree-branch), men docs-rettelse
gøres i opfølgnings-commit på branch.

---

## H3 [LOW] — Intern inkonsistens: stability_pattern 8 vs 10 værdier

**Lokation:** `design.md:88` siger "8 værdier"; `design.md:230` siger "fra 10-værdi sæt".

**Symptom:** Schema-blok lister `stability_pattern` med 8 værdier (de oprindelige Anhøj-
kombinationer). Composition-contract-blok refererer "10-værdi sæt" (inkluderer override-
states `no_variation`, `not_evaluable`).

**Verifikation:** Læs `design.md:88-100` (schema) vs. `design.md:228-237` (composition).

**Konsekvens:** Implementations-blokering: hvad er den korrekte enum for `stability_pattern`?
Hvis schema siger 8 + design siger 10, hvad rapporterer feature-extraction når n<12
(not_evaluable-case)?

**Foreslået fix:** Konsolidér til 10-værdi sæt i begge sektioner:

```
stability_pattern: 1 of c("no_signals", "runs_only", "crossings_only",
  "outliers_only", "runs_crossings", "runs_outliers", "crossings_outliers",
  "all_signals", "no_variation", "not_evaluable")
```

Tilsvarende i spec.md (allerede 10 i ADDED Requirement for `bfh_extract_spc_features`).

---

## H4 [LOW] — anhoej_not_evaluable mischaracteriseret som refactor

**Lokation:** `proposal.md:64-67` (hul #10), `tasks.md:381-417` (Slice 8).

**Symptom:** Proposal beskriver hul #10 som "anhoej_not_evaluable er kort label, ikke fuld
erstatning af stability-arm". Implicerer label er "for kort"; slice tilføjer "dedikeret
sektion".

Realiteten: feltet **bruges aldrig** i `build_fallback_analysis()`-dispatch. Det er kun en
i18n-label-streng (verificeret: 0 R-matches uden for inst/i18n/).

**Verifikation:**
```bash
grep -r "anhoej_not_evaluable" /Users/johanreventlow/R/BFHcharts/R/
# (no matches)
```

Slice 8 introducerer:
- Ny akse `confidence_tier`
- Ny detektion `n_points < 12`
- Ny tærskel-konstant (ej eksisterende `N_MIN`)
- Ny erstatnings-dispatch-vej

Det er **ny feature**, ej refactor af eksisterende label. Scope er større end "udvid label
til sektion" indikerer.

**Konsekvens:** Implementations-effort under-estimeret. Også: ingen N_MIN-konstant
eksisterer i kode-basen (`RECENT_OBS_WINDOW = 6L` er eneste sammenlignelige konstant i
`R/globals.R:91`). Slice skal definere n-threshold som ny dokumenteret konstant.

**Foreslået fix:** Reword proposal.md hul #10 + tasks.md Slice 8:

```
Slice 8: Few-obs / not-evaluable sektion (NY DETEKTION + DISPATCH)

Bemærk: anhoej_not_evaluable findes som ubrugt i18n-label;
slice introducerer ny confidence_tier-akse + threshold-baseret
override-dispatch + ny N_MIN-konstant (default 12 baseret på
Anhøj-litteratur-rekommandation).
```

---

## H5 [LOW] — "Bit-for-bit match" parity-test claim er fragil

**Lokation:** `proposal.md:140` ("eksisterende output bibeholdes bit-for-bit"),
`design.md:283` ("gammelt output skal **bit-for-bit matche**"),
`tasks.md:104-114` (1.4 parity-test).

**Symptom:** Phase 2 cut-over kriterie er "bit-for-bit-identisk output på golden-corpus".

Realistisk udfordring: nuværende cascade producerer prose med floating-point-formatering
(`format_target_value()`), dansk pluralisering (`pluralize_da`), placeholder-substitution
(`pick_text()`), tegnbudget-trim (`ensure_within_max()`). Ny implementation skal
reproducere identisk:
- Decimal-tegn (`,` / `.`)
- Plural-form-valg (singular/plural for outliers)
- Tegnbudget-trim-position (sætnings- vs klausul-grænse)
- Whitespace mellem clauses (paste(collapse = " "))

Ét eneste mismatch i én af disse = parity-test rød.

**Konsekvens:** Risiko for at Phase 1-2 låses i evig parity-mode mens micro-formatering
debugges. Symptomatisk for over-strict parity-criterion.

**Foreslået fix:** Definér parity-test som **semantisk match** med kontrolleret
formaterings-tolerance:

- Eksakt textequal_after_normalize() helper der:
  - Trimmer whitespace
  - Normaliserer decimal-separator pr. sprog
  - Sammenligner SHA-256 efter normalisering
- Tolerance for tegnbudget-trim: output-længde skal være inden for `max_chars - 5`
- Snapshot-test med eksplicit `tolerance` på i18n-formatering

Eller mere pragmatisk: "Parity-test består når der ej observeres semantisk drift fra
gammelt output", med klinisk reviewer i loop ved tvivl.

---

## M1 [LOW] — Schema-versioning på S3-objekt: arkitektonisk overhead

**Lokation:** `design.md:104-110` (`schema_version` semver-policy), `spec.md` ADDED
Requirement `bfh_spc_analysis schema_version SHALL follow semver`.

**Symptom:** Forslår eksplicit semver på `bfh_spc_analysis$schema_version`, separat fra
pakke-version. R-packages bruger typisk ikke runtime-schema-versioning på S3-objekter —
package-version løser samme problem.

**Argumenter mod separat schema-version:**
- Pakke-version er allerede tilgængelig via `packageVersion("BFHcharts")`.
- Downstream-konsumenter (biSPCharts) tjekker pakke-version i DESCRIPTION lower-bound, ej
  S3-attribut.
- Kompliceret vedligehold: schema-version skal bumpes uafhængigt + dokumenteres i NEWS.
- Existing biSPCharts pattern: ingen runtime-schema-tjek; brug DESCRIPTION-version.

**Argumenter for separat schema-version:**
- Multi-output paths (JSON-export) hvor pakke-version ej er tilgængelig.
- Eksplicit fail-fast hvis upstream konsumer parser stale-schema-objekt.

**Konsekvens:** Hvis JSON-export ikke er primær brug, er separat schema-version overhead.
Hvis JSON-export er kerne-mål (audit-logging, AI-prompt-anker), retfærdiggør det semver.

**Foreslået fix:** To muligheder:

**A:** Drop separat `schema_version`-felt. Brug `packageVersion("BFHcharts")` ved
serialisering. Simplere vedligehold.

**B:** Behold separat schema-version men dokumentér eksplicit JSON-export som primær use-case
+ tilføj `validate_bfh_spc_analysis_schema()`-helper til downstream-konsumenter.

Anbefaling: A medmindre JSON-export-konsumenter er konkret identificeret.

---

## M2 [LOW] — AI-integration baseline-anker uændret

**Lokation:** `design.md:289-292`, `proposal.md:121-122`.

**Symptom:** Proposal siger AI-fallback bevares; `bfh_analyse()`-output bruges som
`baseline_analysis` til BFHllm.

Men hvad bliver faktisk sendt? Den nuværende kode sender `build_fallback_analysis()`-output
som character-streng. Ny pipeline producerer `bfh_render_analysis(bfh_analyse(x))` —
samme character-output. Den **strukturerede** analyse-objekt sendes **ej** til AI.

**Konsekvens:** AI-output får ej rigere kontekst. Den proposerede arkitekturs lovning om
"AI-fallback får rigere baseline → bedre LLM-output" (design.md:344-345) er **ej
realiseret** af denne change uden ekstra arbejde.

**Foreslået fix:** Enten:

**A:** Justér løfte. Erstat "AI-fallback får rigere baseline" → "AI-fallback bevarer
eksisterende baseline-tekst-anker, men struktureret objekt bliver tilgængelig for
**fremtidig** strukturet AI-prompt-design (out of scope for denne change)."

**B:** Udvid scope: tilføj `llm_context$structured_analysis = as.list(analysis)` til
BFHllm-kald. Kræver BFHllm-side support og audit-event-udvidelse.

Anbefaling: A. Hold scope strikt; gem AI-strukturet-prompt til separat change.

---

## M3 [LOW] — Modifier-budget 60/25/15 arbitrært

**Lokation:** `design.md:248-251`, `spec.md` (ADDED Requirement `bfh_render_analysis SHALL
compose text via deterministic modifier cascade`).

**Symptom:** Proposal foreskriver tegnbudget-allokering 60% base/target/action + 25%
modifier-pool + 15% tail caveats. Tallene fremstår valgt uden empirisk grundlag.

**Verifikation:** Nuværende `.allocate_text_budget()` (R/spc_analysis.R:700-715) bruger
45/20/35 (med target) eller 55/0/45 (uden target). Foreslået 60/25/15 ændrer fordelingen
væsentligt — særligt action-arm reduceres fra 35-45% til del af "60%".

**Konsekvens:** Action-tekst kan blive afkortet hvis base + target + modifier-pool
prioriteres. Klinisk: action-anbefaling er handlings-driver — afkortning her er
højere-cost end caveat-afkortning.

**Foreslået fix:** Anbefal at budget-allokering kalibreres mod golden-corpus i Phase 1.4
med mål: 0% action-arm-truncation, modifier-pool-truncation acceptabel hvis caveat-
prioritet bevares. Dokumentér budget-final som del af spec efter empirisk fit.

---

## M4 [LOW] — Confidence-tier thresholds udokumenteret

**Lokation:** `design.md:178-184` (n ≥ 20 = high, n ∈ [12, 19] = medium, n < 12 = low).

**Symptom:** Tærskler præsenteret uden litteratur-reference eller empirisk grundlag.

**Anhøj-litteratur (Anhøj & Olesen 2014):** Anhøj-regler kræver typisk **20+ datapunkter**
for fuld pålidelighed; **12-14** er nedre grænse for run-detection at have power.

**Konsekvens:** Tærsklerne er konsistente med litteratur men undokumenterede i designet.
Klinisk reviewer kan spørgsmålssætte dem; uden citation er argumentationen svag.

**Foreslået fix:** Tilføj litteratur-reference til design.md:

```
Confidence-tier thresholds baseret på Anhøj & Olesen (2014).
Run-detection-power synker kraftigt under n=12; over n=20 er
detection robust mod outlier-clustering.

Anhøj J, Olesen AV (2014). Run charts revisited: a simulation
study of run chart rules for detection of non-random variation
in health care processes. PLoS One. 9(11):e113825.
```

---

## L1 [LOW] — Cross-repo coordination med biSPCharts under-specificeret

**Lokation:** `proposal.md:158-163`.

**Symptom:** Proposal beskriver biSPCharts-impact som "App-UI kan opt-in til struktureret
`bfh_analyse()`-output". Men ingen konkret cross-repo PR-plan eller version-bump-timing.

**Konsekvens:** Når BFHcharts-release med ny `bfh_analyse()` shippes, kræves separat
biSPCharts-PR for at adopte. Uden eksplicit cross-repo-koordinations-task risikerer
biSPCharts at hænge på gammelt `bfh_generate_analysis()`-output uden at høste struktureret
output's gevinster.

**Foreslået fix:** Tilføj Task 100.6 udvidelse:

```
- [ ] 100.6.1 BFHcharts MINOR-release (cross-repo bump-protokol)
- [ ] 100.6.2 biSPCharts DESCRIPTION lower-bound bump-PR
       (separat fra adoption — kun version-pin)
- [ ] 100.6.3 Adoptions-PR i biSPCharts:
       valgfri opt-in til struktureret bfh_analyse() i UI-rendering.
       Kan deferres uden at blokere version-bump.
```

---

## L2 [LOW] — Modifier-cascade rigid prioritets-rækkefølge

**Lokation:** `design.md:228-247`.

**Symptom:** Composition-cascade definerer fast prioritets-rækkefølge for 12 modifikatorer.
Risiko: lavest-prioritets-modifier (seasonality_caveat, historic_outliers_clause) får aldrig
plads i budget hvis højere-prioritets modifikatorer fylder.

**Konsekvens:** Hvis fx baseline_delta + magnitude + chart_class + direction alle er aktive
(realistisk for kvalitets-data efter intervention), æder de 25% modifier-pool inden tail-
caveats vurderes.

**Foreslået fix:** Overvej **category-budgets** snarere end ren append-order:

```
Magnitude/Direction/Baseline-context modifikatorer: max 60% af modifier-pool
Chart-class modifikatorer: max 20% af modifier-pool
Caveats (variable_cl, freshness, ...): max 20% af modifier-pool, garanteret
```

Garanterer at vigtige caveats (freshness, variable_cl) ikke fortrænges af nice-to-have
fortolknings-modifikatorer.

---

## Sammenfatning før Codex-pass

| ID | Severity | Type | Anbefaling |
|----|----------|------|------------|
| H1 | MEDIUM | Faktuel fejl | Reword hul #7 — sigma_hat bruges, gap er magnitude-bucket |
| H2 | MEDIUM | Arithmetisk drift | Korrekt count ~52, ej 56 |
| H3 | LOW | Intern inkonsistens | Konsolidér 8 vs 10 stability-værdier |
| H4 | LOW | Scope-misrepresentation | Erkend Slice 8 er ny detektion, ej label-udvidelse |
| H5 | LOW | Fragil parity-criterion | Definér semantisk match med formaterings-tolerance |
| M1 | LOW | Arkitektonisk overhead | Drop separat schema_version eller justify konkret |
| M2 | LOW | Over-løfte | AI-baseline forbedres ej af denne change; rephrase |
| M3 | LOW | Arbitrært budget | 60/25/15 skal kalibreres mod corpus i Phase 1.4 |
| M4 | LOW | Manglende reference | Tilføj Anhøj 2014 citation til confidence-tier |
| L1 | LOW | Cross-repo gap | Konkretisér biSPCharts version-bump + adoptions-PR |
| L2 | LOW | Cascade-fragilitet | Overvej category-budgets ej ren append-order |

**Verdict (foreløbig):** Proposal er arkitektonisk solid. Empiriske claims har 2 faktuelle
fejl (H1, H2) der skal rettes før implementation starter — risiko for at mis-scope Slice 3
+ Slice 8. Øvrige findings er polish + risk-mitigation.

**Anbefalet handlinger:**
1. Rett H1 + H2 + H3 + H4 i proposal.md + design.md + tasks.md
2. Beslut H5 (parity-criterion redefinition) før Phase 1.4 implementation
3. Beslut M1 (schema-version) før Phase 0 schema-design
4. M2-M4 + L1-L2 kan deferreres til implementations-phase som "review-debt"

---

## Codex adversarial-review konsekvens (2026-05-17)

**Verdict: needs-attention / no-ship**

Codex bekræftede 7 af mine 11 fund + introducerede **3 NYE HIGH + 2 NYE MEDIUM** der
fundamentalt rokker arkitektur-contract. Mine 2 MEDIUM (H1, H2) er CONFIRMED men H2's
"~52" er **ej empirisk forsvarligt** — counting-method afhænger af måde at tælle på.

### Bekræftet (verified empirisk i denne reconcile):

| ID | Codex-verdict | Reproduktion |
|----|---------------|--------------|
| H1 | confirmed + sound fix | `R/spc_analysis.R:871-875, 904-908` bruger sigma_hat i target-dispatch (verified) |
| H2 | recalibrated | "~52" ej forsvarligt; brug "roughly 50+ reachable text paths, depending on counting method" |
| H3-H5 | confirmed som risk-notes | Internal inconsistency 8/10, anhoej_not_evaluable ej i R/, parity-fragility |
| M1 | confirmed conditional | Schema-version kun justified hvis JSON/audit-replay konkret use case |
| M2 | confirmed som contract-konflikt (se NEW H4 nedenfor) | — |
| M3-M4, L1-L2 | confirmed som risk-notes | — |

### NYE HIGH-fund (Codex caught, jeg missede):

#### N1 [HIGH] — Confidence-tier `is.na(sigma_hat) = low_confidence` regresserer alle run-charts

**Lokation:** `spec.md:108-113` (`bfh_extract_spc_features SHALL compute orthogonal feature axes`).

**Reproduktion (2026-05-17):**
```r
# R/spc_analysis.R:258 — eksplicit kommentar:
# "sigma_hat: ... NA naar kontrolgraenser ikke findes (run charts)."

# tests/testthat/test-spc_analysis.R:1148:
test_that("bfh_build_analysis_context returns NA sigma_hat for run charts", { ... })

# tests/testthat/test-spc_analysis.R:1047:
test_that("at_target falls back to sd(y) when sigma_hat is NA (run chart)", { ... })
```

Run charts har **sigma_hat = NA by design** (ingen kontrolgrænser). Min spec siger
`confidence_tier = "low"` når `is.na(sigma_hat)` → 24-punkt run-chart med klar runs_only-
pattern bliver markeret som `not_evaluable` og mister sin stability-fortolkning.

**Impact:** Hard runtime regression. Bryder grundlæggende run-chart-use-case.

**Foreslået fix:** Chart-type-aware confidence-tier:
```
confidence_tier == "low" naar:
- n_points < 12 OR
- (chart_type != "run" AND is.na(sigma_hat)) OR
- is.na(sigma_data)
```

Run charts bruger `sigma_data` + n_points + Anhøj-stats til confidence; reserverer
`not_evaluable` til reelt utilstrækkelige data.

#### N2 [HIGH] — bfh_spc_analysis schema mangler render-state for parity-safety

**Lokation:** `spec.md:30-41` (schema-definition).

**Reproduktion:** Eksisterende renderer bruger:
- `R/spc_analysis.R:223-228` — `target_display` invariant bevares (>= 90% ej 0.9)
- `R/spc_analysis.R:294-326` — `y_axis_unit`, `target_display` i context
- `R/spc_analysis.R:835-849` — operator-Unicode-conversion `\U2265`, `\U2264`
- `R/spc_analysis.R:1019-1026` — centerline formaters via `format_target_value`
- `R/spc_analysis.R:1034-1038` — `pluralize_da` for singular/plural-valg

Hvis renderer kun har raw features + aux fra schema → kan ændre `>= 90%` til andet display,
drifter da/en decimal-formatering, mister singular/plural-state.

**Impact:** Silent corruption / display-drift. Parity-test bliver fundamentalt usikker.

**Foreslået fix:** Tilføj eksplicit `render_context`-felt til schema:
```
features <- list(...)
aux <- list(...)
render_context <- list(
  target_display = "≥ 90%",          # original user-input, ej modificeret
  centerline_formatted = "85%",       # format_target_value-output
  y_axis_unit = "percent",
  operator_unicode = "≥",
  outliers_word = "observationer",    # pluralize_da-output, language-aware
  language = "da",
  effective_window = 6L
)
```

Test schema-stability pr. felt før renderer parity.

#### N3 [HIGH] — `texts_loader`-ownership breakdown i ny contract

**Lokation:** `spec.md:12-18` (`bfh_analyse` signatur).

**Reproduktion:**
```r
# tests/testthat/test-spc_analysis.R:226
test_that("bfh_generate_analysis threads texts_loader to fallback pipeline", { ... })

# R/spc_analysis.R:466 — eksisterende signatur:
bfh_generate_analysis(..., texts_loader = NULL)

# R/spc_analysis.R:493-494, 947-949 — loader threades til build_fallback_analysis:
if (is.null(texts_loader)) {
  texts_loader <- function() load_spc_texts(language)
}
```

Min spec `bfh_analyse(x, metadata, language)` har **ingen texts_loader-parameter**. Hvis
`bfh_analyse()` materializes language-specific strings (conclusions, caveats,
suggested_actions som character), kan custom test-loaders ej overrride teksten. Hvis
`bfh_analyse()` kun lagrer keys → spec-claim "suggested_actions: character vector" er
forkert.

**Impact:** Backward-compat break. Eksisterende tests (test-spc_analysis.R:226+) ville
fejle.

**Foreslået fix:** Beslut én af to modeller (dokumenteret i spec):

**A — Key-only model:** `bfh_analyse()` returnerer kun nøgler + features. ALL
language/text-loader-resolution sker i `bfh_render_analysis(analysis, texts_loader, ...)`.
Schema-felter `suggested_actions`/`caveats` lagrer key-paths, ej character-strings.

**B — Eager-render model:** `bfh_analyse(x, metadata, language, texts_loader = NULL)`
accepterer loader + materializes strings. Render-lag er ren formatering.

Anbefaling: **A** — clear separation of concerns + nemmere test, men kræver schema-revision.

### NYE MEDIUM-fund:

#### N4 [MEDIUM] — AI baseline_analysis contract: rendered character ej struktureret

**Lokation:** `spec.md:351-357` (AI-scenario), `proposal.md:121-122`.

Eksisterende `R/spc_analysis.R:565-567`:
```r
llm_context <- list(
  ...
  baseline_analysis = baseline_analysis  # character output
)
```

`baseline_analysis` i `llm_context` er rendered character. Min spec scenario suggererer at
`bfh_analyse()`-objekt sendes som baseline. **Kontrakt-bryd.**

**Impact:** Hvis spec implementeres som beskrevet → BFHllm-side kontrakt-brud + audit-event-
tests fejler.

**Foreslået fix:** Adopter min M2 foreslag A: behold rendered character som
`baseline_analysis`. Hvis struktureret AI-context ønskes senere, separat
`structured_analysis`-felt i separat change. **Hold scope strikt.**

#### N5 [MEDIUM] — Freshness-akse bryder deterministic feature-extraction-krav

**Lokation:** `tasks.md:329-331` (Slice 10).

```
- [ ] 10.2 Detektion: `max(x_dato) - Sys.Date()` med konfigurerbar threshold
```

Mit eget spec-krav (`spec.md:104-106`):
```
The function SHALL be deterministisk: identical input SHALL produce identical output.
```

`Sys.Date()` ændrer sig pr. kalenderdag. Samme `bfh_qic_result` → forskellige features pr.
dag. **Healthcare audit replay umulig** — historisk rapport kan ej re-rendres eksakt.

**Impact:** Silent corruption (audit replay-failure) + golden-snapshot ej reproduktbar.

**Foreslået fix:** Inject `analysis_date` (eller `computed_at`) via metadata eller
`getOption("BFHcharts.analysis_date", Sys.Date())`:

```
- [ ] 10.2 Detektion: `max(x_dato) - analysis_date` hvor analysis_date er
       (a) metadata$analysis_date hvis sat, eller
       (b) getOption("BFHcharts.analysis_date") hvis sat, eller
       (c) Sys.Date() default (med advarsel om non-determinism)
- [ ] 10.2.1 Lagre analysis_date i bfh_spc_analysis$aux for replay
- [ ] 10.2.2 Golden-corpus pin'er analysis_date eksplicit pr. case
```

#### N6 [MEDIUM] — Phase 1.4 parity-corpus 15-20 cases utilstrækkeligt

**Lokation:** `tasks.md:71-78`.

Codex-argument: nuværende dispatch er 8 base + 2 override × 12 action × 2 sprog × target-
formatering × pluralization × trim-position. 15-20 cases dækker ikke matrix; bit-for-bit-
parity-test ville mest debugge formaterings-noise.

Forværrer mit eget H5 (parity-fragility).

**Impact:** Process guard / false-confidence. Phase 1.4 ville passe by coincidence på de
få cases der findes; cut-over til Phase 2 ville fange ægte regressioner i prod.

**Foreslået fix:** Erstat Phase 1.4 task-listen med eksplicit coverage-matrix:

```
- [ ] 1.4.1 Definér coverage-matrix:
       - Alle 8 stability-keys × {target, no-target}
       - no_variation + majority_at_centerline overrides
       - Begge target-direction-grene (numeric, operator)
       - Begge sprog (da, en)
       - Begge percent + non-percent y_axis_unit
       - Trim-boundary-cases (max_chars 100, 200, 375)
       Total: ~60-80 cases dækker matrix
- [ ] 1.4.2 Build golden-corpus via systematisk parameter-sweep
- [ ] 1.4.3 Snapshot-test med eksplicit normalisering-tolerance:
       - Whitespace-normalisering
       - Decimal-separator-normalisering hvis intenderet ændring
       - Trim-position acceptabel inden for ±5 tegn fra base
- [ ] 1.4.4 Semantisk parity-test (clinical reviewer i loop ved tvivl)
```

### Recalibreret samlet fix-strategi

**FØR Phase 0 implementation kan starte, skal proposal revideres på:**

1. **Run-chart confidence-tier** — chart-type-aware regel (N1)
2. **Schema render_context** — eksplicit felt for render-state (N2)
3. **texts_loader-ownership beslutning** — model A (key-only) eller B (eager-render) (N3)
4. **AI baseline_analysis** — rendered character bevares (N4 / M2)
5. **Freshness determinism** — injicér analysis_date (N5)
6. **Coverage-matrix corpus** — ~60-80 cases ej 15-20 (N6 / H5)

**Mine H1-H4 fixes inkorporeres samtidigt:**
- H1: sigma_hat-claim rewords
- H2: "roughly 50+" ej "~52"
- H3: konsolidér 8 vs 10 stability-værdier
- H4: erkend Slice 8 er ny detektion, ej label-udvidelse

**M1 (schema-version):** Vent med beslutning til efter audit-replay-use-case er afklaret
(forbundet til N5).

**Impact-bucketing for Codex-saves:**

| Bucket | Findings | Count |
|--------|----------|-------|
| Hard runtime-regression (havde brudt prod hvis implementeret) | N1 | 1 |
| Silent corruption / contract drift | N2, N4, N5 | 3 |
| Hard backward-compat break | N3 | 1 |
| Process guard / false-confidence | N6 | 1 |
| Recalibrering af min draft | H2 | 1 |

**Reel ROI: Codex caught 4 saves (1 hard + 3 silent) der havde brudt implementation hvis
proposal var gået direkte til Phase 0.**

### Læring

**Dual-review-cycle på proposal-/design-dokumenter (ej kun kode) er valuable.** Mine
empiriske verifikationer dækkede counts + locations men missede **contract-konflikter
mellem ny + eksisterende code-paths**. Codex-prompt der eksplicit beder om
"backward-compat tjek mod eksisterende tests + tests-asserter" fanger denne klasse fund.

Pattern for fremtidige proposal-reviews: spawn code-analyzer for **claim-verification**
(mine 12 claims) + dispatch Codex specifikt på **contract-konsistens mod eksisterende
tests** — to ortogonale verifikations-akser.

### Next steps

1. **Bruger-beslutning:** godkend strategi for N3 (key-only vs eager-render) — påvirker
   schema fundamentalt
2. **Bruger-beslutning:** godkend N5 fix (analysis_date-injection)
3. **Revider proposal.md, design.md, tasks.md, spec.md** med:
   - H1, H2 (recalibreret), H3, H4 fixes
   - N1-N6 fixes
4. **Re-validér** med `openspec validate --strict`
5. **Re-commit** med opsummering af konsekvens
6. **Phase 0 implementation** kan først starte efter revideret proposal

**Pending:** Bruger gennemser dette dokument + svarer på beslutnings-punkter under "Next steps".
