## ADDED Requirements

### Requirement: Organizational asset distribution SHALL use companion package pattern

For organizations that need to bundle proprietary fonts and branding assets (logos, hospital identifiers) with BFHcharts-based deployments, the asset distribution SHALL use a private companion R package pattern. BFHcharts itself SHALL NOT bundle proprietary assets, and consumer applications SHALL NOT hardcode absolute paths to assets in `inject_assets` callbacks. The companion package SHALL:

1. Hosts the proprietary assets in `inst/assets/fonts/` and `inst/assets/images/`
2. Exports a single function (e.g. `inject_bfh_assets(template_dir)`) that copies all bundled assets into a Typst template staging directory
3. Is installed as a private dependency by the consumer application (e.g. biSPCharts on Posit Connect Cloud)
4. Plugs into BFHcharts via the existing `inject_assets` callback parameter on `bfh_export_pdf()` and `bfh_create_export_session()`

**Rationale:**

- BFHcharts itself is GPL-3 and publicly distributed; it cannot bundle proprietary fonts (Mari, Arial) or third-party-owned hospital logos
- The `inject_assets` callback was designed precisely for this asset-runtime-injection pattern but lacked an officially recommended distribution mechanism
- A companion package gives organizations versioned, audit-trackable, dependency-managed asset distribution that integrates cleanly with R's package ecosystem (renv, manifest.json on Posit Connect)
- Compared to ad-hoc deploy-bundle staging, companion packages provide: source-of-truth versioning, reusability across multiple consumer applications, and clean separation of GPL-distributable code from proprietary brand assets

**Anti-patterns this requirement formalizes against:**

- Hardcoded absolute paths in `inject_assets` callbacks (breaks on cloud deployments)
- Manual asset staging in deploy bundles via `.gitignore` + pre-deploy copy scripts (no audit trail; easily forgotten)
- Direct commit of proprietary fonts/logos into BFHcharts (license violations) or into consumer application repos that are public (same violations)

#### Scenario: Companion package exposes single inject_assets-compatible function

- **GIVEN** a private companion package (e.g. `BFHchartsAssets`)
- **WHEN** the package is installed
- **THEN** it SHALL export a function with signature `function(template_dir)` that:
  - Validates `template_dir` is a single character path to an existing directory
  - Copies all bundled fonts from `system.file("assets/fonts", package = "<pkg>")` to `<template_dir>/fonts/`
  - Copies all bundled images from `system.file("assets/images", package = "<pkg>")` to `<template_dir>/images/`
  - Creates `fonts/` and `images/` subdirectories if they do not exist
  - Errors clearly if any file copy fails

```r
# Reference implementation
inject_bfh_assets <- function(template_dir) {
  stopifnot(is.character(template_dir), length(template_dir) == 1, dir.exists(template_dir))

  fonts_src  <- system.file("assets/fonts",  package = "BFHchartsAssets", mustWork = TRUE)
  images_src <- system.file("assets/images", package = "BFHchartsAssets", mustWork = TRUE)

  fonts_dst  <- file.path(template_dir, "fonts")
  images_dst <- file.path(template_dir, "images")
  dir.create(fonts_dst,  showWarnings = FALSE, recursive = TRUE)
  dir.create(images_dst, showWarnings = FALSE, recursive = TRUE)

  fonts_ok  <- all(file.copy(list.files(fonts_src,  full.names = TRUE), fonts_dst,  overwrite = TRUE))
  images_ok <- all(file.copy(list.files(images_src, full.names = TRUE), images_dst, overwrite = TRUE))

  if (!fonts_ok || !images_ok) {
    stop("Failed to inject one or more asset files", call. = FALSE)
  }

  invisible(NULL)
}
```

#### Scenario: Consumer integrates companion via inject_assets parameter

- **GIVEN** a consumer Shiny app (biSPCharts) deployed to Posit Connect Cloud
- **AND** the consumer has `BFHchartsAssets` in its `Imports` and `Remotes`
- **WHEN** the consumer calls `BFHcharts::bfh_export_pdf(..., inject_assets = BFHchartsAssets::inject_bfh_assets)`
- **THEN** the rendered PDF SHALL display full hospital branding with Mari fonts and Region Hovedstaden logos
- **AND** BFHcharts itself SHALL NOT have any code that references `BFHchartsAssets` (clean dependency direction: consumer → BFHcharts; consumer → BFHchartsAssets)

```r
# Consumer code pattern (biSPCharts):
result <- BFHcharts::bfh_qic(data, x = month, y = infections, chart_type = "i")
BFHcharts::bfh_export_pdf(
  result, output_pdf,
  metadata = list(hospital = "Bispebjerg og Frederiksberg Hospital", department = dept),
  inject_assets = BFHchartsAssets::inject_bfh_assets
)
```

#### Scenario: BFHcharts documentation references companion pattern as canonical

- **GIVEN** a user reads `?bfh_export_pdf` or `README.md`
- **WHEN** the user reaches the security/branding section
- **THEN** the documentation SHALL describe the companion-package pattern as the recommended approach for organizations needing proprietary branding
- **AND** SHALL explicitly state that BFHcharts does not bundle Mari fonts or hospital logos

#### Scenario: Companion package is independent of BFHcharts release cadence

- **GIVEN** the companion package and BFHcharts are versioned independently
- **WHEN** BFHcharts releases a patch version
- **THEN** the companion package SHALL NOT need to be re-released unless the `inject_assets`-callback contract changes
- **AND** the companion package's `DESCRIPTION` SHALL specify `BFHcharts (>= <minimum-version>)` to assert the callback contract version it supports

This decoupling allows BFHcharts to evolve its public API freely while organizations control their branding-asset release cadence separately.
