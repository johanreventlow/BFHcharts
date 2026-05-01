# BFHcharts

[![codecov](https://codecov.io/gh/johanreventlow/BFHcharts/branch/main/graph/badge.svg)](https://codecov.io/gh/johanreventlow/BFHcharts) [![PDF smoke](https://github.com/johanreventlow/BFHcharts/actions/workflows/pdf-smoke.yaml/badge.svg)](https://github.com/johanreventlow/BFHcharts/actions/workflows/pdf-smoke.yaml)

> Modern SPC Visualization for Healthcare Quality Improvement

**BFHcharts** is an R package for creating beautiful, publication-ready Statistical Process Control (SPC) charts tailored for healthcare settings. Built on `ggplot2` and `qicharts2`, it provides a consistent visual style inspired by BBC's data journalism approach.

## Features

- 🎨 **Beautiful themes** - Hospital branding with configurable multi-organizational support
- 📊 **SPC chart types** - Run charts, I-charts, P-charts, U-charts, and more
- 🔧 **Flexible API** - Simple one-function interface returning composable ggplot2 objects
- 📖 **Well documented** - Comprehensive vignettes and examples
- ✅ **Production ready** - Test-driven development with extensive coverage

## Installation

### Using pak (recommended)

```r
# Install pak if you don't have it
install.packages("pak")

# For most users: Install stable release from r-universe (fastest)
pak::pkg_install("BFHcharts", repos = "https://johanreventlow.r-universe.dev")

# For developers: Install latest development version from GitHub
pak::pkg_install("johanreventlow/BFHcharts")
```

**r-universe vs GitHub:**
- **r-universe**: Pre-built binaries, ingen compilation, baseret på releases (anbefalet)
- **GitHub**: Seneste kode, kræver build tools, langsom (til udvikling)

### Using install.packages

```r
# From r-universe
install.packages("BFHcharts", repos = "https://johanreventlow.r-universe.dev")

# From GitHub (requires devtools)
devtools::install_github("johanreventlow/BFHcharts")
```

### BFHtheme dependency

BFHcharts depends on `BFHtheme (>= 0.5.0)` for theming and color palettes.
`BFHtheme` lives in the `Remotes:` field (not on CRAN), so it installs
automatically when you use `pak::pkg_install()` or
`remotes::install_github()` -- but **not** with the bare `install.packages()`
form. If you see a startup message
`BFHcharts requires BFHtheme >= 0.5.0`, install it explicitly:

```r
remotes::install_github("johanreventlow/BFHtheme@v0.5.0")
```

## Font Requirements

BFHcharts PDF export uses the **Mari font** for hospital branding when available.

### Internal Users (Region Hovedstaden)
Mari font is installed automatically on hospital computers. **No action needed** - PDFs will display full hospital branding.

### External Users
The package uses font fallback: **Mari → Roboto → Arial → Helvetica → sans-serif**.

PDFs will be fully functional and readable, but without Region Hovedstaden specific branding. This is by design - Mari font is copyrighted and cannot be redistributed with the package.

### Branding for Organizational Deployments

Healthcare organizations that need consistent proprietary branding (custom fonts, hospital logos) across their BFHcharts deployments should distribute those assets via a **private companion R package** rather than bundling them in their consumer application or hardcoding paths.

**Pattern:**

1. Create a private R package (e.g. `MyOrgAssets`) hosting fonts and images in `inst/assets/`
2. Export a single function `inject_my_assets(template_dir)` that copies bundled assets into the staged Typst template directory
3. In your consumer application (e.g. a Shiny dashboard), depend on the companion package and pass its inject function to BFHcharts:

```r
BFHcharts::bfh_export_pdf(
  result, "report.pdf",
  inject_assets = MyOrgAssets::inject_my_assets
)
```

This keeps proprietary assets out of public BFHcharts and out of your consumer app's git history, while supporting full branding in production deployments (including Posit Connect Cloud, RStudio Connect, and Docker).

For the BFH/Region Hovedstaden reference deployment, the `BFHchartsAssets` private companion package (separate repository, hospital-internal access) implements this pattern. See its repository documentation for setup details.

## PDF Asset Policy

This section documents exactly what the public `BFHcharts` package bundles, what requires
a companion package, and how to verify your setup.

### What the public package guarantees

- **Typst template:** `inst/templates/typst/bfh-template/bfh-template.typ` is bundled
  and used by default for all `bfh_export_pdf()` calls.
- **Font fallback chain:** The template specifies `("Mari", "Roboto", "Arial", "Helvetica", "sans-serif")`.
  If Mari is absent, Typst falls through to the next available font automatically. Roboto,
  Arial, and Helvetica are widely available on Ubuntu, macOS, and Windows.
- **No proprietary assets in package:** Mari fonts and hospital logos are gitignored and
  never committed to the public repository. A clean `pak::pkg_install()` from GitHub
  produces a package that renders PDFs with system-available fonts.
- **Auto-detect staged fonts:** `bfh_compile_typst()` automatically detects a `fonts/`
  subdirectory placed by `inject_assets` callbacks and passes it as `--font-path` to the
  Typst compiler — no extra configuration needed.

### What companion packages supply

- **Mari font files** (proprietary, Region Hovedstaden): `BFHchartsAssets::inject_bfh_assets`
  copies Mari `.otf`/`.ttf` files into the staged template directory before compile.
- **Hospital logo** (`images/Hospital_Maerke_RGB_A1_str.png`): supplied by the companion
  package alongside fonts.

Without a companion package, PDFs render correctly using system fonts but without the
hospital logo and Mari branding.

### Verifying your setup

```r
# Check which fonts Typst will find on your system
systemfonts::system_fonts()[grepl("Mari|Roboto", systemfonts::system_fonts()$family), "family"]

# Smoke-render a PDF to verify the full pipeline works
result <- bfh_qic(
  data.frame(x = 1:20, y = runif(20, 0.05, 0.15), n = rep(100, 20)),
  x = "x", y = "y", n = "n", chart_type = "p"
)
bfh_export_pdf(result, tempfile(fileext = ".pdf"))
message("PDF rendered successfully")
```

### Known limitation (images/)

The `images/` directory containing the hospital logo is currently untracked in the public
repository. A `git archive HEAD` tarball will produce a package where the default template
references an absent image. Rendering will succeed only when companion assets are injected
via `inject_assets`. A future release will add a conditional image reference or placeholder
asset to close this gap (see `inst/adr/ADR-001-pdf-asset-policy.md`).

## Quick Start

```r
library(BFHcharts)

# Example data: Monthly hospital-acquired infections
data <- data.frame(
  month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
  infections = rpois(24, lambda = 15),
  surgeries = rpois(24, lambda = 100)
)

# Example 1: Simple run chart
bfh_qic(
  data = data,
  x = month,
  y = infections,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Monthly Hospital-Acquired Infections"
)

# Example 2: P-chart with target line
bfh_qic(
  data = data,
  x = month,
  y = infections,
  n = surgeries,
  chart_type = "p",
  y_axis_unit = "percent",
  chart_title = "Infection Rate per 100 Surgeries",
  target_value = 0.02,
  target_text = "↓ Target: 2%"
)

# Example 3: I-chart with intervention (phase split)
bfh_qic(
  data = data,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count",
  chart_title = "Infections Before/After Intervention",
  part = c(12),  # Intervention after 12 months
  freeze = 12    # Freeze baseline at month 12
)
```

## Advanced Usage

### Hospital Branding with BFHtheme

BFHcharts integrates with the **BFHtheme** package for consistent hospital branding:

```r
library(BFHtheme)

# Example 1: Use default BFHtheme
plot <- bfh_qic(
  data = data,
  x = month,
  y = infections,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Hospital Quality Improvement Chart"
)

# Example 2: Add hospital logo
plot <- plot |> BFHtheme::add_bfh_logo()

# Example 3: Apply alternative BFHtheme variants
plot <- bfh_qic(
  data = data,
  x = month,
  y = infections,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Dark Theme Chart"
) + BFHtheme::theme_bfh_dark()

# Example 4: Use BFHtheme color palettes
plot <- bfh_qic(
  data = data,
  x = month,
  y = infections,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Custom Colors"
) +
  BFHtheme::scale_color_bfh_continuous()
```

**Note:** Customization of hospital colors is handled by the [BFHtheme](https://github.com/your-org/BFHtheme) package. Refer to BFHtheme documentation for advanced theming options.

## Batch PDF Export

When generating PDFs for multiple departments or indicators in a loop,
use `bfh_create_export_session()` to copy the Typst template assets once
and share them across all exports. This eliminates the recursive
directory copy that otherwise happens on every `bfh_export_pdf()` call.

```r
library(BFHcharts)

# Create a session — template assets copied once
session <- bfh_create_export_session()
on.exit(close(session))  # Cleanup when done

departments <- c("ICU", "Medicine", "Surgery")
for (dept in departments) {
  result <- bfh_qic(dept_data[[dept]], x = month, y = value,
                    chart_type = "i", chart_title = paste("Quality —", dept))
  bfh_export_pdf(result,
                 output = paste0(dept, "_report.pdf"),
                 metadata = list(department = dept),
                 batch_session = session)
}
# close(session) called automatically via on.exit()
```

**Notes:**
- `batch_session` cannot be combined with `template_path` or `inject_assets`.
- Pass `inject_assets` and `font_path` to `bfh_create_export_session()` instead.
- Sessions are single-threaded; do not share across parallel workers.

## Supported Languages

Chart labels, analysis text, and details output are available in Danish (`"da"`, default) and English (`"en"`).

```r
# English output
result <- bfh_qic(data, x = month, y = value, chart_type = "p",
                  language = "en")

bfh_generate_analysis(result, language = "en")
bfh_generate_details(result, language = "en")
```

Default is `language = "da"` — existing code without the parameter is unaffected.
See `TRANSLATORS.md` for instructions on adding a new language.

## Limitations

- Facettering (`facets`, `nrow`, `ncol`, `scales`) er endnu ikke understøttet i BFHcharts; multi-panel plots kræver manuel opbygning indtil issue #1 løses.

## Documentation

- Roxygen reference topics, e.g. `?bfh_qic` or `help(package = "BFHcharts")`
- Architecture notes in [`docs/`](docs/DOCUMENTATION_OVERVIEW.md)
- Vignettes are planned; links will be added once the articles ship

## License

GPL-3 © Johan Reventlow

## Acknowledgments

- Inspired by [BBC's bbplot](https://github.com/bbc/bbplot) design philosophy
- Built on [qicharts2](https://github.com/anhoej/qicharts2) for SPC calculations
- Developed for Bispebjerg og Frederiksberg Hospital quality improvement work
