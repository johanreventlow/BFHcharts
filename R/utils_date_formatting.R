#' Date Formatting Utilities
#'
#' Intelligent date detection, parsing, and formatting for SPC chart x-axes.
#' Supports Danish date formats with automatic interval detection.
#'
#' @name date_formatting
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# DATE INTERVAL DETECTION
# ============================================================================

#' Detect Date Intervals in Time Series Data
#'
#' Intelligent detection of date intervals (daily, weekly, monthly, etc.)
#' based on the spacing between consecutive dates.
#'
#' @param dates Vector of Date or POSIXct objects
#' @param debug Logical, enable debug output (default: FALSE)
#'
#' @return List with interval information:
#' \describe{
#'   \item{type}{Interval type: "daily", "weekly", "monthly", "quarterly", "yearly", "irregular"}
#'   \item{median_days}{Median days between observations}
#'   \item{consistency}{Consistency score 0-1 (1 = perfectly regular)}
#'   \item{timespan_days}{Total timespan in days}
#'   \item{n_obs}{Number of observations}
#' }
#'
#' @keywords internal
#' @noRd
#' @family spc-date-formatting
#' @seealso [get_optimal_formatting()], [parse_danish_dates()]
#' @examples
#' \dontrun{
#' dates <- seq(as.Date("2024-01-01"), by = "week", length.out = 52)
#' detect_date_interval(dates)
#' }
detect_date_interval <- function(dates, debug = FALSE) {
  insufficient_response <- function(n_obs) {
    list(
      type = "insufficient_data",
      median_days = NA_real_,
      consistency = 0,
      timespan_days = 0,
      n_obs = n_obs
    )
  }

  if (length(dates) < 2) {
    return(insufficient_response(length(dates)))
  }

  # Sorter datoer og beregn intervaller
  sorted_dates <- sort(dates[!is.na(dates)])
  if (length(sorted_dates) < 2) {
    return(insufficient_response(length(sorted_dates)))
  }

  # Beregn forskelle mellem konsekutive datoer (i dage)
  intervals <- as.numeric(diff(sorted_dates))

  if (length(intervals) == 0) {
    return(insufficient_response(length(sorted_dates)))
  }

  median_interval <- median(intervals, na.rm = TRUE)
  interval_variance <- var(intervals, na.rm = TRUE)
  consistency <- 1 - (sqrt(interval_variance) / median_interval) # Høj værdi = konsistent
  consistency <- max(0, min(1, consistency)) # Klamp til 0-1

  timespan_days <- as.numeric(max(sorted_dates) - min(sorted_dates))

  # Klassificer interval type baseret på median
  interval_type <- if (median_interval <= 1) {
    "daily"
  } else if (median_interval <= 10) {
    "weekly"
  } else if (median_interval <= 40) {
    "monthly"
  } else if (median_interval <= 120) {
    "quarterly"
  } else if (median_interval <= 400) {
    "yearly"
  } else {
    "irregular"
  }

  return(list(
    type = interval_type,
    median_days = median_interval,
    consistency = consistency,
    timespan_days = timespan_days,
    n_obs = length(sorted_dates)
  ))
}

# ============================================================================
# OPTIMAL FORMATTING
# ============================================================================

#' Get Optimal Date Formatting Configuration
#'
#' Returns optimal x-axis formatting based on detected date intervals
#' and number of observations.
#'
#' @param interval_info List from [detect_date_interval()]
#' @param debug Logical, enable debug output (default: FALSE)
#'
#' @return List with formatting configuration:
#' \describe{
#'   \item{labels}{Date format string or scales label function}
#'   \item{breaks}{Break specification for scale}
#'   \item{n_breaks}{Number of breaks}
#'   \item{use_smart_labels}{Logical, use scales::label_date_short()}
#' }
#'
#' @keywords internal
#' @noRd
#' @family spc-date-formatting
#' @seealso [detect_date_interval()], [create_spc_chart()]
#' @examples
#' \dontrun{
#' dates <- seq(as.Date("2024-01-01"), by = "month", length.out = 24)
#' interval_info <- detect_date_interval(dates)
#' get_optimal_formatting(interval_info)
#' }
get_optimal_formatting <- function(interval_info, debug = FALSE) {
  interval_type <- interval_info$type
  n_obs <- interval_info$n_obs
  timespan_days <- interval_info$timespan_days

  # Formatering matrix baseret på interval type og antal observationer
  config <- switch(interval_type,
    daily = {
      if (n_obs < 30) {
        list(labels = "%d %b", breaks = "1 week", n_breaks = 8)
      } else if (n_obs < 90) {
        list(labels = "%b %Y", breaks = "2 weeks", n_breaks = 10)
      } else {
        list(labels = "%b %Y", breaks = "1 month", n_breaks = 12)
      }
    },
    weekly = {
      if (n_obs <= 36) {
        # Intelligent uge-formatering med scales::label_date_short()
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(),
          n_breaks = min(n_obs, 24)
        )
      } else {
        # For mange uger - skift til månedlig visning
        list(
          use_smart_labels = FALSE,
          labels = "%b %Y",
          breaks = "1 month",
          n_breaks = 12
        )
      }
    },
    monthly = {
      if (n_obs < 12) {
        # Intelligent måneds-formatering med scales::label_date_short()
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(
            format = c("%Y", "%b"), # År først, så måneder
            sep = "\n"
          ),
          breaks = "1 month",
          n_breaks = n_obs
        )
      } else if (n_obs < 40) {
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(),
          breaks = "3 months",
          n_breaks = 8
        )
      } else {
        # For mange måneder - skift til årlig visning
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(
            format = c("%Y", "", ""),
            sep = ""
          ),
          breaks = "6 months",
          n_breaks = 10
        )
      }
    },
    quarterly = {
      list(labels = "Q%q %Y", breaks = "3 months", n_breaks = 8)
    },
    yearly = {
      list(labels = "%Y", breaks = "1 year", n_breaks = min(n_obs, 10))
    },
    # Default/irregular
    {
      if (timespan_days < 100) {
        list(labels = "%d %b %Y", breaks = "2 weeks", n_breaks = 8)
      } else if (timespan_days < 730) {
        list(labels = "%b %Y", breaks = "2 months", n_breaks = 10)
      } else {
        list(labels = "%Y", breaks = "1 year", n_breaks = 12)
      }
    }
  )

  return(config)
}

# ============================================================================
# DATE PARSING
# ============================================================================

#' Parse Danish Date Formats
#'
#' Attempts to parse dates in common Danish formats (dd-mm-yyyy).
#'
#' @param date_strings Character vector of date strings
#'
#' @return POSIXct vector of parsed dates (NA for failed parses)
#'
#' @keywords internal
#' @noRd
#' @family spc-date-formatting
#' @seealso [detect_date_interval()]
#' @examples
#' \dontrun{
#' parse_danish_dates(c("01-01-2024", "15-03-2024", "31-12-2024"))
#' }
parse_danish_dates <- function(date_strings) {
  # Try Danish format first (dd-mm-yyyy)
  parsed <- suppressWarnings(lubridate::dmy(date_strings))

  # If that fails, try ISO format (yyyy-mm-dd)
  if (all(is.na(parsed))) {
    parsed <- suppressWarnings(lubridate::ymd(date_strings))
  }

  # Convert to POSIXct for consistency with qicharts2
  as.POSIXct(parsed)
}
