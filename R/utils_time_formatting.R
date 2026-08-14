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
# COMPOSITE TIME FORMAT (Canonical for y-axis + data-point labels)
# ============================================================================

#' Tids-naturlige kandidat-intervaller i minutter
#'
#' Bruges af `time_breaks()` til at vaelge tick-afstand. Daekker fra 1 minut
#' op til 30 dage.
#'
#' @keywords internal
#' @noRd
TIME_BREAK_CANDIDATES <- c(
  1, 2, 5, 10, 15, 20, 30, # minutter
  60, 120, 180, 240, 360, 720, # timer (1t, 2t, 3t, 4t, 6t, 12t)
  1440, 2880, 10080, 43200 # dage (1d, 2d, 7d, 30d)
)

#' Formater minutter som komposit tidsstreng (single value)
#'
#' Runder input til hele minutter foer komponentopdeling for at undgaa
#' overflow (59,7 min -> `1t`, ikke `60m`). Max 2 komponenter for laesbarhed:
#' ved dage+timer vises ikke minutter.
#'
#' @param v numeric(1). Tidsvaerdi i minutter.
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

#' Formater minutter som komposit tidsstreng (vektoriseret)
#'
#' Producerer laesbare danske tidsstrenge som `"45m"`, `"1t 30m"`, `"2d 13t"`.
#' Max 2 komponenter; dage+timer udelader minutter. Input rundes til hele
#' minutter inden opdeling, saa vaerdier naer en unit-graense (fx 59,7 min)
#' kollapser korrekt til naeste unit (`1t`) i stedet for at producere
#' overflow-komponenter (`60m`).
#'
#' Bruges som kanonisk formatering paa y-aksen og i data-punkt labels
#' (centrallinje, target), saa akse- og label-tekst altid er i samme
#' format.
#'
#' @param minutes numeric. Tidsvaerdi(er) i minutter. Negative vaerdier
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

#' Generer tids-naturlige tick-breaks
#'
#' Vaelger det **stoerste** interval fra `TIME_BREAK_CANDIDATES` der stadig
#' giver mindst `target_n` ticks inden for data-range. Det giver
#' naturligt grovere ticks for store ranges og finere for smalle ranges.
#' Begge ender floor-snappes til multipla af det valgte interval
#' (ggplot2's `expansion()` sikrer at y_max stadig er synligt).
#'
#' Defensive guards:
#' \itemize{
#'   \item Ikke-finite input (`NA`, `NaN`, `Inf`, `-Inf`) filtreres
#'     via `is.finite()` - ggplot2 passerer undertiden `Inf` under layout,
#'     hvilket ville crashe `seq()` senere.
#'   \item Konstant range (`y_min == y_max`) returnerer et enkelt tick.
#'   \item Sub-unit range (< 1 minut) falder tilbage til data-bracketing
#'     `c(y_min, y_max)` saa aksen ikke bliver blank.
#' }
#'
#' @param y_values numeric. Data-range at generere ticks til.
#' @param target_n integer. Minimums-antal ticks. Default `5L`.
#' @return numeric vektor med tick-positioner i minutter. Tom vektor
#'   hvis `y_values` kun indeholder ikke-finite vaerdier.
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

  # Konstant range: returner enkelt tick paa vaerdien
  if (y_min == y_max) {
    return(y_min)
  }

  # Primaer: stoerste interval med >= target_n ticks.
  # Itererer alle kandidater (floor-snap kan give non-monotonisk n_ticks
  # i sjaeldne tilfaelde for smaa target_n - omkostningen er ubetydelig).
  chosen_interval <- NULL
  for (interval in TIME_BREAK_CANDIDATES) {
    start <- floor(y_min / interval) * interval
    end <- floor(y_max / interval) * interval
    n_ticks <- (end - start) / interval + 1L
    if (n_ticks >= target_n) {
      chosen_interval <- interval
    }
  }

  # Fallback 1: meget smal range - brug mindste interval med >= 2 ticks
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

  # Fallback 2: sub-unit range (f.eks. 0,3-0,9 min) - returner
  # data-bracketing tick-par saa aksen ikke bliver blank.
  if (is.null(chosen_interval)) {
    return(c(y_min, y_max))
  }

  start <- floor(y_min / chosen_interval) * chosen_interval
  end <- floor(y_max / chosen_interval) * chosen_interval

  seq(start, end, by = chosen_interval)
}

# ============================================================================
# CLOCK FORMAT (klokkeslaet tt:mm - for tidspunkt-paa-dagen-indikatorer)
# ============================================================================

#' Formater sekunder siden midnat som klokkeslaet (single value)
#'
#' Til indikatorer hvor maalevaerdien er et TIDSPUNKT paa dagen (fx median
#' knivtidsstart), ikke en varighed - komposit-formatet ("8t 57m") ville
#' vaere semantisk forkert. Input-enheden er sekunder siden midnat, som er
#' den enhed klokkeslaets-data typisk lagres i
#' (\code{period_to_seconds(hms(...))}).
#'
#' Runder til hele minutter foer komponentopdeling, saa 08:59:50 bliver
#' \code{"09:00"} (ikke \code{"08:60"}). Ingen doegn-wrap: vaerdier er
#' samme-dags klokkeslaet, saa 86390 formateres \code{"24:00"}.
#'
#' @param v numeric(1). Sekunder siden midnat.
#' @return character(1) \code{"tt:mm"}-streng. \code{NA_character_} ved NA.
#' @keywords internal
#' @noRd
format_clock_single <- function(v) {
  if (is.na(v)) {
    return(NA_character_)
  }

  min_total <- as.integer(round(v / 60))
  t <- min_total %/% 60L
  m <- min_total %% 60L

  sprintf("%02d:%02d", t, m)
}

#' Formater sekunder siden midnat som klokkeslaet (vektoriseret)
#'
#' @param seconds numeric. Sekunder siden midnat. NA propageres.
#' @return character vektor med \code{"tt:mm"}-strenge.
#' @keywords internal
#' @noRd
#' @examples
#' \dontrun{
#' format_clock(29700) # "08:15"
#' format_clock(0) # "00:00"
#' format_clock(c(21600, NA)) # c("06:00", NA)
#' }
format_clock <- function(seconds) {
  if (length(seconds) == 0) {
    return(character(0))
  }

  vapply(seconds, format_clock_single, character(1))
}

#' Generer klokkeslaets-naturlige tick-breaks (sekunder siden midnat)
#'
#' Genbruger \code{time_breaks()}-algoritmen ved at skalere sekunder til
#' minutter og tilbage: tick-intervallerne bliver dermed de samme
#' tids-naturlige kandidater (1m, 5m, 15m, 30m, 1t, ...) som varigheds-
#' aksen, blot udtrykt i sekunder saa de matcher clock-dataenes enhed.
#'
#' @param y_values numeric. Data-range i sekunder siden midnat.
#' @param target_n integer. Minimums-antal ticks. Default \code{5L}.
#' @return numeric vektor med tick-positioner i sekunder.
#' @keywords internal
#' @noRd
clock_breaks <- function(y_values, target_n = 5L) {
  time_breaks(y_values / 60, target_n = target_n) * 60
}
