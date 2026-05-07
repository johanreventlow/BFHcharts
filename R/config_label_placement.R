# ==============================================================================
# CONFIG_LABEL_PLACEMENT.R
# ==============================================================================
# FORMAAL: Intelligent label placement configuration for SPC plots med collision
#         avoidance. Alle vaerdier er empirisk tunet for optimal visuel separation
#         mellem labels og linjer.
#
# ANVENDES AF:
#   - fct_add_spc_labels.R - Label placement logic (entry point)
#   - utils_label_placement.R - Geometry + collision avoidance
#   - utils_add_right_labels_marquee.R - Marquee label rendering
#   - utils_note_placement.R - Annotation placement
#   - utils_panel_measurement.R - Panel/label sizing
#   - globals.R - Re-exports config constants
#
# BRUG:
#   config <- get_label_placement_config()
#   gap_line <- config$relative_gap_line * label_height_npc
# ==============================================================================

#' Label Placement Configuration Constants
#'
#' Centraliseret konfiguration for label placement system.
#' Alle relative vaerdier er procent af label_height_npc for konsistent skalering.
#'
#' @format List med foelgende elementer:
#' \describe{
#'   \item{relative_gap_line}{Gap fra label edge til linje (som % af label_height)}
#'   \item{relative_gap_labels}{Gap mellem to labels (som % af label_height)}
#'   \item{pad_top}{Top panel padding (NPC)}
#'   \item{pad_bot}{Bottom panel padding (NPC)}
#'   \item{coincident_threshold_factor}{Threshold for sammenfaldende linjer (% af label_height)}
#'   \item{tight_lines_threshold_factor}{Threshold for taette linjer (% af min_center_gap)}
#'   \item{gap_reduction_factors}{Multi-level gap reduction strategi (vector)}
#'   \item{shelf_center_threshold}{Midtpunkt til shelf-valg (NPC)}
#'   \item{marquee_size_factor}{Base marquee size multiplier}
#'   \item{marquee_lineheight}{Line height for marquee labels}
#'   \item{height_safety_margin}{Safety margin ved grob-maaling (multiplier)}
#'   \item{height_fallback_npc}{Fallback hoejde hvis maaling fejler (NPC)}
#' }
#'
#' @keywords internal
#' @noRd
LABEL_PLACEMENT_CONFIG <- list(
  # === Gap Configuration (relative til label_height_npc) ===
  # Disse vaerdier balancerer "taet placering" med "ingen overlap"
  relative_gap_line = 0.05,
  # 5% af faktisk label hoejde
  # Rationale: Gap beregnes nu fra kun synlige (non-empty) labels.
  #            5% giver optimal visuel separation mellem label og linje.
  #            Skalerer automatisk proportionelt med device stoerrelse da label_size
  #            auto-scales baseret paa viewport-bredde (se fct_add_spc_labels.R).

  relative_gap_labels = 0.30,
  # 30% af label hoejde
  # Rationale: Giver klar visuel separation mellem to labels uden at spilde for meget plads.
  #            Dette er "optimal" gap - collision avoidance kan reducere til 15% hvis noedvendigt.
  #            Baseret paa gestalt-principper for visuel gruppering.

  # === Panel Padding ===
  # Fixed NPC vaerdier - sikrer labels aldrig gaar uden for panel edges

  pad_top = 0.01,
  # 1% top padding
  # Rationale: Minimal padding for at undgaa at labels klippes ved panel top.
  #            Sammenlignet med ggplot2 default expansion (5%), dette er konservativt.

  pad_bot = 0.01,
  # 1% bottom padding
  # Rationale: Symmetrisk med pad_top for konsistent appearance.

  # === Collision Detection Thresholds ===

  coincident_threshold_factor = 0.1,
  # 10% af label hoejde
  # Rationale: Hvis to linjer er inden for 10% af en label hoejde, behandles de som sammenfaldende.
  #            Dette haandterer tilfaelde hvor target = CL (meget almindeligt i SPC plots).
  #            Ved sammenfaldende linjer placeres labels over/under samme linje.

  tight_lines_threshold_factor = 0.5,
  # 50% af min_center_gap
  # Rationale: Hvis gap mellem linjer < 50% af noedvendig center-gap, trigges special handling.
  #            Dette aktiverer "en over, en under" strategi for taette linjer.

  # === Multi-Level Fallback Strategy ===

  gap_reduction_factors = c(0.5, 0.3, 0.15),
  # NIVEAU 1: Reducer gap_labels til 50%, 30%, 15% af original
  # Rationale: Progressiv degradation - proev mindre aggressive reduktioner foerst.
  #            50%: Reducerer gap fra 30% til 15% - stadig synlig separation
  #            30%: Reducerer gap fra 30% til 9% - minimal men acceptabel
  #            15%: Reducerer gap fra 30% til 4.5% - sidste udvej foer flip

  shelf_center_threshold = 0.5,
  # Midtpunkt (50% NPC)
  # Rationale: Ved shelf placement (sidste udvej), brug panel-midten til at afgoere
  #            hvilken shelf (top/bottom) der skal bruges for den ikke-prioriterede label.

  # === Marquee Rendering ===

  marquee_size_factor = 6,
  # Base marquee size multiplier
  # Rationale: Ved base_size=14, giver dette marquee_size=6 (standard for geom_marquee).
  #            Empirisk testet for at matche ggplot2 text size conventions.

  marquee_lineheight = 0.9,
  # Line height for marquee labels
  # Rationale: 0.9 giver kompakt multi-line labels uden at linjerne roerer hinanden.
  #            Standard for mange text rendering systemer.

  # === Height Estimation (grob-baseret) ===

  height_safety_margin = 1.0,
  # Safety margin ved grob-maaling (multiplier)
  # Rationale: Med korrekt panel-based grob maalinger (via panel_height_inches)
  #            er ingen ekstra safety margin noedvendig. Maalinger er praecise.
  #            Tidligere vaerdi 1.44 var en workaround for legacy fallback-baseret hoejde.
  #            Nu med faktiske grob maalinger: 1.0 = ingen ekstra margin

  height_fallback_npc = 0.13,
  # 13% NPC fallback
  # Rationale: Hvis grob-maaling fejler, brug denne vaerdi.
  #            Baseret paa typisk 2-line label (8pt header + 24pt value).
  #            Konservativ vaerdi der passer til de fleste cases.

  # === Note Label Placement ===

  note_label_offset_factor = 0.18,
  # Label offset i normaliseret [0,1] space
  # Rationale: 18% af plottet giver tilstraekkelig afstand fra datapunkt til label-center,
  #            ogsaa for labels med stor bbox (lang tekst eller multi-line).

  note_line_buffer_factor = 0.07,
  # Minimumsafstand fra label-kant til linje i normaliseret space
  # Rationale: 7% buffer sikrer tydelig visuel separation fra linjer og segmenter.

  note_max_label_width = 25,
  # Word-wrap bredde i tegn
  # Rationale: 25 tegn giver kompakt multi-line labels der ikke er for brede.

  note_line_penalty_weight = 100,
  # Penalty-vaegt for naerhed til linjer
  # Rationale: Hoej vaegt sikrer at linje-undgaaelse prioriteres over andre faktorer.

  note_label_overlap_weight = 80,
  # Penalty-vaegt for overlap med andre labels
  # Rationale: Naesthoejeste prioritet - labels maa ikke overlappe hinanden.

  note_distance_weight = 1,
  # Penalty-vaegt for afstand fra datapunkt
  # Rationale: Lav vaegt - afstand er en tiebreaker, ikke en primaer faktor.

  note_bounds_penalty = 1000,
  # Penalty for labels uden for plotomraadet
  # Rationale: Meget hoej - labels uden for bounds er aldrig acceptable.

  note_char_width_factor = 0.011,
  # Estimeret bredde per tegn som broekdel af plot-bredde i [0,1] space

  note_line_height_factor = 0.07
  # Estimeret hoejde per tekstlinje som andel af y-range
  # Rationale: Approksimation til bounding box hoejde-beregning.
)

#' Hent label placement parameter med default fallback
#'
#' Utility funktion til at hente konfigurationsvaerdier med type checking.
#'
#' @param key Parameter navn (fx "relative_gap_line")
#' @param default Default vaerdi hvis key ikke findes (optional)
#' @return Parameter vaerdi
#'
#' @examples
#' \dontrun{
#' gap_line_factor <- get_label_placement_param("relative_gap_line")
#' # Returns: 0.08
#'
#' custom_value <- get_label_placement_param("nonexistent_key", default = 0.5)
#' # Returns: 0.5
#' }
#'
#' @keywords internal
#' @noRd
get_label_placement_param <- function(key, default = NULL) {
  # Hent konfiguration
  config <- LABEL_PLACEMENT_CONFIG

  # Check om key findes
  value <- config[[key]]

  if (is.null(value)) {
    if (is.null(default)) {
      stop(
        "Label placement parameter '", key, "' ikke fundet i LABEL_PLACEMENT_CONFIG. ",
        "Tilg\u00e6ngelige keys: ", paste(names(config), collapse = ", ")
      )
    }
    return(default)
  }

  return(value)
}

#' Hent hele label placement configuration
#'
#' Returnerer en kopi af hele konfigurationsobjektet.
#' Nyttig for debugging eller naar flere parametre skal hentes paa en gang.
#'
#' @return List med alle konfigurationsparametre
#'
#' @examples
#' \dontrun{
#' config <- get_label_placement_config()
#' gap_line <- config$relative_gap_line * label_height_npc
#' gap_labels <- config$relative_gap_labels * label_height_npc
#' }
#'
#' @keywords internal
#' @noRd
get_label_placement_config <- function() {
  # Returner en kopi for at undgaa utilsigtet modification
  as.list(LABEL_PLACEMENT_CONFIG)
}
