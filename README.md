# BFHcharts

> Modern SPC Visualization for Healthcare Quality Improvement

**BFHcharts** is an R package for creating beautiful, publication-ready Statistical Process Control (SPC) charts tailored for healthcare settings. Built on `ggplot2` and `qicharts2`, it provides a consistent visual style inspired by BBC's data journalism approach.

## Features

- 🎨 **Beautiful themes** - Hospital branding with configurable multi-organizational support
- 📊 **SPC chart types** - Run charts, I-charts, P-charts, U-charts, and more
- 🔧 **Flexible API** - High-level convenience functions + low-level customization
- 📖 **Well documented** - Comprehensive vignettes and examples
- ✅ **Production ready** - Test-driven development with extensive coverage

## Installation

```r
# Install from GitHub
# install.packages("devtools")
devtools::install_github("johanreventlow/BFHcharts")
```

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
plot <- plot |> BFHtheme::add_logo()

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
