## Context

BFHcharts beregner i dag alle kort via `qicharts2::qic(return.data = TRUE)` og
funneler resultatet — en data.frame med fast kolonnekontrakt — gennem hele
render-/label-/summary-pipelinen. Integrationen sker ét sted:
`invoke_qicharts2()` i `R/utils_bfh_qic_helpers.R`.

I'-kortet (Taylor) findes i `pbcharts::pbc()` af samme forfatter (Anhoej).
Empirisk verifikation (installeret pbcharts, koert `pbc(plot = FALSE)`,
diffet kolonnesaet, grepet downstream-forbrugere) viser at `pbc()$data` deler
naesten hele qicharts2-kontrakten: begge pakker bruger samme kolonnenavne
(`runs.signal`, `sigma.signal`, `longest.run.max`, `n.crossings.min`, ...).
Kun `n` og `notes` mangler i pbc-output.

pbcharts er pure base-R uden transitive afhaengigheder, men findes kun paa
GitHub (ikke CRAN).

## Goals / Non-Goals

**Goals:**
- Tilfoej `chart_type = "i'"` rent additivt uden at roere eksisterende kort.
- Genbrug hele den eksisterende pipeline ved at mappe pbc-output til
  qicharts2-kontrakten i stedet for at duplikere render-logik.
- Hold pbcharts som optional afhaengighed (CRAN-clean release bevares).
- Fuld notes/annotation-paritet med qicharts2-kort.
- Garantér statistisk integritet: pbc's kontrolgraenser maa ikke transformeres.

**Non-Goals:**
- Facet-paritet (pbc `facet` vs qicharts2 `facet1/facet2`) — guarded, ikke v1.
- `agg.fun` for I'-kort (pbc auto-summer num/den).
- pbc `chart = "ms"` (moving standard deviation).
- UI-arbejde i biSPCharts (separat repo/PR).

## Decisions

### D1: Adapter-seam foer build-step (ikke inde i invoke)

Branch paa `chart_type == "i'"` i `bfh_qic.R` **foer** `build_qic_args()`,
med en parallel `build_pbc_args()` + `invoke_pbcharts()` + `map_pbc_to_qic_data()`
sti der konsumerer de samme captured NSE-symboler.

*Alternativ forkastet:* branch inde i `invoke_qicharts2()`. `qic_args` er paa
det tidspunkt allerede qicharts2-formet (`chart=`, `y=`, `n=`, `part=`), saa
det ville kraeve un-translation tilbage til pbc's `num/den/split` — forkert lag.

### D2: Kontrakt-mapping frem for render-duplikering

`map_pbc_to_qic_data()` tilfoejer kun de 2 manglende kolonner: `n <- den`
(til `export_details`) og `notes` (via x-lookup). Alt andet er kolonne-paritet.

*Rationale:* ~25 linjers mapper vs. ~150 linjers parallel render-sti.
Faar gratis: labels, summary, Anhoej-normalisering, PDF-eksport.

### D3: Denominator-semantik = ratio-kort

pbc beregner altid `y = num/den`. `y_expr → num`, `n_expr → den`. Dokumenteres
eksplicit som p/u-kort-model, ikke `"i"`-model. Manglende `n` → pbc `den = 1`
→ degenererer til individuals (gyldig fallback, `message()` oplyser).

*Alternativ forkastet:* forsoeg paa at bevare `"i"`-semantik (y plottes raat
+ separat den-justering) — ville modarbejde Taylors I-prime-definition og
kraeve egen formel-implementering (bryder D2 + projektets "ingen
kontrolgraense-formler uden statistisk validering").

### D4: Notes via x-vaerdi-lookup

pbc stable-sorterer output paa x og aggregerer ikke multi-row-per-x
(verificeret). Annotationer er en ren BFHcharts-concern (`extract_comment_data()`
laeser kun `qic_data$notes`). Adapter vedhaefter notes via
`lookup[match(qic_data$x, input_x)]` — immun mod pbc's reordering.

*Alternativ forkastet:* positional alignment — usikker pga. pbc's x-sortering.

### D5: Optional dependency (Suggests + Remotes + guard)

pbcharts i `Suggests:` med `Remotes: anhoej/pbcharts@<pin>` + runtime
`requireNamespace`-guard i `invoke_pbcharts()`.

*Alternativ forkastet:* `Imports:` — blokerer CRAN-clean release og tvinger
GitHub-dep paa alle brugere uanset om de bruger I'-kort.

## Risks / Trade-offs

- **pbc upstream-aendring bryder kolonnekontrakt** → Pin Remotes til
  tag/SHA; acceptance-test asserter kontrakt-fuldstaendighed + CL-identitet,
  saa drift fanges i CI.
- **Silent CL-korruption** → Afkraeftet: auto-mean-substitution er hard-gated
  til `chart_type == "run"` (`detect_majority_at_median_per_phase` returnerer
  `integer(0)` ellers). Acceptance-test asserter `identical` CL/UCL/LCL.
- **Multi-note-per-x** → Antagelse "én note pr. x" (universel SPC-praksis);
  lookup tager foerste non-NA. Dokumenteret begraensning.
- **pbcharts ikke paa CRAN** → Optional via Suggests; release forbliver
  CRAN-clean uden pbcharts installeret.
- **Bruger-forvirring `"i"` vs `"i'"`** → Eksplicit roxygen-note om
  ratio-semantik + `@examples`.

## Migration Plan

- Rent additivt; ingen migration for eksisterende kald.
- MINOR version bump + NEWS-entry under `## Nye features`.
- biSPCharts: separat downstream-PR der bumper `Imports: BFHcharts (>= NY)`
  og eksponerer `"i'"` i UI (uden for denne change).
- Rollback: fjern `"i'"` fra `CHART_TYPES_EN` + branch — ingen state/data-effekt.

## Open Questions

- Eksakt Remotes-pin: seneste pbcharts-release-tag vs. fast SHA — afgoeres ved
  implementation (tjek `git ls-remote --tags anhoej/pbcharts`).
