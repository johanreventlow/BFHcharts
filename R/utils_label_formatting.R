# utils_label_formatting.R
# Delt formatering af y-akse værdier for konsistens mellem labels og akser
#
# Sikrer at labels formateres PRÆCIS som y-aksen for alle enhedstyper

#' Formatér y-akse værdi til display string
#'
#' Formaterer numeriske værdier til display strings der matcher y-akse formatting.
#' Understøtter flere enhedstyper: count, percent, rate, time.
#'
#' @param val numeric værdi at formatere
#' @param y_unit character enhedstype ("count", "percent", "rate", "time", eller andet)
#' @param y_range numeric(2) y-akse range (kun brugt for "time" unit context)
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
#' @export
format_y_value <- function(val, y_unit, y_range = NULL) {
  # Input validation
  if (is.na(val)) {
    return(NA_character_)
  }

  if (!is.numeric(val)) {
    warning("format_y_value: val skal være numerisk, modtog: ", class(val))
    return(as.character(val))
  }

  # Percent formatting
  if (y_unit == "percent") {
    # Matcher scale_y_continuous(labels = scales::label_percent())
    return(scales::label_percent()(val))
  }

  # Count formatting med K/M/mia notation
  if (y_unit == "count") {
    if (abs(val) >= 1e9) {
      scaled <- val / 1e9
      if (scaled == round(scaled)) {
        return(paste0(round(scaled), " mia."))
      } else {
        return(paste0(format(scaled, decimal.mark = ",", nsmall = 1), " mia."))
      }
    } else if (abs(val) >= 1e6) {
      scaled <- val / 1e6
      if (scaled == round(scaled)) {
        return(paste0(round(scaled), "M"))
      } else {
        return(paste0(format(scaled, decimal.mark = ",", nsmall = 1), "M"))
      }
    } else if (abs(val) >= 1e3) {
      scaled <- val / 1e3
      if (scaled == round(scaled)) {
        return(paste0(round(scaled), "K"))
      } else {
        return(paste0(format(scaled, decimal.mark = ",", nsmall = 1), "K"))
      }
    } else {
      # For values < 1000: show decimals only if present
      if (val == round(val)) {
        return(format(round(val), decimal.mark = ",", big.mark = "."))
      } else {
        return(format(val, decimal.mark = ",", big.mark = ".", nsmall = 1))
      }
    }
  }

  # Rate formatting - kun decimaler hvis tilstede
  if (y_unit == "rate") {
    if (val == round(val)) {
      return(format(round(val), decimal.mark = ","))
    } else {
      return(format(val, decimal.mark = ",", nsmall = 1))
    }
  }

  # Time formatting (input: minutes) - kontekst-aware
  if (y_unit == "time") {
    # Hvis y_range ikke er givet, kan vi ikke bestemme kontekst
    if (is.null(y_range) || length(y_range) < 2) {
      warning("format_y_value: y_range mangler for 'time' unit, bruger default formatering")
      if (val == round(val)) {
        return(format(round(val), decimal.mark = ","))
      } else {
        return(format(val, decimal.mark = ",", nsmall = 1))
      }
    }

    max_minutes <- max(y_range, na.rm = TRUE)

    if (max_minutes < 60) {
      # Minutes
      if (val == round(val)) {
        return(paste0(round(val), " min"))
      } else {
        return(paste0(format(val, decimal.mark = ",", nsmall = 1), " min"))
      }
    } else if (max_minutes < 1440) {
      # Hours
      hours <- val / 60
      if (hours == round(hours)) {
        return(paste0(round(hours), " timer"))
      } else {
        return(paste0(format(hours, decimal.mark = ",", nsmall = 1), " timer"))
      }
    } else {
      # Days
      days <- val / 1440
      if (days == round(days)) {
        return(paste0(round(days), " dage"))
      } else {
        return(paste0(format(days, decimal.mark = ",", nsmall = 1), " dage"))
      }
    }
  }

  # Default formatting - dansk notation
  if (val == round(val)) {
    return(format(round(val), decimal.mark = ","))
  } else {
    return(format(val, decimal.mark = ",", nsmall = 1))
  }
}
