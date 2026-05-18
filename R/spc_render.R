# Render-lag: bfh_render_analysis() resolverer struktureret objekt til tekst
#
# Tredje lag i tre-lags-arkitekturen. Tager bfh_spc_analysis-objekt og
# producerer character output via i18n-resolution + budget-allokering.
#
#   bfh_qic_result + metadata
#     -> bfh_extract_spc_features()                     -- raw features
#     -> bfh_analyse()                                  -- conclusions + caveats + actions
#     -> bfh_render_analysis(texts_loader)              -- denne fil; character output
#
# Refs: openspec change restructure-spc-analysis-architecture, Phase 1.3
# Spec: openspec/specs/spc-analysis-api/spec.md ADDED requirement
#       "bfh_render_analysis SHALL compose text via deterministic
#       modifier cascade"
#
# ASCII-only source (CRAN policy).


#' Render a bfh_spc_analysis Object to Character Output
#'
#' Resolverer i18n-noegler i `analysis$conclusions`, `analysis$caveats`
#' og `analysis$suggested_actions` til tekst via `texts_loader`, sammen-
#' saetter base + target + action + caveats inden for `max_chars`-budget.
#'
#' `render_context`-vaerdier (target_display, centerline_formatted,
#' operator_unicode, outliers_word_key) bruges verbatim som
#' placeholder-vaerdier. Renderer re-deriverer IKKE disse fra
#' features/aux for at undgaa silent display-drift.
#'
#' @param analysis A `bfh_spc_analysis` object from `bfh_analyse()`.
#' @param max_chars Maximum characters in output. Default 375.
#' @param texts_loader Function that returns SPC analysis text templates.
#'   Defaults to `load_spc_texts(analysis$language)`. Primarily intended
#'   for tests/mocking.
#'
#' @return Character of length 1, `nchar(...) <= max_chars`.
#'
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = month, y = value, chart_type = "i")
#' analysis <- bfh_analyse(result, metadata = list(target = ">= 90%"))
#' text <- bfh_render_analysis(analysis, max_chars = 375)
#' }
#'
#' @export
bfh_render_analysis <- function(analysis,
                                max_chars = 375,
                                texts_loader = NULL) {
  if (!inherits(analysis, "bfh_spc_analysis")) {
    stop("analysis must be a bfh_spc_analysis object from bfh_analyse()",
      call. = FALSE
    )
  }

  language <- analysis$language

  # Default-loader matcher eksisterende konvention
  if (is.null(texts_loader)) {
    texts_loader <- function() load_spc_texts(language)
  }
  if (!is.function(texts_loader)) {
    stop("texts_loader must be a function", call. = FALSE)
  }
  texts <- texts_loader()

  # Budget-allokering matcher eksisterende build_fallback_analysis()
  # pre-modifier-introduktion (45/20/35 med target, 55/45 uden).
  # Modifier-pool + tail-caveat-budget kalibreres i Slice 3+ Phase.
  has_target <- isTRUE(analysis$features$target_relation != "none")
  budgets <- .allocate_text_budget(max_chars, has_target)

  # Byg placeholder-data fra render_context + aux + features
  placeholder_data <- .build_placeholder_data(analysis, texts, language)

  # Override-paths (no_variation, majority_at_centerline) + low-confidence
  # gating beregnes oppe foran modifier-pool og target+action-arms.
  is_override <- analysis$conclusions$stability_key %in%
    c("no_variation", "majority_at_centerline")
  is_low_confidence <- identical(analysis$confidence, "low") && !is_override

  # --- 1. Stabilitetstekst ---
  stability_text <- .render_stability(
    analysis, texts, budgets$stability_budget, placeholder_data, language
  )

  # --- 1b. Modifier-pool: magnitude (Slice 3 INCLUDE) + direction (Slice 4 INCLUDE) ---
  # Appender til stability-output. Rekkefolge: magnitude foer direction
  # saa prose-floder naturligt ("skift i niveau (~30% forandring) i
  # den oenskede retning").  Aktiveres kun udenfor override-paths +
  # non-low-confidence.
  if (!is_low_confidence && !is_override) {
    magnitude_text <- .render_magnitude_modifier(analysis, texts, language)
    if (nzchar(magnitude_text)) {
      stability_text <- paste(stability_text, magnitude_text)
    }
    direction_text <- .render_direction_modifier(analysis, texts, language)
    if (nzchar(direction_text)) {
      stability_text <- paste(stability_text, direction_text)
    }
    # Slice 5: baseline-delta + phase-intervention
    baseline_delta_text <- .render_baseline_delta_modifier(analysis, texts, language)
    if (nzchar(baseline_delta_text)) {
      stability_text <- paste(stability_text, baseline_delta_text)
    }
  }

  # --- 2. Maalvurdering ---
  # Slice 8: low-confidence skipper target+action helt. Med under N_MIN
  # observationer er konkrete maal-/handlings-anbefalinger ej forsvarlige.
  # Override-paths (no_variation, majority_at_centerline) bevarer
  # target+action selv ved low confidence.
  target_text <- if (is_low_confidence) {
    ""
  } else {
    .render_target(analysis, texts, budgets$target_budget, placeholder_data, language)
  }

  # --- 3. Handlingsforslag ---
  action_text <- if (is_low_confidence) {
    ""
  } else {
    .render_action(analysis, texts, budgets$action_budget, placeholder_data)
  }

  # --- 4. Tail-caveats ---
  # Slice 9 INCLUDE: CL-disclosure (cl_user_supplied / cl_auto_mean).
  # Future slices appender til samme pool (freshness, variable_cl, ...).
  tail_caveats <- .render_tail_caveats(analysis, texts, language)

  parts <- c(stability_text, target_text, action_text, tail_caveats)
  parts <- parts[nchar(parts) > 0]
  text <- paste(parts, collapse = " ")

  ensure_within_max(text, max_chars)
}


# ---------------------------------------------------------------------------
# Magnitude modifier (Slice 3 INCLUDE)
# ---------------------------------------------------------------------------

# Resolverer features$magnitude til prose-clause med {pct_abs}-substitution.
# Returnerer "" naar magnitude=NA eller baseline_delta_pct mangler.
.render_magnitude_modifier <- function(analysis, texts, language) {
  mag <- analysis$features$magnitude
  if (is.null(mag) || is.na(mag) ||
    !mag %in% c("small", "medium", "large")) {
    return("")
  }
  pct <- analysis$aux$baseline_delta_pct
  if (!is_valid_scalar(pct) || !is.finite(pct)) {
    return("")
  }

  templates <- texts$modifier$magnitude[[mag]]
  if (is.null(templates)) {
    return("")
  }

  data <- list(pct_abs = abs(round(pct, 0)))
  pick_text(templates, data = data, budget = 200L)
}


# ---------------------------------------------------------------------------
# Baseline-delta modifier (Slice 5 INCLUDE)
# ---------------------------------------------------------------------------

# Resolverer phase_context == "post_intervention" til prose-clause med
# {baseline_value} + {current_value} substitution. Returnerer "" naar
# phase_context != post_intervention eller baseline-aux mangler.
.render_baseline_delta_modifier <- function(analysis, texts, language) {
  if (!identical(analysis$features$phase_context, "post_intervention")) {
    return("")
  }
  baseline_cl <- analysis$aux$baseline_centerline
  current_cl <- analysis$aux$centerline
  if (!is_valid_scalar(baseline_cl) || !is.finite(baseline_cl) ||
    !is_valid_scalar(current_cl) || !is.finite(current_cl)) {
    return("")
  }

  templates <- texts$modifier$baseline_delta
  if (is.null(templates)) {
    return("")
  }

  y_axis_unit <- analysis$render_context$y_axis_unit
  baseline_value <- format_target_value(baseline_cl,
    y_axis_unit = y_axis_unit, language = language
  )
  current_value <- analysis$render_context$centerline_formatted
  if (!nzchar(current_value)) {
    current_value <- format_target_value(current_cl,
      y_axis_unit = y_axis_unit, language = language
    )
  }

  data <- list(
    baseline_value = baseline_value,
    current_value = current_value
  )
  pick_text(templates, data = data, budget = 200L)
}


# ---------------------------------------------------------------------------
# Direction modifier (Slice 4 INCLUDE)
# ---------------------------------------------------------------------------

# Resolverer features$direction til prose-clause (favorable/unfavorable).
# Returnerer "" naar direction in (neutral, unknown) eller texts mangler.
.render_direction_modifier <- function(analysis, texts, language) {
  dir <- analysis$features$direction
  if (!dir %in% c("favorable", "unfavorable")) {
    return("")
  }
  templates <- texts$modifier$direction[[dir]]
  if (is.null(templates)) {
    return("")
  }
  # Brug standard-variant; budget-allokering haandteres af caller
  template_value <- templates$standard %||% templates$short %||% ""
  if (!nzchar(template_value)) {
    return("")
  }
  template_value
}


# ---------------------------------------------------------------------------
# Tail-caveats (Slice 9 + fremtidige slices)
# ---------------------------------------------------------------------------

# Returnerer concatenated character (eller "" hvis ingen aktive caveats).
# Caveats appendes i fast prioritets-raekkefoelge: cl_source > freshness
# > variable_cl > historic_outliers > seasonality. Future slices kan
# tilfoeje uden at aendre allerede-aktive caveats.
.render_tail_caveats <- function(analysis, texts, language) {
  # Fast prioritets-raekkefoelge: Slice 9 (cl_source), Slice 14
  # (discrete_scale mild/moderate -- extreme rendres via stability-base),
  # Slice 7 (variable_cl). Future slices (freshness, historic_outliers,
  # seasonality) tilfoejes ved at appende slot-navn til denne vektor.
  caveat_slots <- c("cl_source", "discrete_scale", "variable_cl")

  parts <- character(0L)
  for (slot in caveat_slots) {
    key <- analysis$caveats[[slot]]
    if (is.null(key) || !nzchar(key)) next
    text <- i18n_lookup(paste0("labels.caveats.", key), language)
    if (!is.null(text) && nzchar(text)) {
      parts <- c(parts, text)
    }
  }

  if (length(parts) == 0L) {
    return("")
  }
  paste(parts, collapse = " ")
}


# ---------------------------------------------------------------------------
# Placeholder-data: builds full {placeholder}-map til pick_text()
# ---------------------------------------------------------------------------

# Konstruerer placeholder_data svarende til
# build_fallback_analysis() linje 1028-1043, men traekker vaerdier fra
# struktureret analysis-objekt:
#  - centerline:   render_context$centerline_formatted
#  - target:       render_context$target_display
#  - outliers_*:   aux + i18n labels via outliers_word_key
#  - runs_*, crossings_*: tilgaengelig kun fra feature-extraction --
#    Anhoej-stats lagres ikke i bfh_spc_analysis-schema (Phase 1
#    parity-decision: vi henter dem fra context via re-call paa
#    eksisterende bfh_extract_spc_stats helper hvis i fremtidig version).
#    For Phase 1 vi videre-eksporterer fra aux (nye felter).
.build_placeholder_data <- function(analysis, texts, language) {
  rc <- analysis$render_context
  aux <- analysis$aux

  outliers_word <- i18n_lookup(
    paste0("labels.outliers.", rc$outliers_word_key),
    language
  )

  level <- .resolve_level_placeholders(analysis, language)

  list(
    # Anhoej-stats fra aux
    runs_actual = aux$runs_actual,
    runs_expected = aux$runs_expected,
    crossings_actual = aux$crossings_actual,
    crossings_expected = aux$crossings_expected,
    outliers_actual = aux$outliers_recent_count %||% aux$outliers_actual,
    outliers_word = outliers_word,
    effective_window = aux$effective_window %||% RECENT_OBS_WINDOW,
    centerline = rc$centerline_formatted,
    target = rc$target_display,
    level_direction = level$direction,
    level_vs_target = level$vs_target
  )
}


# Resolverer {level_direction}-/{level_vs_target}-placeholders til
# sprog-specifikke i18n-strings via shared .compute_level_keys()-helper
# i spc_analysis.R (key-triplet "at"/"over"/"under"). Returnerer
# named list (direction, vs_target) eller list("","") naar target
# ej sat.
.resolve_level_placeholders <- function(analysis, language) {
  has_target <- isTRUE(analysis$features$target_relation != "none")
  level_keys <- .compute_level_keys(
    analysis$aux$centerline,
    analysis$aux$target_value,
    has_target
  )
  if (is.null(level_keys)) {
    return(list(direction = "", vs_target = ""))
  }
  list(
    direction = i18n_lookup(
      paste0("labels.level_direction.", level_keys$direction_key), language
    ),
    vs_target = i18n_lookup(
      paste0("labels.level_vs_target.", level_keys$vs_target_key), language
    )
  )
}


# ---------------------------------------------------------------------------
# Stability arm
# ---------------------------------------------------------------------------

# Vaelger template fra texts$stability[[key]] eller texts$base[[override]].
# Prioritet:
#   1. no_variation / majority_at_centerline -> texts$stability[[key]]
#      (override-state har forrang over low-confidence; konstant data
#      med n>>N_MIN er specifikt no_variation, ej "for kort serie")
#   2. Slice 8 INCLUDE: confidence_tier == "low" -> texts$base$not_evaluable
#      (erstatter stability-base helt; specialiseret kort-serie-tekst)
#   3. 8 signal-baserede keys -> texts$stability[[key]]
.render_stability <- function(analysis, texts, budget, placeholder_data, language) {
  key <- analysis$conclusions$stability_key

  # Override-state-paths: no_variation + majority_at_centerline
  # har forrang over low-confidence (specifikke meddelelser for
  # specifikke data-egenskaber).
  is_override <- key %in% c("no_variation", "majority_at_centerline")

  if (is_override) {
    data <- list(centerline = placeholder_data$centerline)
    templates <- texts$stability[[key]]
    if (is.null(templates)) {
      return("")
    }
    return(pick_text(templates, data = data, budget = budget))
  }

  # Slice 8: low-confidence override (ej for override-paths ovenfor)
  if (identical(analysis$confidence, "low")) {
    templates <- texts$base$not_evaluable %||% NULL
    if (!is.null(templates)) {
      data <- list(
        n_points = analysis$aux$n_points %||% 0L,
        centerline = placeholder_data$centerline
      )
      return(pick_text(templates, data = data, budget = budget))
    }
    # Fallback til legacy-label hvis ny base.not_evaluable mangler i loader
  }

  templates <- texts$stability[[key]]
  if (is.null(templates)) {
    return("")
  }
  pick_text(templates, data = placeholder_data, budget = budget)
}


# ---------------------------------------------------------------------------
# Target arm
# ---------------------------------------------------------------------------

.render_target <- function(analysis, texts, budget, placeholder_data, language) {
  key <- analysis$conclusions$target_key
  if (!nzchar(key)) {
    return("")
  }

  templates <- texts$target[[key]]
  if (is.null(templates)) {
    return("")
  }

  # target_display-fallback: hvis render_context$target_display er tom
  # men aux$target_value findes (numerisk input via metadata$target=50),
  # format value via format_target_value med caller-language. Matcher
  # .evaluate_target_arm() linje 835-843.
  display <- analysis$render_context$target_display
  if (!nzchar(display) && !is.null(analysis$aux$target_value) &&
    !is.na(analysis$aux$target_value)) {
    display <- format_target_value(
      analysis$aux$target_value,
      y_axis_unit = analysis$render_context$y_axis_unit,
      language = language
    )
  }

  # Operator-Unicode-konvertering via shared helper i spc_analysis.R.
  display <- .normalize_target_operators(display)

  data <- list(
    target = display,
    centerline = placeholder_data$centerline,
    level_direction = placeholder_data$level_direction,
    level_vs_target = placeholder_data$level_vs_target
  )
  pick_text(templates, data = data, budget = budget)
}


# ---------------------------------------------------------------------------
# Action arm
# ---------------------------------------------------------------------------

.render_action <- function(analysis, texts, budget, placeholder_data) {
  key <- analysis$conclusions$action_key
  templates <- texts$action[[key]]
  if (is.null(templates)) {
    return("")
  }

  data <- list(
    centerline = placeholder_data$centerline,
    level_direction = placeholder_data$level_direction,
    level_vs_target = placeholder_data$level_vs_target
  )
  pick_text(templates, data = data, budget = budget)
}
