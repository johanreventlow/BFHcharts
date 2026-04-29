## Why

BFHcharts er public GPL-3-pakke distribueret via GitHub + r-universe. Den må derfor **ikke** bundle proprietære assets:

- **Mari fonts** (Region Hovedstadens custom font) — eksplicit forbudt af `openspec/specs/pdf-export/spec.md:46` ("Package SHALL NOT bundle copyrighted Mari fonts") og README ("Mari font is copyrighted and cannot be redistributed with the package")
- **Arial fonts** (Microsoft/Monotype) — proprietær, EULA forbyder redistribution af TTF-kopier fra Win/Mac OS
- **Hospital-logoer** (Logo_Bispebjerg*, BFH_medicin) — Region Hovedstadens brand-ejendom, GPL-3-redistribution implicerer GPL-licensiering hvilket RegionH ikke har samtykket til

Pakken understøtter allerede `inject_assets`-callback (`bfh_export_pdf()` + `bfh_create_export_session()`) der lader downstream-brugere kopiere assets ind i Typst-template-staging-direktoriet ved runtime. Mekanismen findes — men der mangler en officiel asset-leverandør for biSPCharts og fremtidige forbrugere.

biSPCharts er deployed til **Posit Connect Cloud** og skal kunne rendere PDF'er med fuld hospital-branding (Mari + logos). Uden et formelt asset-distribuerings-pattern er der to suboptimale workarounds:

1. **Manuel staging i deploy-bundle** — assets gitignored i biSPCharts, lokalt kopieret før `rsconnect::deployApp()`. Skrøbeligt: assets er ikke versioneret, manuelt staging-trin nemt at glemme, ingen audit-trail
2. **Hardcoded paths** — `inject_assets`-callback med absolute paths til lokal udvikler-maskine. Bryder på Connect Cloud

Løsningen er en **privat companion-pakke** `BFHchartsAssets` der hoster proprietære assets, distribueres via privat GitHub repo, og genereres fra Mari + logo source files ved bumping. biSPCharts importerer den som dependency og kalder `BFHchartsAssets::inject_bfh_assets()` i sit `inject_assets`-callback.

## What Changes

**Ud af scope for BFHcharts repo:** Companion-pakken er et **separat repo**, ikke en ændring i BFHcharts. Denne OpenSpec change scaffolder companion-pakke-design + dokumenterer integration-pattern fra BFHcharts-side.

**Konkrete deliverables:**

### A. Nyt privat repo: `johanreventlow/BFHchartsAssets`

Struktur:

```
BFHchartsAssets/                       (PRIVAT GitHub repo)
├── DESCRIPTION                        Imports: BFHcharts (>= 0.11.1)
├── NAMESPACE
├── R/
│   └── inject.R                       eksporterer inject_bfh_assets()
├── inst/
│   └── assets/
│       ├── fonts/                     Mari*.otf, MariOffice*.ttf, ARIAL*.TTF
│       └── images/                    Logo_Bispebjerg*.png, BFH_medicin.png
├── tests/testthat/
│   └── test-inject.R                  verificerer at filer kopieres korrekt
├── LICENSE                            Copyright Region Hovedstaden, "All rights reserved" (privat)
├── README.md                          dokumenterer Posit Connect Cloud setup + PAT
└── .github/workflows/R-CMD-check.yaml minimal CI

```

`R/inject.R`:

```r
#' Inject BFH branding assets into a Typst template directory
#'
#' Drop-in callback for [BFHcharts::bfh_export_pdf()]'s `inject_assets` argument.
#' Copies all bundled fonts and images into the staged template's `fonts/`
#' and `images/` subdirectories.
#'
#' @param template_dir Character path to the staged template directory
#'   (passed by BFHcharts at runtime)
#' @return Invisible NULL. Called for side effects.
#' @export
inject_bfh_assets <- function(template_dir) {
  stopifnot(is.character(template_dir), length(template_dir) == 1, dir.exists(template_dir))

  fonts_src  <- system.file("assets/fonts",  package = "BFHchartsAssets", mustWork = TRUE)
  images_src <- system.file("assets/images", package = "BFHchartsAssets", mustWork = TRUE)

  fonts_dst  <- file.path(template_dir, "fonts")
  images_dst <- file.path(template_dir, "images")
  dir.create(fonts_dst,  showWarnings = FALSE, recursive = TRUE)
  dir.create(images_dst, showWarnings = FALSE, recursive = TRUE)

  font_files  <- list.files(fonts_src,  full.names = TRUE)
  image_files <- list.files(images_src, full.names = TRUE)

  fonts_ok  <- all(file.copy(font_files,  fonts_dst,  overwrite = TRUE))
  images_ok <- all(file.copy(image_files, images_dst, overwrite = TRUE))

  if (!fonts_ok || !images_ok) {
    stop("BFHchartsAssets: failed to inject one or more asset files", call. = FALSE)
  }

  invisible(NULL)
}
```

### B. biSPCharts integration

biSPCharts `DESCRIPTION`:
```
Imports:
    BFHcharts (>= 0.11.1),
    BFHchartsAssets
Remotes:
    johanreventlow/BFHcharts,
    johanreventlow/BFHchartsAssets
```

biSPCharts server-kode (eksempel):
```r
result <- BFHcharts::bfh_qic(...)

BFHcharts::bfh_export_pdf(
  result, output_pdf,
  metadata = metadata,
  inject_assets = BFHchartsAssets::inject_bfh_assets
)
```

For batch:
```r
session <- BFHcharts::bfh_create_export_session(
  inject_assets = BFHchartsAssets::inject_bfh_assets
)
on.exit(close(session))
for (dept in departments) {
  BFHcharts::bfh_export_pdf(results[[dept]], paste0(dept, ".pdf"), batch_session = session)
}
```

`inject_assets`-callback peger automatisk `font_path` til `template_dir/fonts/` (eksisterende logik i `bfh_create_export_session()`).

### C. Posit Connect Cloud setup

Connect Cloud kræver autoriseret adgang til private repos for at installere `BFHchartsAssets`. Konkret konfiguration:

1. **Generate GitHub PAT** med scope `repo` (læseadgang til private repos)
2. Connect Cloud app **Settings → Environment Variables**:
   - `GITHUB_PAT=ghp_...` (eller `GITHUB_TOKEN`)
3. Verificér at `manifest.json` for biSPCharts genereres med `Remote*`-felter (memory: BFHcharts skal have `RemoteType`, `RemoteHost`, `RemoteUsername`, `RemoteRepo`, `RemoteSha`, `GithubRepo`, `GithubSHA`-felter; samme krav gælder `BFHchartsAssets`)
4. Re-deploy biSPCharts via `rsconnect::deployApp()` — Connect Cloud trækker `BFHchartsAssets` fra privat repo via PAT

### D. BFHcharts dokumentations-tilføjelse

Denne change ændrer **ikke** BFHcharts-koden. Men opdaterer:

- `README.md` — ny sektion "Branding for organizational deployments" der peger på companion-pakke-pattern
- `R/export_pdf.R` Roxygen `@section Security` — tilføj note om at en officiel companion-pakke er tilgængelig via privat distribution for hospitaler der vil genbruge BFH-branding
- OpenSpec spec `pdf-export` — tilføj requirement om at companion-asset-injection er den anbefalede pattern for proprietær branding

### Out of scope

- Skabelse af `BFHchartsAssets`-repo selv (separat git-init i privat scope)
- Faktisk push af Mari-fonts/logos til `BFHchartsAssets`/inst/assets/ (ud af BFHcharts repo control)
- biSPCharts-side ændringer (dispatches separat til biSPCharts repo som companion change)
- CI-smoke-render-strategi (dækket af `enable-ci-safe-pdf-smoke-render`-proposal; CI-test bruger DejaVu-only test-template, ikke companion-pkg)

## Impact

**Affected specs:**
- `pdf-export` — ADDED requirement: companion-pakke-pattern dokumenteret som anbefalet asset-distribution-mekanisme

**Affected code (BFHcharts repo):**
- `R/export_pdf.R` Roxygen — udvidet `@section Security` med companion-pkg-reference
- `R/export_session.R` Roxygen — samme
- `README.md` — ny sektion

**Cross-repo coordination:**
- **Privat repo creation**: `johanreventlow/BFHchartsAssets` (manuelt admin-trin)
- **biSPCharts companion change**: separat OpenSpec proposal i biSPCharts repo der adopter `BFHchartsAssets`-dependency

**Risiko:**
- Lav teknisk risiko for BFHcharts (kun docs-ændringer)
- Operativ risiko for biSPCharts/Connect Cloud setup (PAT-konfiguration, manifest.json Remote*-felter)

**Effort estimat:**
- BFHcharts side: 1-2 timer (docs-opdatering)
- BFHchartsAssets repo creation: 2-3 timer (init + DESCRIPTION + R/inject.R + tests + privat license + push)
- biSPCharts integration: 2-4 timer (DESCRIPTION-update + replace eksisterende inject_assets-implementation + Connect Cloud env-vars + re-deploy verifikation)
