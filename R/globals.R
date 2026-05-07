#' @importFrom rlang .data
NULL

# Global variables for NSE in ggplot2/dplyr
# Suppresses R CMD check NOTEs about "no visible binding"

utils::globalVariables(c(
  # ggplot2 aesthetics
  "x", "y", "lcl", "ucl", "target", "cl",
  "label", "color", "vjust",

  # dplyr/qicharts2 columns
  "part", "anhoej.signal",
  "n.crossings", "n.crossings.min",
  "part_n_cross", "part_n_cross_min"
))

# ============================================================================
# SIZING CONSTANTS
# ============================================================================

# ============================================================================
# LABEL SIZING CONSTANTS
# ============================================================================

# Line extension factor - hvor langt CL/target forlaenges forbi sidste datapunkt
LINE_EXTENSION_FACTOR <- 0.20

# Default y-axis expansion for chart scales - holdes lav for at minimere
# tom whitespace. Boundary labels kan stadig udvide skalaen dynamisk.
Y_AXIS_BASE_EXPANSION_MULT <- 0.05

# Y-axis expansion multiplier - matcher ggplot2 expansion(mult = ...)
Y_AXIS_EXPANSION_MULT <- 0.25

# Arrow endpoint padding - afstand fra datapunkt i normaliserede koordinater
ARROW_PADDING_NORM <- 0.03

# ============================================================================
# PDF EXPORT DIMENSIONS
# ============================================================================

# PNG image dimensions for ggsave (what gets embedded in Typst)
# These dimensions should match the available chart area in the Typst template
# Based on 6.6mm grid layout:
# - A4 landscape: 297x210mm
# - Page margins: bottom 6.6mm, rest 0mm
# - Chart area inset left: 26.4mm (4x grid)
# - Chart area inset right: 6.6mm (1x grid)
# - SPC column width: 72.6mm (11x grid)
# Image width: 297 - 26.4 - 6.6 - 72.6 = 191.4mm
# Image height: 210 - 6.6 (bottom margin) - 52.8 - 26.4 - 2 (top inset) - 13.2 (bottom space) = 109mm
PDF_IMAGE_WIDTH_MM <- 191.4
PDF_IMAGE_HEIGHT_MM <- 109

# NOTE: Chart width/height matcher image dimensions i den nuvaerende Typst-layout.
# Vi beholder separate konstanter for semantisk tydelighed:
# - PDF_IMAGE_* bruges ved eksport-rendering (ggsave output)
# - PDF_CHART_* bruges ved label-placement beregninger
# Hvis template-layout divergerer i fremtiden, kan de aendres uafhaengigt.

# Target dimensions for label placement calculation (in mm)
# These represent the actual visible chart area in the Typst template
# Based on bfh-diagram 6.6mm grid layout:
# - A4 landscape: 297x210mm
# - Page margins: bottom 6.6mm, rest 0mm
# - Header row: 59.4mm (9x grid)
# - Analysis row: 26.4mm (4x grid)
# - Chart area insets: left 26.4mm, right 6.6mm, top 6.6mm
# - SPC table column: 72.6mm (11x grid)
# Chart width: 297 - 26.4 - 6.6 - 72.6 = 191.4mm
# Chart height: 210 - 6.6 (bottom margin) - 52.8 - 26.4 - 2 (top inset) - 13.2 (bottom space) = 109mm
# Labels should be positioned for how they appear in final PDF
PDF_CHART_WIDTH_MM <- 191.4
PDF_CHART_HEIGHT_MM <- 109

# Fixed label size for PDF export
# This ensures consistent, readable labels regardless of how the chart was created
# Value of 6 is calibrated for the PDF template dimensions
PDF_LABEL_SIZE <- 6

# ============================================================================
# SPC ANALYSIS CONSTANTS
# ============================================================================

# Window of most-recent observations used by the outlier counter (6 is standard in SPC literature)
RECENT_OBS_WINDOW <- 6L

#' Minimum recommended baseline observations for stable SPC control limits
#'
#' The Anhoej rules and SPC literature (Anhoej & Olesen 2014) require approximately
#' 8+ points for meaningful control limits and reliable signal detection.
#' Below this threshold, the control limits are statistically unreliable.
MIN_BASELINE_N <- 8L

# ============================================================================
# LABEL PLACEMENT CONSTANTS
# ============================================================================
# Constants used by `place_two_labels_npc()` (R/utils_label_placement.R) for
# multi-niveau collision resolution. Values mirror the historical defaults
# in the function body's `default_cfg` list and are also overridable via
# `get_label_placement_config()` at runtime.

#' Gap-reduction factors for NIVEAU 1 collision resolution
#'
#' When the initial label placement creates a line-gap collision, NIVEAU 1
#' incrementally shrinks the inter-label gap by these factors (50%, then 30%,
#' then 15% of the configured `gap_labels`). The first factor that resolves
#' the collision is used.
LABEL_PLACEMENT_GAP_REDUCTION_FACTORS <- c(0.5, 0.3, 0.15)

#' Tight-lines threshold factor for early flip-strategy
#'
#' When `abs(yA_npc - yB_npc) < min_center_gap * THIS_FACTOR`, lines are
#' considered too close for both labels to share a side; pref_pos is rewritten
#' so one label sits above and the other below.
LABEL_PLACEMENT_TIGHT_LINES_THRESHOLD_FACTOR <- 0.5

#' Coincident-lines threshold factor
#'
#' When `abs(yA_npc - yB_npc) < label_height_npc * THIS_FACTOR`, lines are
#' treated as effectively coincident; labels are placed one above and one
#' below the same line position.
LABEL_PLACEMENT_COINCIDENT_THRESHOLD_FACTOR <- 0.1

#' Shelf-center threshold for NIVEAU 3 placement
#'
#' During NIVEAU 3 (last-resort shelf placement), the non-priority label is
#' pushed to the opposite shelf (top vs bottom of panel) based on whether
#' the priority label center is below this NPC threshold.
LABEL_PLACEMENT_SHELF_CENTER_THRESHOLD <- 0.5

# ============================================================================
# AUDIT + CONSENT CONSTANTS
# ============================================================================

#' Required value for `data_consent` when `use_ai = TRUE`
#'
#' Caller must pass exactly this string to acknowledge AI-egress of clinical
#' data. Used by `bfh_generate_analysis()`.
DATA_CONSENT_EXPLICIT <- "explicit"

#' Audit event type for AI-egress events
#'
#' Used as the `event` field of audit records produced by
#' `.emit_audit_event()` when AI analysis is invoked.
AUDIT_EVENT_AI_EGRESS <- "ai_egress"

#' Option name: path to audit log file
#'
#' When set, `.emit_audit_event()` appends JSON-line records to this path.
#' Otherwise events are emitted via `message()`.
BFHCHARTS_OPT_AUDIT_LOG <- "BFHcharts.audit_log"

#' Option name: opt-out for globalenv inject_assets warning
#'
#' When `TRUE`, suppresses the warning emitted by `.validate_inject_assets()`
#' for functions defined in `.GlobalEnv` (development convenience).
BFHCHARTS_OPT_ALLOW_GLOBALENV_INJECT <- "BFHcharts.allow_globalenv_inject"

#' Option name: explicit Quarto binary path
#'
#' When set, `find_quarto()` uses this path instead of running auto-detection.
#' The path is shell-metachar validated and existence-checked before use.
BFHCHARTS_OPT_QUARTO_PATH <- "BFHcharts.quarto_path"

#' Option name: suppress unit auto-detection message
#'
#' When `TRUE`, `bfh_export_pdf()` and friends do not emit the informational
#' message "Auto-detected units: ..." when units are inferred from filename.
BFHCHARTS_OPT_SUPPRESS_UNIT_AUTO_DETECT <- "BFHcharts.suppress_unit_auto_detect_message"

#' Option name: debug logging for label-placement fallback paths
#'
#' When `TRUE`, `place_two_labels_npc()` emits diagnostic messages when the
#' niveau cascade falls back to legacy NPC-based gap calculation.
BFHCHARTS_OPT_DEBUG_LABEL_PLACEMENT <- "BFHcharts.debug.label_placement"
