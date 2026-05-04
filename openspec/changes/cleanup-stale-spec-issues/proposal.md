## Why

OpenSpec audit (2026-05-04) afsloerede 3 design-issues i de gennemarbejdede
main specs der kraever koordinerede aendringer:

### 1. `caching-system` refererer fjernet kode

Spec dokumenterer `configure_grob_cache()` + `clear_grob_cache()` som
public helpers. Begge fjernet i v0.5.0 -- kun `marquee_cache` (intern
style-cache i `R/cache_marquee_styles.R`) eksisterer i dag. Spec's
Purpose, alle 4 requirements, og dokumentations-references (e.g.
`docs/CACHING_SYSTEM.md`) refererer til en feature der ikke laengere
findes. Resultat: nye bidragsydere foer-laeser dokumentationsstart i
spec'en og bliver vildledt om paketens caching-strategi.

Yderligere: ingen af de 4 requirements har Scenario blocks (struktur-fejl
flagget af `openspec validate --specs --strict`).

### 2. `code-organization` requirement #7 har urealistisk linje-target

Requirement: `add_right_labels_marquee` SHALL be ≤220 lines.
Faktisk: `R/utils_add_right_labels_marquee.R` = 731 lines.

Filen blev decomposed til 3-layer pattern (orchestrator + named helpers
+ isolation-testable side-effekt-helpers) i change
`2026-05-03-decompose-marquee-labels` -- men 220-line hard cap er en
arbitraer maeleenhed der ikke afspejler den strukturelle vaerdi af
3-layer pattern. Files maa naturligt vaere stoerre naar de indeholder
mange smaa helpers + dokumentation. Hard cap incentiverer fragmentering
til stoerre antal smaa filer (oeget review-cost) frem for at kontrollere
kompleksitet via single-responsibility helpers.

Strukturelle krav (named helpers, dependency injection, cleanup-closures)
er stadig vaerdifulde og skal bevares.

### 3. `public-api` ↔ `spc-analysis-api` har overlappende ejerskab

Tre kontrakter er aktuelt dokumenteret i begge specs:

- `bfh_extract_spc_stats()`-funktionssignaturen
- `bfh_merge_metadata()`-funktionssignaturen
- `cl_user_supplied`-attribute (tilfoejet i 0.16.0)

Overlap er ikke ren duplication -- hvert spec beskriver kontrakter fra
sit perspektiv. Men uden klart afgraenset ejerskab risikerer fremtidige
changes at opdatere et spec og glemme det andet, foreaarsage
inconsistencies.

## What Changes

**Slice 1 -- `caching-system` refit:**

- **MODIFIED** `caching-system` spec Purpose: opdater til at beskrive
  marquee-cache som primaer caching-strategi; fjern referencer til
  grob-cache.
- **REMOVED** `caching-system` requirement der dokumenterer
  `configure_grob_cache()` / `clear_grob_cache()` public helpers
  (funktioner ej i kode siden v0.5.0).
- **MODIFIED** resterende requirements: tilfoej Scenario blocks for at
  daekke marquee-cache lifecycle (cache-key beregning, eviction,
  thread-safety) baseret paa faktisk kode i
  `R/cache_marquee_styles.R`.

**Slice 2 -- `code-organization` #7 line-cap fjernes:**

- **MODIFIED** `code-organization` requirement #7 ("Label-pipeline
  orchestrators SHALL follow 3-layer decomposition"): fjern hard
  220-line cap; bevar krav om named helpers, isolation-testbarhed, og
  cleanup-closure-pattern. Tilfoej eksplicit guidance: orchestrator-
  rolle handler om _ansvar_, ikke linje-tal -- target er at undgaa
  inline kompleksitet (geometry-resolution, device-acquisition,
  measurement) i orchestrator, ej at maeke samlet fil-stoerrelse.

**Slice 3 -- spec-boundary cleanup mellem `public-api` og `spc-analysis-api`:**

- **MODIFIED** `public-api` Purpose: praeciseret som ejer af
  user-facing API contracts (signaturer, eksport-status, return-types,
  attribute-existence).
- **MODIFIED** `spc-analysis-api` Purpose: praeciseret som ejer af
  internal signal-detection logic (Anhoej rules, fallback-narrative
  dispatch, threshold semantics).
- **REMOVED** redundant kontrakt-dokumentation:
  - `spc-analysis-api`: fjern signatur-detaljer for
    `bfh_extract_spc_stats()` og `bfh_merge_metadata()` (ejes af
    public-api).
  - `public-api`: fjern Anhoej-signal interpretations-detaljer
    (ejes af spc-analysis-api).
- **MODIFIED** krydsreferencer: hver spec bevarer en kort "See X spec
  for Y"-reference hvor det er nyttigt.

## Capabilities

### Modified Capabilities

- `caching-system`: refit til marquee-cache only.
- `code-organization`: req #7 line-cap fjernes; strukturelle krav
  bevares.
- `public-api`: ejer user-facing API contracts.
- `spc-analysis-api`: ejer internal signal-detection logic.

## Impact

**Specs:** 4 specs modified, ingen nye specs.

**Kode:** Ingen kode-aendringer.

**Tests:** Ingen test-aendringer (specs beskriver _kontrakter_, ikke
implementation; faktisk kode er allerede paa plads og bestaaet
2995-test-suite).

**Risiko:** Lav. Aendringer er rent dokumentations- og kontrakt-
oprydning. Ingen API-aendringer, ingen behavior-aendringer.

**Cross-repo:** Ingen impact paa biSPCharts.

**Out of scope:**
- pdf-smoke.yaml comment-refresh (Phase 1 #14, blokeret af pre-tool-use
  hook -- separat manuel opgave).
- code-organization: hvorvidt `add_right_labels_marquee.R` _faktisk_
  matcher den nye strukturelle definition (audit-opgave for
  implementation-PR; specs definerer kun kontrakten).
- batch session regression tests (Phase 1 #5, allerede landet i PR
  #302).
