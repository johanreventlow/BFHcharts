## Context

OpenSpec audit (2026-05-04) gennemgik 7 main specs (totalt 64
requirements) og fandt 5 issues. To er allerede haandteret (Phase 1):

- pdf-smoke.yaml comment-refresh: deferred (hook-blokeret)
- batch session regression tests: tilfoejet i PR #302

Resterende 3 issues kraever koordinerede design-aendringer der
beroerer flere specs og potentielt har downstream-konsekvenser hvis
forkert haandteret. Bundles i en enkelt OpenSpec change for at:

1. Sikre at boundary-redefinitioner mellem specs (#3) ikke giver
   inconsistencies hvis kun delvist landet.
2. Reducere review-overhead -- hver enkelt issue er smaa, men de
   beroerer beslaegtede specs.
3. Levere komplet "spec hygiene"-state efter merge.

Stakeholders:
- BFHcharts maintainer (Johan Reventlow) -- ejer alle specs.
- Fremtidige bidragsydere -- specs er primaer kontekst-kilde for nye
  changes; misvisende dokumentation oeger onboarding-cost og introducer
  risk for incorrect change-proposals.

Constraints:
- Ingen kode-aendringer (specs beskriver kontrakter; faktisk kode er
  allerede correct).
- Pre-1.0 (`0.16.0`); spec-aendringer udloeser ej version bump per
  `VERSIONING_POLICY.md` §A (kun adfaerd/API udloeser bump).
- Skal validere `openspec validate --specs --strict` 7/7 efter merge.

## Goals / Non-Goals

**Goals:**
- `caching-system` afspejler aktuel kode (marquee-cache only).
- `code-organization` #7 har mening for fremtidige bidragsydere
  (strukturelle krav, ikke linje-tal).
- `public-api` ↔ `spc-analysis-api` har klart afgraenset ejerskab uden
  indholdsduplication.
- Alle specs har komplete Scenario blocks per
  `openspec validate --strict`.

**Non-Goals:**
- Refactor `add_right_labels_marquee.R` til ≤220 lines (line-cap
  fjernes, faktisk fil-struktur er allerede 3-layer).
- Fjern `caching-system` spec helt (ville miste design-rationale for
  marquee-cache; refit er bedre).
- Tilfoej nye public-api-funktioner.
- Hard rename mellem `public-api` og `spc-analysis-api` (begge specs
  bevares; kun ejerskab praeciseret).

## Decisions

### D1 -- `caching-system` refit, ej retire (Slice 1)

`caching-system` spec bevares fordi `marquee_cache` er en bevidst
design-beslutning med performance-impact (label-rendering hot path).
Spec'en er det sted hvor invarianter (cache-key beregning, eviction-
politik, thread-safety) skal dokumenteres for fremtidige bidragsydere.

**Rationale:**
- Retire ville miste design-rationale.
- Refit er enklere -- fjern obsolete grob-cache-references, tilfoej
  Scenario blocks for marquee-cache baseret paa faktisk kode.
- `R/cache_marquee_styles.R` er ~50 LOC med simpel API; spec-vedlige-
  hold er minimalt.

### D2 -- `code-organization` #7 line-cap fjernes, strukturelle krav bevares (Slice 2)

220-line hard cap er arbitraer. Vaerdien af 3-layer pattern er
strukturel:

- **Orchestrator:** parameter binding, helper invocation pipeline-
  rakkefolge, result aggregation. Ingen inline geometry-resolution,
  device-acquisition, measurement.
- **Named helpers:** `@keywords internal @noRd`-praefiks `.`, single
  responsibility, dependency-injected.
- **Cleanup-closures:** side-effekt-helpers returnerer cleanup-fn
  bundtet via `on.exit(..., add = TRUE)`.

`R/utils_add_right_labels_marquee.R` (731 lines) opfylder denne
struktur med 13+ named helpers. 220-line hard cap er en historisk
maaling der ikke afspejler kompleksitet -- den incentiverer fragmen-
tering til flere filer (oeger review-cost) frem for at kontrollere
kompleksitet inde i en fil.

**Rationale:**
- Strukturel vurdering kan formuleres som krav (ingen inline
  device-acquisition).
- Linje-tal er konsekvens af helper-mengde, ikke kompleksitet.
- Fremtidige bidragsydere kan vurdere om en orchestrator passer
  modellen uden at tjekke `wc -l`.

### D3 -- spec-boundary praeciseret, ej hard split (Slice 3)

`public-api` og `spc-analysis-api` er beslaegtede men ortogonale:

| Concern | Owner |
|---|---|
| Hvad eksporterer paketten? | public-api |
| Hvad er signature/return-type? | public-api |
| Hvilke attributes/contracts laever output? | public-api |
| Hvad betyder Anhoej-signaler? | spc-analysis-api |
| Hvordan dispatcher fallback-narrative? | spc-analysis-api |
| Hvordan computer-resolveres target-direction? | spc-analysis-api |

**Rationale:**
- `public-api` er stable surface -- aendringer kraever MAJOR/MINOR bump.
- `spc-analysis-api` er semantic interpretation -- aendringer kan
  vaere subtilere (e.g. tweaks i tolkning af crossings).
- Tre specifikke kontrakter (`bfh_extract_spc_stats()` signatur,
  `bfh_merge_metadata()` signatur, `cl_user_supplied`-attribute)
  beroerer begge concerns -- per-spec-rolle afgoer hvor de doku-
  menteres.
- Krydsreferencer ("See X for Y") sikrer at laesere finder vej uden
  at indholdet duplikeres.

## Risks / Trade-offs

**Risk 1: Spec-boundary praecisering misforstaas som breaking change.**
Spec-aendringer er rent dokumentation -- ingen kode-aendringer, ingen
adfaerds-aendringer. Aendringerne reducerer fremtidig review-friction
men har ingen runtime-impact. NEWS.md vil bemaerke spec-cleanup.

**Risk 2: Marquee-cache invarianter dokumenteres forkert.**
Mitigation: implementations-PR validerer mod faktisk kode i
`R/cache_marquee_styles.R` ved tilfoejelse af Scenario blocks.

**Risk 3: code-organization #7 fortolkes for laxt uden line-cap.**
Mitigation: kvalitative krav er normative ("orchestrator SHALL NOT
contain inline X"). Fremtidig review kan nemt vurdere om en orchestra-
tor matcher modellen.

**Trade-off: Bundlet vs separate proposals.**
Bundlet: en review-cyklus, koordinerede deltas. Separat: smallere
diffs, but tre review-cycler for low-impact aendringer.
*Decision:* Bundlet -- alle slices er rent dokumentation, lav risk,
faelles audit-context.

## Migration Plan

1. Land i feature-branch `chore/cleanup-stale-spec-issues`.
2. Aben PR mod develop.
3. Verify CI green (R-CMD-check, lint, test-coverage).
4. Verify `openspec validate --specs --strict`: 7/7.
5. Merge til develop. Ingen tag, ingen NEWS-entry udover en kort
   "Internal: spec hygiene" note (specs paavirker ikke API-version).
6. Cross-repo: ingen biSPCharts-impact.

## Open Questions

- **Q1:** Skal `caching-system` spec slettes hvis marquee-cache
  i fremtiden ogsaa fjernes?
  *Tentative answer:* Yes -- spec lever saa laenge cachen er en
  bevidst design-beslutning. Naar koden fjernes, retire spec via
  proposal med `## REMOVED Capabilities` section.

- **Q2:** Burde `code-organization` #7 erstattes af en helt ny
  formulering, eller skal den modificeres in-place?
  *Tentative answer:* Modify in-place. Identiteten ("3-layer
  decomposition") bevares; kun maaling-mekanismen aendres fra "lines"
  til "structural attributes".

- **Q3:** Krydsreferencer mellem `public-api` og `spc-analysis-api` --
  formelt link eller prose-reference?
  *Tentative answer:* Prose ("See spc-analysis-api Requirement: X for
  Y"). OpenSpec har ikke et formelt cross-spec-link-system, og prose
  laekker ej ved versionering af aendringer.
