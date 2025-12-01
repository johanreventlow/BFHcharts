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
#' @param threshold numeric afstand i procentpoint hvor decimaler vises (default 0.05 = 5%)
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
format_percent_contextual <- function(val, target = NULL, threshold = 0.05) {

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
#' @param y_range numeric(2) y-akse range (kun brugt for "time" unit context)
#' @param target numeric target værdi for kontekstuel præcision (kun for "percent")
#' @return character formateret string
#'
#' @details
#' Formatering per enhedstype:
#' - **count**: K/M/mia notation for store tal, dansk decimal/tusind separator
#' - **percent**: scales::label_percent() formatering
#' - **rate**: dansk decimal notation, decimaler kun hvis nødvendigt
#' - **time**: kontekst-aware formatering (min/timer/dage baseret på range)
#' - **default**: dansk decimal notation
#'
#' This function delegates to canonical implementations in:
#' - `format_count_danish()` for count formatting
#' - `format_rate_danish()` for rate formatting
#' - `format_time_auto()` for time formatting
#'
#' @examples
#' \dontrun{
#' format_y_value(1234, "count")
#' # Returns: "1K"
#'
#' format_y_value(0.456, "percent")
#' # Returns: "46%"
#'
#' format_y_value(120, "time", y_range = c(0, 200))
#' # Returns: "2 timer"
#' }
#'
#' @keywords internal
#' @noRd
#' @family spc-formatting
#' @seealso [apply_y_axis_formatting()], [format_count_danish()], [format_time_auto()],
#'   [format_percent_contextual()]
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

  # Time formatting - delegates to canonical format_time_auto()
  if (y_unit == "time") {
    if (is.null(y_range) || length(y_range) < 2) {
      warning("format_y_value: y_range mangler for 'time' unit, bruger default formatering")
    }
    return(format_time_auto(val, y_range))
  }

  # Default formatting - dansk notation
  if (isTRUE(all.equal(val, round(val), tolerance = 1e-10))) {
    return(format(round(val), decimal.mark = ","))
  } else {
    return(format(val, decimal.mark = ",", nsmall = 1))
  }
}
