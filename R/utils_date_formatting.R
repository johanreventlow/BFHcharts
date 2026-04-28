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

  # Guard: identiske datoer (median=0) -> insufficient data
  if (median_interval == 0) {
    return(insufficient_response(length(sorted_dates)))
  }

  # Guard: kun et interval (2 datapunkter) -> var() giver NA, antag perfekt konsistens
  if (length(intervals) < 2) {
    consistency <- 1
  } else {
    interval_variance <- var(intervals, na.rm = TRUE)
    consistency <- 1 - (sqrt(interval_variance) / median_interval)
    consistency <- max(0, min(1, consistency))
  }

  timespan_days <- as.numeric(max(sorted_dates) - min(sorted_dates))

  # Klassificer interval type baseret paa median
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
#' @param interval_info List from detect_date_interval()
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

  # Formatering matrix baseret paa interval type og antal observationer
  config <- switch(interval_type,
    daily = {
      if (n_obs < 30) {
        # Short daily: Show days with month context
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(format = c("%Y", "%b", "%d", "")),
          breaks = "1 week",
          n_breaks = 8
        )
      } else if (n_obs < 90) {
        # Medium daily: Emphasize months
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(format = c("%Y", "%b", "", "")),
          breaks = "2 weeks",
          n_breaks = 10
        )
      } else {
        # Long daily: Monthly breaks
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(format = c("%Y", "%b", "", "")),
          breaks = "1 month",
          n_breaks = 12
        )
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
        # For mange uger - skift til maanedlig visning
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(format = c("%Y", "%b", "", "")),
          breaks = "1 month",
          n_breaks = 12
        )
      }
    },
    monthly = {
      if (n_obs < 12) {
        # Intelligent maaneds-formatering med scales::label_date_short()
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(
            format = c("%Y", "%b", "", ""), # \u00c5r f\u00f8rst, s\u00e5 m\u00e5neder
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
        # For mange maaneder - vis aar og maaned
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(
            format = c("%Y", "%b", "", "")
          ),
          breaks = "6 months",
          n_breaks = 10
        )
      }
    },
    quarterly = {
      # Month-based formatting for quarterly data (jan, apr, jul, okt)
      list(
        use_smart_labels = TRUE,
        labels = scales::label_date_short(format = c("%Y", "%b", "", "")),
        breaks = "3 months",
        n_breaks = 8
      )
    },
    yearly = {
      list(
        use_smart_labels = TRUE,
        labels = scales::label_date_short(format = c("%Y", "", "", "")),
        breaks = "1 year",
        n_breaks = min(n_obs, 10)
      )
    },
    # Default/irregular
    {
      if (timespan_days < 100) {
        # Short irregular: Full dates with intelligent year display
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(format = c("%Y", "%b", "%d", "")),
          breaks = "2 weeks",
          n_breaks = 8
        )
      } else if (timespan_days < 730) {
        # Medium irregular: Month/year
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(format = c("%Y", "%b", "", "")),
          breaks = "2 months",
          n_breaks = 10
        )
      } else {
        # Long irregular: Years only
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(format = c("%Y", "", "", "")),
          breaks = "1 year",
          n_breaks = 12
        )
      }
    }
  )

  return(config)
}

# ============================================================================
# DANISH DATE FORMATTING
# ============================================================================

# Danish month abbreviations (standard)
.danish_months <- c(
  "jan.", "feb.", "mar.", "apr.", "maj", "jun.",
  "jul.", "aug.", "sep.", "okt.", "nov.", "dec."
)

#' Format Date in Short Danish Format
#'
#' Formats a Date or POSIXt object to short Danish format with abbreviated
#' month names (e.g., "feb. 2019", "okt. 2024").
#'
#' @param date Date or POSIXt object to format
#'
#' @return Character string in format "mmm. yyyy" (e.g., "feb. 2019")
#'
#' @keywords internal
#' @noRd
#' @examples
#' \dontrun{
#' format_danish_date_short(as.Date("2019-02-15"))
#' # Returns: "feb. 2019"
#'
#' format_danish_date_short(as.Date("2024-10-01"))
#' # Returns: "okt. 2024"
#' }
format_danish_date_short <- function(date) {
  if (is.null(date) || length(date) == 0 || is.na(date)) {
    return(NA_character_)
  }

  # Convert to Date if POSIXt
  date <- as.Date(date)

  # Extract month (1-12) and year
  month_num <- as.integer(format(date, "%m"))
  year <- format(date, "%Y")

  # Get Danish month abbreviation
  month_abbr <- .danish_months[month_num]

  # Combine: "feb. 2019"
  paste(month_abbr, year)
}

#' Get Danish Interval Label
#'
#' Returns the Danish label for a detected interval type.
#'
#' @param interval_type Character string from detect_date_interval()$type
#'
#' @return Character string with Danish interval label
#'
#' @keywords internal
#' @noRd
get_danish_interval_label <- function(interval_type, language = "da") {
  key <- switch(interval_type,
    "daily" = "labels.interval.daily",
    "weekly" = "labels.interval.weekly",
    "monthly" = "labels.interval.monthly",
    "quarterly" = "labels.interval.quarterly",
    "yearly" = "labels.interval.yearly",
    "labels.interval.irregular"
  )
  i18n_lookup(key, language)
}
