## ADDED Requirements

### Requirement: PR-blocking PDF render gate SHALL be CI-safe via deterministic fallback fonts

A PR-blocking GitHub Actions workflow SHALL execute end-to-end PDF rendering on every pull request to `main` and `develop`. The workflow SHALL be deterministically green when the package code is correct, despite the proprietary Mari font not being installable on CI.

**Rationale:**

- End-to-end Typst/Quarto pipeline regressions (template syntax, escape bugs, asset paths, font-fallback wiring) cannot be caught by unit tests of R code alone
- Without a PR gate, regressions land on `main` and are caught only by weekly cron renders or manual verification — too slow to block bad merges
- Mari font is proprietary and cannot be redistributed in a public repository; CI must rely on legally redistributable fallback fonts
- Disabling the workflow (current state: `pdf-smoke.yaml.disabled`) leaves an exposed gap that both code reviews flagged

**CI font strategy contract:**

The workflow SHALL satisfy one of the following CI-safe configurations:

**Option A (preferred):** Use system-installed open fallback fonts via `apt-get install`, point `BFHCHARTS_SMOKE_FONT_PATH` env var to their installation path, and let the package's existing font-fallback chain (Mari → Roboto → Arial → Helvetica → sans-serif) resolve to a system font. Requires `ignore_system_fonts = FALSE` OR explicit `font_path` to apt-installed fonts.

**Option B (fallback):** Use a minimal CI-only Typst test-template (`tests/smoke/test-template.typ`) that hardcodes only universal open fonts (e.g., DejaVu Sans). The production `bfh-template.typ` is not exercised on CI but still used in production where Mari is available.

**Asset bundling contract:**

- Template files in `inst/templates/typst/bfh-template/` SHALL be tracked in git **except** files identified as proprietary (Mari fonts)
- Proprietary font filenames SHALL be explicitly excluded via `.gitignore`
- Non-proprietary assets (logos, open fonts, images) SHALL be tracked so CI checkout can reproduce the rendering environment

#### Scenario: PDF smoke workflow is enabled and required

- **GIVEN** the GitHub repository
- **WHEN** a developer inspects `.github/workflows/`
- **THEN** `pdf-smoke.yaml` SHALL exist (not `.disabled`)
- **AND** the workflow SHALL be configured as a required status check on the `main` and `develop` branches via branch protection

#### Scenario: Smoke workflow renders against legally redistributable fonts

- **GIVEN** the smoke workflow runs on a fresh GitHub-hosted Ubuntu runner
- **WHEN** the workflow installs system fonts via `apt-get install fonts-dejavu fonts-liberation fonts-noto`
- **THEN** the env var `BFHCHARTS_SMOKE_FONT_PATH` SHALL point to a directory those fonts are installed in
- **AND** `tests/smoke/render_smoke.R` SHALL pass `font_path = Sys.getenv("BFHCHARTS_SMOKE_FONT_PATH")` to `bfh_export_pdf()`
- **AND** `bfh_export_pdf()` SHALL successfully compile a PDF that is non-empty and has at least 1 page

```r
# tests/smoke/render_smoke.R contract:
font_path_override <- Sys.getenv("BFHCHARTS_SMOKE_FONT_PATH", unset = NA_character_)
stopifnot(!is.na(font_path_override) || !is_ci())  # CI must set the env var

result <- bfh_qic(test_data, ...)
out_pdf <- tempfile(fileext = ".pdf")
bfh_export_pdf(
  result, out_pdf,
  font_path = if (!is.na(font_path_override)) font_path_override else NULL
)

stopifnot(file.exists(out_pdf))
stopifnot(file.info(out_pdf)$size > 0)
stopifnot(pdftools::pdf_info(out_pdf)$pages >= 1)
```

#### Scenario: Proprietary fonts excluded from git

- **GIVEN** developer adds a Mari-licensed font to the local template directory
- **WHEN** the developer runs `git status`
- **THEN** the Mari font file SHALL appear as ignored (via `.gitignore` pattern)
- **AND** SHALL NOT be accidentally committed via `git add inst/`

```gitignore
# Excerpt from .gitignore
inst/templates/typst/bfh-template/fonts/Mari*.ttf
inst/templates/typst/bfh-template/fonts/Mari*.otf
```

#### Scenario: Workflow header documentation matches actual implementation

- **GIVEN** `.github/workflows/pdf-smoke.yaml` header comment claims a font strategy
- **WHEN** a maintainer reads the workflow header
- **THEN** the documented strategy SHALL match what the workflow steps actually do
- **AND** any env vars referenced in the header SHALL actually be set by a workflow step
- **AND** drift between header and steps SHALL be treated as a documentation bug requiring fix

This scenario specifically prevents the regression where the prior `pdf-smoke.yaml.disabled` header described setting `BFHCHARTS_SMOKE_FONT_PATH` while no workflow step actually exported it.

#### Scenario: Workflow failure uploads diagnostic artifacts

- **GIVEN** the smoke workflow fails (non-zero exit code from `Rscript tests/smoke/render_smoke.R`)
- **WHEN** the workflow finishes
- **THEN** `actions/upload-artifact@v4` SHALL upload generated `.pdf`, `.typ`, and `.tex.log` files
- **AND** the artifact name SHALL include `${{ github.run_id }}` for unique identification
- **AND** retention SHALL be at least 7 days
