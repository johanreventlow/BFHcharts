#' Unit Conversion Utilities
#'
#' Utilities for converting between different units (cm, mm, in, px) for plot dimensions.
#' Provides smart auto-detection for user-friendly Danish units.
#'
#' @name utils_unit_conversion
NULL

# ============================================================================
# UNIT CONVERSION
# ============================================================================

#' Convert Width and Height to Inches
#'
#' Converts plot dimensions from various units to inches (ggplot2 internal format).
#' Supports centimeters, millimeters, inches, and pixels.
#'
#' @param width Numeric width value
#' @param height Numeric height value
#' @param units Unit type: "cm", "mm", "in", "px", or NULL for smart detection
#' @param dpi Dots per inch for pixel conversion (default: 96)
#'
#' @return List with width_inches, height_inches, and detected_unit
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Centimeters (Danish standard)
#' convert_to_inches(25, 15, "cm")  # → 9.84 × 5.91 inches
#'
#' # Millimeters
#' convert_to_inches(250, 150, "mm")  # → 9.84 × 5.91 inches
#'
#' # Pixels (web/Shiny)
#' convert_to_inches(800, 600, "px", dpi = 96)  # → 8.33 × 6.25 inches
#'
#' # Inches (legacy)
#' convert_to_inches(10, 6, "in")  # → 10 × 6 inches
#'
#' # Smart auto-detection
#' convert_to_inches(25, 15, NULL)  # → Auto-detects cm
#' convert_to_inches(800, 600, NULL)  # → Auto-detects px
#' }
convert_to_inches <- function(width, height, units = NULL, dpi = 96) {
  # Validate inputs
  if (!is.numeric(width) || !is.numeric(height)) {
    stop("width and height must be numeric", call. = FALSE)
  }

  if (length(width) != 1 || length(height) != 1) {
    stop("width and height must be single values", call. = FALSE)
  }

  if (width <= 0 || height <= 0) {
    stop("width and height must be positive", call. = FALSE)
  }

  # Use smart detection if units not specified
  if (is.null(units)) {
    return(smart_convert_to_inches(width, height, dpi))
  }

  # Validate units parameter
  valid_units <- c("cm", "mm", "in", "px")
  if (!units %in% valid_units) {
    stop(sprintf(
      "units must be one of: %s",
      paste(valid_units, collapse = ", ")
    ), call. = FALSE)
  }

  # Convert to inches based on unit type
  width_in <- switch(units,
    "cm" = width / 2.54,
    "mm" = width / 25.4,
    "in" = width,
    "px" = width / dpi,
    stop("Invalid unit type", call. = FALSE)
  )

  height_in <- switch(units,
    "cm" = height / 2.54,
    "mm" = height / 25.4,
    "in" = height,
    "px" = height / dpi,
    stop("Invalid unit type", call. = FALSE)
  )

  list(
    width_inches = width_in,
    height_inches = height_in,
    detected_unit = units
  )
}

#' Smart Auto-Detection of Units
#'
#' Intelligently detects units based on magnitude of width/height values.
#'
#' Detection heuristics:
#' - value > 100: pixels (typical: 600-2000px)
#' - value 10-100: centimeters (typical: 15-40cm)
#' - value < 10: inches (typical: 6-16in, legacy compatibility)
#'
#' @param width Numeric width value
#' @param height Numeric height value
#' @param dpi Dots per inch for pixel conversion (default: 96)
#'
#' @return List with width_inches, height_inches, and detected_unit
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' smart_convert_to_inches(800, 600)  # → Detects pixels
#' smart_convert_to_inches(25, 15)    # → Detects cm
#' smart_convert_to_inches(10, 6)     # → Detects inches
#' }
smart_convert_to_inches <- function(width, height, dpi = 96) {
  # Heuristic detection based on magnitude
  # Use the larger dimension for detection to handle both landscape/portrait
  max_dim <- max(width, height)

  detected_unit <- if (max_dim > 100) {
    "px"  # Typical pixel ranges: 600-2000
  } else if (max_dim > 10) {
    "cm"  # Typical cm ranges: 15-40
  } else {
    "in"  # Typical inch ranges: 6-16 (legacy compatibility)
  }

  # Convert using detected unit
  convert_to_inches(width, height, detected_unit, dpi)
}

#' Convert Inches to Target Unit
#'
#' Reverse conversion from inches to specified unit.
#' Useful for displaying dimensions in user-friendly units.
#'
#' @param width_inches Width in inches
#' @param height_inches Height in inches
#' @param target_unit Target unit: "cm", "mm", "in", "px"
#' @param dpi Dots per inch for pixel conversion (default: 96)
#'
#' @return List with width, height in target unit
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' convert_from_inches(10, 6, "cm")  # → 25.4 × 15.24 cm
#' convert_from_inches(10, 6, "px", dpi = 96)  # → 960 × 576 px
#' }
convert_from_inches <- function(width_inches, height_inches, target_unit, dpi = 96) {
  width_out <- switch(target_unit,
    "cm" = width_inches * 2.54,
    "mm" = width_inches * 25.4,
    "in" = width_inches,
    "px" = width_inches * dpi,
    stop("Invalid target_unit", call. = FALSE)
  )

  height_out <- switch(target_unit,
    "cm" = height_inches * 2.54,
    "mm" = height_inches * 25.4,
    "in" = height_inches,
    "px" = height_inches * dpi,
    stop("Invalid target_unit", call. = FALSE)
  )

  list(
    width = width_out,
    height = height_out,
    unit = target_unit
  )
}
