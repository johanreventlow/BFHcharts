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

  median_interval <- stats::median(intervals, na.rm = TRUE)

  # Guard: identiske datoer (median=0) -> insufficient data
  if (median_interval == 0) {
    return(insufficient_response(length(sorted_dates)))
  }

  # Guard: kun et interval (2 datapunkter) -> var() giver NA, antag perfekt konsistens
  if (length(intervals) < 2) {
    consistency <- 1
  } else {
    interval_variance <- stats::var(intervals, na.rm = TRUE)
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
#'   \item{break_unit}{Calendar unit driving major breaks: "day", "week"
#'     or "month". Consumed by calculate_date_breaks()}
#'   \item{minor_break_unit}{Calendar unit for unlabelled minor ticks, or
#'     NULL when the axis carries no minor ticks}
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

  # Month-anchored config shared by dense daily and weekly series. Once
  # labels need thinning, per-unit breaks drift off the calendar (e.g. a
  # 4-week step lands on arbitrary days of the month), so both types switch
  # to month starts with unlabelled weekly ticks.
  month_anchored_config <- list(
    use_smart_labels = TRUE,
    labels = scales::label_date_short(format = c("%Y", "%b", "", "")),
    break_unit = "month",
    minor_break_unit = "week",
    n_breaks = 12
  )

  # Formatering matrix baseret paa interval type og antal observationer
  config <- switch(interval_type,
    daily = {
      if (timespan_days <= BFH_MAX_DATE_BREAKS) {
        # Short daily: every day can carry its own label
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(format = c("%Y", "%b", "%d", "")),
          break_unit = "day",
          minor_break_unit = NULL,
          n_breaks = 8
        )
      } else if (timespan_days / 7 <= BFH_MAX_DATE_BREAKS) {
        # Medium daily: a span of a few weeks holds too few month starts to
        # label (30 days can contain just one), so anchor on week starts and
        # keep day-level ticks.
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(format = c("%Y", "%b", "%d", "")),
          break_unit = "week",
          minor_break_unit = "day",
          n_breaks = 12
        )
      } else {
        month_anchored_config
      }
    },
    weekly = {
      if (timespan_days / 7 <= BFH_MAX_DATE_BREAKS) {
        # Intelligent uge-formatering med scales::label_date_short()
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(),
          break_unit = "week",
          minor_break_unit = NULL,
          n_breaks = min(n_obs, 24)
        )
      } else {
        month_anchored_config
      }
    },
    monthly = {
      # Monthly series are already calendar-anchored; only break_unit is
      # added so the contract is explicit. Label cadence keeps coming from
      # calculate_interval_multiplier().
      if (n_obs < 12) {
        # Intelligent maaneds-formatering med scales::label_date_short()
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(
            format = c("%Y", "%b", "", ""), # \u00c5r f\u00f8rst, s\u00e5 m\u00e5neder
            sep = "\n"
          ),
          break_unit = "month",
          minor_break_unit = NULL,
          n_breaks = n_obs
        )
      } else if (n_obs < 40) {
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(),
          break_unit = "month",
          minor_break_unit = NULL,
          n_breaks = 8
        )
      } else {
        # For mange maaneder - vis aar og maaned
        list(
          use_smart_labels = TRUE,
          labels = scales::label_date_short(
            format = c("%Y", "%b", "", "")
          ),
          break_unit = "month",
          minor_break_unit = NULL,
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

#' Format a Period Endpoint at the Data's Own Granularity
#'
#' Renders one end of the period line so it describes the data as precisely
#' as the data allows. Month + year on a weekly series hides which weeks are
#' covered; a bare year on daily data hides everything below it.
#'
#' | Interval  | Example        |
#' | --------- | -------------- |
#' | daily     | `1. dec. 2025` |
#' | weekly    | `UGE 49, 2025` |
#' | monthly   | `dec. 2025`    |
#' | quarterly | `K4 2025`      |
#' | yearly    | `2025`         |
#'
#' Week numbers are paired with the **ISO year**, not the calendar year:
#' 2025-12-29 is week 01 of ISO year 2026, and reporting it as "week 01,
#' 2025" would place it a year off.
#'
#' Unknown or irregular intervals fall back to month + year, which carries
#' no assumption about a finer unit.
#'
#' @param date Date or POSIXt scalar
#' @param interval_type Character from [detect_date_interval()]
#' @param language Character language code
#' @return Character scalar, or `NA_character_` for unusable input
#' @keywords internal
#' @noRd
format_period_endpoint <- function(date, interval_type, language = "da") {
  if (is.null(date) || length(date) == 0 || all(is.na(date))) {
    return(NA_character_)
  }
  date <- as.Date(date)

  switch(interval_type,
    "daily" = sprintf(
      "%d. %s %s",
      as.integer(format(date, "%d")),
      .danish_months[as.integer(format(date, "%m"))],
      format(date, "%Y")
    ),
    "weekly" = sprintf(
      "%s %s, %s",
      i18n_lookup("labels.details.periode_uge", language),
      strftime(date, "%V"),
      # %G is the ISO week-numbering year, which diverges from %Y around
      # the turn of the year -- exactly where the distinction matters.
      strftime(date, "%G")
    ),
    "quarterly" = sprintf(
      "%s%d %s",
      i18n_lookup("labels.details.periode_kvartal", language),
      (as.integer(format(date, "%m")) - 1L) %/% 3L + 1L,
      format(date, "%Y")
    ),
    "yearly" = format(date, "%Y"),
    # monthly, irregular, insufficient_data
    format_danish_date_short(date)
  )
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
