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

  # --- 1. Stabilitetstekst ---
  stability_text <- .render_stability(
    analysis, texts, budgets$stability_budget, placeholder_data, language
  )

  # --- 2. Maalvurdering ---
  target_text <- .render_target(
    analysis, texts, budgets$target_budget, placeholder_data, language
  )

  # --- 3. Handlingsforslag ---
  action_text <- .render_action(
    analysis, texts, budgets$action_budget, placeholder_data
  )

  # --- 4. Tail-caveats (Phase 1: cl_disclosure naar aktiv) ---
  # Phase 3+ udvider med modifier-pool og freshness/variable_cl-caveats.
  # For Phase 1 holder vi parity med eksisterende output (ingen caveats
  # i prose -- de er i PDF-sidebar).

  parts <- c(stability_text, target_text, action_text)
  parts <- parts[nchar(parts) > 0]
  text <- paste(parts, collapse = " ")

  ensure_within_max(text, max_chars)
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

  level_dir <- .compute_level_direction(analysis, language)
  level_vs <- .compute_level_vs_target(analysis, language)

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
    level_direction = level_dir,
    level_vs_target = level_vs
  )
}


# Compute {level_direction}-placeholder: target-relativ position af CL.
# Matcher build_fallback_analysis() linje 990-1001.
.compute_level_direction <- function(analysis, language) {
  has_target <- isTRUE(analysis$features$target_relation != "none")
  if (!has_target) {
    return("")
  }

  cl <- analysis$aux$centerline
  tv <- analysis$aux$target_value %||% NA_real_

  if (is.na(cl) || is.na(tv)) {
    return("")
  }

  delta <- abs(cl - tv)
  if (delta < 1e-9) {
    return(i18n_lookup("labels.level_direction.at", language))
  }
  if (cl > tv) {
    return(i18n_lookup("labels.level_direction.over", language))
  }
  i18n_lookup("labels.level_direction.under", language)
}


# Compute {level_vs_target}-placeholder. Matcher build_fallback_analysis()
# linje 1002-1013.
.compute_level_vs_target <- function(analysis, language) {
  has_target <- isTRUE(analysis$features$target_relation != "none")
  if (!has_target) {
    return("")
  }

  cl <- analysis$aux$centerline
  tv <- analysis$aux$target_value %||% NA_real_

  if (is.na(cl) || is.na(tv)) {
    return("")
  }

  if (abs(cl - tv) < 1e-9) {
    return(i18n_lookup("labels.level_vs_target.at", language))
  }
  if (cl > tv) {
    return(i18n_lookup("labels.level_vs_target.over", language))
  }
  i18n_lookup("labels.level_vs_target.under", language)
}


# ---------------------------------------------------------------------------
# Stability arm
# ---------------------------------------------------------------------------

# Vaelger template fra texts$stability[[key]] eller texts$stability[[override]].
# Matcher build_fallback_analysis() prioritet:
# no_variation > majority_at_centerline > 8 signal-keys.
.render_stability <- function(analysis, texts, budget, placeholder_data, language) {
  key <- analysis$conclusions$stability_key

  # Specialiserede placeholders for no_variation / majority_at_centerline
  data <- if (key %in% c("no_variation", "majority_at_centerline")) {
    list(centerline = placeholder_data$centerline)
  } else {
    placeholder_data
  }

  templates <- texts$stability[[key]]
  if (is.null(templates)) {
    return("")
  }
  pick_text(templates, data = data, budget = budget)
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

  # Operator-Unicode-konvertering for target_display.
  # Matcher build_fallback_analysis() linje 848-849.
  if (nzchar(display)) {
    display <- gsub(">=", "\U2265", display, fixed = TRUE)
    display <- gsub("<=", "\U2264", display, fixed = TRUE)
  }

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
