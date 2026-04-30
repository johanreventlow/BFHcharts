#' BFHcharts: SPC Visualization for Healthcare Quality Improvement
#'
#' @description
#' BFHcharts provides modern, publication-ready Statistical Process Control (SPC)
#' charts for healthcare quality improvement. Built on ggplot2 and qicharts2,
#' it offers:
#'
#' * Beautiful themes with hospital branding support
#' * High-level convenience functions for quick plotting
#' * Low-level API for advanced customization
#' * Comprehensive SPC chart types (run, I, P, U, C, etc.)
#'
#' @section Main Functions:
#' The package exports one primary function:
#' * `bfh_qic()` - High-level wrapper for complete SPC workflow
#'
#' Additional exported utilities:
#' * `bfh_export_pdf()`, `bfh_export_png()` - Export charts to PDF/PNG
#' * `bfh_extract_spc_stats()`, `bfh_merge_metadata()` - Utility functions
#'
#' @section Design Philosophy:
#' Inspired by BBC's bbplot, BFHcharts follows these principles:
#' * Reproducibility through standardization
#' * Beautiful defaults with flexible customization
#' * Modern tidyverse-compatible API
#' * Comprehensive documentation and examples
#'
#' @section BFHtheme dependency:
#' BFHcharts requires `BFHtheme >= 0.5.0` for theming, color palettes and
#' scale helpers. `BFHtheme` is hosted as a GitHub-only package via the
#' `Remotes:` field; install with `pak::pkg_install("johanreventlow/BFHcharts")`
#' or `remotes::install_github("johanreventlow/BFHtheme@v0.5.0")` to ensure
#' it is present.
#'
#' If `BFHtheme` is missing or older than 0.5.0, BFHcharts emits a
#' `packageStartupMessage()` at `library(BFHcharts)` and fails fast with an
#' actionable install hint at the first plot call. The check is cached per
#' session for performance.
#'
#' @examples
#' \dontrun{
#' # Quick start
#' library(BFHcharts)
#'
#' # Create SPC chart with one function
#' chart <- bfh_qic(
#'   data = my_data,
#'   x = Date,
#'   y = Admissions,
#'   chart_type = "run"
#' )
#'
#' # Plot resultatet
#' plot(chart)
#' }
#'
#' @keywords internal
#' @noRd
"_PACKAGE"

## usethis namespace: start
## svglite is loaded indirectly via ggplot2::ggsave(filename = ".svg", ...)
## inside `bfh_export_pdf()` -> `export_chart_svg()`. Declared in Imports
## so downstream deployments (Posit Connect, renv) auto-install it; the
## directive below silences the "Namespace not imported from" R CMD check
## NOTE without altering call-site behaviour.
#' @importFrom svglite svglite
## usethis namespace: end
NULL
