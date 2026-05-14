## Context

`at_target`-klassifikationen anvendes i den **værdineutrale gren** af analyse-
tekst-cascade — dvs. når brugeren har angivet et target uden retnings-operator
(`<=`/`>=`/`<`/`>`). Tekstvalget mellem `at_target` / `over_target` /
`under_target` driver downstream-valg af `action_key` (`stable_at_target` vs
`stable_not_at_target` osv.), så en forkert klassifikation propagerer ind i
hele den anbefalede handling.

Den nuværende regel blev introduceret med refactor 70254f1
(`extract .evaluate_target_arm()`) og bygger på en *relativ-til-target* model:
tolerancen er en procent af target-værdien (`target_tolerance × |target|`), med
en absolut floor på `0.01` for at undgå tolerance = 0 ved `target = 0`.

Designet rammer en kant-case som vi har en reproducer for:

- target på proportionsskala (fx 0.01 = "1 %")
- centerlinje væsentligt forskellig fra target (fx 0.019)
- absolut floor (0.01) er **større** end den naturlige relative tolerance
  (0.01 × 0.05 = 0.0005) — floor'en dominerer
- forskellen `|CL − target| = 0.009` er mindre end floor'en → klassificeres som
  `at_target` på trods af at CL er næsten dobbelt så høj som målet.

Den underliggende design-fejl: tolerance-skalaen er afkoblet fra processens
egen variation. SPC giver os processens variation gratis via kontrolgrænserne
(`UCL − LCL = 6σ̂` ved 3-sigma-grænser), men den ressource udnyttes ikke.

**Stakeholders:**
- BFHcharts maintainer (Johan Reventlow) — har rapporteret bug-scenariet og
  ejer både BFHcharts og biSPCharts.
- biSPCharts: konsumerer `bfh_generate_analysis()` til analysetekst i
  Shiny-app'en. Påvirkes af output-ændring (men ikke API-ændring).
- Kliniske brugere: ser analysetekst i PDF-eksporter og UI; nuværende fejl-
  klassifikation kan give vildledende anbefalinger ("fortsæt nuværende
  praksis" når processen ikke når målet).

**Constraints:**
- Adfærdsændring i `bfh_generate_analysis()`-output — bevidst, men kræver
  NEWS-entry og forventet test-suite-update.
- API-signatur bevares bagudkompatibel: `target_tolerance`-parameter accepteres
  stadig men ignoreres efter deprecation warning.
- Ny logik må ikke ramme retningsbevidst gren (`goal_met` / `goal_not_met`) —
  den fortolkning er allerede statistisk korrekt og berøres ikke.
- Pre-1.0 (`0.16.x`): output-ændring i analysetekst udløser minor bump per
  `VERSIONING_POLICY.md`; ikke major.

## Goals / Non-Goals

**Goals:**
- `at_target` klassificerer kun når CL er statistisk forenelig med target —
  målt på processens egen variationsskala.
- Reglen reducerer trivielt til `LCL ≤ target ≤ UCL` ved konstante 3-sigma-
  grænser, hvilket matcher SPC-konvention.
- Run charts og degenererede tilfælde har veldefineret fallback uden ad-hoc
  magic numbers.
- API-signatur bevares funktionelt (parameter accepteres, deprecation
  flagges).
- Klinisk bug-scenarie (target = 0.01, CL = 0.019, tight limits) klassificeres
  korrekt som `not_at_target`.

**Non-Goals:**
- Tilføje en konfigurerbar k-multiplikator. k=3 er hardcoded for at matche SPC-
  konvention og fjerne et magisk tal — ikke for at give finjustering.
- Revurdere retningsbevidst gren (`goal_met` / `goal_not_met`). Den
  fortolkning er korrekt og berøres ikke.
- Asymmetri-håndtering for bounded charts (p/u med LCL=0). Aksepteres som
  kendt let underestimat af σ̂ nær 0-grænsen.
- Revision af `over_target.detailed` / `under_target.detailed`-formuleringer.
  De er statistisk korrekte i det reelle værdineutrale tilfælde.
- Diagnose/fix af biSPCharts' operator-stripping. Out-of-scope (separat issue i
  biSPCharts).

## Design Decisions

### Decision 1: Use mean(UCL_i − LCL_i)/6 over last phase as σ̂

**Alternativer overvejet:**

1. **Mean half-width** (`mean((UCL_i − LCL_i) / 6)`) — **valgt**
2. Bredeste bånd (`min(LCL), max(UCL)`)
3. Smalleste bånd (`max(LCL), min(UCL)`)
4. Median half-width

**Begrundelse:** Mean er den eneste der reducerer **trivielt** til konstant-
case-reglen `LCL ≤ target ≤ UCL` når grænserne er konstante (`mean = value`
ved konstante data). Det giver os en enkelt regel der virker for både
fixed-n og variable-n charts uden case-distinktion. Bredeste/smalleste bånd
introducerer afhængighed af subgruppe-størrelsesfordeling der ikke afspejler
"typisk" processpredning. Median er robust mod outliers men mister information
om uneven spread.

### Decision 2: Three-tier cascade (controlled / sd / exact)

**Alternativer overvejet:**

1. **Tre-vejs cascade** (kontrolgrænse-baseret → sd-baseret → eksakt) — **valgt**
2. To-vejs (drop `at_target` helt når kontrolgrænser mangler)
3. Bevar relativ regel som fallback (samme fejl, mindre)

**Begrundelse:** Run charts udgør en signifikant brugskategori. At droppe
`at_target` helt (option 2) mister legitim information — "CL = 1.9 % vs
target = 1 %" er en faktuel observation man rimeligt kan forvente at se. Men
kontrolgrænser findes ikke for run charts, så vi kan ikke bruge primær-reglen.
`sd(y)` over sidste fase er det eneste statistisk meningsfulde fallback der
ikke kræver SPC-antagelser. Eksakt-match-fallback (tier 3) handler om
degenererede tilfælde (konstant y, n=1) hvor sd=0; uden det ville `0 ≤ 0`
være evergreen.

### Decision 3: Bevar `target_tolerance` i signatur men ignorér med deprecation

**Alternativer overvejet:**

1. **Behold, ignorér, fyr `deprecate_warn`** — **valgt**
2. Fjern parameter helt (breaking API change)
3. Genfortolk semantisk (k = `target_tolerance × 60` — forvirrende)

**Begrundelse:** Eksisterende kaldere (biSPCharts, eksempelkode) kan have
hardcoded `target_tolerance = 0.05`. At fjerne parameter ville give
`unused argument`-fejl uden forudgående advarsel. `deprecate_warn()` giver
glidende migration: parameter forsvinder først i næste major release. Option 3
afvist fordi parameter-navnet ville lyve om semantikken (nu sigma-baseret, ikke
proportions-baseret).

### Decision 4: over/under_target er rent faktuelle (ingen tolerance)

Under den nye logik er `over_target` / `under_target` bestemt af `CL > target`
hhv. `CL < target` — uden tolerance. Kun "tæt på"-grenen kræver skala. Det
betyder boundary-tilfælde (`CL` præcist på `target`) klassificeres som
`at_target` (via tier 3 eksakt-match), aldrig som `over_target`/`under_target`.

### Decision 5: Koblet i18n-ændring — `at_target.detailed` simplificeres

Den nuværende `at_target.detailed`-formulering ("inden for den tolerance der
accepteres som målopfyldelse") implicerer (a) en normativ standard for
acceptabel afvigelse og (b) en målopfyldelses-værdidom. Begge brydes af den
nye regel:

- (a) Tolerancen kommer fra **processens variation**, ikke fra en accepteret
  norm.
- (b) Value-neutral cascade undgår bevidst værdidomme om hvorvidt det er godt
  eller skidt at ligge tæt på målet — det er hele pointen med at skille fra
  `goal_met` / `goal_not_met`.

Simplifikation til samme tekst som `short`/`standard` ("Niveauet ligger tæt på
målet ({target}).") undgår begge problemer. Detailed-varianten bliver
funktionelt identisk med de korte — accepteret som tab af nuance i denne
gren.

## Risks / Trade-offs

**Risiko 1: Test-suite-bredde**

Mange tests matcher konkrete strenge der dækker `at_target`-grenen.
Klassifikation kan skifte for et bredt undersæt af scenarier, ikke kun den
specifikke bug-reproducer. Mitigation: kør hele test-suite, identificer alle
tests der nu fejler pga. ændret klassifikation, gennemgå hver enkelt for at
verificere at ny klassifikation faktisk er den statistisk korrekte.

**Risiko 2: Klinisk regression for bredt-spredte processer**

For processer med meget vid variation (UCL−LCL stor) bliver tolerancen
tilsvarende stor, hvilket kan klassificere CL som `at_target` selv når CL og
target ligger relativt langt fra hinanden. Det er imidlertid statistisk
korrekt: hvis processen er så ustabil, kan vi ikke statistisk adskille CL fra
target. Det matcher pointen med at sige "tæt på" — det er ikke en præcision-
udsagn men et statistisk indistinguishability-udsagn.

**Risiko 3: Bounded chart asymmetri**

For p/u-charts med CL nær 0 censoreres LCL til 0, hvilket gør `(UCL−LCL)/6`
til et let underestimat af sand σ̂. Praktisk betydning er begrænset: når CL er
nær 0 er target også typisk nær 0, og forskellene `|CL − target|` er små.
Accepteres som kendt begrænsning; revisiteres hvis kliniske rapporter
antyder problem.

**Risiko 4: biSPCharts operator-stripping**

Vi opdagede i diagnose-fasen at "<1%" sat via biSPCharts-UI tilsyneladende mister
sin operator inden BFHcharts. Det betyder den værdineutrale gren rammes oftere
end forventet. **Out of scope** for denne change, men bemærk at den nye regel
faktisk **forbedrer** opførslen i præcis det scenarie — operatoren burde
være parset, men selv uden operator giver den nye regel nu korrekt
klassifikation for små targets.

## Migration Plan

1. Implementér ny regel i `.evaluate_target_arm()` + udvid context med
   `sigma_hat`-felt.
2. Tilføj `deprecate_warn()` ved `target_tolerance`-brug.
3. Kør test-suite, identificer alle tests der nu fejler pga. ændret
   klassifikation.
4. For hver fejlende test: verificer at ny klassifikation er statistisk
   korrekt, opdater forventet streng.
5. Tilføj nye tests for edge cases (variable-n, run chart, sd=0, bounded
   chart, bug-reproducer).
6. Opdater `inst/i18n/{da,en}.yaml`: simplificér `at_target.detailed`.
7. Opdater `NEWS.md` med adfærdsændring + eksempel.
8. Update `openspec/specs/spc-analysis-api/spec.md` med ny requirement +
   modificeret eksisterende requirement.
9. Notificer biSPCharts-maintainer (Johan Reventlow) om output-ændring.
