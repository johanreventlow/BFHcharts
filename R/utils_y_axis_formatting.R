#' Y-Axis Formatting Utilities
#'
#' Unit-specific Y-axis formatting for SPC plots with Danish number notation.
#'
#' @name y_axis_formatting
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# MAIN FORMATTING FUNCTION
# ============================================================================

#' Apply Y-Axis Formatting to SPC Plot
#'
#' Applies unit-specific Y-axis formatting to an SPC ggplot object.
#' Supports percentage, count, rate, and time units with Danish formatting.
#'
#' @param plot ggplot object to format
#' @param y_axis_unit Unit type: "percent", "count", "rate", or "time"
#' @param qic_data QIC data frame (required for time unit context)
#'
#' @return Modified ggplot object with appropriate y-axis scale
#'
#' @details
#' **Unit Types:**
#' - **percent**: Percentage values (0-100%) with % suffix
#' - **count**: Integers with intelligent K/M/mia. notation
#' - **rate**: Decimal values with comma notation
#' - **time**: Context-aware minutes/hours/days formatting
#'
#' **Danish Formatting:**
#' - Decimal mark: `,` (e.g., "12,5")
#' - Thousand separator: `.` (e.g., "1.250")
#'
#' @keywords internal
#' @noRd
#' @examples
#' \dontrun{
#' library(ggplot2)
#'
#' count_data <- data.frame(
#'   x = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
#'   y = seq(5, 16, length.out = 12)
#' )
#'
#' percent_data <- data.frame(
#'   x = count_data$x,
#'   y = seq(0.05, 0.25, length.out = 12)
#' )
#'
#' count_plot <- ggplot(count_data, aes(x = x, y = y)) +
#'   geom_line()
#'
#' # Apply percentage formatting
#' percent_plot <- ggplot(percent_data, aes(x = x, y = y)) +
#'   geom_line()
#' apply_y_axis_formatting(percent_plot, "percent", percent_data)
#'
#' # Apply count formatting
#' apply_y_axis_formatting(count_plot, "count", count_data)
#' }
apply_y_axis_formatting <- function(plot, y_axis_unit = "count",
                                    qic_data = NULL, language = "da") {
  .ensure_bfhtheme()
  # Validate inputs
  if (!inherits(plot, "ggplot")) {
    warning("apply_y_axis_formatting: plot is not a ggplot object")
    return(plot)
  }

  if (is.null(y_axis_unit) || !is.character(y_axis_unit)) {
    warning("apply_y_axis_formatting: invalid y_axis_unit, defaulting to 'count'")
    y_axis_unit <- "count"
  }
  if (!language %in% c("da", "en")) language <- "da"

  # Beregn y_range for percent precision context
  y_range <- if (!is.null(qic_data) && "y" %in% names(qic_data)) {
    range(qic_data$y, na.rm = TRUE)
  } else {
    NULL
  }

  # Apply unit-specific formatting
  switch(y_axis_unit,
    percent = plot + format_y_axis_percent(y_range, language = language),
    count = plot + format_y_axis_count(language = language),
    rate = plot + format_y_axis_rate(language = language),
    time = plot + format_y_axis_time(qic_data),
    {
      # Unknown unit - warn user
      warning(
        sprintf(
          "Unknown y_axis_unit: '%s'. Valid values are: 'count', 'percent', 'rate', 'time'. No formatting applied.",
          y_axis_unit
        ),
        call. = FALSE
      )
      plot
    }
  )
}

# ============================================================================
# UNIT-SPECIFIC FORMATTERS
# ============================================================================

#' Format Y-Axis for Percentage Data
#'
#' Range-aware precision: viser decimaler naar y-aksen spaender < 5 procentpoint.
#'
#' @param y_range numeric(2) y-akse range, eller NULL
#' @return ggplot2 scale layer
#' @keywords internal
#' @noRd
format_y_axis_percent <- function(y_range = NULL, language = "da") {
  .ensure_bfhtheme()
  # Locale-aware separators + suffix
  decimal_mark <- if (identical(language, "en")) "." else ","
  big_mark <- if (identical(language, "en")) "," else "."
  pct_suffix <- if (identical(language, "en")) "%" else " %"

  # Custom breaks + accuracy der sikrer unikke labels uden huller
  percent_breaks <- function(limits) {
    b <- scales::breaks_pretty(n = 5)(limits)
    b <- b[b >= 0 & b <= 1]
    if (length(b) > 0) {
      if (limits[1] <= 0.05 && !0 %in% b) b <- c(0, b)
      if (limits[2] >= 0.95 && !1 %in% b) b <- c(b, 1)
    }
    sort(unique(b))
  }

  # Bestem accuracy baseret paa faktisk break-interval (beregnes dynamisk)
  percent_labels <- function(x) {
    if (length(x) < 2) {
      return(scales::label_percent(
        accuracy = 1,
        decimal.mark = decimal_mark,
        big.mark = big_mark,
        suffix = pct_suffix
      )(x))
    }

    # Beregn mindste interval mellem breaks (i procentpoint)
    intervals <- diff(sort(x)) * 100
    min_interval <- min(intervals[intervals > 0])

    # Vaelg accuracy der kan skelne alle breaks
    accuracy <- if (min_interval >= 1) {
      1 # 1%, 2%, 3%
    } else if (min_interval >= 0.1) {
      0.1 # 0.5%, 1.0%, 1.5%
    } else {
      0.01 # 0.05%, 0.10%
    }

    scales::label_percent(
      accuracy = accuracy,
      decimal.mark = decimal_mark,
      big.mark = big_mark,
      suffix = pct_suffix
    )(x)
  }

  BFHtheme::scale_y_continuous_bfh(
    expand = ggplot2::expansion(mult = c(Y_AXIS_BASE_EXPANSION_MULT, Y_AXIS_BASE_EXPANSION_MULT)),
    breaks = percent_breaks,
    labels = percent_labels
  )
}

#' Format Y-Axis for Count Data with K/M Notation
#'
#' Intelligent scaling:
#' - < 1,000: Standard notation with thousand separator
#' - At least 1,000: K notation (e.g., "1,5K")
#' - At least 1,000,000: M notation (e.g., "2,3M")
#' - At least 1,000,000,000: mia. notation (e.g., "1,2 mia.")
#'
#' @return ggplot2 scale layer
#' @keywords internal
#' @noRd
format_y_axis_count <- function(language = "da") {
  .ensure_bfhtheme()
  BFHtheme::scale_y_continuous_bfh(
    expand = ggplot2::expansion(mult = c(Y_AXIS_BASE_EXPANSION_MULT, Y_AXIS_BASE_EXPANSION_MULT)),
    labels = function(x, ...) {
      # format_count() dispatcher er scalar - vektoriser via map_chr for at
      # haandtere ggplot2's vektor-input af breakpoints.
      purrr::map_chr(x, format_count, language = language)
    }
  )
}

#' Format Y-Axis for Rate Data
#'
#' @return ggplot2 scale layer
#' @keywords internal
#' @noRd
format_y_axis_rate <- function(language = "da") {
  .ensure_bfhtheme()
  BFHtheme::scale_y_continuous_bfh(
    expand = ggplot2::expansion(mult = c(Y_AXIS_BASE_EXPANSION_MULT, Y_AXIS_BASE_EXPANSION_MULT)),
    labels = function(x, ...) {
      # format_rate() dispatcher er scalar - vektoriser via map_chr for at
      # haandtere ggplot2's vektor-input af breakpoints.
      purrr::map_chr(x, format_rate, language = language)
    }
  )
}

#' Format Y-Axis for Time Data (Composite Format: "1t 30m", "2d 4t")
#'
#' Producerer tids-naturlige tick-breaks via `time_breaks()` og komposit
#' label-format via `format_time_composite()`. Input antages at vaere i
#' minutter (kanonisk intern enhed).
#'
#' Erstatter tidligere "0,6666667 timer"-style formatering med kompakte
#' labels som `"45m"`, `"1t 30m"` og `"2d 13t"` - samme format som
#' data-punkt labels, hvilket sikrer visuel konsistens mellem y-aksen
#' og pilene fra centrallinje/target til deres vaerdier.
#'
#' @param qic_data QIC data frame with y column (time values in minutes)
#'
#' @return ggplot2 scale layer
#' @keywords internal
#' @noRd
format_y_axis_time <- function(qic_data) {
  .ensure_bfhtheme()
  if (is.null(qic_data) || !"y" %in% names(qic_data)) {
    warning("format_y_axis_time: missing qic_data or y column, using default")
    return(BFHtheme::scale_y_continuous_bfh(
      expand = ggplot2::expansion(mult = c(Y_AXIS_BASE_EXPANSION_MULT, Y_AXIS_BASE_EXPANSION_MULT))
    ))
  }

  # Tids-naturlige tick-breaks baseret paa data-range (target_n = 5 som default)
  breaks <- time_breaks(qic_data$y)

  BFHtheme::scale_y_continuous_bfh(
    expand = ggplot2::expansion(mult = c(Y_AXIS_BASE_EXPANSION_MULT, Y_AXIS_BASE_EXPANSION_MULT)),
    breaks = breaks,
    labels = function(x, ...) {
      # Defensiv: ggplot2 kan passere waiver-objekter under layout
      if (inherits(x, "waiver")) {
        return(x)
      }
      if (!is.numeric(x)) {
        x <- suppressWarnings(as.numeric(as.character(x)))
      }
      format_time_composite(x)
    }
  )
}

# ============================================================================
# NOTE: Helper functions moved to canonical files
# ============================================================================
# The following functions have been consolidated into dedicated utility files:
#
# - format_scaled_number() -> R/utils_number_formatting.R
# - format_unscaled_number() -> R/utils_number_formatting.R
# - format_time_with_unit() -> R/utils_time_formatting.R (as format_time_danish())
#
# This ensures DRY compliance with a single source of truth for formatting.
