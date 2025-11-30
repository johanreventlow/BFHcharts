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
#' * [bfh_qic()] - High-level wrapper for complete SPC workflow
#' * [bfh_spc_plot()] - Low-level plotting from qic data
#' * [BFHtheme::theme_bfh()] - Apply BFH hospital theme styling (from BFHtheme package)
#' * [spc_plot_config()], [viewport_dims()], [phase_config()] - Configuration objects
#'
#' @section Design Philosophy:
#' Inspired by BBC's bbplot, BFHcharts follows these principles:
#' * Reproducibility through standardization
#' * Beautiful defaults with flexible customization
#' * Modern tidyverse-compatible API
#' * Comprehensive documentation and examples
#'
#' @examples
#' \dontrun{
#' # Quick start
#' library(BFHcharts)
#'
#' # Create SPC chart with one function
#' chart <- bfh_qic(
#'   data = my_data,
#'   x = "Date",
#'   y = "Admissions",
#'   chart_type = "run"
#' )
#'
#' # Apply BFH theme (from BFHtheme package)
#' chart + BFHtheme::theme_bfh()
#' }
#'
#' @keywords internal
#' @noRd
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
