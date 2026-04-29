## Why

Begge code reviews 2026-04-29 (Claude statisk + Codex runtime) flaggede at `.github/workflows/pdf-smoke.yaml` er disabled (`pdf-smoke.yaml.disabled`, commit `c798142`). Den var oprindeligt designet som PR-blocking gate for end-to-end Typst/Quarto-pipeline-regressioner.

Codex' anden runtime-undersøgelse identificerede de **konkrete årsager** til at workflowet ikke kan blive grøn:

**1. Untracked template assets:**

```
$ git ls-files inst/templates/typst/bfh-template
inst/templates/typst/bfh-template/bfh-template.typ
```

Lokalt findes også `inst/templates/typst/bfh-template/fonts/` og `images/` — men de er **untracked**. Bekræftes af `git status` ved session-start: `?? inst/templates/typst/bfh-template/images/`. CI-checkout får kun `bfh-template.typ`, ingen Mari-fonts og ingen logo-billeder.

**2. Workflow env-var ikke sat:**

`pdf-smoke.yaml.disabled` header siger:
```
... installerer open fallback-fonts (DejaVu, Liberation, Noto, Roboto)
og sætter dem som font_path-override i render_smoke.R via env-var
BFHCHARTS_SMOKE_FONT_PATH.
```

Men workflow-stepsene installerer fonts via `apt-get` og kører `fc-cache`, **uden** at sætte `BFHCHARTS_SMOKE_FONT_PATH`. `tests/smoke/render_smoke.R:80` læser denne env-var — når den er tom, falder den tilbage til default-adfærd (`ignore_system_fonts = TRUE`), hvilket forhindrer Typst i at bruge de apt-installerede fonts.

**3. Mari-font-strategi:**

Mari er proprietær og kan ikke commits til public repo. Pakkens egen font-fallback-chain (Mari → Roboto → Arial → Helvetica → sans-serif) er designet netop til scenarier hvor Mari ikke er tilgængelig — men kun hvis Typst faktisk kan se fallbacks.

**Korrekt analyse:** PDF-smoke kan blive grøn på CI **hvis** font-strategien er CI-eksplicit. Den nuværende disable er et bevidst kompromis fordi første aktiverings-forsøg ikke loadede fallback-fonts korrekt — ikke fordi det er principielt umuligt.

**Cost-benefit:**
- **Cost ved ikke at have PR-gate:** Typst/Quarto-pipeline-regressioner (template-syntax, escape-bugs, asset-paths) lander på main og fanges først ved næste manuelle render eller ugentlig cron i `render-tests.yaml`. Codex' runtime-tests bestod 3/3 lokalt → pipelinen virker, så regressions-risiko er reel
- **Cost ved at fikse:** ~2-4 timer arbejde, ingen breaking changes, ingen nye dependencies

## What Changes

- **NON-BREAKING** — kun CI-konfiguration og test-asset-staging
- Beslutning: enten **(A) font-fallback-only** eller **(B) bundled-test-fonts**. Forslag: **A først, B kun hvis A insufficient**

### Strategi A: Font-fallback only (foretrukket — enklere)

1. **Track template assets der mangler i git:**
   - Verificér at `inst/templates/typst/bfh-template/fonts/` indeholder kun licens-kompatible fonts (ingen Mari) — hvis ja, track. Hvis Mari ligger der, ekskludér via `.gitignore` og dokumentér hvor den kommer fra ved lokal udvikling
   - Track `inst/templates/typst/bfh-template/images/` (logo-assets der ikke er proprietære)
2. **Fix workflow env-var:**
   - I `pdf-smoke.yaml`, tilføj efter `apt-get install`-step:
     ```yaml
     - name: Set font path for smoke render
       run: |
         echo "BFHCHARTS_SMOKE_FONT_PATH=/usr/share/fonts/truetype" >> $GITHUB_ENV
     ```
   - ELLER alternativt: ændre `tests/smoke/render_smoke.R` til at sætte `ignore_system_fonts = FALSE` på CI (detect via `Sys.getenv("CI") == "true"`), så Typst kan bruge apt-installerede fonts uden eksplicit path
3. **Reactivate workflow:**
   - Rename `pdf-smoke.yaml.disabled` → `pdf-smoke.yaml`
   - Verificér at workflowet bliver grøn på en test-PR før merge

### Strategi B: Bundled test fonts (fallback hvis A ikke er nok)

Hvis A ikke giver grøn CI (fx fordi `bfh-template.typ` har hardcoded font-names der ikke er installerede):

1. Tilføj minimal test-template `tests/smoke/test-template.typ` der kun bruger `set text(font: "DejaVu Sans")`
2. `render_smoke.R` bruger denne test-template via `template_path`-argument på CI
3. `bfh-template.typ` med Mari-fonts forbliver kun brugt lokalt + via `BFHcharts:::system.file()` i produktion

**Out of scope:**
- Visuel regression med Mari-fonts på CI — håndteres allerede af `vdiffr` (skipped on CI for platform-specific font rendering) og manuel review
- Branch-protection-konfiguration på GitHub — kræver manuel admin-handling dokumenteret i tasks
- Replikering af proprietære Mari-fonts i CI — udelukket pga. licens

## Impact

**Affected specs:**
- `test-infrastructure` — MODIFIED requirement: PR-blocking PDF render gate SHALL be CI-safe via deterministic font fallback strategy

**Affected code:**
- `.github/workflows/pdf-smoke.yaml.disabled` → `.github/workflows/pdf-smoke.yaml` (rename + fix font env-var step)
- `tests/smoke/render_smoke.R` — optional: tilføj CI-detect for `ignore_system_fonts = FALSE`-override
- `inst/templates/typst/bfh-template/` — track legitimate assets (verify Mari ikke commits)
- Eventuelt: `tests/smoke/test-template.typ` (kun hvis Strategi B nødvendig)
- `.gitignore` — eksplicit ekskludér Mari-font-filer ved navn hvis de tidligere lå untracked

**Branch-protection (manuelt admin-step):**
- Settings → Branches → main + develop → Require status checks → tilføj `pdf-smoke (ubuntu-latest)`

**Risiko:**
- Lav teknisk risiko (CI-only ændring, intet runtime-impact)
- Procesmæssig risiko: workflowet kan stadig fejle initialt indtil rigtig kombination af `font_path` + `ignore_system_fonts` er fundet. Mitigér via test-PR før branch-protection aktiveres

**Effort estimat:**
- Strategi A: 2-4 timer (asset-staging + workflow-fix + test-PR-iteration)
- Strategi B: +2-3 timer (separat test-template)

**Effort matches priority:** FIX SOON, ikke FIX NOW. Kan ligge i næste sprint.
