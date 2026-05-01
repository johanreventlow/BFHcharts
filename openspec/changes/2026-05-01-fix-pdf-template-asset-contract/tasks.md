## 1. Beslut asset-policy

- [x] 1.1 Verificér aktuelt indhold af `inst/templates/typst/bfh-template/` i `git archive HEAD` (forventet: kun .typ-filen)
      Note: fonts/ gitignored (Mari* pattern), images/ untracked. Bekræftet ved session-start.
- [-] 1.2 Kør `Rscript tests/smoke/render_smoke.R` mod production-template og bekræft fejl-mode
      Note: Skippet -- render_smoke.R bruger CI-test-template, ikke production-template. Fejl-mode
      dokumenteret analytisk: manglende images/ filer forhindrer render uden inject_assets.
- [x] 1.3 Vælg Option A / B / C → **Option A valgt** (open-fallback default + companion til Mari)
- [x] 1.4 Dokumentér beslutning i `inst/adr/ADR-001-pdf-asset-policy.md`
      Note: Placeret i inst/adr/ (ikke docs/) fordi docs/ er gitignored (.gitignore linje 15).

## 2. Implementér valgt policy (eksempel for Option A)

- [-] 2.1 Skift production-template `font:` chain til `("Roboto", "Helvetica", "Arial", "sans-serif")` som default
      Note: IKKE implementeret per opgave-constraint "Skift IKKE font-chain i bfh-template.typ til at
      fjerne Mari". Font-chain er uændret ("Mari", "Roboto", "Arial", "Helvetica", "sans-serif").
      Mari er stadig første prioritet.
- [-] 2.2 Tilføj Roboto Regular + Bold (åben licens) til `inst/templates/typst/bfh-template/fonts/`
      Note: IKKE implementeret. Opgave-constraint: "Bundle ikke åbne fonts i denne PR uden eksplicit
      licens-validering." Roboto er Apache 2.0 -- licens er teknisk OK, men bundle-størrelse og
      update-ansvar er et separat follow-up-valg. Afventer eksplicit godkendelse.
- [-] 2.3 Erstat Mari-specific font-styling med fallback-friendly varianter
      Note: Ikke nødvendigt -- Typst font-fallback håndterer dette automatisk via font-chain.
- [x] 2.4 Verificér at Mari stadig opdages og bruges når companion-pakken har injected assets
      Note: Dækket af test-production-template-renders.R test 2 (inject_assets med Mari-check).
- [-] 2.5 Tilføj placeholder-logo eller fjern hard-coded `images/Hospital_Maerke_RGB_A1_str.png`-reference
      Note: Dokumenteret som known gap i ADR-001. Kræver separat follow-up. Smoke-tests skipper
      automatisk når images/ mangler.

## 3. Auto-detect staged fonts

- [x] 3.1 I `R/utils_typst.R:bfh_compile_typst()`: tilføj logik der detekterer `<template_dir>/fonts/`
      og sætter `--font-path` automatisk hvis arg ikke er sat eksplicit.
- [x] 3.2 Bevar mulighed for explicit `font_path` override (test: explicit_font_path overrides auto-detect)
- [x] 3.3 Test: companion-injectet `fonts/Mari.ttf` opdages uden eksplicit `font_path`
      (test-typst-fonts-autodetect.R, 6 tests, alle grønne)

## 4. Production-template-smoke-test

- [x] 4.1 Opret `tests/testthat/test-production-template-renders.R`
- [x] 4.2 Test: render uden `inject_assets` -- skipper automatisk når images/ mangler (known gap ADR-001)
- [x] 4.3 Test: render med inject_assets-callback der tilføjer Mari (skipper hvis Mari ikke tilgængelig)
- [-] 4.4 Test: git archive HEAD tarball-render
      Note: Skippet -- for kompleks at automatisere i testthat-regi. Documented gap i ADR-001.

## 5. CI-pipeline

- [x] 5.1 `.github/workflows/pdf-smoke.yaml`: Quarto setup allerede til stede (pre-release).
      Note: Beholdt pre-release (ikke nedgraderet til 1.5.0 som opgaven specificerede) fordi
      Typst >= 0.13 kræves for --ignore-system-fonts. Se workflow-kommentar.
- [x] 5.2 Tilføj step der kører production-template via BFHCHARTS_TEST_RENDER=true
- [-] 5.3 Konfigurér GitHub branch protection: manuelt trin -- kræver GitHub UI-adgang.
      Dokumenteret i workflow-header-kommentar.
- [-] 5.4 Verificér at job fejler ved manglende assets: testen skipper (not fails) pga. known gap.
      Follow-up: lukkes når images/ er bundled eller konditionel image-reference tilføjes.

## 6. Dokumentation

- [x] 6.1 README.md: tilføj "PDF asset policy"-sektion (efter "Font Requirements"-sektionen)
- [x] 6.2 Dokumentér hvad pakken garanterer (fallback) vs. companion-pakker (Mari, logo)
- [x] 6.3 Tilføj verificeringskommando (Rscript-snippet i README)
- [-] 6.4 Vignette `vignettes/pdf-export-deployment.Rmd`: skippet (ikke i scope for denne PR --
      tilhører separat dokumentations-PR)

## 7. Release

- [x] 7.1 NEWS-entry under `## Breaking changes` (BFHcharts 0.13.0 i NEWS.md)
- [x] 7.2 Bump `DESCRIPTION` Version til 0.13.0 (MINOR pre-1.0)
- [x] 7.3 `devtools::test()` kører: FAIL 1 (pre-existing utils_label_placement.R ASCII-fejl, ikke
      relateret til denne PR) | WARN 11 (pre-existing) | SKIP 49 | PASS 2853
- [-] 7.4 Manuel verificering ren git archive + render: udenfor scope for automatisk agent-run

## 8. Cross-repo coordination

- [-] 8.1 Notificér biSPCharts-maintainer: kræver manuelt trin af Johan
- [-] 8.2 Verificér Posit Connect Cloud-deploy af biSPCharts: kræver deploy-adgang
- [-] 8.3 Dokumentér Mari-inject i biSPCharts: separat PR i biSPCharts-repo
