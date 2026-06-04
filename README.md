# BFHcharts

[![codecov](https://codecov.io/gh/johanreventlow/BFHcharts/branch/main/graph/badge.svg)](https://codecov.io/gh/johanreventlow/BFHcharts) [![PDF smoke](https://github.com/johanreventlow/BFHcharts/actions/workflows/pdf-smoke.yaml/badge.svg)](https://github.com/johanreventlow/BFHcharts/actions/workflows/pdf-smoke.yaml)

> Moderne SPC-visualisering til kvalitetsforbedring i sundhedsvæsenet

**BFHcharts** er en R-pakke til at lave publikationsklare SPC-diagrammer (Statistical Process Control) skræddersyet til klinisk kvalitetsarbejde. Pakken bygger på `ggplot2` og `qicharts2` og giver et konsistent visuelt udtryk med hospitalsbranding, dansk standardsprog og automatisk PDF/PNG-eksport.

Pakken er udviklet til Bispebjerg og Frederiksberg Hospital og fungerer som visualiseringsmotor for Shiny-applikationen **biSPCharts**.

## Indhold

- [Funktioner](#funktioner)
- [Installation](#installation)
- [Hurtig start](#hurtig-start)
- [Funktionsoversigt](#funktionsoversigt)
- [Diagramtyper](#diagramtyper)
- [Resultatobjektet og arbejdsgangen](#resultatobjektet-og-arbejdsgangen)
- [PDF- og PNG-eksport](#pdf--og-png-eksport)
- [Automatisk analysetekst](#automatisk-analysetekst)
- [Sprog](#sprog)
- [Avanceret brug](#avanceret-brug)
- [Begrænsninger](#begrænsninger)
- [Dokumentation](#dokumentation)
- [Licens](#licens)

## Funktioner

- 🎯 **Enkelt primært API** – `bfh_qic()` dækker hele diagramdannelsen; sekundære funktioner er kun nødvendige til eksport og analysetekst.
- 📊 **Mange diagramtyper** – run-, I-, MR-, P-, U-, C-, G-, Xbar-, S- og T-charts med Anhøj-regler.
- 🎨 **Hospitalsbranding** – BFHtheme-integration med konfigurerbar multi-organisatorisk understøttelse.
- 📄 **PDF/PNG-eksport** – Typst-baserede PDF-skabeloner (via Quarto) og direkte PNG-eksport i millimeter-dimensioner.
- 🧠 **Automatisk analysetekst** – dansk standardtekst med valgfri AI-generering via BFHllm.
- 🌍 **Flersproget** – diagramlabels og analysetekst på dansk (standard) og engelsk.
- ✅ **Produktionsklar** – testdrevet udvikling med omfattende dækning.

## Installation

### Med pak (anbefalet)

```r
# Installér pak hvis du ikke har det
install.packages("pak")

# De fleste brugere: stabil release fra r-universe (hurtigst, prækompileret)
pak::pkg_install("BFHcharts", repos = "https://johanreventlow.r-universe.dev")

# Udviklere: seneste kode fra GitHub (kræver build-tools)
pak::pkg_install("johanreventlow/BFHcharts")
```

**r-universe vs. GitHub:**
- **r-universe**: prækompilerede binaries, ingen kompilering, baseret på releases (anbefalet).
- **GitHub**: seneste kode, kræver build-tools, langsommere (til udvikling).

### Med install.packages

```r
# Fra r-universe
install.packages("BFHcharts", repos = "https://johanreventlow.r-universe.dev")

# Fra GitHub (kræver devtools)
devtools::install_github("johanreventlow/BFHcharts")
```

### BFHtheme-afhængighed

BFHcharts afhænger af `BFHtheme (>= 0.5.1)` til temaer og farvepaletter.
`BFHtheme` ligger i `Remotes:`-feltet (ikke på CRAN) og installeres derfor
automatisk med `pak::pkg_install()` eller `remotes::install_github()` – men
**ikke** med den rene `install.packages()`-form. Hvis du ser en
opstartsbesked om at `BFHcharts kræver BFHtheme >= 0.5.1`, installér den
eksplicit:

```r
remotes::install_github("johanreventlow/BFHtheme")
```

### Lukkede / offline-miljøer

Nogle hospitalsnetværk (Posit Connect / RStudio Workbench bag firewall,
luftgappede kliniske miljøer) blokerer for offentlig GitHub-adgang og kan
ikke nå `r-universe.dev` eller `github.com` direkte. BFHcharts kan stadig
deployes via et af tre mønstre:

**1. Intern Posit Package Manager (anbefalet)**

Hvis din organisation hoster en Posit Package Manager-instans, så spejl
`johanreventlow.r-universe.dev` eller udgiv BFHcharts + BFHtheme + BFHllm som
interne kildepakker. Peg `options(repos = ...)` mod det interne endpoint og:

```r
install.packages("BFHcharts")
```

**2. Lokal tarball-installation**

Til engangsdeployments uden internt spejl: hent release-tarballs fra GitHub
Releases på en netværksforbundet maskine og overfør dem:

```r
# På forbundet maskine: hent release-assets
# https://github.com/johanreventlow/BFHcharts/releases
# https://github.com/johanreventlow/BFHtheme/releases

# På deployment-target: installér i afhængighedsrækkefølge
install.packages("BFHtheme_0.5.1.tar.gz",  repos = NULL, type = "source")
install.packages("BFHcharts_0.23.0.tar.gz", repos = NULL, type = "source")
```

CRAN-spejlede runtime-afhængigheder (`ggplot2`, `qicharts2`, `dplyr`,
`scales`, `lubridate`, `purrr`, `stringr`, `tibble`, `yaml`, `commonmark`,
`xml2`, `systemfonts`, `rlang`, `svglite`, `marquee`, `grid`, `lemon`) skal
være tilgængelige fra et CRAN-spejl som target-miljøet kan nå.

**3. Posit Connect manifest-deployment**

For Shiny-apps der deployer via `rsconnect::writeManifest()` til Posit
Connect (Cloud eller selv-hostet) pinpointer manifestet pakkeversioner
inklusive `Remotes:`-referencer. Connect løser disse via sine konfigurerede
upstream-repositories. Kan Connect ikke løse `johanreventlow/BFHtheme`
direkte, så konfigurér en intern Package Manager og pin manifestets
`Remotes:`-felt til den interne URL.

Se [#270 i biSPCharts](https://github.com/johanreventlow/biSPCharts) for et
eksempel på en Posit Connect Cloud-deployment-konfiguration.

## Hurtig start

```r
library(BFHcharts)

# Eksempeldata: månedlige hospitalserhvervede infektioner
data <- data.frame(
  month      = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
  infections = rpois(24, lambda = 15),
  surgeries  = rpois(24, lambda = 100)
)

# Eksempel 1: simpelt run-chart
bfh_qic(
  data        = data,
  x           = month,
  y           = infections,
  chart_type  = "run",
  y_axis_unit = "count",
  chart_title = "Månedlige hospitalserhvervede infektioner"
)

# Eksempel 2: P-chart med mållinje
bfh_qic(
  data         = data,
  x            = month,
  y            = infections,
  n            = surgeries,
  chart_type   = "p",
  y_axis_unit  = "percent",
  chart_title  = "Infektionsrate pr. operation",
  target_value = 0.10,
  target_text  = "Mål: 10 %"
)

# Eksempel 3: I-chart med intervention (fase-opdeling)
bfh_qic(
  data        = data,
  x           = month,
  y           = infections,
  chart_type  = "i",
  y_axis_unit = "count",
  chart_title = "Infektioner før/efter intervention",
  part        = 12,   # intervention efter 12 måneder
  freeze      = 12    # frys baseline ved måned 12
)
```

`bfh_qic()` returnerer et `bfh_qic_result`-objekt. Når det printes, vises
diagrammet automatisk; objektet kan også sendes direkte videre til eksport-
og analysefunktionerne (se [arbejdsgangen](#resultatobjektet-og-arbejdsgangen)).

## Funktionsoversigt

Pakken er bygget op om ét primært API – `bfh_qic()`. De øvrige eksporterede
funktioner bruges kun til eksport, analysetekst og introspektion af resultatet.

### Primært API

| Funktion | Formål |
|----------|--------|
| `bfh_qic()` | Laver et komplet SPC-diagram fra data og returnerer et `bfh_qic_result`. **Den eneste funktion de fleste brugere har brug for.** |

### Eksport (PDF/PNG)

| Funktion | Formål |
|----------|--------|
| `bfh_export_pdf()` | Eksporterer et resultat til PDF via Typst-skabeloner med hospitalsbranding (kræver Quarto CLI). Returnerer resultatet usynligt (pipe-venlig). |
| `bfh_export_png()` | Eksporterer til PNG i millimeter-dimensioner med konfigurerbar opløsning. Pipe-venlig. |
| `bfh_create_export_session()` | Opretter en genbrugelig batch-session der deler Typst-skabelonens assets på tværs af mange eksporter (IO-optimering ved loops). |

### Analysetekst

| Funktion | Formål |
|----------|--------|
| `bfh_generate_analysis()` | Genererer fortolkende analysetekst (dansk standardtekst, valgfri AI via BFHllm). |
| `bfh_generate_details()` | Genererer en kort detaljestreng: periode, gennemsnit og seneste niveau. |
| `bfh_analyse()` | Samler et struktureret analyseobjekt (`bfh_spc_analysis`) med features, konklusioner og forbehold. |
| `bfh_render_analysis()` | Renderer et `bfh_spc_analysis`-objekt til tekst med i18n og tegnbudget. |
| `bfh_build_analysis_context()` | Samler relevant kontekst fra et resultat til analyse-generering. |

### Introspektion og hjælpere

| Funktion | Formål |
|----------|--------|
| `bfh_get_plot()` | Udtrækker `ggplot`-objektet fra et resultat til videre tilpasning. |
| `bfh_extract_spc_stats()` | Udtrækker SPC-statistik (runs, crossings, outliers) fra et resultat. |
| `bfh_merge_metadata()` | Fletter brugerens metadata med pakkens defaults til PDF-generering. |
| `is_bfh_qic_result()`, `is_bfh_spc_analysis()` | Prædikater til klassetjek. |
| `bfh_create_typst_document()`, `bfh_subsample_label_indices()`, `new_bfh_qic_result()` | Lavniveau-funktioner til power-brugere og downstream-konsumenter (fx biSPCharts). |

## Diagramtyper

`chart_type` accepterer følgende værdier (default `"run"`):

| Type | Beskrivelse |
|------|-------------|
| `run` | Run-chart (median som centerlinje) |
| `i` | I-chart (individuelle målinger) |
| `mr` | Moving range-chart |
| `p` | P-chart (andele, kræver nævner `n`) |
| `pp` | Prime P-chart (overdispersion-justeret) |
| `u` | U-chart (rater, kræver nævner `n`) |
| `up` | Prime U-chart |
| `c` | C-chart (antal hændelser) |
| `g` | G-chart (hændelser mellem sjældne tilfælde) |
| `xbar` | Xbar-chart (delgruppe-gennemsnit) |
| `s` | S-chart (delgruppe-standardafvigelse) |
| `t` | T-chart (tid mellem hændelser) |

`y_axis_unit` styrer akseformatering og accepterer `"count"`, `"percent"`,
`"rate"` eller `"time"`.

## Resultatobjektet og arbejdsgangen

`bfh_qic()` returnerer et `bfh_qic_result`-objekt med fire komponenter:

- `$plot` – `ggplot`-objektet med det renderede diagram
- `$summary` – data.frame med SPC-statistik
- `$qic_data` – rå qicharts2-beregningsdata (centerlinje, kontrolgrænser, signaler)
- `$config` – de oprindelige funktionsparametre

Objektet understøtter S3-metoderne `print()` og `plot()`. Den typiske
arbejdsgang er:

```r
result <- bfh_qic(data, x = month, y = infections, chart_type = "i")

# Tilpas diagrammet videre som et almindeligt ggplot
library(ggplot2)
bfh_get_plot(result) + labs(subtitle = "Tilføjet lag")

# Eller eksportér direkte – eksportfunktionerne er pipe-venlige
result |>
  bfh_export_png("diagram.png", width_mm = 200, height_mm = 120) |>
  bfh_export_pdf("rapport.pdf", metadata = list(department = "Medicinsk afd."))
```

## PDF- og PNG-eksport

PNG-eksport virker uden eksterne afhængigheder. PDF-eksport bruger Typst-
skabeloner og kræver **Quarto CLI (>= 1.4.0)** installeret på systemet.

### Batch-eksport

Når du genererer PDF'er for flere afdelinger eller indikatorer i et loop, så
brug `bfh_create_export_session()` til at kopiere skabelonens assets én gang
og dele dem på tværs af alle eksporter:

```r
session <- bfh_create_export_session()
on.exit(close(session))  # oprydning når du er færdig

departments <- c("ITA", "Medicinsk", "Kirurgisk")
for (dept in departments) {
  result <- bfh_qic(dept_data[[dept]], x = month, y = value,
                    chart_type = "i", chart_title = paste("Kvalitet –", dept))
  bfh_export_pdf(result,
                 output = paste0(dept, "_rapport.pdf"),
                 metadata = list(department = dept),
                 batch_session = session)
}
```

**Bemærk:**
- `batch_session` kan ikke kombineres med `template_path` eller `inject_assets`.
- Send i stedet `inject_assets` og `font_path` til `bfh_create_export_session()`.
- Sessioner er enkelt-trådede; del dem ikke på tværs af parallelle workers.

### Skrifttyper og branding

PDF-eksport bruger **Mari-fonten** til hospitalsbranding når den er
tilgængelig, med fallback-kæden **Mari → Roboto → Arial → Helvetica → sans-serif**.

- **Interne brugere (Region Hovedstaden):** Mari er installeret automatisk på
  hospitalscomputere – ingen handling nødvendig, fuld branding.
- **Eksterne brugere:** PDF'erne er fuldt funktionelle og læsbare, men uden
  Region Hovedstaden-specifik branding. Mari er ophavsretsbeskyttet og kan
  ikke distribueres med pakken.

Den offentlige pakke bundter Typst-skabelonen
(`inst/templates/typst/bfh-template/`) og fallback-fontkæden, men **ingen**
proprietære fonte eller logoer. En ren installation renderer korrekt med
systemets tilgængelige fonte.

#### Organisatorisk branding via companion-pakke

Organisationer der har brug for konsistent proprietær branding (egne fonte,
hospitalslogoer) bør distribuere disse assets via en **privat companion-pakke**
frem for at bundte dem i forbrugerapplikationen eller hardkode stier.

> **Sikkerhedsadvarsel:** `inject_assets` er **fuld kodeeksekvering**. Den
> angivne funktion kører med samme rettigheder som den kaldende R-session og
> har fuld fil- og netværksadgang. Den må **aldrig** komme fra brugerinput
> (Shiny-inputs, REST-parametre, konfigurationsfiler af ukendt oprindelse).
> Videresend **aldrig** brugerangivne værdier til `inject_assets` – det skaber
> en RCE-vektor (remote code execution). Send kun funktioner fra
> versionsstyret applikationskode eller en kontrolleret companion-pakke.
> Se `?bfh_export_pdf` (Security-sektionen) for acceptable/uacceptable kilder.

**Mønster:**

1. Lav en privat R-pakke (fx `MyOrgAssets`) der hoster fonte og billeder i `inst/assets/`.
2. Eksportér en funktion `inject_my_assets(template_dir)` der kopierer de bundtede assets ind i den staged Typst-skabelonmappe.
3. Lad din forbrugerapplikation afhænge af companion-pakken og send dens inject-funktion til BFHcharts:

```r
BFHcharts::bfh_export_pdf(
  result, "rapport.pdf",
  inject_assets = MyOrgAssets::inject_my_assets   # sikker: fra companion-pakke
)
```

For BFH/Region Hovedstaden-referencedeploymentet implementerer den private
`BFHchartsAssets`-pakke (separat, hospital-internt repository) dette mønster.

#### Verificér din opsætning

```r
# Tjek hvilke fonte Typst finder på dit system
sf <- systemfonts::system_fonts()
sf[grepl("Mari|Roboto", sf$family), "family"]

# Smoke-render en PDF for at verificere pipelinen
result <- bfh_qic(
  data.frame(x = 1:20, y = runif(20, 0.05, 0.15), n = rep(100, 20)),
  x = x, y = y, n = n, chart_type = "p"
)
bfh_export_pdf(result, tempfile(fileext = ".pdf"))
```

Se `inst/adr/ADR-001-pdf-asset-policy.md` for den fulde asset-politik.

## Automatisk analysetekst

BFHcharts kan generere fortolkende analysetekst til et diagram. Som standard
bruges danske, regelbaserede standardtekster; valgfrit kan teksten genereres
med AI via `BFHllm`-pakken.

```r
result <- bfh_qic(data, x = month, y = infections, chart_type = "i")

# Kort detaljestreng (periode, gennemsnit, seneste niveau)
bfh_generate_details(result)

# Fortolkende analysetekst (standardtekst uden AI)
bfh_generate_analysis(result, use_ai = FALSE)
```

AI-generering kræver `BFHllm` og eksplicit samtykke til datadeling
(`data_consent`). Se `?bfh_generate_analysis` for detaljer.

## Sprog

Diagramlabels, analysetekst og detaljeoutput findes på dansk (`"da"`,
standard) og engelsk (`"en"`).

```r
result <- bfh_qic(data, x = month, y = infections, chart_type = "p",
                  language = "en")

bfh_generate_analysis(result, language = "en")
bfh_generate_details(result, language = "en")
```

Standard er `language = "da"` – eksisterende kode uden parameteren er upåvirket.
Se `TRANSLATORS.md` for at tilføje et nyt sprog.

## Avanceret brug

### Hospitalsbranding med BFHtheme

```r
library(BFHtheme)

plot <- bfh_qic(data, x = month, y = infections, chart_type = "run",
                y_axis_unit = "count", chart_title = "Kvalitetsdiagram")

# Tilføj hospitalslogo
plot <- bfh_get_plot(plot) |> BFHtheme::add_bfh_logo()
```

Diagrammer returneres som komponérbare ggplot-objekter (via `bfh_get_plot()`),
så du kan tilføje vilkårlige lag, skalaer og temaer. Tilpasning af
hospitalsfarver håndteres af
[BFHtheme](https://github.com/johanreventlow/BFHtheme)-pakken.

## Begrænsninger

- Facettering (`facets`, `nrow`, `ncol`, `scales`) understøttes endnu ikke;
  multi-panel-plots kræver manuel opbygning indtil
  [issue #1](https://github.com/johanreventlow/BFHcharts/issues/1) er løst.

## Dokumentation

- Roxygen-reference, fx `?bfh_qic` eller `help(package = "BFHcharts")`
- Arkitekturnoter i [`docs/`](docs/DOCUMENTATION_OVERVIEW.md)
- ADR'er i `inst/adr/`

## Licens

GPL-3 © Johan Reventlow

## Tak til

- Inspireret af [BBC's bbplot](https://github.com/bbc/bbplot)-designfilosofi
- Bygget på [qicharts2](https://github.com/anhoej/qicharts2) til SPC-beregninger
- Udviklet til kvalitetsarbejdet på Bispebjerg og Frederiksberg Hospital
