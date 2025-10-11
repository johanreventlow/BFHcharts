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

# Create an SPC chart with one function call
chart <- create_spc_chart(
  data = my_data,
  x = "Date",
  y = "Count",
  chart_type = "run",
  title = "Patient Admissions"
)

# Apply BFH hospital theme
chart + bfh_theme()
```

## Advanced Usage

For more control, use the low-level API:

```r
# Configure plot parameters
plot_cfg <- spc_plot_config(
  chart_type = "p",
  y_axis_unit = "percent",
  target_value = 95
)

# Create plot
qic_data <- qicharts2::qic(x = date, y = numerator, n = denominator,
                            chart = "p", return.data = TRUE)
plot <- bfh_spc_plot(qic_data, plot_cfg)
```

## Documentation

- [Getting Started Vignette](vignettes/getting-started.Rmd)
- [Customizing SPC Plots](vignettes/customization.Rmd)
- [Multi-Hospital Theming](vignettes/theming.Rmd)

## License

GPL-3 © Johan Reventlow

## Acknowledgments

- Inspired by [BBC's bbplot](https://github.com/bbc/bbplot) design philosophy
- Built on [qicharts2](https://github.com/anhoej/qicharts2) for SPC calculations
- Developed for Bispebjerg og Frederiksberg Hospital quality improvement work
