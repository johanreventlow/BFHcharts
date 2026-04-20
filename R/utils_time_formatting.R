#' Time Formatting Utilities
#'
#' Canonical time formatting functions for SPC plots with Danish labels.
#' Single source of truth for all time-related formatting in the package.
#'
#' @name utils_time_formatting
#' @keywords internal
#' @noRd
NULL

# ============================================================================
# CANONICAL TIME FORMATTING
# ============================================================================

#' Determine Appropriate Time Unit Based on Data Range
#'
#' Selects minutes, hours, or days based on the maximum value in the range.
#'
#' @param max_minutes Maximum time value in minutes
#'
#' @return Character: "minutes", "hours", or "days"
#' @keywords internal
#' @noRd
determine_time_unit <- function(max_minutes) {
  if (is.na(max_minutes) || max_minutes < 60) {
    "minutes"
  } else if (max_minutes < 1440) {
    "hours"
  } else {
    "days"
  }
}

#' Scale Time Value to Appropriate Unit
#'
#' Converts minutes to the specified time unit.
#'
#' @param val_minutes Time value in minutes
#' @param time_unit Target unit: "minutes", "hours", or "days"
#'
#' @return Scaled numeric value
#' @keywords internal
#' @noRd
scale_to_time_unit <- function(val_minutes, time_unit) {
  switch(time_unit,
    minutes = val_minutes,
    hours = val_minutes / 60,
    days = val_minutes / 1440,
    val_minutes
  )
}

#' Get Danish Time Unit Label
#'
#' Returns the appropriate Danish label for a time unit with pluralization.
#'
#' @param time_unit Unit: "minutes", "hours", or "days"
#' @param value Numeric value (for pluralization)
#' @param is_decimal Logical, whether value has decimals (always plural)
#'
#' @return Danish unit label string
#' @keywords internal
#' @noRd
get_danish_time_label <- function(time_unit, value = 2, is_decimal = FALSE) {
  # Decimals always use plural form (e.g., "1,5 timer")
  if (is_decimal) {
    return(switch(time_unit,
      minutes = " minutter",
      hours = " timer",
      days = " dage",
      " min"
    ))
  }

  # Integer pluralization: 1 = singular, others = plural
  switch(time_unit,
    minutes = if (value == 1) " minut" else " minutter",
    hours = if (value == 1) " time" else " timer",
    days = if (value == 1) " dag" else " dage",
    " min"
  )
}

#' Format Time Value with Danish Labels (Canonical)
#'
#' Converts time in minutes to a formatted string with appropriate unit and
#' Danish labels. This is the single source of truth for time formatting.
#'
#' @param val_minutes Time value in minutes
#' @param time_unit Unit: "minutes", "hours", or "days". If NULL, uses "minutes".
#'
#' @return Formatted string (e.g., "30 min", "1 time", "2 timer", "1 dag", "2 dage")
#'
#' @details
#' **Pluralization rules (Danish):**
#' - 1 minut / 2+ minutter
#' - 1 time / 2+ timer
#' - 1 dag / 2+ dage
#' - Decimals always use plural (e.g., "1,5 timer")
#'
#' @keywords internal
#' @noRd
#' @family spc-formatting
format_time_danish <- function(val_minutes, time_unit = "minutes") {
  if (is.na(val_minutes)) {
    return(NA_character_)
  }

  # Handle NULL time_unit
  if (is.null(time_unit)) {
    time_unit <- "minutes"
  }

  # Scale to appropriate unit

  scaled <- scale_to_time_unit(val_minutes, time_unit)

  # Check if value is integer or decimal
  is_integer <- is_effective_integer(scaled)

  if (is_integer) {
    num <- round(scaled)
    unit_label <- get_danish_time_label(time_unit, num, is_decimal = FALSE)
    paste0(num, unit_label)
  } else {
    unit_label <- get_danish_time_label(time_unit, scaled, is_decimal = TRUE)
    paste0(format(scaled, decimal.mark = ",", nsmall = 1), unit_label)
  }
}

# ============================================================================
# COMPOSITE TIME FORMAT (Canonical for y-axis + data-point labels)
# ============================================================================

#' Tids-naturlige kandidat-intervaller i minutter
#'
#' Bruges af `time_breaks()` til at vælge tick-afstand. Dækker fra 1 minut
#' op til 30 dage.
#'
#' @keywords internal
#' @noRd
TIME_BREAK_CANDIDATES <- c(
  1, 2, 5, 10, 15, 20, 30, # minutter
  60, 120, 180, 240, 360, 720, # timer (1t, 2t, 3t, 4t, 6t, 12t)
  1440, 2880, 10080, 43200 # dage (1d, 2d, 7d, 30d)
)

#' Formatér minutter som komposit tidsstreng (single value)
#'
#' Runder input til hele minutter før komponentopdeling for at undgå
#' overflow (59,7 min → `1t`, ikke `60m`). Max 2 komponenter for læsbarhed:
#' ved dage+timer vises ikke minutter.
#'
#' @param v numeric(1). Tidsværdi i minutter.
#' @return character(1) komposit-streng. `NA_character_` hvis `v` er NA.
#' @keywords internal
#' @noRd
format_time_composite_single <- function(v) {
  if (is.na(v)) {
    return(NA_character_)
  }

  sign_prefix <- if (v < 0) "-" else ""
  v_int <- as.integer(round(abs(v)))

  d <- v_int %/% 1440L
  rem <- v_int %% 1440L
  t <- rem %/% 60L
  m <- rem %% 60L

  result <- if (d > 0L && t > 0L) {
    paste0(d, "d ", t, "t")
  } else if (d > 0L) {
    paste0(d, "d")
  } else if (t > 0L && m > 0L) {
    paste0(t, "t ", m, "m")
  } else if (t > 0L) {
    paste0(t, "t")
  } else if (m > 0L) {
    paste0(m, "m")
  } else {
    "0m"
  }

  paste0(sign_prefix, result)
}

#' Formatér minutter som komposit tidsstreng (vektoriseret)
#'
#' Producerer læsbare danske tidsstrenge som `"45m"`, `"1t 30m"`, `"2d 13t"`.
#' Max 2 komponenter; dage+timer udelader minutter. Input rundes til hele
#' minutter inden opdeling, så værdier nær en unit-grænse (fx 59,7 min)
#' kollapser korrekt til næste unit (`1t`) i stedet for at producere
#' overflow-komponenter (`60m`).
#'
#' Bruges som kanonisk formatering på y-aksen og i data-punkt labels
#' (centrallinje, target), så akse- og label-tekst altid er i samme
#' format.
#'
#' @param minutes numeric. Tidsværdi(er) i minutter. Negative værdier
#'   prefikses med `"-"`. NA propageres til `NA_character_`.
#' @return character vektor med komposit-formaterede strenge.
#' @keywords internal
#' @noRd
#' @examples
#' \dontrun{
#' format_time_composite(0) # "0m"
#' format_time_composite(45) # "45m"
#' format_time_composite(90) # "1t 30m"
#' format_time_composite(59.7) # "1t" (rounded overflow)
#' format_time_composite(3660) # "2d 13t"
#' format_time_composite(-30) # "-30m"
#' format_time_composite(c(60, NA, 90)) # c("1t", NA, "1t 30m")
#' }
format_time_composite <- function(minutes) {
  if (length(minutes) == 0) {
    return(character(0))
  }

  vapply(minutes, format_time_composite_single, character(1))
}

#' Generér tids-naturlige tick-breaks
#'
#' Vælger det **største** interval fra `TIME_BREAK_CANDIDATES` der stadig
#' giver mindst `target_n` ticks inden for data-range. Det giver
#' naturligt grovere ticks for store ranges og finere for smalle ranges.
#' Begge ender floor-snappes til multipla af det valgte interval
#' (ggplot2's `expansion()` sikrer at y_max stadig er synligt).
#'
#' Defensive guards:
#' \itemize{
#'   \item Ikke-finite input (`NA`, `NaN`, `Inf`, `-Inf`) filtreres
#'     via `is.finite()` — ggplot2 passerer undertiden `Inf` under layout,
#'     hvilket ville crashe `seq()` senere.
#'   \item Konstant range (`y_min == y_max`) returnerer et enkelt tick.
#'   \item Sub-unit range (< 1 minut) falder tilbage til data-bracketing
#'     `c(y_min, y_max)` så aksen ikke bliver blank.
#' }
#'
#' @param y_values numeric. Data-range at generere ticks til.
#' @param target_n integer. Minimums-antal ticks. Default `5L`.
#' @return numeric vektor med tick-positioner i minutter. Tom vektor
#'   hvis `y_values` kun indeholder ikke-finite værdier.
#' @keywords internal
#' @noRd
#' @examples
#' \dontrun{
#' time_breaks(c(0, 120)) # 0 30 60 90 120
#' time_breaks(c(15, 185)) # 0 30 60 90 120 150 180
#' time_breaks(c(0, 480)) # 0 120 240 360 480
#' }
time_breaks <- function(y_values, target_n = 5L) {
  # Defensiv: filtrer ikke-finite (NA, NaN, Inf, -Inf) og tomme inputs.
  # ggplot2 passerer undertiden Inf/-Inf under layout; seq() ville senere
  # crashe med 'to must be a finite number' uden denne filtrering.
  y_clean <- y_values[is.finite(y_values)]
  if (length(y_clean) == 0L) {
    return(numeric(0))
  }

  y_min <- min(y_clean)
  y_max <- max(y_clean)

  # Konstant range: returnér enkelt tick på værdien
  if (y_min == y_max) {
    return(y_min)
  }

  # Primær: største interval med >= target_n ticks.
  # Itererer alle kandidater (floor-snap kan give non-monotonisk n_ticks
  # i sjældne tilfælde for små target_n — omkostningen er ubetydelig).
  chosen_interval <- NULL
  for (interval in TIME_BREAK_CANDIDATES) {
    start <- floor(y_min / interval) * interval
    end <- floor(y_max / interval) * interval
    n_ticks <- (end - start) / interval + 1L
    if (n_ticks >= target_n) {
      chosen_interval <- interval
    }
  }

  # Fallback 1: meget smal range — brug mindste interval med >= 2 ticks
  if (is.null(chosen_interval)) {
    for (interval in TIME_BREAK_CANDIDATES) {
      start <- floor(y_min / interval) * interval
      end <- floor(y_max / interval) * interval
      n_ticks <- (end - start) / interval + 1L
      if (n_ticks >= 2L) {
        chosen_interval <- interval
        break
      }
    }
  }

  # Fallback 2: sub-unit range (f.eks. 0,3-0,9 min) — returnér
  # data-bracketing tick-par så aksen ikke bliver blank.
  if (is.null(chosen_interval)) {
    return(c(y_min, y_max))
  }

  start <- floor(y_min / chosen_interval) * chosen_interval
  end <- floor(y_max / chosen_interval) * chosen_interval

  seq(start, end, by = chosen_interval)
}
