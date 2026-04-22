# utils_label_formatting.R
# Delt formatering af y-akse værdier for konsistens mellem labels og akser
#
# Sikrer at labels formateres PRÆCIS som y-aksen for alle enhedstyper
#
# NOTE: This file delegates to canonical formatting functions in:
# - R/utils_number_formatting.R (count, rate formatting)
# - R/utils_time_formatting.R (time formatting)

#' Formatér procent med kontekstuel præcision
#'
#' Viser decimaler kun når værdien er tæt på target (inden for threshold).
#' Bruges til centerline-labels hvor præcision er vigtig nær målet.
#'
#' @param val numeric værdi (0-1 skala, f.eks. 0.887 for 88.7%)
#' @param target numeric target værdi (0-1 skala), eller NULL
#' @param threshold numeric afstand i procentpoint hvor decimaler vises (default 0.02 = 2%)
#' @return character formateret string med dansk notation
#'
#' @details
#' Logik:
#' - Hvis target er NULL eller val er > threshold fra target: hele procent ("89%")
#' - Hvis val er <= threshold fra target: én decimal med dansk komma ("88,7%")
#'
#' @examples
#' \dontrun{
#' format_percent_contextual(0.887, target = 0.90)
#' # Returns: "88,7%" (tæt på target)
#'
#' format_percent_contextual(0.634, target = 0.90)
#' # Returns: "63%" (langt fra target)
#'
#' format_percent_contextual(0.887, target = NULL)
#' # Returns: "89%" (intet target)
#' }
#'
#' @keywords internal
#' @noRd
format_percent_contextual <- function(val, target = NULL, threshold = 0.02) {
  if (length(val) != 1 || !(is.numeric(val) || is.na(val))) {
    stop("val must be a single numeric value", call. = FALSE)
  }

  if (!is.null(target) &&
    (length(target) != 1 || !(is.numeric(target) || is.na(target)))) {
    stop("target must be NULL or a single numeric value", call. = FALSE)
  }

  if (!is.numeric(threshold) || length(threshold) != 1 || is.na(threshold) ||
    !is.finite(threshold) || threshold < 0) {
    stop("threshold must be a single non-negative finite numeric value", call. = FALSE)
  }

  if (is.na(val)) {
    return(NA_character_)
  }

  pct <- val * 100

  # Hvis intet target eller langt fra target: hele procent
  if (is.null(target) || is.na(target) || abs(val - target) > threshold) {
    return(paste0(round(pct), "%"))
  }

  # Tæt på target: vis én decimal med dansk komma (altid nsmall=1 for konsistens)
  formatted <- format(round(pct, 1), decimal.mark = ",", nsmall = 1)
  return(paste0(formatted, "%"))
}

#' Formatér y-akse værdi til display string
#'
#' Formaterer numeriske værdier til display strings der matcher y-akse formatting.
#' Understøtter flere enhedstyper: count, percent, rate, time.
#'
#' @param val numeric værdi at formatere
#' @param y_unit character enhedstype ("count", "percent", "rate", "time", eller andet)
#' @param y_range numeric(2) y-akse range. Legacy-parameter bibeholdt for
#'   bagudkompatibilitet; ignoreres for `"time"` (komposit-format
#'   auto-detekterer minutter/timer/dage) og bruges kun som signatur-
#'   placeholder for andre enheder.
#' @param target numeric target værdi for kontekstuel præcision (kun for "percent")
#' @return character formateret string
#'
#' @details
#' Formatering per enhedstype:
#' - **count**: K/M/mia notation for store tal, dansk decimal/tusind separator
#' - **percent**: scales::label_percent() formatering
#' - **rate**: dansk decimal notation, decimaler kun hvis nødvendigt
#' - **time**: komposit-format (`"30m"`, `"1t 30m"`, `"2d 13t"`) — samme
#'   format som y-aksen, så pile fra CL/target til akse-labels rammer
#'   præcis samme tekst.
#' - **default**: dansk decimal notation
#'
#' This function delegates to canonical implementations in:
#' - `format_count_danish()` for count formatting
#' - `format_rate_danish()` for rate formatting
#' - `format_time_composite()` for time formatting
#'
#' @examples
#' \dontrun{
#' format_y_value(1234, "count")
#' # Returns: "1K"
#'
#' format_y_value(0.456, "percent")
#' # Returns: "46%"
#'
#' format_y_value(120, "time")
#' # Returns: "2t"
#' }
#'
#' @keywords internal
#' @noRd
format_y_value <- function(val, y_unit, y_range = NULL, target = NULL) {
  # Input validation
  if (is.na(val)) {
    return(NA_character_)
  }

  if (!is.numeric(val)) {
    warning("format_y_value: val skal være numerisk, modtog: ", class(val))
    return(as.character(val))
  }

  # Percent formatting - kontekstuel præcision når target er sat
  if (y_unit == "percent") {
    return(format_percent_contextual(val, target = target))
  }

  # Count formatting - delegates to canonical format_count_danish()
  if (y_unit == "count") {
    return(format_count_danish(val))
  }

  # Rate formatting - delegates to canonical format_rate_danish()
  if (y_unit == "rate") {
    return(format_rate_danish(val))
  }

  # Time formatting - komposit-format ("30m", "1t 30m", "2d 13t")
  # y_range ignoreres bevidst: komposit-formatet håndterer selv
  # minutter/timer/dage via componentopdeling.
  if (y_unit == "time") {
    return(format_time_composite(val))
  }

  # Default formatting - kontekstuel dansk notation
  if (is_effective_integer(val)) {
    return(format(round(val), decimal.mark = ","))
  } else if (abs(val) < 1) {
    return(format(round(val, 2), decimal.mark = ",", nsmall = 2))
  } else {
    return(format(round(val, 1), decimal.mark = ",", nsmall = 1))
  }
}
