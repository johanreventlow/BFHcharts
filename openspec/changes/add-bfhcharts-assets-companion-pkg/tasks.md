## 1. BFHcharts repo (this proposal's direct scope)

### 1a. Documentation updates

- [ ] 1.1 Tilføj sektion til `README.md` under existing "Font Requirements": "Branding for organizational deployments" der beskriver companion-pakke-pattern
- [ ] 1.2 Udvid Roxygen `@section Security` i `R/export_pdf.R` (linje ~107-130) med reference til at en officiel companion-pakke kan eksistere for organisationen
- [ ] 1.3 Samme reference i `R/export_session.R` Roxygen
- [ ] 1.4 Kør `devtools::document()` for at regenerere Rd-filer
- [ ] 1.5 NEWS.md entry under `## Dokumentation` for næste patch

### 1b. OpenSpec spec update

- [ ] 1.6 Tilføj nyt requirement i `openspec/specs/pdf-export/spec.md`: "Companion-pakker SHALL be the recommended pattern for organizational asset distribution" med scenarios

## 2. BFHchartsAssets repo (separat — manuelt admin-trin)

**[MANUELT TRIN]** Denne sektion kan ikke automatiseres fra BFHcharts repo. Udføres separat.

- [ ] 2.1 Opret privat GitHub repo `johanreventlow/BFHchartsAssets` (visibility: private)
- [ ] 2.2 Initialiser R-pakke-struktur lokalt:
  ```bash
  mkdir BFHchartsAssets && cd BFHchartsAssets
  Rscript -e 'usethis::create_package(".")'
  ```
- [ ] 2.3 Skriv `DESCRIPTION`:
  ```
  Package: BFHchartsAssets
  Title: BFH Branding Assets for BFHcharts
  Version: 0.1.0
  Authors@R: person("Johan", "Reventlow", email = "johan.reventlow@regionh.dk", role = c("aut", "cre"))
  Description: Private companion package providing proprietary fonts and
      hospital branding images for BFHcharts PDF export. Distributed via
      private GitHub repository; not for public release.
  License: file LICENSE
  Encoding: UTF-8
  Imports:
      BFHcharts (>= 0.11.1)
  Remotes:
      johanreventlow/BFHcharts
  ```
- [ ] 2.4 Skriv `LICENSE` med "Proprietary - Region Hovedstaden - All rights reserved"
- [ ] 2.5 Skriv `R/inject.R` med `inject_bfh_assets()` (kode i proposal.md)
- [ ] 2.6 `usethis::use_roxygen_md()` + `devtools::document()`
- [ ] 2.7 Kopiér Mari-fonts + Arial-fonts + logos fra lokalt master-source til `inst/assets/fonts/` og `inst/assets/images/`
- [ ] 2.8 Skriv `tests/testthat/test-inject.R`:
  - Test: `inject_bfh_assets(tmpdir)` opretter `fonts/` og `images/` subdir'er
  - Test: alle bundlede filer findes på destinationen efter kald
  - Test: callback fejler gracefully ved ugyldig `template_dir`
- [ ] 2.9 `devtools::check()` — sikre 0 errors/warnings
- [ ] 2.10 Initial commit + push til privat repo
- [ ] 2.11 Tag `v0.1.0` annoteret + push tag

## 3. biSPCharts integration (separat — i biSPCharts repo)

**[CROSS-REPO]** Udføres som separat OpenSpec change i biSPCharts repo.

- [ ] 3.1 Opret OpenSpec proposal i biSPCharts: `adopt-bfhcharts-assets-companion`
- [ ] 3.2 biSPCharts `DESCRIPTION`: tilføj `BFHchartsAssets` til `Imports` + `Remotes`
- [ ] 3.3 Erstat eksisterende ad-hoc `inject_assets`-implementation (hvis nogen) med `BFHchartsAssets::inject_bfh_assets`
- [ ] 3.4 Opdatér `manifest.json` via `rsconnect::writeManifest()` så `BFHchartsAssets` har `Remote*`-felter (memory: samme problem som tidligere blokerede BFHcharts på Connect Cloud)
- [ ] 3.5 Test lokal PDF-render: bekræft Mari-fonts + logos rendres korrekt

## 4. Posit Connect Cloud setup (manuelt admin-trin)

**[MANUELT TRIN]**

- [ ] 4.1 Generér GitHub PAT med scope `repo` (read access til private repos)
- [ ] 4.2 Connect Cloud → biSPCharts app → Settings → Environment Variables:
  - Tilføj `GITHUB_PAT=<token>` (eller `GITHUB_TOKEN`)
- [ ] 4.3 Re-deploy biSPCharts via `rsconnect::deployApp()`
- [ ] 4.4 Verifikation: download en genereret PDF fra Connect Cloud, bekræft Mari-fonts og logos rendres
- [ ] 4.5 Hvis fejl: tjek Connect Cloud install logs for `BFHchartsAssets`-installation; verificér PAT scope; verificér `manifest.json` Remote*-felter

## 5. Verification (BFHcharts side)

- [ ] 5.1 `devtools::check()` på BFHcharts efter docs-ændringer: 0 nye errors/warnings
- [ ] 5.2 Manuel: `?bfh_export_pdf` viser opdateret security-section med companion-pkg-reference
- [ ] 5.3 OpenSpec spec validation: nyt requirement er well-formed

## 6. Release coordination

- [ ] 6.1 BFHcharts: bump til næste patch + tag (kan kombineres med #1 og/eller #4)
- [ ] 6.2 BFHchartsAssets: tag v0.1.0 efter initial commit
- [ ] 6.3 biSPCharts: bump efter integration + redeploy verificeret
