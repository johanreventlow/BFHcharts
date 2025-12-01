#' BFH QIC Result S3 Class
#'
#' S3 class for wrapping SPC chart outputs. Enables pipe-compatible export
#' workflows while maintaining backwards-compatible console display.
#'
#' @name bfh_qic_result
#' @keywords internal
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
#' @keywords internal
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
#' @keywords internal
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
#' @keywords internal
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
#' @keywords internal
#' @export
get_plot <- function(x) {
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
#' @keywords internal
#' @export
is_bfh_qic_result <- function(x) {
  inherits(x, "bfh_qic_result")
}
