## Why

`at_target`-klassifikationen i `.evaluate_target_arm()` bruger i dag en regel
forankret i target-værdien selv:

```r
tolerance <- max(abs(target_value) * target_tolerance, 0.01)
if (abs(centerline - target_value) <= tolerance) at_target <- TRUE
```

Den absolutte floor på 0.01 — oprindeligt tilføjet for at undgå
`tolerance = 0` ved `target = 0` — dominerer fuldstændigt når target selv er
lille. Resultat: kliniske scenarier hvor centerlinjen ligger **næsten dobbelt
så højt som målet** bliver fejlagtigt klassificeret som "tæt på".

Konkret reproduktion (rapporteret af maintainer):

- `target = "<1%"` (proportionsskala: 0.01), `centerline = 0.019`
- `tolerance = max(0.01 × 0.05, 0.01) = 0.01`
- `|0.019 − 0.01| = 0.009 ≤ 0.01` → `at_target = TRUE`
- Forventet klassifikation: `not_at_target` (CL er 90 % højere end target)

Floor'en har **ingen statistisk begrundelse** — den modellerer ikke processens
variation. Reglen bør i stedet forankres i kontrolgrænserne, som *netop* er
processens naturlige skala. SPC giver os den skala gratis: `UCL − LCL = 6σ̂`
ved 3-sigma-grænser.

## What Changes

**Slice 1 — Statistical at_target rule**

- **MODIFIED** `.evaluate_target_arm()` ([R/spc_analysis.R:735](../../R/spc_analysis.R#L735)):
  erstat den værdineutrale gren (linje 772-790) med tre-vejs cascade:
  1. **Primær (kontrolgrænse-baseret):** `at_target ⟺ |CL − target| ≤ 3·σ̂`,
     hvor `σ̂ = mean((UCL_i − LCL_i) / 6)` over sidste fase af `x$qic_data`.
  2. **Fallback (data-σ-baseret):** Når kontrolgrænser ikke findes (run charts)
     eller `σ̂ = 0`: `at_target ⟺ |CL − target| ≤ sd(y)`.
  3. **Degenereret:** Når både `σ̂ = 0` og `sd(y) = 0`:
     `at_target ⟺ |CL − target| < 1e-9` (eksakt match).
- **MODIFIED** `build_analysis_context()` ([R/spc_analysis.R:209](../../R/spc_analysis.R#L209)):
  tilføj `sigma_hat`-felt til context, beregnet fra `x$qic_data` filtreret til
  sidste fase.
- **MODIFIED** `over_target` / `under_target`: bestemmes nu **uafhængigt af
  tolerance** — rent faktuelt fra `CL` vs `target`. Kun "tæt på"-grenen har
  behov for skala.

**Slice 2 — API deprecation**

- **DEPRECATED** `target_tolerance`-parameter på `bfh_generate_analysis()`:
  argumentet accepteres stadig i signaturen for backward compatibility, men
  fyrer `lifecycle::deprecate_warn()` ved brug. Værdien ignoreres i den nye
  logik. Fjernes endeligt i næste major release.

**Slice 3 — Koblet i18n-justering**

- **MODIFIED** `inst/i18n/da.yaml` og `inst/i18n/en.yaml`: simplificér
  `target.at_target.detailed` til samme tekst som `short` / `standard`.
  Den nuværende formulering "inden for den tolerance der accepteres som
  målopfyldelse" er ikke længere statistisk korrekt under den nye regel —
  tolerancen kommer fra processens egen variation, ikke fra en normativ
  "acceptabel" standard, og value-neutral cascade smugler ikke længere en
  målopfyldelses-værdidom ind.

## Capabilities

### Modified Capabilities

- `spc-analysis-api`: opdater Requirement
  *"build_fallback_analysis SHALL use direction-aware goal logic when target
  direction is known"* — fjern reference til `target_tolerance` som tunable
  parameter; tilføj ny requirement der dokumenterer process-variation-baseret
  regel for value-neutral cascade.

## Impact

**Specs:** 1 spec modified (`spc-analysis-api`).

**Kode:**
- `R/spc_analysis.R`: ~40 linjer ændret i `.evaluate_target_arm()` +
  `build_analysis_context()`.
- `inst/i18n/{da,en}.yaml`: 2 linjer ændret per locale.

**Tests:**
- `tests/testthat/test-spc_analysis.R`: opdater fixtures der nu klassificerer
  anderledes.
- `tests/testthat/test-summary-precision.R`: opdater hvis matchede strenge
  rammer den ændrede klassifikation.
- Nye tests: bounded chart med LCL=0, variable-n p-chart, run chart fallback,
  degenereret sd=0, target præcist på UCL, bug-reproduktion (CL=0.019,
  target=0.01).

**Risiko:** Medium. Klassifikation som `at_target` falder for et undersæt af
small-target/tight-process-cases, hvilket ændrer `action_key`
(`stable_at_target` → `stable_not_at_target` osv.) og dermed analysetekst.
Det er bevidst — adfærdsændringen er en bug-fix, men output ændrer sig.

**Cross-repo (biSPCharts):**
- Analysetekst-output ændrer sig for berørte cases; ingen API-signatur ændres
  funktionelt (signatur er backward-compatible via deprecation).
- Identificeret i diagnose-fasen: biSPCharts' UI sender muligvis `target = "<1%"`
  som `target_value = 0.01` (numerisk) og taber operator-strengen, så
  `target_direction = NULL` på trods af brugerens hensigt. **Out of scope** for
  denne change — håndteres som separat issue i biSPCharts-repoet.

**Out of scope:**
- Revision af `target.over_target.detailed` / `target.under_target.detailed`
  formuleringer — er statistisk korrekte i det reelle værdineutrale tilfælde
  og bevares uændret.
- biSPCharts input-håndtering (operator-stripping).
- Asymmetri-håndtering for bounded charts hvor LCL censoreres til 0 —
  accepteres som kendt let underestimat; revurderes hvis kliniske rapporter
  antyder problem.
