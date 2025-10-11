# ==============================================================================
# CONFIG_LABEL_PLACEMENT.R
# ==============================================================================
# FORMÅL: Intelligent label placement configuration for SPC plots med collision
#         avoidance. Alle værdier er empirisk tunet for optimal visuel separation
#         mellem labels og linjer.
#
# ANVENDES AF:
#   - fct_add_spc_labels.R - Label placement logic
#   - Plot generation system (collision detection)
#   - Label rendering (gap calculation, marquee sizing)
#
# RELATERET:
#   - config_ui.R - Font scaling configuration
#   - fct_spc_plot_generation.R - Plot rendering
#   - See: docs/CONFIGURATION.md for complete guide
#
# BRUG:
#   config <- get_label_placement_config()
#   gap_line <- config$relative_gap_line * label_height_npc
# ==============================================================================

#' Label Placement Configuration Constants
#'
#' Centraliseret konfiguration for label placement system.
#' Alle relative værdier er procent af label_height_npc for konsistent skalering.
#'
#' @format List med følgende elementer:
#' \describe{
#'   \item{relative_gap_line}{Gap fra label edge til linje (som % af label_height)}
#'   \item{relative_gap_labels}{Gap mellem to labels (som % af label_height)}
#'   \item{pad_top}{Top panel padding (NPC)}
#'   \item{pad_bot}{Bottom panel padding (NPC)}
#'   \item{coincident_threshold_factor}{Threshold for sammenfaldende linjer (% af label_height)}
#'   \item{tight_lines_threshold_factor}{Threshold for tætte linjer (% af min_center_gap)}
#'   \item{gap_reduction_factors}{Multi-level gap reduction strategi (vector)}
#'   \item{shelf_center_threshold}{Midtpunkt til shelf-valg (NPC)}
#'   \item{marquee_size_factor}{Base marquee size multiplier}
#'   \item{marquee_lineheight}{Line height for marquee labels}
#'   \item{height_safety_margin}{Safety margin ved grob-måling (multiplier)}
#'   \item{height_fallback_npc}{Fallback højde hvis måling fejler (NPC)}
#' }
#'
#' @export
LABEL_PLACEMENT_CONFIG <- list(
  # === Gap Configuration (relative til label_height_npc) ===
  # Disse værdier balancerer "tæt placering" med "ingen overlap"
  relative_gap_line = 0.05,
  # 5% af faktisk label højde
  # Rationale: Gap beregnes nu fra kun synlige (non-empty) labels.
  #            5% giver optimal visuel separation mellem label og linje.
  #            Skalerer automatisk proportionelt med device størrelse da label_size
  #            auto-scales baseret på device height (se fct_add_spc_labels.R).
  #            Tidligere problem: Inkluderede empty textB fallback (0.13 NPC), nu fikseret.

  relative_gap_labels = 0.30,
  # 30% af label højde
  # Rationale: Giver klar visuel separation mellem to labels uden at spilde for meget plads.
  #            Dette er "optimal" gap - collision avoidance kan reducere til 15% hvis nødvendigt.
  #            Baseret på gestalt-principper for visuel gruppering.

  # === Panel Padding ===
  # Fixed NPC værdier - sikrer labels aldrig går uden for panel edges

  pad_top = 0.01,
  # 1% top padding
  # Rationale: Minimal padding for at undgå at labels klippes ved panel top.
  #            Sammenlignet med ggplot2 default expansion (5%), dette er konservativt.

  pad_bot = 0.01,
  # 1% bottom padding
  # Rationale: Symmetrisk med pad_top for konsistent appearance.

  # === Collision Detection Thresholds ===

  coincident_threshold_factor = 0.1,
  # 10% af label højde
  # Rationale: Hvis to linjer er inden for 10% af en label højde, behandles de som sammenfaldende.
  #            Dette håndterer tilfælde hvor target = CL (meget almindeligt i SPC plots).
  #            Ved sammenfaldende linjer placeres labels over/under samme linje.

  tight_lines_threshold_factor = 0.5,
  # 50% af min_center_gap
  # Rationale: Hvis gap mellem linjer < 50% af nødvendig center-gap, trigges special handling.
  #            Dette aktiverer "en over, en under" strategi for tætte linjer.

  # === Multi-Level Fallback Strategy ===

  gap_reduction_factors = c(0.5, 0.3, 0.15),
  # NIVEAU 1: Reducer gap_labels til 50%, 30%, 15% af original
  # Rationale: Progressiv degradation - prøv mindre aggressive reduktioner først.
  #            50%: Reducerer gap fra 30% til 15% - stadig synlig separation
  #            30%: Reducerer gap fra 30% til 9% - minimal men acceptabel
  #            15%: Reducerer gap fra 30% til 4.5% - sidste udvej før flip

  shelf_center_threshold = 0.5,
  # Midtpunkt (50% NPC)
  # Rationale: Ved shelf placement (sidste udvej), brug panel-midten til at afgøre
  #            hvilken shelf (top/bottom) der skal bruges for den ikke-prioriterede label.

  # === Marquee Rendering ===

  marquee_size_factor = 6,
  # Base marquee size multiplier
  # Rationale: Ved base_size=14, giver dette marquee_size=6 (standard for geom_marquee).
  #            Empirisk testet for at matche ggplot2 text size conventions.

  marquee_lineheight = 0.9,
  # Line height for marquee labels
  # Rationale: 0.9 giver kompakt multi-line labels uden at linjerne rører hinanden.
  #            Standard for mange text rendering systemer.

  # === Height Estimation (grob-baseret) ===

  height_safety_margin = 1.0,
  # Safety margin ved grob-måling (multiplier)
  # Rationale: Med korrekt panel-based grob målinger (via panel_height_inches)
  #            er ingen ekstra safety margin nødvendig. Målinger er præcise.
  #            Tidligere værdi 1.44 var en workaround for legacy fallback-baseret højde.
  #            Nu med faktiske grob målinger: 1.0 = ingen ekstra margin

  height_fallback_npc = 0.13
  # 13% NPC fallback
  # Rationale: Hvis grob-måling fejler, brug denne værdi.
  #            Baseret på typisk 2-line label (8pt header + 24pt value).
  #            Konservativ værdi der passer til de fleste cases.
)

#' Hent label placement parameter med default fallback
#'
#' Utility funktion til at hente konfigurationsværdier med type checking.
#'
#' @param key Parameter navn (fx "relative_gap_line")
#' @param default Default værdi hvis key ikke findes (optional)
#' @return Parameter værdi
#'
#' @examples
#' gap_line_factor <- get_label_placement_param("relative_gap_line")
#' # Returns: 0.08
#'
#' custom_value <- get_label_placement_param("nonexistent_key", default = 0.5)
#' # Returns: 0.5
#'
#' @export
get_label_placement_param <- function(key, default = NULL) {
  # Hent konfiguration
  config <- LABEL_PLACEMENT_CONFIG

  # Check om key findes
  value <- config[[key]]

  if (is.null(value)) {
    if (is.null(default)) {
      stop(
        "Label placement parameter '", key, "' ikke fundet i LABEL_PLACEMENT_CONFIG. ",
        "Tilgængelige keys: ", paste(names(config), collapse = ", ")
      )
    }
    return(default)
  }

  return(value)
}

#' Hent hele label placement configuration
#'
#' Returnerer en kopi af hele konfigurationsobjektet.
#' Nyttig for debugging eller når flere parametre skal hentes på en gang.
#'
#' @return List med alle konfigurationsparametre
#'
#' @examples
#' config <- get_label_placement_config()
#' gap_line <- config$relative_gap_line * label_height_npc
#' gap_labels <- config$relative_gap_labels * label_height_npc
#'
#' @export
get_label_placement_config <- function() {
  # Returner en kopi for at undgå utilsigtet modification
  as.list(LABEL_PLACEMENT_CONFIG)
}

#' Overskrive label placement configuration (for testing)
#'
#' VIGTIGT: Denne funktion er kun til test-formål.
#' Den modificerer den globale konfiguration og skal kun bruges i tests.
#'
#' @param ... Named arguments med værdier at overskrive
#' @return Invisible: Den gamle konfiguration (for restore)
#'
#' @examples
#' \dontrun{
#' # I test:
#' old_config <- override_label_placement_config(
#'   relative_gap_line = 0.10,
#'   pad_top = 0.02
#' )
#'
#' # ... run tests ...
#'
#' # Restore:
#' LABEL_PLACEMENT_CONFIG <<- old_config
#' }
#'
#' @keywords internal
override_label_placement_config <- function(...) {
  overrides <- list(...)

  # Gem gamle værdier
  old_config <- LABEL_PLACEMENT_CONFIG

  # Valider at alle keys findes
  invalid_keys <- setdiff(names(overrides), names(LABEL_PLACEMENT_CONFIG))
  if (length(invalid_keys) > 0) {
    warning(
      "Ukendte konfigurationsnøgler: ", paste(invalid_keys, collapse = ", "),
      ". Disse ignoreres."
    )
  }

  # Opdater konfiguration
  valid_overrides <- overrides[names(overrides) %in% names(LABEL_PLACEMENT_CONFIG)]
  for (key in names(valid_overrides)) {
    LABEL_PLACEMENT_CONFIG[[key]] <<- valid_overrides[[key]]
  }

  # Returner gamle værdier for restore
  invisible(old_config)
}
