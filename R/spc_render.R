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
  # (key=="not_evaluable" per H4 fix) gating beregnes foran modifier-pool
  # og target+action-arms.
  is_override <- analysis$conclusions$stability_key %in%
    c("no_variation", "majority_at_centerline")
  is_low_confidence <- identical(analysis$conclusions$stability_key, "not_evaluable")

  # --- 1. Stabilitetstekst ---
  stability_text <- .render_stability(
    analysis, texts, budgets$stability_budget, placeholder_data, language
  )

  # --- 1b. Modifier-saetning: magnitude + direction + baseline-delta (cycle 05 finding #2) ---
  # Tidligere paste-konkatenering producerede brudt prose (fragments med
  # parens, lowercase-leadings, dobbelt-perioder). Composeren bygger nu
  # EN sammenhaengende saetning ved at vaelge sentence-frame baseret paa
  # hvilke modifikatorer er aktive.
  modifier_sentence <- if (!is_low_confidence && !is_override) {
    modifier_budget <- max(80L, floor(max_chars * 0.30))
    .compose_modifier_sentence(analysis, texts, language, budget = modifier_budget)
  } else {
    ""
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

  parts <- c(stability_text, modifier_sentence, target_text, action_text, tail_caveats)
  parts <- parts[nchar(parts) > 0]
  text <- paste(parts, collapse = " ")

  # Cycle 07 finding #1: priority-aware trim. ensure_within_max() trims
  # blind fra slutningen og kan klippe action_text vaek selv om
  # modifier_sentence + tail_caveats er optional. Drop low-priority
  # segments FOR blind-clip naar total overskrider max_chars.
  # Priority (low -> high): modifier_sentence > tail_caveats > target_text.
  # stability_text + action_text er klinisk must-keep.
  if (nchar(text) > max_chars) {
    drop_candidates <- c(modifier_sentence, tail_caveats, target_text)
    for (segment in drop_candidates) {
      if (!nzchar(segment)) next
      parts <- parts[parts != segment]
      text <- paste(parts, collapse = " ")
      if (nchar(text) <= max_chars) break
    }
  }

  ensure_within_max(text, max_chars)
}


# ---------------------------------------------------------------------------
# Modifier sentence composer (cycle 05 finding #2 fix)
# ---------------------------------------------------------------------------

# Bygger EN sammenhaengende modifier-saetning af op til 3 aktive modifiers
# (baseline_delta, magnitude, direction). Erstatter den tidligere
# paste-konkatenering af fragmenter, som producerede brudt prose.
#
# Sentence-frame styres af kombinationen:
#  baseline_delta + (magnitude eller direction) -> "lead, {mag} {dir}."
#  baseline_delta kun                           -> "standalone."
#  magnitude + direction (ej baseline)          -> "Niveauet viser {mag} {dir}."
#  magnitude kun                                -> "Niveauet viser {mag}."
#  direction kun                                -> "Niveauet bevaeger sig {dir}."
#  ingen aktive                                 -> ""
#
# Returnerer character af laengde 1 (potentielt "").
.compose_modifier_sentence <- function(analysis, texts, language, budget = 200L) {
  features <- analysis$features
  aux <- analysis$aux

  has_baseline <- identical(features$phase_context, "post_intervention") &&
    is_valid_scalar(aux$baseline_centerline) && is.finite(aux$baseline_centerline) &&
    is_valid_scalar(aux$centerline) && is.finite(aux$centerline)

  has_mag <- !is.null(features$magnitude) && !is.na(features$magnitude) &&
    features$magnitude %in% c("small", "medium", "large") &&
    is_valid_scalar(aux$baseline_delta_pct) && is.finite(aux$baseline_delta_pct)

  has_dir <- !is.null(features$direction) &&
    features$direction %in% c("favorable", "unfavorable")

  if (!has_baseline && !has_mag && !has_dir) {
    return("")
  }

  # Hent clause-templates (variant-aware via pick_text).
  mag_clause <- if (has_mag) {
    templates <- texts$modifier$magnitude[[features$magnitude]]
    if (is.null(templates)) {
      ""
    } else {
      pct <- abs(round(aux$baseline_delta_pct, 0))
      pick_text(templates, data = list(pct_abs = pct), budget = budget)
    }
  } else {
    ""
  }

  dir_clause <- if (has_dir) {
    templates <- texts$modifier$direction[[features$direction]]
    if (is.null(templates)) "" else pick_text(templates, budget = budget)
  } else {
    ""
  }

  baseline_data <- if (has_baseline) {
    y_axis_unit <- analysis$render_context$y_axis_unit
    # target threades gennem saa baseline/current CL bevarer en decimal
    # naar |CL - target| <= 2pp -- matcher chart-label-praecision.
    target_val <- aux$target_value
    list(
      baseline_value = format_target_value(aux$baseline_centerline,
        y_axis_unit = y_axis_unit, language = language, target = target_val
      ),
      current_value = format_target_value(aux$centerline,
        y_axis_unit = y_axis_unit, language = language, target = target_val
      )
    )
  } else {
    list()
  }

  # Compose final sentence.
  if (has_baseline && (nzchar(mag_clause) || nzchar(dir_clause))) {
    lead_templates <- texts$modifier$baseline_delta$lead
    if (is.null(lead_templates)) {
      return("")
    }
    lead <- pick_text(lead_templates, data = baseline_data, budget = budget)
    tail_clauses <- c(mag_clause, dir_clause)
    tail_clauses <- tail_clauses[nzchar(tail_clauses)]
    tail <- paste(tail_clauses, collapse = " ")
    paste0(lead, ", ", tail, ".")
  } else if (has_baseline) {
    standalone_templates <- texts$modifier$baseline_delta$standalone
    if (is.null(standalone_templates)) "" else pick_text(standalone_templates, data = baseline_data, budget = budget)
  } else if (nzchar(mag_clause)) {
    # Magnitude (+/- direction). Frame "Niveauet viser {clauses}.".
    frame_templates <- texts$modifier$compose$mod_only
    if (is.null(frame_templates)) {
      return("")
    }
    clauses <- if (nzchar(dir_clause)) {
      paste(mag_clause, dir_clause)
    } else {
      mag_clause
    }
    pick_text(frame_templates, data = list(clauses = clauses), budget = budget)
  } else if (nzchar(dir_clause)) {
    # Direction kun. Frame "Niveauet bevaeger sig {clauses}.".
    frame_templates <- texts$modifier$compose$dir_only
    if (is.null(frame_templates)) {
      return("")
    }
    pick_text(frame_templates, data = list(clauses = dir_clause), budget = budget)
  } else {
    ""
  }
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

  # H1 fix: format centerline ved render-time med caller-language. Tidligere
  # cached render_context$centerline_formatted hardcoded 'da' -> mixed
  # decimals for language='en'.
  # target threades gennem saa percent-CL bevarer en decimal naar
  # |CL - target| <= 2pp -- matcher chart-label-praecision
  # (format_y_value via format_percent_contextual).
  centerline_str <- if (!is.null(aux$centerline) && !is.na(aux$centerline)) {
    format_target_value(aux$centerline,
      y_axis_unit = rc$y_axis_unit, language = language,
      target = aux$target_value
    )
  } else {
    i18n_lookup("labels.misc.ukendt", language) %||% ""
  }

  list(
    runs_actual = aux$runs_actual,
    runs_expected = aux$runs_expected,
    crossings_actual = aux$crossings_actual,
    crossings_expected = aux$crossings_expected,
    outliers_actual = aux$outliers_recent_count %||% aux$outliers_actual,
    outliers_word = outliers_word,
    effective_window = aux$effective_window %||% RECENT_OBS_WINDOW,
    centerline = centerline_str,
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
    has_target,
    y_axis_unit = analysis$render_context$y_axis_unit
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

  # H4 fix: stability_key == "not_evaluable" er nu canonical low-confidence-
  # state (.resolve_stability_pattern returnerer noeglen). Render-lag matcher
  # key, ej confidence-tier separat -- feature-state og rendered output er
  # konsistente.
  #
  # Cycle 05 finding #5: dispatch paa low_confidence_reason saa prose
  # matcher faktisk aarsag (few_obs vs no_centerline vs no_spread).
  if (identical(key, "not_evaluable")) {
    reason <- analysis$features$low_confidence_reason %||% "few_obs"
    if (!reason %in% LOW_CONFIDENCE_REASONS) {
      reason <- "few_obs" # safety-fallback
    }
    templates <- texts$base$not_evaluable[[reason]] %||% NULL
    if (!is.null(templates)) {
      data <- list(
        n_points = analysis$aux$n_points %||% 0L,
        centerline = placeholder_data$centerline
      )
      return(pick_text(templates, data = data, budget = budget))
    }
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
