# Proposal: month-anchored-weekly-axis

## Why

X-aksen paa daglige og ugentlige SPC-kort bliver visuelt tilfaeldig naar
serien er laengere end ~15 punkter i basisenheden. Break-beregningen
genererer breaks som `enhedsstart + k x multiplier` uden kalenderforankring,
saa labels lander paa vilkaarlige maanedsdage.

Maalt paa nuvaerende kode (2026-08-10):

| Case | Breaks i dag |
| ---- | ------------ |
| 37 uger (PDF-casen) | `01-dec, 28-dec, 25-jan, 22-feb, 22-mar, 19-apr, ...` |
| 104 uger | 13-ugers-step (91d ≠ kvartal) → glider ~3 dage bagud pr. aar |
| 120 dage | `01-jan, 09-jan, 17-jan, 25-jan, 02-feb, ...` (8-dages-step) |
| 60 dage | 4-dages-step, 16 breaks |
| 16 uger | 18 breaks — 2 af dem *efter* sidste datapunkt |
| 18 maaneder fra d. 15. | `15-jan-25, 01-apr, 01-jul, ...` — skaevt foerste break |

Fire underliggende defekter:

1. `calculate_date_breaks()` ignorerer `format_config`-parameteren totalt —
   intentionen i `get_optimal_formatting()` om at skifte til maanedlig
   visning for lange serier er doed kode. Rammer **alle** daily-branches og
   den lange weekly-branch.
2. Et force-first-break paa praecis `data_x_min` tilfoejer et off-grid break.
   Rammer ogsaa monthly-data der ikke ligger paa d. 1.
3. `round_to_interval_start(x, "weekly")` bruger lubridates default-ugestart
   (**soendag**), ikke mandag. Mandags-data floores til foregaaende soendag.
4. Breaks filtreres kun i den nedre ende, saa der genereres op til 2 breaks
   efter sidste datapunkt.

Det hierarkiske label-udtryk fra `scales::label_date_short()` (aar/maaned kun
naar noedvendigt) fungerer godt og skal bevares.

I praksis forekommer kun tre interval-typer: **daily, weekly, monthly**.
`quarterly`/`yearly`/`irregular` bevares uaendret som defensiv fallback.

## What Changes

- **Maaneds-ankrede major breaks** for daily og weekly over threshold:
  breaks lander altid paa d. 1. i maaneden; labels via `label_date_short()`
  (maanedsnavn, aar kun ved foerste label og aarsskifte).
- **Uge-minor-ticks**: en lille umaerket tick pr. ugestart (mandag,
  eksplicit `week_start = 1`) via ggplot2 `minor_breaks` +
  `guide_axis(minor.ticks = TRUE)`.
- **Threshold**: maanedsmode aktiveres saa snart labels ville kraeve
  udtynding (> `BFH_MAX_DATE_BREAKS = 15` breaks i basisenheden, beregnet paa
  dataspaendet). Korte serier (<= 15) beholder uaendret 1:1-labels.
- **Udtynding ved mange maaneder**: > 15 maaneder udtyndes maaneds-labels med
  eksisterende multiplier-logik (3/6/12); minor-ticks eskalerer da fra uge-
  til maanedsniveau.
- **Fix af doed branch**: `calculate_date_breaks()` dispatcher paa
  `break_unit` fra `format_config`.
- **Force-first-break fjernes** for alle interval-typer.
- **Breaks trimmes i begge ender** af dataspaendet.
- **Mandag som ugestart** rettes ogsaa i eksisterende
  `round_to_interval_start()`.

## Capabilities

### New Capabilities

- `x-axis-temporal-formatting`: kalenderforankret break-beregning for
  temporale x-akser — maaneds-ankrede major breaks, uge-minor-ticks,
  threshold-styret modeskift, span-trimning og hierarkiske labels. Spec'en
  daekker den interne formatteringspipeline (`detect_date_interval` →
  `get_optimal_formatting` → `calculate_date_breaks` →
  `apply_temporal_x_axis`), som hidtil har vaeret uspecificeret.

### Modified Capabilities

<!-- Ingen eksisterende spec daekker x-akse-formattering. public-api beroeres
     ikke: bfh_qic()-signaturen er uaendret. -->

## Impact

**Kode (BFHcharts):**

- `R/utils_x_axis_formatting.R`: ny `calculate_month_anchored_breaks()`
  (major + minor); `calculate_date_breaks()` laeser break-unit fra config,
  dropper force-first-break, trimmer i begge ender;
  `round_to_interval_start()` faar `week_start = 1`;
  `apply_temporal_x_axis()` sender `minor_breaks` + `guide` +
  minor-tick-theme gennem `BFHtheme::scale_x_datetime_bfh(...)`.
- `R/utils_date_formatting.R`: daily- og weekly-branches i
  `get_optimal_formatting()` faar threshold-logik og returnerer
  `break_unit`/`minor_break_unit`.
- `tests/testthat/test-utils_x_axis_formatting.R`: nye contract-tests.

**Dependencies:**

- `DESCRIPTION`: `ggplot2 (>= 3.4.0)` → `(>= 3.5.0)` (kraevet af
  `guide_axis(minor.ticks)`; 3.5.0 udkom feb. 2024).

**Public API:**

- Ingen signatur-aendringer. Ren visuel/intern adfaerdsaendring →
  MINOR version bump (pre-1.0, adfaerdsaendring markeres i NEWS).

**biSPCharts (downstream):**

- Ingen kodeaendring noedvendig. Alle daglige og ugentlige charts over
  threshold aendrer visuelt udtryk (bedre); maintainer orienteres via
  NEWS-entry.

**Visuel regression:**

- vdiffr-snapshots skal opdateres for: uge-akser > 15 uger, dags-akser
  > 15 dage, korte uge-charts (bredde-aendring fra span-trimning) og
  monthly-charts med skaev start. Nye snapshots for 12/26/37/52/104-ugers
  og 30/60/120-dages scenarier.

**Statistisk validering:**

- Ikke paakraevet — aendringen beroerer kun akse-formattering, ingen
  beregninger.
