## Why

Klinikere har brug for I'-kontrolkort (I-prime, Taylor) til maaledata og
taelledata hvor naevneren (subgruppe-stoerrelse) skifter mellem punkter —
standard individuals-kort kan ikke justere kontrolgraenser for varierende
naevner. Beregningen findes allerede i `pbcharts::pbc()` fra samme forfatter
(Anhoej) som `qicharts2`, BFHcharts' nuvaerende beregningsmotor.

## What Changes

- Ny `chart_type = "i'"` i `bfh_qic()` der renderer I'-kort med
  naevner-justerede 3-sigma-kontrolgraenser.
- Beregning delegeres til `pbcharts::pbc(chart = "i")` via en intern adapter;
  output mappes til den eksisterende qicharts2-kolonnekontrakt saa hele
  render-/label-/summary-pipelinen genbruges uaendret.
- pbcharts tilfoejes som **optional** afhaengighed (`Suggests:` + `Remotes:`
  GitHub-pin) med runtime-guard — ingen ny haard afhaengighed for brugere
  der ikke bruger I'-kort.
- Notes/annotationer understoettes fuldt paa I'-kort (vedhaeftes via
  x-vaerdi-lookup, da pbc ikke har en notes-parameter).
- Ikke breaking: rent additivt. Eksisterende chart-typer uaendrede.

## Capabilities

### New Capabilities
- `i-prime-chart`: I'-kontrolkort som valgbar chart-type i `bfh_qic()`,
  inkl. pbcharts-adapter (param-mapping, kontrakt-mapping, optional-dependency
  guard, notes-alignment) og statistisk integritets-garanti (pbc's
  kontrolgraenser passerer uroert gennem pipelinen).

### Modified Capabilities
<!-- Ingen. public-api-spec'en enumererer ikke chart-typer som krav, og
     package-config-kravet ("DESCRIPTION SHALL only declare features that
     exist") opfyldes blot af den nye Suggests/Remotes-deklaration uden at
     kravet selv aendres. -->

## Impact

**Kode (BFHcharts):**
- `R/chart_types.R`: `CHART_TYPES_EN` udvides med `"i'"`.
- `R/bfh_qic.R`: branch paa `chart_type == "i'"` foer `build_qic_args()`.
- `R/utils_bfh_qic_helpers.R`: 3 nye interne funktioner
  (`build_pbc_args()`, `invoke_pbcharts()`, `map_pbc_to_qic_data()`).
- Roxygen-doc for `chart_type` + nyt `@examples`-afsnit.

**Dependencies:**
- `DESCRIPTION`: `Suggests: pbcharts` + `Remotes: anhoej/pbcharts@<pin>`.
- pbcharts er pure base-R (ingen transitive afhaengigheder).

**Public API:**
- `bfh_qic()`-signatur uaendret; kun det gyldige vaerdisaet for
  `chart_type` udvides. Ikke-breaking → MINOR version bump.

**biSPCharts (downstream):**
- Ingen tvungen aendring. Kan efterfoelgende eksponere `"i'"` i
  UI-dropdown + bumpe `Imports: BFHcharts (>= NY_VERSION)` i separat PR.

**Statistisk validering:**
- Kraevet: acceptance-test der asserter at `bfh_qic(chart_type="i'")`
  producerer `cl/ucl/lcl` der er `identical` til `pbcharts::pbc()`'s egne
  beregnede vaerdier (ingen silent transformation i pipelinen).
