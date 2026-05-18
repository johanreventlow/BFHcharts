# ADR-003: Structured SPC Analysis Architecture

Status: Accepted (per openspec change `restructure-spc-analysis-architecture`, archived 2026-05-18)

## Kontekst

`bfh_generate_analysis()` (pre-Phase-2) implementerede SPC-analyseteksten
som monolitisk cascade-dispatch: én funktion samlede signal-detection,
target-evaluering, action-valg og rendering i samme call-path via
`build_fallback_analysis()`. Dispatch-rummet bestod af ~50 effektive
output-kombinationer (10 stability × ~5 action-paths × target-presence).

Eksisterende corpus (`inst/i18n/da.yaml`) var teknisk komplet ift. de
nøgler kode kunne vælge, men havde 12 strukturelle huller mod fagligt
nødvendige SPC-fortolkninger:

1. Retning på forandring (favorable/unfavorable)
2. Fase-/interventionsfortolkning
3. Chart-type-specifik fortolkning
4. Datakvalitet/evaluerbarhed
5. Historiske outliers
6. Baseline-delta ved part >= 2
7. Sigma-shift magnitude som prose-modifier
8. Direction uden eksplicit target
9. CL-disclosure i prose (ej kun PDF-sidebar)
10. Anhøj-not-evaluable som dispatch-sektion
11. Data-freshness
12. Trend vs step

Naivt fix (tilføj nøgler til cascade-dispatchen) ville producere
multiplikativ matrix-eksplosion: ~50 paths × 12 nye dimensioner →
tusinder af kombinationer. Vedligehold og klinisk validering bliver
uigennemførligt.

## Beslutning

**Tre-lags arkitektur**: feature-extraction → composition → render.
**Key-only model**: struktureret analyse-objekt er primær output, ren
tekst er én af flere views.

```
bfh_qic_result + metadata
  → bfh_extract_spc_features()       (R/spc_features.R)
                                     pure deterministisk, 12 akser
  → bfh_analyse()                    (R/spc_compose.R, EXPORTED)
                                     i18n-nøgler, ej resolverede strings
  → bfh_render_analysis(texts_loader)  (R/spc_render.R, EXPORTED)
                                     character output, sprog-aware
```

`bfh_generate_analysis()` bibeholdes som backward-compat-wrapper med
uændret public-signatur — internt delegerer til ny pipeline.

### Composition-cascade (kanonisk prioritets-rækkefølge)

1. **Blocking caveats** (erstatter base):
   - `not_evaluable` (n < N_MIN) eller manglende centerline/sigma
   - `no_variation` (konstant data) — overrider low-confidence
   - `discrete_scale = extreme` (majority_at_centerline)
2. **Base sentence** (stability_pattern, 10 værdier)
3. **Modifier-pool** (aktiveres hvis ikke override eller low-confidence):
   - `magnitude_clause` (Slice 3) — "~X% forandring"
   - `direction_clause` (Slice 4) — "i den ønskede retning"
   - `baseline_delta_clause` (Slice 5) — "flyttet fra X til Y"
4. **Target clause** (eksisterende target-arm, retning-aware)
5. **Action clause** (eksisterende action-arm)
6. **Tail-caveats** (fast prioritet):
   - `cl_source_caveat` (Slice 9)
   - `discrete_scale_caveat` (mild/moderate, Slice 14)
   - `variable_cl_caveat` (Slice 7)

### Determinisme + analysis_date-injection

`bfh_extract_spc_features()` SKAL være deterministisk: samme input +
metadata producerer altid samme output. `analysis_date` injiceres via
3-vejs præcedens for at undgå `Sys.Date()`-afhængighed:

1. `metadata$analysis_date` (eksplicit per-call)
2. `getOption(BFHCHARTS_OPT_ANALYSIS_DATE)` (global override, til tests)
3. `Sys.Date()` (production-default)

Audit-replay (re-rendre arkiveret rapport 6 mdr senere) kræver pinned
`analysis_date`.

### Chart-type-aware confidence-tier (kritisk N1-fix)

Run-charts har `sigma_hat = NA` by design (ingen kontrolgrænser).
`is.na(sigma_hat)` alene UDLØSER IKKE `confidence_tier = low` — det
ville fejlmarkere 24-punkt run-charts som not_evaluable.

Korrekt regel (R/spc_features.R `.compute_confidence_tier`):

```
low:    n_points < N_MIN (12) OR ingen centerline OR
        BÅDE sigma_hat OG sigma_data er NA/zero
medium: n_points in [12, 19] AND finite spread-estimat
high:   n_points >= 20 AND finite spread-estimat
```

Spread-estimat: `sigma_hat` (control-charts) eller `sigma_data` (run-charts).

### Backward-compat strategi

- `bfh_generate_analysis()`-signatur uændret (10 parametre + default-værdier).
- `bfh_build_analysis_context()`, `.detect_signal_flags()`,
  `.select_stability_key()`, `.select_action_key()`,
  `.evaluate_target_arm()`, `.allocate_text_budget()` bevares som
  intern API gennem mindst ét major-release-cycle.
- `build_fallback_analysis()` markeret `@keywords internal @noRd`
  som backward-compat-layer; fjernes i næste major release.
- 14 parity-tests bekræftede semantic match mellem ny pipeline +
  pre-Phase-2-build_fallback_analysis ved cut-over.

## Konsekvenser

### Positive

- **Klinisk-faglig dækning** af 7 nye fortolknings-dimensioner per
  bruger-godkendt INCLUDE-liste (Slice 3, 4, 5, 7, 8, 9, 14).
- **Skalerbar** tilføjelse af nye dimensioner uden cascade-refactor.
- **Audit-spor** for klinisk regulering — features → tekst-valg er
  inspicerbart via struktureret `bfh_spc_analysis`-objekt.
- **Genbrug**: PDF-eksport, app-UI, AI-prompt, JSON-export, audit-log
  deler samme strukturerede objekt.
- **Bilingual parity** som design-egenskab via 99.3 CI-gate
  (placeholder-paritet + KNOWN_DIVERGENCES-whitelist).
- **Schema-stability** via 99.4 tests + downstream consumer-simulering.

### Negative

- **~2700 LOC tilføjet** (R/spc_features.R + spc_compose.R +
  spc_render.R + spc_analysis_class.R + utils_analysis_date.R +
  tests).
- **Per-call overhead +26-37%** (~0.4 ms) vs pre-Phase-2 monolitisk
  cascade. Irrelevant for Shiny/PDF-render-envelope (10-100 ms / sekunder).
- **i18n-corpus dobbelt-sporet**: gammel cascade-key-struktur bevaret
  for backward-compat + ny modifier-sektion. Konsolideres i næste
  major release.
- **Schema-version** vedligehold: `bfh_spc_analysis$schema_version`
  evolveres uafhængigt af pakke-version.

### Risici og mitigation

| Risiko | Mitigation |
|--------|------------|
| Parity-test fanger ikke subtile output-aendringer | Snapshot-corpus i tests/_snaps/spc_golden_corpus.md fanger drift på 12 baseline-cases |
| Modifier-interaktion giver inkoherent prose | Cascade-rækkefølge dokumenteret + testet pr. kombination |
| Klinisk corpus drift fra implementation | Bilingual parity-test + KNOWN_DIVERGENCES-whitelist; klinisk reviewer-loop deferreres |
| Schema-bump breaker downstream | `bfh_spc_analysis$schema_version` semver + downstream simuleret i 99.4 tests |
| Bilingual parity bryder | Test-suite tjekker placeholder-paritet + nøgle-paritet; CI-gate |

### Implementations-omkostning

- Phase 0-2 (foundation + core refactor + cut-over): ~3 dages udvikling
- Phase 3+ (7 INCLUDE-slices): ~4 dages udvikling
- Phase 99 (validation infrastructure): ~1 dags udvikling

Total: ~8 dages udvikling. 16 commits over 1 udviklings-cycle.

## Alternatives Considered

### A. Patch-cascade (afvist)

Tilføj nye nøgler til eksisterende cascade-dispatch.
- Multiplikativ matrix-eksplosion (tusinder af kombinationer)
- YAML-corpus uvedligeholdelig
- Hver ny dimension kræver dispatch-refactor

### B. LLM-only (afvist)

Erstat templates med BFHllm-kald.
- Healthcare kræver determinisme + audit-spor
- AI kan hallucinere statistiske påstande
- Privacy-følsom: kræver data_consent + DPA
- Eksisterende `use_ai = TRUE` bevares som polering, ej erstatning

### C. Atomisk sætnings-bibliotek (delvist adopteret)

Bibliotek af korte fakta-sætninger; render plukker per feature.
- Modifier-clauses ER atomiske (tail-caveats, magnitude, direction)
- Base + target + action bevares som strukturerede templates for
  prose-koherens

### D. Multi-pass refinement (afvist)

Pass 1: skelet; Pass 2: enrichment; Pass 3: polering.
- Mod-deterministisk
- Test-strategi kompleks

## References

- Openspec change: `openspec/changes/archive/2026-05-18-restructure-spc-analysis-architecture/`
  (proposal.md + design.md + tasks.md + specs/)
- Review: `docs/reviews/03-structured-spc-analysis-proposal-2026-05-17.md`
  (dual-review-cycle: Claude + Codex)
- Archived predecessor: `2026-05-15-goal-direction-tolerance` (direction-aware
  dispatch præcedens)
- Archived predecessor: `2026-05-14-at-target-tolerance-process-variation`
  (sigma-baseret tolerance — fundament for confidence-tier)
- Anhøj J, Olesen AV (2014). Run charts revisited: a simulation study of
  run chart rules for detection of non-random variation in health care
  processes. *PLoS One*. 9(11):e113825. (kilde til N_MIN = 12)

---

**Dato:** 2026-05-18
