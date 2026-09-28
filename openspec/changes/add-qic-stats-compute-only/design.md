## Context

`bfh_qic()` er i dag een funktion der baade beregner (qicharts2/pbcharts,
auto-mean, summary) og tegner (viewport, plot, labels). Kaldere der kun
skal bruge tallene har ingen vej uden om tegningen.

## Goals / Non-Goals

**Goals:**
- En eksporteret funktion der returnerer praecis de samme `summary` og
  `qic_data` som `bfh_qic()`, uden at tegne.
- Een beregningssti: `bfh_qic()` og `bfh_qic_stats()` deler den.
- `bfh_qic()`'s output uaendret.

**Non-Goals:**
- Hurtigere tegning i `bfh_qic()` selv.
- Fjerne `return_data` (allerede deprecated; separat).

## Decisions

### D1: Separat funktion og klasse frem for `render = FALSE`

`new_bfh_qic_result()` kraever et ggplot-objekt, og syv steder laeser
`$plot` (print, plot, `bfh_get_plot()`, PDF-/PNG-eksport, Typst). Et
`bfh_qic_result` uden plot ville kraeve vagter alle steder eller fejle
foerst dybt nede i en eksport. En separat klasse `bfh_qic_stats` afvises
allerede korrekt af de funktioner (de tjekker `is_bfh_qic_result()`), og
invarianten "et bfh_qic_result har altid et plot" bevares.

### D2: Faelles intern beregningsfase

Beregningen (validering, qicharts2/pbcharts-kald, auto-mean,
advarsel om brugerdefineret `cl`, `format_qic_summary()`) flyttes til en
intern hjaelper, som begge eksporterede funktioner kalder. NSE-fangst
(`substitute()`, `missing()`, `parent.frame()`) forbliver i hver
eksporteret funktion — den er scope-sensitiv og skal ske i kalderens
scope; hjaelperen faar udtrykkene og miljoeet som argumenter.

Tegne-specifik validering (`base_size`, `width`, `height`, `plot_margin`,
`ylim`, `language` m.fl.) koeres kun af `bfh_qic()`.

### D3: Aekvivalens som testkontrakt

Testen `identical(bfh_qic_stats(...)$summary, bfh_qic(...)$summary)` (og
tilsvarende for `qic_data`) koeres for alle charttyper i `CHART_TYPES_EN`
samt for `part`, `freeze`, `exclude`, brugerdefineret `cl`, auto-mean og
naevner. Den er kontrakten, der forhindrer de to funktioner i at glide.

## Risks / Trade-offs

- [Opdelingen aendrer utilsigtet `bfh_qic()`'s output] -> de eksisterende
  visuelle snapshots og hele testpakken skal vaere uaendret groenne.
- [Advarsler/beskeder koeres i en anden raekkefoelge] -> beregningsfasen
  bevarer raekkefoelgen; tests af eksisterende advarsler skal stadig passere.
