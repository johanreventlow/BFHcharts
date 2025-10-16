#' SPC Chart Type Definitions
#'
#' Constants and utilities for SPC chart types, including Danish/English
#' mappings and denominator requirements.
#'
#' @name chart_types
NULL

# ============================================================================
# CHART TYPE MAPPINGS
# ============================================================================

#' Danish Chart Type Names
#'
#' Mapping mellem danske UI labels og engelske qicharts2 koder.
#'
#' @format Named character vector med dansk label → engelsk kode
#' @family spc-chart-types
#' @seealso [CHART_TYPES_EN], [get_qic_chart_type()]
#' @export
#' @examples
#' CHART_TYPES_DA["Seriediagram med SPC (Run Chart)"]  # Returns "run"
CHART_TYPES_DA <- c(
  "Seriediagram med SPC (Run Chart)" = "run",
  "I-kort (Individuelle værdier)" = "i",
  "MR-kort (Moving Range)" = "mr",
  "P-kort (Andele)" = "p",
  "P'-kort (Andele, standardiseret)" = "pp",
  "U-kort (Rater)" = "u",
  "U'-kort (Rater, standardiseret)" = "up",
  "C-kort (Tællinger)" = "c",
  "G-kort (Tid mellem hændelser)" = "g"
)

#' English Chart Type Codes
#'
#' Valid qicharts2 chart type codes.
#'
#' @format Character vector of valid chart codes
#' @family spc-chart-types
#' @seealso [CHART_TYPES_DA], [get_qic_chart_type()]
#' @export
CHART_TYPES_EN <- c("run", "i", "mr", "p", "pp", "u", "up", "c", "g", "xbar", "s", "t")

# ============================================================================
# CHART TYPE DESCRIPTIONS
# ============================================================================

#' Chart Type Descriptions (Danish)
#'
#' Danske beskrivelser af hver chart type til dokumentation og UI.
#'
#' @format Named character vector med engelsk kode → dansk beskrivelse
#' @family spc-chart-types
#' @seealso [get_chart_description()], [CHART_TYPES_DA]
#' @keywords internal
CHART_TYPE_DESCRIPTIONS <- c(
  run = "Seriediagram der viser data over tid med median centerlinje",
  i = "I-kort til individuelle målinger",
  mr = "Moving Range kort til variabilitet mellem på hinanden følgende målinger",
  p = "P-kort til andele og procenter",
  pp = "P'-kort til standardiserede andele",
  u = "U-kort til rater og hændelser per enhed",
  up = "U'-kort til standardiserede rater",
  c = "C-kort til tællinger af defekter eller hændelser",
  g = "G-kort til tid mellem sjældne hændelser"
)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

#' Convert Danish Chart Type Names to QIC Codes
#'
#' Konverterer danske displaynavne til engelske qicharts2-koder for plot generation.
#'
#' @param danish_selection Valgt chart type (dansk label eller engelsk kode)
#' @return Engelsk qicharts2 kode (fx "i", "run", "p")
#'
#' @family spc-chart-types
#' @seealso [CHART_TYPES_DA], [CHART_TYPES_EN]
#' @keywords internal
#' @examples
#' \dontrun{
#' get_qic_chart_type("I-kort (Individuelle værdier)")  # Returns "i"
#' get_qic_chart_type("i")  # Returns "i" (already English)
#' get_qic_chart_type(NULL)  # Returns "run" (default)
#' }
get_qic_chart_type <- function(danish_selection) {
  if (is.null(danish_selection) || danish_selection == "") {
    return("run") # Default fallback
  }

  # Hvis det allerede er en engelsk kode, returner som-den-er
  if (danish_selection %in% CHART_TYPES_EN) {
    return(danish_selection)
  }

  # Find mapping fra dansk til engelsk
  matched_code <- CHART_TYPES_DA[danish_selection]

  if (!is.na(matched_code) && length(matched_code) > 0) {
    return(unname(matched_code))
  }

  # Fallback hvis ikke fundet
  warning(sprintf(
    "Unknown chart type '%s' - defaulting to 'run'",
    danish_selection
  ))
  return("run")
}

#' Check if Chart Type Requires Denominator
#'
#' Afgør om diagramtype kræver en nævner (n) kolonne.
#' Bruges til UI validering og qicharts2 parameter passing.
#'
#' @param chart_type Valgt diagramtype (dansk label eller engelsk kode)
#' @return Logical - TRUE hvis nævner er påkrævet, ellers FALSE
#'
#' @details
#' Chart types requiring denominator:
#' - **p**, **pp**: Proportion charts (numerator/denominator)
#' - **u**, **up**: Rate charts (events/exposure)
#'
#' @family spc-chart-types
#' @seealso [get_qic_chart_type()], [create_spc_chart()]
#' @keywords internal
#' @examples
#' \dontrun{
#' chart_type_requires_denominator("p")  # TRUE
#' chart_type_requires_denominator("i")  # FALSE
#' chart_type_requires_denominator("P-kort (Andele)")  # TRUE
#' }
chart_type_requires_denominator <- function(chart_type) {
  # Normalisér til qicharts2-kode
  ct <- get_qic_chart_type(chart_type)

  # Nævner er relevant for p, pp, u, up
  return(ct %in% c("p", "pp", "u", "up"))
}

#' Get Chart Type Description
#'
#' Henter dansk beskrivelse for et givent chart type.
#'
#' @param chart_type Chart type (engelsk kode eller dansk navn)
#' @return Dansk beskrivelse af chart type
#'
#' @family spc-chart-types
#' @seealso [CHART_TYPE_DESCRIPTIONS], [get_qic_chart_type()]
#' @keywords internal
#' @examples
#' \dontrun{
#' get_chart_description("run")
#' get_chart_description("I-kort (Individuelle værdier)")
#' }
get_chart_description <- function(chart_type) {
  # Normalisér til engelsk kode
  code <- get_qic_chart_type(chart_type)

  # Hent beskrivelse
  desc <- CHART_TYPE_DESCRIPTIONS[code]

  if (is.na(desc)) {
    return("SPC chart")
  }

  return(unname(desc))
}
