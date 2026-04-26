# BFHcharts

[![codecov](https://codecov.io/gh/johanreventlow/BFHcharts/branch/main/graph/badge.svg)](https://codecov.io/gh/johanreventlow/BFHcharts)

> Modern SPC Visualization for Healthcare Quality Improvement

**BFHcharts** is an R package for creating beautiful, publication-ready Statistical Process Control (SPC) charts tailored for healthcare settings. Built on `ggplot2` and `qicharts2`, it provides a consistent visual style inspired by BBC's data journalism approach.

## Features

- 🎨 **Beautiful themes** - Hospital branding with configurable multi-organizational support
- 📊 **SPC chart types** - Run charts, I-charts, P-charts, U-charts, and more
- 🔧 **Flexible API** - High-level convenience functions + low-level customization
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

## Font Requirements

BFHcharts PDF export uses the **Mari font** for hospital branding when available.

### Internal Users (Region Hovedstaden)
Mari font is installed automatically on hospital computers. **No action needed** - PDFs will display full hospital branding.

### External Users
The package uses font fallback: **Mari → Roboto → Arial → Helvetica → sans-serif**.

PDFs will be fully functional and readable, but without Region Hovedstaden specific branding. This is by design - Mari font is copyrighted and cannot be redistributed with the package.

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
create_spc_chart(
  data = data,
  x = month,
  y = infections,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Monthly Hospital-Acquired Infections"
)

# Example 2: P-chart with target line
create_spc_chart(
  data = data,
  x = month,
  y = infections,
  n = surgeries,
  chart_type = "p",
  y_axis_unit = "percent",
  chart_title = "Infection Rate per 100 Surgeries",
  target_value = 2.0,
  target_text = "↓ Target: 2%"
)

# Example 3: I-chart with intervention (phase split)
create_spc_chart(
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

### Low-Level API for Fine Control

```r
# Step 1: Calculate QIC data using qicharts2
library(qicharts2)

qic_data <- qic(
  x = month,
  y = infections,
  n = surgeries,
  data = data,
  chart = "p",
  return.data = TRUE
)

# Step 2: Configure plot
plot_cfg <- spc_plot_config(
  chart_type = "p",
  y_axis_unit = "percent",
  chart_title = "Custom Infection Rate",
  target_value = 2.0,
  target_text = "Target: 2%"
)

viewport <- viewport_dims(base_size = 14)

# Step 3: Generate plot
plot <- bfh_spc_plot(qic_data, plot_cfg, viewport)
plot
```

### Hospital Branding with BFHtheme

BFHcharts integrates with the **BFHtheme** package for consistent hospital branding:

```r
library(BFHtheme)

# Example 1: Use default BFHtheme
plot <- create_spc_chart(
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
plot <- create_spc_chart(
  data = data,
  x = month,
  y = infections,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Dark Theme Chart"
) + BFHtheme::theme_bfh_dark()

# Example 4: Use BFHtheme color palettes
plot <- create_spc_chart(
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

- Roxygen reference topics, e.g. `?create_spc_chart` or `help(package = "BFHcharts")`
- Architecture notes in [`docs/`](docs/DOCUMENTATION_OVERVIEW.md)
- Vignettes are planned; links will be added once the articles ship

## License

GPL-3 © Johan Reventlow

## Acknowledgments

- Inspired by [BBC's bbplot](https://github.com/bbc/bbplot) design philosophy
- Built on [qicharts2](https://github.com/anhoej/qicharts2) for SPC calculations
- Developed for Bispebjerg og Frederiksberg Hospital quality improvement work
