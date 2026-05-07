#' BFH QIC Result S3 Class
#'
#' S3 class for wrapping SPC chart outputs. Enables pipe-compatible export
#' workflows while maintaining backwards-compatible console display.
#'
#' Objects of class \code{bfh_qic_result} are returned by \code{\link{bfh_qic}}.
#' Access components with \code{result$plot}, \code{result$summary},
#' \code{result$qic_data}, and \code{result$config}.
#'
#' @name bfh_qic_result
NULL

#' Create a bfh_qic_result Object
#'
#' Constructor for the bfh_qic_result S3 class. This class wraps SPC chart
#' outputs to enable pipe-compatible export functions while preserving
#' backwards-compatible console behavior.
#'
#' @param plot ggplot2 object containing the SPC chart
#' @param summary tibble with SPC statistics (runs, crossings, control limits)
#' @param qic_data data.frame with raw qicharts2 calculation results
#' @param config list with original function parameters
#'
#' @return An object of class \code{bfh_qic_result} containing:
#'   \item{plot}{ggplot2 object with the SPC chart}
#'   \item{summary}{tibble with summary statistics}
#'   \item{qic_data}{data.frame with qicharts2 calculations}
#'   \item{config}{list with original parameters}
#'
#' @section Stability:
#' \code{new_bfh_qic_result} is a stable, exported constructor. The structure of
#' \code{bfh_qic_result} objects has been stable since v0.10.0. Field names
#' (\code{$plot}, \code{$summary}, \code{$qic_data}, \code{$config}) will not
#' be removed without a deprecation cycle.
#'
#' @section qic_data columns:
#' The \code{$qic_data} field is a \code{data.frame} with the following
#' canonical columns (supplied by qicharts2 >= 0.7.0):
#' \describe{
#'   \item{x}{Original x-axis input values}
#'   \item{y}{Original y-axis input values (per-period)}
#'   \item{n}{Denominator counts (for proportion/rate charts)}
#'   \item{cl}{Numeric center line}
#'   \item{ucl}{Numeric upper control limit}
#'   \item{lcl}{Numeric lower control limit}
#'   \item{ucl.95, lcl.95}{95-percent warning limits (Shewhart sigma = 2)}
#'   \item{sigma.signal}{Logical: point outside 3-sigma control limits}
#'   \item{runs.signal}{Logical: Anhoej runs-rule signal}
#'   \item{longest.run, longest.run.max}{Observed and threshold run lengths}
#'   \item{n.crossings, n.crossings.min}{Observed and minimum crossing counts}
#'   \item{anhoej.signal}{Logical combined Anhoej-rule signal (runs OR
#'     crossings). May be \code{FALSE} for series < 10 points where crossing
#'     criterion is not applied.}
#'   \item{cl.lab, ucl.lab, lcl.lab}{Character labels for chart annotations}
#'   \item{part, baseline, include}{Phase/freeze/filter columns}
#'   \item{notes}{Free-text annotation column}
#' }
#' The qicharts2 column contract is stable across minor versions >= 0.7.0.
#' Additional columns may be present but should not be relied upon.
#'
#' @examples
#' \dontrun{
#' # bfh_qic() returns a bfh_qic_result via this constructor
#' data <- data.frame(
#'   month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
#'   infections = rpois(12, lambda = 15)
#' )
#' result <- bfh_qic(data, x = month, y = infections, chart_type = "run")
#' inherits(result, "bfh_qic_result")
#' }
#'
#' @export
new_bfh_qic_result <- function(plot, summary, qic_data, config) {
  # Validate inputs
  if (!inherits(plot, "ggplot")) {
    stop("plot must be a ggplot object", call. = FALSE)
  }

  if (!is.data.frame(summary)) {
    stop("summary must be a data.frame or tibble", call. = FALSE)
  }

  if (!is.data.frame(qic_data)) {
    stop("qic_data must be a data.frame", call. = FALSE)
  }

  if (!is.list(config)) {
    stop("config must be a list", call. = FALSE)
  }

  # Create S3 object
  structure(
    list(
      plot = plot,
      summary = summary,
      qic_data = qic_data,
      config = config
    ),
    class = c("bfh_qic_result", "list")
  )
}

#' Print Method for bfh_qic_result
#'
#' Displays the plot in the console/viewer, maintaining backwards-compatible
#' behavior with previous versions that returned ggplot objects directly.
#'
#' @param x A \code{bfh_qic_result} object
#' @param ... Additional arguments (ignored)
#'
#' @return The object invisibly for pipe chaining
#'
#' @export
print.bfh_qic_result <- function(x, ...) {
  print(x$plot)
  invisible(x)
}

#' Plot Method for bfh_qic_result
#'
#' Extracts and displays the ggplot object from a bfh_qic_result.
#' Enables use of generic plot() function.
#'
#' @param x A \code{bfh_qic_result} object
#' @param ... Additional arguments passed to print.ggplot
#'
#' @return The ggplot object invisibly
#'
#' @export
plot.bfh_qic_result <- function(x, ...) {
  print(x$plot, ...)
  invisible(x$plot)
}

#' Extract Plot from bfh_qic_result
#'
#' Helper function to extract the ggplot object for further customization.
#' Users can use \code{result$plot} directly or call this function.
#'
#' @param x A \code{bfh_qic_result} object
#'
#' @return ggplot2 object
#'
#' @export
bfh_get_plot <- function(x) {
  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object", call. = FALSE)
  }
  x$plot
}

#' Check if Object is bfh_qic_result
#'
#' @param x Object to test
#'
#' @return Logical indicating whether x is a bfh_qic_result object
#'
#' @examples
#' \dontrun{
#' data <- data.frame(
#'   month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
#'   infections = rpois(12, lambda = 15)
#' )
#' result <- bfh_qic(data, x = month, y = infections, chart_type = "run")
#' is_bfh_qic_result(result) # TRUE
#' is_bfh_qic_result(result$plot) # FALSE
#' }
#'
#' @export
is_bfh_qic_result <- function(x) {
  inherits(x, "bfh_qic_result")
}
