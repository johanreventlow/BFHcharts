#' @importFrom rlang .data
NULL

# Global variables for NSE in ggplot2/dplyr
# Suppresses R CMD check NOTEs about "no visible binding"

# All ggplot2 aes() calls now use the .data pronoun (e.g. .data[["x"]]) so
# no bare column names need to be declared here. Keep this block as a
# reminder that globalVariables() should only list names that genuinely
# cannot be expressed via .data or rlang::.data in NSE contexts.
# utils::globalVariables(character(0))

# ============================================================================
# SIZING CONSTANTS
# ============================================================================

# ============================================================================
# LABEL SIZING CONSTANTS
# ============================================================================

# Line extension factor - hvor langt CL/target forlaenges forbi sidste datapunkt
LINE_EXTENSION_FACTOR <- 0.20

# Default y-axis expansion for chart scales (top + bund). 17.5% placerer
# data i de midterste ~65% af plot-omraadet, jf. SPC-litteraturens
# anbefaling, og giver luft til marquee-labels (target/CL) naar de
# ligger i ydre 10-20% af y-aksen. Tidligere 5% (#164) klippede
# boundary-labels ved akse-graensen; 12.5% var efterfoelgende default
# men gav for lidt luft til labels over/under datapunkter.
Y_AXIS_BASE_EXPANSION_MULT <- 0.175

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

# Percent-unit "near target" classification caps (proportion scale, ej procentpoint).
# Bruges af .evaluate_target_arm() / .compute_level_keys() i analysis_core.R.
#
# NEAR_TARGET_DISPLAY_THRESHOLD (0.02 = 2pp): max delta hvor chart-label viser
# en decimal istedet for hele procent. Matcher format_percent_contextual()
# default threshold i utils_label_formatting.R. Bruges som "display-precision-
# equality" cutoff: hvis CL og target afrunder til samme display-vaerdi
# klassificeres som at_target/goal_met (matcher hvad laeseren ser i chart).
NEAR_TARGET_DISPLAY_THRESHOLD <- 0.02

# NEAR_TARGET_PCT_CAP (0.03 = 3pp): absolut cap paa near_target-tolerance.
# Klinisk "lige over"-betydning: tolerance skal vaere baade statistisk
# (3*sigma_hat) OG absolut <= 3pp OG relativt <= NEAR_TARGET_PCT_RELATIVE.
# Forhindrer at stoejende processer (fx 0-30% spread) ratiionaliserer en
# CL paa 11% mod target=5% som "lige over". 3pp valgt empirisk efter
# empirisk review (PDF 13: 19% mod 15% = 4pp, PDF 15: 7% mod 3% = 4pp --
# begge skal NU klassificeres som goal_not_met, ej near_target).
NEAR_TARGET_PCT_CAP <- 0.03

# NEAR_TARGET_PCT_RELATIVE (0.25 = 25% af target): relativ cap paa
# near_target-tolerance. Haandterer smaa-target-cases hvor 3pp absolut
# stadig ville vaere klinisk for stor afvigelse. Eksempel: target=3%,
# CL=5% har delta=2pp (under abs-cap) men 67% relativt -- ikke "lige over".
# Med relative-cap = 0.25 * 0.03 = 0.0075 (0.75pp) klassificeres 5%-vs-3%
# korrekt som goal_not_met. Anvendes kun som loft (min med abs-cap),
# saa store-target-cases (target=90%) ej rammer urealistiske
# relative-tolerancer (0.25 * 0.90 = 22.5pp).
NEAR_TARGET_PCT_RELATIVE <- 0.25

#' Minimum recommended baseline observations for stable SPC control limits
#'
#' The Anhoej rules and SPC literature (Anhoej & Olesen 2014) require approximately
#' 8+ points for meaningful control limits and reliable signal detection.
#' Below this threshold, the control limits are statistically unreliable.
#' @keywords internal
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
#' @keywords internal
LABEL_PLACEMENT_GAP_REDUCTION_FACTORS <- c(0.5, 0.3, 0.15)

#' Tight-lines threshold factor for early flip-strategy
#'
#' When `abs(yA_npc - yB_npc) < min_center_gap * THIS_FACTOR`, lines are
#' considered too close for both labels to share a side; pref_pos is rewritten
#' so one label sits above and the other below.
#' @keywords internal
LABEL_PLACEMENT_TIGHT_LINES_THRESHOLD_FACTOR <- 0.5

#' Coincident-lines threshold factor
#'
#' When `abs(yA_npc - yB_npc) < label_height_npc * THIS_FACTOR`, lines are
#' treated as effectively coincident; labels are placed one above and one
#' below the same line position.
#' @keywords internal
LABEL_PLACEMENT_COINCIDENT_THRESHOLD_FACTOR <- 0.1

#' Shelf-center threshold for NIVEAU 3 placement
#'
#' During NIVEAU 3 (last-resort shelf placement), the non-priority label is
#' pushed to the opposite shelf (top vs bottom of panel) based on whether
#' the priority label center is below this NPC threshold.
#' @keywords internal
LABEL_PLACEMENT_SHELF_CENTER_THRESHOLD <- 0.5

# ============================================================================
# DEPENDENCY VERSION CONSTANTS
# ============================================================================

#' Minimum required version of BFHtheme
#'
#' Single source of truth for the BFHtheme lower-bound used in dep-guards
#' (utils_dep_guards.R), .onAttach (zzz.R), and package-level docs
#' (BFHcharts-package.R). Must match the Imports: lower-bound in DESCRIPTION.
.BFHTHEME_MIN_VERSION <- "0.5.1"

# ============================================================================
# AUDIT + CONSENT CONSTANTS
# ============================================================================

#' Required value for `data_consent` when `use_ai = TRUE`
#'
#' Caller must pass exactly this string to acknowledge AI-egress of clinical
#' data. Used by `bfh_generate_analysis()`.
#' @keywords internal
DATA_CONSENT_EXPLICIT <- "explicit"

#' Audit event type for AI-egress events
#'
#' Used as the `event` field of audit records produced by
#' `.emit_audit_event()` when AI analysis is invoked.
#' @keywords internal
AUDIT_EVENT_AI_EGRESS <- "ai_egress"

#' Option name: path to audit log file
#'
#' When set, `.emit_audit_event()` appends JSON-line records to this path.
#' Otherwise events are emitted via `message()`.
#' @keywords internal
BFHCHARTS_OPT_AUDIT_LOG <- "BFHcharts.audit_log"

#' Option name: opt-out for globalenv inject_assets warning
#'
#' When `TRUE`, suppresses the warning emitted by `.validate_inject_assets()`
#' for functions defined in `.GlobalEnv` (development convenience).
#' @keywords internal
BFHCHARTS_OPT_ALLOW_GLOBALENV_INJECT <- "BFHcharts.allow_globalenv_inject"

#' Option name: explicit Quarto binary path
#'
#' When set, `find_quarto()` uses this path instead of running auto-detection.
#' The path is shell-metachar validated and existence-checked before use.
#' @keywords internal
BFHCHARTS_OPT_QUARTO_PATH <- "BFHcharts.quarto_path"

#' Option name: analysis_date override
#'
#' When set, `.resolve_analysis_date()` uses this Date as the analysis
#' anchor instead of `Sys.Date()`. Lower priority than per-call
#' `metadata$analysis_date`. Intended for test-suites (set in `setup.R`)
#' and audit-replay scenarios where determinism across calendar days
#' matters.
#' @keywords internal
BFHCHARTS_OPT_ANALYSIS_DATE <- "BFHcharts.analysis_date"

#' Minimum observation count for full Anhoej-evaluability
#'
#' Below this threshold, `confidence_tier` collapses to `"low"` and the
#' renderer substitutes the `not_evaluable`-base. Default value follows
#' Anhoej & Olesen (2014) detection-power analysis: run-detection-power
#' drops sharply below n = 12.
#'
#' Anhoej J, Olesen AV (2014). Run charts revisited: a simulation study
#' of run chart rules for detection of non-random variation in health
#' care processes. PLoS One. 9(11):e113825.
#' @keywords internal
N_MIN <- 12L

#' Low-confidence reason enum
#'
#' Set af gyldige `low_confidence_reason`-vaerdier ved
#' `confidence_tier == "low"`. Bruges af feature-extraction
#' (`.compute_low_confidence_reason`), render-dispatch
#' (`.render_stability` -> `texts$base$not_evaluable[[reason]]`) og
#' schema-validator. NA_character_ er gyldig vaerdi naar tier != "low".
#' @keywords internal
LOW_CONFIDENCE_REASONS <- c("few_obs", "no_centerline", "no_spread")

#' Magnitude-modifier ratio-cap
#'
#' Safety-cap for `.compute_magnitude()` baseline-delta-sigma-ratio.
#' Microscopic sigma (~1e-12) fra near-constant data combineret med
#' float-noise baseline-delta kan producere astronomical ratios and
#' falsk "large"-klassifikation. Ratio > cap returnerer NA i stedet
#' for magnitude-bucket. Default `100` svarer til 100 sigma-shifts --
#' empirisk usandsynligt klinisk-meaningful + klart-ufysisk for
#' kontrolgraense-baseret SPC.
#'
#' Cycle 04 H2 fix (2026-05-18). Foreloebigt safety-net; permanent
#' loesning kraever sigma-floor med scale/unit-awareness.
#' @keywords internal
MAGNITUDE_RATIO_CAP <- 100

#' Option name: suppress unit auto-detection message
#'
#' When `TRUE`, `bfh_export_pdf()` and friends do not emit the informational
#' message "Auto-detected units: ..." when units are inferred from filename.
#' @keywords internal
BFHCHARTS_OPT_SUPPRESS_UNIT_AUTO_DETECT <- "BFHcharts.suppress_unit_auto_detect_message"

#' Option name: debug logging for label-placement fallback paths
#'
#' When `TRUE`, `place_two_labels_npc()` emits diagnostic messages when the
#' niveau cascade falls back to legacy NPC-based gap calculation.
#' @keywords internal
BFHCHARTS_OPT_DEBUG_LABEL_PLACEMENT <- "BFHcharts.debug.label_placement"
