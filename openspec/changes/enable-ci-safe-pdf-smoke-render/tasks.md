## 0. Pre-investigation (BLOCKING for strategy choice)

- [ ] 0.1 Inspect `inst/templates/typst/bfh-template/fonts/` lokalt — list filnavne + licenser:
  - Mari fonts (proprietær): SKAL IKKE committes
  - DejaVu/Roboto/etc: kan committes hvis licens tillader (typisk OFL/Apache)
- [ ] 0.2 Inspect `inst/templates/typst/bfh-template/images/` — verificér at intet er proprietært
- [ ] 0.3 Læs `bfh-template.typ` — identificér hvilke font-names der hardcodes (fx `set text(font: "Mari")`); afgør om Strategi A er tilstrækkelig
- [ ] 0.4 Beslutning: Strategi A (font-fallback) eller Strategi B (bundled test-template). Dokumentér valg i PR-beskrivelsen

## 1. Asset-staging (Strategi A)

- [ ] 1.1 Track ikke-proprietære filer i `inst/templates/typst/bfh-template/`:
  ```bash
  git add inst/templates/typst/bfh-template/images/
  git add inst/templates/typst/bfh-template/fonts/<licens-tilladte filer>
  ```
- [ ] 1.2 Tilføj eksplicit `.gitignore`-entry for proprietære fonts:
  ```
  inst/templates/typst/bfh-template/fonts/Mari*.ttf
  inst/templates/typst/bfh-template/fonts/Mari*.otf
  ```
- [ ] 1.3 Dokumentér i `inst/templates/typst/bfh-template/README.md` (ny) hvor Mari-fonts kommer fra ved lokal udvikling og hvordan eksterne developers håndterer fallback

## 2. Workflow-fix

- [ ] 2.1 Rename `.github/workflows/pdf-smoke.yaml.disabled` → `.github/workflows/pdf-smoke.yaml`
- [ ] 2.2 Tilføj font-path env-step efter `apt-get install`:
  ```yaml
  - name: Configure smoke render font path
    run: |
      # /usr/share/fonts er hvor apt-installerede fonts ligger
      echo "BFHCHARTS_SMOKE_FONT_PATH=/usr/share/fonts" >> $GITHUB_ENV
      # Verify fonts are reachable
      fc-list | head -20
    shell: bash
  ```
- [ ] 2.3 Verificér at `tests/smoke/render_smoke.R` korrekt læser `BFHCHARTS_SMOKE_FONT_PATH` og videregiver til `bfh_export_pdf(..., font_path = ...)`
- [ ] 2.4 Optional: i `render_smoke.R`, tilføj CI-detection:
  ```r
  is_ci <- Sys.getenv("CI", unset = "") != ""
  ignore_fonts <- !is_ci  # på CI: brug system fonts; lokalt: ignore for konsistens
  bfh_export_pdf(..., ignore_system_fonts = ignore_fonts)
  ```

## 3. Test-PR-iteration

- [ ] 3.1 Open test-PR med ovenstående ændringer mod `develop`
- [ ] 3.2 Verificér at `pdf-smoke (ubuntu-latest)`-job bliver grøn
- [ ] 3.3 Hvis fejler: download `pdf-smoke-failures-<run_id>` artifact og diagnosticér (typisk Typst font-error eller manglende asset)
- [ ] 3.4 Iterér på Strategi A; hvis fortsat fejler efter 2-3 forsøg, eskalér til Strategi B

## 4. Strategi B (kun hvis 3.4 kræver det)

- [ ] 4.1 Opret `tests/smoke/test-template.typ` — minimal Typst-template der kun bruger universelle fonts (`set text(font: "DejaVu Sans")`)
- [ ] 4.2 Modificér `render_smoke.R` til at bruge denne test-template via `template_path`-argument når `Sys.getenv("CI") == "true"`
- [ ] 4.3 Re-test PR — verificér grøn

## 5. Branch protection (MANUELT TRIN)

- [ ] 5.1 **[MANUELT TRIN]** GitHub admin: Settings → Branches → Branch protection rules → main + develop → Require status checks → tilføj `pdf-smoke (ubuntu-latest)`
- [ ] 5.2 Dokumentér ændringen i `CONTRIBUTING.md` eller PR-template

## 6. Documentation

- [ ] 6.1 Opdatér `tests/smoke/render_smoke.R` header-kommentar med faktisk CI-strategi (efter strategi-valg)
- [ ] 6.2 NEWS.md entry under `## CI` for næste patch-version
- [ ] 6.3 Opdatér `pdf-smoke.yaml` header-kommentar så den matcher det faktiske workflow (fjern den misvisende sætning om `BFHCHARTS_SMOKE_FONT_PATH` hvis den ikke længere matcher)

## 7. Verification

- [ ] 7.1 Test-PR mod `develop` har grøn smoke-render i mindst 3 successive runs
- [ ] 7.2 Dummy-failure test: introducér bevidst Typst-syntax-fejl, verificér at workflowet rød-flagger og artifact-uploader fejler-PDF til debugging
- [ ] 7.3 Cleanup test-PR efter verification
