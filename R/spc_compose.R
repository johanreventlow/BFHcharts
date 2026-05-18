# Composition-lag: bfh_analyse() pakker features til bfh_spc_analysis
#
# bfh_analyse(x, metadata, language) komposerer feature-extraction-output
# til struktureret bfh_spc_analysis-objekt (key-only model). Andet lag
# i tre-lags-arkitekturen:
#
#   bfh_qic_result + metadata
#     -> bfh_extract_spc_features()                     -- raw features
#     -> bfh_analyse()                                  -- denne fil; conclusions + caveats + actions
#     -> bfh_render_analysis(texts_loader)              -- character output
#
# Refs: openspec change restructure-spc-analysis-architecture, Phase 1.2
# Spec: openspec/specs/spc-analysis-api/spec.md ADDED requirement
#       "bfh_analyse SHALL return a structured bfh_spc_analysis S3 object
#       (key-only model)"
#
# ASCII-only source (CRAN policy).


#' Compose a Structured SPC Analysis Object
#'
#' Returnerer struktureret `bfh_spc_analysis`-objekt med features,
#' conclusions (i18n-keys), caveats, suggested_actions, og
#' render-context. Det er primaer canonical-output for struktureret SPC-
#' analyse; rentekst-rendering sker via `bfh_render_analysis()`.
#'
#' **Key-only model:** `conclusions$*_key`, `caveats$*` og
#' `suggested_actions` indeholder i18n-noegler, ej resolverede tekst-
#' strenge. Tekst-resolution sker udelukkende i `bfh_render_analysis()`
#' via `texts_loader`. Dette bevarer language-neutralt
#' JSON-eksport-output + tillader audit-replay paa anden sprog uden
#' re-extraction.
#'
#' @param x A `bfh_qic_result` object from `bfh_qic()`.
#' @param metadata Optional named list. Kan indeholde:
#'   - `data_definition`: Description of what the data represents
#'   - `target`: Target value (numeric or operator-prefixed character)
#'   - `direction`: Optional `"higher_better"` / `"lower_better"` /
#'     `"neutral"` override for direction-akse (Slice 4)
#'   - `analysis_date`: Date pinned for determinism (Phase 0.4)
#'   - `hospital`, `department`: passes through to context
#' @param language Character: `"da"` (default) or `"en"`. Stored in
#'   object for downstream render-defaults; SHALL NOT cause text
#'   resolution at this stage.
#'
#' @return Object of class `bfh_spc_analysis`. See ADR-XXX for schema.
#'
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = month, y = value, chart_type = "i")
#' analysis <- bfh_analyse(result, metadata = list(target = ">= 90%"))
#' print(analysis)
#'
#' # Render to text:
#' text <- bfh_render_analysis(analysis, max_chars = 375)
#'
#' # Audit-trail via JSON:
#' jsonlite::toJSON(as.list(analysis), auto_unbox = TRUE, Date = "ISO8601")
#' }
#'
#' @export
bfh_analyse <- function(x, metadata = list(), language = c("da", "en")) {
  language <- match.arg(language)

  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object from bfh_qic()", call. = FALSE)
  }

  # Feature-extraction (Phase 1.1)
  extracted <- bfh_extract_spc_features(x, metadata)
  features <- extracted$features
  aux <- extracted$aux
  render_context <- extracted$render_context
  intermediate <- extracted$`_intermediate`

  # Conclusions (i18n-noegler)
  conclusions <- .compose_conclusions(features, intermediate)

  # Caveats (NULL for inaktiv, noegle-string for aktiv)
  caveats <- .compose_caveats(features, intermediate, aux)

  # Suggested actions (character-vektor af noegler)
  suggested_actions <- .compose_suggested_actions(features, conclusions, intermediate)

  # Confidence-tier afspejler features$confidence_tier direkte
  confidence <- features$confidence_tier

  new_bfh_spc_analysis(
    features = features,
    aux = aux,
    render_context = render_context,
    conclusions = conclusions,
    confidence = confidence,
    caveats = caveats,
    suggested_actions = suggested_actions,
    language = language
  )
}


# ---------------------------------------------------------------------------
# .compose_conclusions: features -> 3 i18n-noegler (stability/target/action)
# ---------------------------------------------------------------------------

.compose_conclusions <- function(features, intermediate) {
  stability_key <- features$stability_pattern

  target_key <- .derive_target_key(features, intermediate)

  # Brug eksisterende .select_action_key(): dispatch over flags +
  # target-direction + goal_met/at_target/near_target.
  action_key <- .select_action_key(
    flags = intermediate$flags,
    target_direction = intermediate$target_direction,
    goal_met = isTRUE(intermediate$goal_met),
    at_target = isTRUE(intermediate$at_target),
    near_target = isTRUE(intermediate$near_target)
  )

  list(
    stability_key = stability_key,
    target_key = target_key,
    action_key = action_key
  )
}


# Map target_relation + direction til target-template-noegle.
# Direction-aware grenen producerer goal_met/near_target/goal_not_met.
# Value-neutral grenen producerer at_target/over_target/under_target
# (sidstnaevnte to udledes af centerline > target).
.derive_target_key <- function(features, intermediate) {
  rel <- features$target_relation
  if (rel == "none") {
    return("")
  }

  if (!is.null(intermediate$target_direction)) {
    # Direction-aware: 3-vejs
    return(switch(rel,
      "met" = "goal_met",
      "near" = "near_target",
      "not_met" = "goal_not_met",
      ""
    ))
  }

  # Value-neutral: at_target/over/under afhaenger af centerline vs target
  if (rel == "met") {
    return("at_target")
  }
  if (rel == "not_met") {
    # Brug intermediate-data til at vaelge over/under
    # NB: intermediate har target_value + features$aux er ej tilgaengelig her,
    # men context.centerline er bevaret via render_context (vi har dog ej
    # direkte ref hertil). Vi udleder via intermediate-flags --
    # at_target == FALSE betyder enten over eller under. Tilfaeldighed:
    # nuvaerende design eksponerer ikke centerline > target direkte.
    # For Phase 1 (parity-pass) brug konventionen: action-arm dispatcher
    # selv via .select_action_key, saa target_key her behoever kun at vaere
    # noget Phase 1 render-lag forstaar. Vi laver minimal valid key.
    # Tjek intermediate -- vi tilfoejer cl_above_target i Phase 1.2-extension.
    return(if (isTRUE(intermediate$cl_above_target)) "over_target" else "under_target")
  }

  "" # near i value-neutral gren ej support (matcher eksisterende semantik)
}


# ---------------------------------------------------------------------------
# .compose_caveats: features + aux -> aktiv-caveat-noegler
# ---------------------------------------------------------------------------

# Returnerer named list med NULL for inaktive caveats, character-noegle
# for aktive. Render-lag mapper noegle til labels.caveats[[key]].
#
# Phase 1 aktive caveats:
#  - cl_source (Slice 9 INCLUDE)
#  - few_obs   (overlap med Slice 8 confidence_tier-detection)
#
# SKIP/DEFER caveats forbliver NULL men felterne er i schema.
.compose_caveats <- function(features, intermediate, aux) {
  cl_source <- features$cl_source
  ds_tier <- features$data_quality$discrete_scale

  # cl_source mapper: enum-vaerdi -> i18n-noegle (eller NULL for inaktiv).
  cl_caveat <- switch(cl_source,
    "user_supplied" = "cl_user_supplied",
    "auto_mean"     = "cl_auto_mean",
    NULL
  )

  # Slice 14: mild/moderate som tail-caveat. extreme haandteres via
  # stability_pattern="majority_at_centerline" (full base-override).
  ds_caveat <- switch(ds_tier,
    "mild"     = "discrete_scale_mild",
    "moderate" = "discrete_scale_moderate",
    NULL
  )

  list(
    cl_source = cl_caveat,
    freshness = NULL, # Slice 10 SKIP
    few_obs = if (isTRUE(features$data_quality$few_obs)) "few_obs" else NULL,
    # Slice 7: variable kontrolgraenser pga svingende n.
    variable_cl = if (isTRUE(features$data_quality$variable_cl)) "variable_cl" else NULL,
    discrete_scale = ds_caveat,
    historic_outliers = NULL, # Slice 11 DEFER
    seasonality = NULL # Slice 13 SKIP
  )
}


# ---------------------------------------------------------------------------
# .compose_suggested_actions: character-vektor af i18n-noegler
# ---------------------------------------------------------------------------

# Phase 1: returnerer single-action vektor med action_key fra conclusions.
# Modifier-slices i Phase 3+ kan tilfoeje yderligere actions.
.compose_suggested_actions <- function(features, conclusions, intermediate) {
  c(conclusions$action_key)
}
