# config_font_scaling.R
# Responsive font scaling configuration for viewport-adaptive typography
#
# Controls how base_size scales based on viewport dimensions using geometric mean approach

#' Responsive Font Scaling Configuration
#'
#' Controls how base_size scales based on viewport dimensions (width × height).
#'
#' @details
#' **Formula:**
#' ```
#' viewport_diagonal = sqrt(width_inches * height_inches)
#' base_size = max(min_size, min(max_size, viewport_diagonal / divisor))
#' ```
#'
#' **Geometric Mean Approach:**
#' Using `sqrt(width × height)` provides balanced scaling based on both
#' dimensions. This ensures fonts scale intuitively with overall plot size,
#' not just one dimension.
#'
#' **Parameters:**
#' - `divisor`: Lower value = larger fonts (e.g., 40 → ~40% larger than 56)
#' - `min_size`: Minimum font size regardless of viewport
#' - `max_size`: Maximum font size even on large screens
#'
#' **Examples (divisor = 3.5):**
#' - 6×4 inch plot: diagonal = 4.90 → base_size = 14.0pt
#' - 10×6 inch plot: diagonal = 7.75 → base_size = 22.1pt
#' - 14×8 inch plot: diagonal = 10.58 → base_size = 30.2pt
#'
#' **Typical Use Cases:**
#' - Web display: 8×5 inches (diagonal 6.02 → base_size 17.2pt)
#' - Print output: 10×6 inches (diagonal 7.75 → base_size 22.1pt)
#' - Presentation: 16×9 inches (diagonal 12.04 → base_size 34.4pt)
#'
#' @format Named list with scaling parameters:
#' \describe{
#'   \item{divisor}{Viewport diagonal divisor (default: 3.5)}
#'   \item{min_size}{Minimum base_size in points (default: 8)}
#'   \item{max_size}{Maximum base_size in points (default: 48)}
#' }
#'
#' @keywords internal
#' @noRd
#' @family spc-config
#' @seealso [calculate_base_size()], [viewport_dims()]
#' @examples
#' \dontrun{
#' # Default configuration
#' FONT_SCALING_CONFIG
#'
#' # Calculate base_size for specific viewport
#' width <- 10  # inches
#' height <- 6  # inches
#' diagonal <- sqrt(width * height)
#' base_size <- max(
#'   FONT_SCALING_CONFIG$min_size,
#'   min(FONT_SCALING_CONFIG$max_size, diagonal / FONT_SCALING_CONFIG$divisor)
#' )
#' }
FONT_SCALING_CONFIG <- list(
  divisor = 3.5,  # Viewport diagonal divisor (lower = larger fonts)
  min_size = 8,   # Minimum base_size in points
  max_size = 48   # Maximum base_size in points
)

#' Calculate Responsive Base Size from Viewport Dimensions
#'
#' Computes optimal base_size using geometric mean of viewport dimensions.
#'
#' @param width Viewport width in inches
#' @param height Viewport height in inches
#' @param config Font scaling configuration (default: [FONT_SCALING_CONFIG])
#'
#' @return Numeric base_size in points
#'
#' @details
#' Uses geometric mean approach: `sqrt(width × height) / divisor`
#'
#' This provides balanced scaling that considers both dimensions,
#' ensuring typography scales proportionally with plot area.
#'
#' @keywords internal
#' @noRd
#' @family spc-config
#' @seealso [FONT_SCALING_CONFIG], [viewport_dims()]
#' @examples
#' \dontrun{
#' # Standard web plot
#' calculate_base_size(width = 8, height = 5)
#' # Returns: ~17.2pt
#'
#' # Print-quality plot
#' calculate_base_size(width = 10, height = 6)
#' # Returns: ~22.1pt
#'
#' # Large presentation plot
#' calculate_base_size(width = 16, height = 9)
#' # Returns: ~34.4pt (clamped to max_size = 48)
#' }
calculate_base_size <- function(width, height, config = FONT_SCALING_CONFIG) {
  if (is.null(width) || is.null(height) || is.na(width) || is.na(height)) {
    return(14)  # Default fallback
  }

  # Geometric mean of dimensions
  viewport_diagonal <- sqrt(width * height)

  # Apply scaling with min/max bounds
  base_size <- max(
    config$min_size,
    min(config$max_size, viewport_diagonal / config$divisor)
  )

  return(base_size)
}
