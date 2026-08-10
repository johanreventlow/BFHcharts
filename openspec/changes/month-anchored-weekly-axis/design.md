# Design: month-anchored-weekly-axis

## Context

Formatteringskaeden for temporale x-akser er i dag:

1. `detect_date_interval()` (`R/utils_date_formatting.R`) klassificerer
   median-interval → `"daily" | "weekly" | "monthly" | ...`
2. `get_optimal_formatting()` vaelger label-format
   (`scales::label_date_short()`) + break-spec pr. interval-type/n_obs.
3. `calculate_date_breaks()` (`R/utils_x_axis_formatting.R`) genererer
   breaks — men **ignorerer** `format_config`-parameteren og bruger altid
   interval-typens egen enhed: uge-data faar `ugestart + k x interval`,
   hvor multiplier k ∈ {2, 4, 13} vaelges saa antal breaks <= 15
   (`calculate_interval_multiplier()`).
4. `apply_temporal_x_axis()` saetter scale via
   `BFHtheme::scale_x_datetime_bfh()` (passer `...` videre til ggplot2) og
   locale-wrapper labels via `with_lc_time_labeler()`.

Konsekvens: 37 ugers data → 4-ugers breaks → labels paa vilkaarlige
maanedsdage. Linje 193-196 forcerer desuden et break paa praecis
`data_x_min`, som typisk ligger off-grid.

### Empirisk baseline (maalt 2026-08-10, ggplot2 4.0.3)

Kun tre interval-typer forekommer i praksis: **daily, weekly, monthly**
(bekraeftet af bruger). Faktisk output fra nuvaerende kode:

| Case | Breaks i dag | Problem |
| ---- | ------------ | ------- |
| weekly 37 obs (PDF-casen) | `01-dec, 28-dec, 25-jan, 22-feb, 22-mar, ...` | 27-dages-step, skaeve maanedsdage |
| weekly 104 obs | `01-jan-24, 31-mar, 30-jun, 29-sep, 29-dec, 30-mar-26` | 13-ugers-step = 91d ≠ kvartal → glider ~3d/aar bagud |
| weekly 16 obs | 18 breaks (step 6d/7d), **2 breaks efter data-max** | overshoot; se D9 |
| daily 120 obs | `01-jan, 09-jan, 17-jan, 25-jan, ...` (8-dages-step) | 16 breaks, skaeve datoer |
| daily 60 obs | 4-dages-step, 16 breaks | samme defekt i "medium daily"-branchen |
| daily 30 obs | 2-dages-step, 16 breaks | samme defekt i "short daily"-branchen |
| monthly d. 1. | `01-jan-25, 01-apr, 01-jul, 01-okt, ...` | **allerede korrekt** — kalenderforankret |
| monthly d. 15. | `15-jan-25, 01-apr, 01-jul, ...` | kun foerste break off-grid (force-first-break) |

Fire fund der aendrer scope ift. foerste udkast:

1. **Daily er lige saa ramt som weekly** — alle tre daily-branches
   (`< 30`, `30-89`, `>= 90` obs) producerer skaeve dags-multipla, ikke kun
   `>= 90`. Daily loeftes derfor fra "sidegevinst" til foersteklasses scope.
2. **Monthly er stort set korrekt allerede** — `round_to_interval_start()`
   floorer til maanedsstart og `seq(by = "N months")` bruger aegte
   kalendermaaneder. Kun force-first-break skaber et off-grid startbreak.
   Monthly behoever derfor *ikke* ny break-sti, kun D8-fixet.
3. **`round_to_interval_start(x, "weekly")` bruger soendag** som ugestart
   (lubridate-default; `getOption("lubridate.week.start")` er unset).
   Mandags-data floores til foregaaende soendag. Ramte hidtil kun
   startpunktet; med eksplicitte uge-minor-ticks bliver det synligt.
4. **Break-overshoot**: for weekly genereres breaks til
   `ceiling_date(max, "week") + interval`, hvilket giver op til 2 breaks
   *efter* sidste datapunkt (maalt: 18 breaks for 16 ugers data).

Verificerede forudsaetninger:
- ggplot2 4.0.3 installeret; `guide_axis()` har `minor.ticks`-parameter og
  `axis.minor.ticks.length.x.bottom` findes i element-treet.
- `scale_x_datetime_bfh(...)` accepterer `minor_breaks`/`guide` via dots.
- **`DESCRIPTION` har `ggplot2 (>= 3.4.0)`** — skal bumpes til `>= 3.5.0`.

## Goals / Non-Goals

**Goals:**

- Kalenderforankrede, forudsigelige break-positioner for **daily og weekly**
  data over threshold: major = maanedsstarter, minor = ugestarter.
- Bevar det hierarkiske "kun det noedvendige"-label-udtryk
  (`label_date_short`: aar ved foerste label + aarsskifte).
- Fix den doede `format_config`-branch saa break-unit-intentioner i
  `get_optimal_formatting()` faktisk honoreres.
- Fjern off-grid startbreak for **alle** interval-typer (rammer ogsaa
  monthly-data der ikke ligger paa d. 1.).
- Uaendret adfaerd for korte serier under threshold.

**Non-Goals:**

- Minor-ticks paa monthly-serier (kun daily/weekly i v1).
- Aendringer i BFHtheme (minor-tick-styling saettes lokalt via
  `ggplot2::theme()` i BFHcharts).
- Konfigurerbarhed af threshold via `bfh_qic()`-parameter (kan tilfoejes
  senere hvis behov opstaar).
- Numeriske/kategoriske x-akser (`apply_numeric_x_axis`,
  `bfh_subsample_label_indices`) — uberoert.
- `quarterly`/`yearly`/`irregular`-stierne: forekommer ikke i praksis.
  Bevares uden aendring som defensiv fallback; ingen nye testkrav.

## Decisions

### D1: Threshold = "labels kraever udtynding" (> 15 breaks i basisenheden)

Maanedsmode aktiveres naar antal potentielle breaks i interval-typens
basisenhed (dage for daily, uger for weekly) overstiger den eksisterende
graense paa 15 — samme konstant som `calculate_interval_multiplier()`
bruger, udtraekkes som `BFH_MAX_DATE_BREAKS <- 15L`. Under threshold vises
hver enhed med egen label praecis som i dag (multiplier 1).

Threshold beregnes paa **dataspaendet**, ikke `n_obs`:
`timespan_days / 7 > 15` for weekly, `timespan_days > 15` for daily. Det
matcher den eksisterende `potential_breaks`-beregning i
`calculate_date_breaks()` og haandterer serier med huller korrekt.

Maalt graense for weekly: multiplier skifter fra 1 til 13 mellem
`potential_breaks = 15` (n=16 obs) og `16` (n=17 obs). Maanedsmode overtager
praecis der, saa 13-ugers-steppet aldrig naas.

*Rationale:* De skaeve datoer opstaar praecis i det oejeblik multiplier > 1
vaelges. Ved at skifte mode ved samme graense elimineres skaeve multipla
fuldstaendigt — der findes ingen mellemtilstand med udtyndede uge-/dags-labels.

*Alternativ forkastet:* behold nuvaerende 36-ugers graense og skift foerst
derover — efterlader problemet intakt for 16-36 uger (PDF-casens omraade).

### D2: Major breaks genereres som maanedsstarter, uden force-first-break

`calculate_month_anchored_breaks()` genererer major breaks som
`seq(floor_date(min, "month"), ceiling_date(max, "month"), by = "N months")`
og filtrerer til `>= data_x_min`. Force-first-break (nuvaerende linje
193-196) anvendes ikke i maanedsmode — maanedsgriddet ER ankeret.

Starter data midt i en maaned, er foerste synlige label foerste
maanedsstart i spaendet; `label_date_short()` viser aaret ved den foerste
synlige label, saa aarskonteksten bevares.

*Alternativ forkastet:* udvid akse-limits bagud til forudgaaende
maanedsstart, saa fx "DEC" altid vises — koster op til ~4 ugers tom plot-
flade og strider mod nuvaerende stramme `expansion(mult = c(0.025, 0))`.

### D3: Minor ticks = ugestarter (kalendergrid, mandage)

Minor breaks genereres som `seq(floor_date(min, "week"), max, by = "1 week")`
— et regelmaessigt grid uafhaengigt af datapunkternes faktiske placering.
Renderes via `guide = ggplot2::guide_axis(minor.ticks = TRUE)` +
`ggplot2::theme(axis.minor.ticks.length.x.bottom = grid::unit(...))` med
laengde ~50% af major-tick og daempet farve.

*Rationale:* roligt, forudsigeligt udtryk; ugentlige datapunkter falder
naturligt paa/naer grid. Ticks ved faktiske datapunkter (alternativ) flytter
grid'et med data og bliver uregelmaessigt ved manglende uger.

*Verificeret defekt:* `lubridate::floor_date(x, "week")` defaulter til
**soendag** — `getOption("lubridate.week.start")` er unset paa denne host,
og mandag 2026-08-10 floores til soendag 2026-08-09. Det rammer allerede
`round_to_interval_start(x, "weekly")` i dag (kun paa startpunktet, derfor
uopdaget). Implementering SKAL eksplicit bruge `week_start = 1` (mandag,
ISO-8601/dansk konvention) **baade** i den nye minor-break-generering og i
den eksisterende `round_to_interval_start()`.

### D4: `calculate_date_breaks()` faar en break-unit-kontrakt

`get_optimal_formatting()` udvides til at returnere eksplicitte felter
`break_unit` (`"week" | "month" | ...`) og `minor_break_unit`
(`"week" | "month" | NULL`), og `calculate_date_breaks()` dispatcher paa
`break_unit` i stedet for raa interval-type. Den ubrugte
`format_config`-parameter bliver dermed baerende for kontrakten, og de
eksisterende doede string-specs (`breaks = "1 month"`) erstattes af de nye
felter.

Konfigurationsmatrix efter aendringen (fuld, for de tre reelle typer):

| Interval | Betingelse           | break_unit | minor_break_unit | Labels                        |
| -------- | -------------------- | ---------- | ---------------- | ----------------------------- |
| weekly   | uger i spaend <= 15  | week       | NULL             | `label_date_short()` (som nu) |
| weekly   | uger i spaend > 15   | month      | week             | `c("%Y", "%b", "", "")`       |
| daily    | dage i spaend <= 15  | day        | NULL             | `label_date_short()` (som nu) |
| daily    | uger i spaend <= 15  | week       | day              | `c("%Y", "%b", "%d", "")`     |
| daily    | uger i spaend > 15   | month      | week             | `c("%Y", "%b", "", "")`       |
| monthly  | alle                 | month      | NULL             | (som nu)                      |

Daily-raekkerne evalueres i raekkefoelge (foerste match vinder), jf. D7.
Monthly beholder sin nuvaerende sti uaendret — den er allerede
kalenderforankret (maalt). Den eneste aendring for monthly kommer fra D8.

`calculate_date_breaks()` dispatcher paa `break_unit ∈ {"week", "month"}`
til den kalender-ankrede generator; `"day"` og manglende felt falder til
den eksisterende multiplier-sti.

*Rationale:* fixer den doede branch eet sted og goer intentionen testbar.
Daily og weekly deler nu samme maaneds-ankrede maal-tilstand, saa der er
kun eén ny break-generator at teste.

### D5: Maaneds-label-udtynding genbruger multiplier-logik; minor eskalerer

Ved > 15 maaneder i spaendet anvendes eksisterende
`calculate_interval_multiplier(n, "monthly")` (kandidater 3/6/12) paa major
breaks. Naar maaneds-multiplier > 1 eskalerer minor-unit fra `"week"` til
`"month"` — hver maanedsstart faar en lille tick, labels hver 3./6./12.
maaned. Dermed forbliver minor-tick-antallet begraenset (~<= 65 uge-ticks
ved 15 maaneder er max i uge-mode).

*Rationale:* ved 2+ aars ugedata er 100+ uge-ticks stoej; maanedsticks
bevarer taelleligheden paa det relevante granularitetsniveau.

### D6: Minor-tick-SYNLIGHED ejes af BFHcharts, styling af BFHtheme (REVIDERET 2x)

*(Historik: (1) saet theme-detaljer lokalt → (2) overlad alt til BFHtheme →
(3) split ansvaret. Hver revision fulgte af et empirisk fund.)*

Ansvarsdelingen deler sig i to spoergsmaal med hver sin ejer:

| Spoergsmaal | Ejer | Hvorfor |
| ----------- | ---- | ------- |
| **Om** ticks vises paa et givet chart | BFHcharts | Datadrevet: kun naar aksen er kalenderankret og har en finere enhed under (uger under maanedslabels, dage under ugelabels). Et tema er statisk og kender ikke interval-typen |
| **Hvordan** de ser ud | BFHtheme | Visuelt udtryk. `minor_tick_theme()` afleder farve + linewidth fra temaets eget tick-element i stedet for at hardcode |

Betingelsen findes allerede som `format_config$minor_break_unit`, saa
aktiveringen kraever ingen ny parameter — og ingen brugervalg.

*Fejl i den forrige revision (rettet):* den paastod at minor ticks ikke
kunne renderes uden at overskrive designsystemet. Det byggede paa en **fejl
i maaleteknikken**, ikke paa adfaerden: tick-grobs blev talt via `id`-feltet,
men ggplot2 tegner ticks som polylines *uden* `id` (2 punkter pr. maerke,
nestet i akse-gtablet). Kontrolmaaling viste `ticks=0` selv under
`theme_grey()` uden nogen blanking — hvilket afsloerede maalefejlen.

*Faktisk adfaerd (verificeret):* `theme_bfh()` blanker `axis.ticks.x`, og
minor ticks arver det. Men `axis.minor.ticks.x.bottom` kan saettes eksplicit
**efter** temaet, og saa renderer de fint — ogsaa gennem
`lemon::coord_capped_cart()`. Maalt: 37 uge-maerker paa PDF-casen, 0 paa
maanedsdata.

**Beslutning:** `apply_spc_theme()` tilfoejer `minor_tick_theme(plot)` efter
`theme_bfh()`. No-op naar aksen ikke baerer minor breaks, saa monthly-charts
og korte serier forbliver tick-frie jf. BFHtheme's udtryk.

*Note om BFHtheme#80:* issuet er stadig relevant — men som et
**styling**-spoergsmaal (hvilke tokens er de rigtige at afledde fra), ikke
som en blokering. Verificeret i v0.5.4-kilden at y-aksen har aktive ticks
(`R/themes.R:106-107`), saa "ingen ticks" gaelder specifikt x-aksen.

*Alternativ forkastet:* `bfh_qic(x_minor_ticks = TRUE)` som opt-in — unoedigt,
da betingelsen er datadrevet og allerede beregnet. Ville tilfoeje en parameter
til et API hvis pointe er at man kun skal laere `bfh_qic()`.

### D7: Daily-serier faar en tre-trins kalenderankring

*(Revideret under implementering efter empirisk fund — se noten nedenfor.)*

Alle tre daily-branches i `get_optimal_formatting()` producerer i dag skaeve
dags-multipla (maalt: 2d-step ved 30 obs, 4d ved 60, 8d ved 120 — alle med
16 breaks). Daily faar derfor kalenderankring, men i **tre** trin:

| Spaend | Ankring | Labels | Minor ticks |
| ------ | ------- | ------ | ----------- |
| <= 15 dage | dag | hver dag (`%d`) | ingen |
| 16 dage - 15 uger | **ugestart (mandag)** | hver mandag | hver dag |
| > 15 uger | maanedsstart | hver maaned | hver uge |

*Empirisk begrundelse for mellemtrinnet:* ren maaneds-ankring blev afproevet
foerst og gav **0-2 labels** for 20-40-dages serier — en 30-dages serie fra
1. jan indeholder kun een maanedsstart (1. jan selv), og efter trimning kan
resultatet blive en helt umaerket akse. Maalt foer mellemtrinnet:
`n=20 → 1 label`, `n=30 → 1`, `n=40 → 2`. Med uge-ankring: `n=20 → 3`,
`n=30 → 4`, `n=60 → 8`.

*Rationale:* ankringen skal matche den granularitet spaendet faktisk
indeholder. Et spaend paa faa uger har for faa maanedsgraenser til at baere
labels, men rigeligt med ugegraenser.

*Alternativ forkastet:* haev daily-threshold til ~90 dage og behold
dags-multipla derunder — efterlader de skaeve dags-datoer i 16-90-dages
omraadet, praecis den defekt aendringen skal fjerne.

*Konsekvens:* generatoren parametriseres med `major_unit` (`"week"` |
`"month"`) i stedet for at vaere hardcodet til maaneder. Weekly-serier under
threshold bliver samtidig mandags-ankrede i stedet for datastart-ankrede —
en sidegevinst, daekket af snapshots.

### D8: Force-first-break fjernes for alle interval-typer

Linje 193-196 i `calculate_date_breaks()` indsaetter `data_x_min` som break
hvis det foerste beregnede break ikke matcher praecis. Det er kilden til det
skaeve startlabel — ogsaa for monthly-data der ikke ligger paa d. 1.
(maalt: `15-jan-25, 01-apr-25, 01-jul-25, ...`). Blokken fjernes helt.

*Rationale:* kalendergriddet ER ankeret; et ekstra off-grid break bryder
rytmen uden at tilfoeje information. `label_date_short()` viser aaret ved
foerste *synlige* label, saa aarskonteksten bevares uanset.

*Konsekvens:* monthly-serier der ikke starter paa d. 1. mister deres
foerste label. Data fra 15. jan viser foerste label 01-apr — accepteret,
da punkterne stadig er placeret korrekt paa aksen.

*Alternativ forkastet:* behold force-first kun for monthly — inkonsistent
adfaerd mellem interval-typer uden reel gevinst.

### D9: Breaks trimmes til dataspaendet

Nuvaerende kode genererer breaks til `ceiling_date(max, "week") + interval`
og filtrerer kun i den nedre ende (`breaks >= data_x_min`). Maalt: 16 ugers
data faar 18 breaks, hvoraf 2 ligger efter sidste datapunkt. Ny generator
filtrerer i **begge** ender (`>= data_x_min & <= data_x_max`).

*Rationale:* breaks efter sidste datapunkt giver tomme akse-labels og
straekker plot-omraadet. Kombineret med `expansion(mult = c(0.025, 0))`
(ingen hoejre-ekspansion) er de rent stoej.

*Note:* dette aendrer ogsaa den visuelle bredde af eksisterende korte
uge-charts (< 16 uger), som ellers var uden for scope. Vurderet som
oenskvaerdig oprydning; daekkes af vdiffr-snapshots.

### D10: Kalendersekvenser rekonstrueres i inputtets egen tidszone

*(Tilfoejet under implementering.)*

`generate_calendar_sequence()` bygger sekvensen paa Date-niveau (DST-sikkert)
og konverterer tilbage til POSIXct. Konverteringen SKAL bruge inputtets egen
`tzone`-attribut — ikke `Sys.timezone()`.

*Maalt defekt:* `as.Date()`-input giver UTC-midnat. Rekonstruktion i CET
gav breaks 3600 sekunder *foer* `data_x_min`, saa trimningen
(`>= data_x_min`) kasserede det foerste gyldige break. PDF-casen mistede sit
`01-dec`-label, og monthly-serier fra d. 1. mistede foerste label.

*Beslaegtet faldgrube i tests:* `as.Date.POSIXct()` konverterer i UTC og
skubber lokal midnat en dag tilbage (CET-midnat → foregaaende dato).
Assertions sammenligner derfor via `format(x, "%Y-%m-%d")`, aldrig
`as.Date(x)`. Dette kostede en fejlsoegningsrunde hvor `week_start = 1`
fejlagtigt saa ud til ikke at virke.

## Risks / Trade-offs

- **vdiffr-churn**: bredere end foerst antaget — alle uge- OG dags-akse-
  snapshots over threshold aendres (D1/D7), korte uge-charts aendrer bredde
  (D9), og monthly-charts med skaev start mister foerste label (D8).
  Mitigering: aendringerne er tilsigtede; snapshots gennemses manuelt foer
  accept, i separat commit.
- **DST-overgange**: POSIXct-sekvenser med `by = "1 week"` over
  DST-graenser kan skride 1 time. Mitigering: generer sekvenser paa
  Date-niveau og konverter til POSIXct til sidst; test daekker
  marts/oktober-overgange.
- **`label_date_short()` + maanedsformat `c("%Y","%b","","")`**: viser aar
  ved aarsskifte som ekstra linje — bekraeftes i visuel validering at det
  matcher det oenskede udtryk (det er samme mekanisme som i dag).
- **ggplot2-bump kraevet**: `DESCRIPTION` har i dag `ggplot2 (>= 3.4.0)`,
  men `guide_axis(minor.ticks)` kraever >= 3.5.0. Bumpes i denne change.
  Ikke breaking for brugere med opdaterede pakker (3.5.0 udkom feb. 2024).
- **Skaev datastart midt i maaned**: foerste ~uger kan staa uden major
  label (kun minor ticks). Accepteret trade-off jf. D2.
- **Daily under threshold mister ikke dag-labels, men over gaar de tabt**:
  en 20-dages serie faar maanedslabels + uge-ticks. Vurderes acceptabelt,
  men bekraeftes i visuel validering (task 5.1) — hvis udtrykket er for
  groft, kan daily-threshold haeves separat uden at roere weekly.

## Migration Plan

Ingen API-migration — intern/visuel aendring. Udrulning:

1. Feature-branch fra `develop`, TDD-implementering.
2. vdiffr-snapshots opdateres bevidst i separat commit (reviewbar diff).
3. NEWS-entry under "Nye features" beskriver det nye akse-udtryk;
   MINOR-bump ved naeste release.
4. biSPCharts: ingen handling paakraevet; visuel aendring nedarves ved
   naeste dependency-bump.

## Open Questions

- Skal minor-tick-farve/laengde matche et eksisterende BFHtheme-token
  (afklares ved implementering; default: samme farve som major ticks,
  50% laengde)?
- Praecis placering af `BFH_MAX_DATE_BREAKS`-konstanten (globals.R vs.
  utils_x_axis_formatting.R) — afgoeres af eksisterende konvention for
  `BFH_MAX_X_LABELS_TEXT` (ligger i utils_x_axis_formatting.R; foelg den).
- Er daily-threshold paa 15 dage for lavt i praksis (jf. Risks)? Besvares
  empirisk i visuel validering, ikke foer implementering.
