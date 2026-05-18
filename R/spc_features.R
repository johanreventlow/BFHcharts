# Feature-extraction lag for struktureret SPC-analyse
#
# bfh_extract_spc_features(x, metadata) er pure deterministisk funktion
# der ekstraherer 12 ortogonale fortolknings-akser fra et
# bfh_qic_result-objekt. Det er foerste lag i den nye tre-lags-arkitektur:
#
#   bfh_qic_result + metadata
#     -> bfh_extract_spc_features() (denne fil)        -- features + aux + render_context
#     -> bfh_analyse()                                  -- conclusions + caveats + suggested_actions
#     -> bfh_render_analysis(texts_loader)              -- character output
#
# Refs: openspec change restructure-spc-analysis-architecture, Phase 1.1
# Spec: openspec/specs/spc-analysis-api/spec.md ADDED requirement
#       "bfh_extract_spc_features SHALL compute orthogonal feature axes"
#
# ASCII-only source (CRAN policy).


# Tag intern API: feature-extraction kaldes af bfh_analyse() (Phase 1.2).
# Direct kald uden for pakke ej forventet; eksponeres som internal helper
# saa downstream (biSPCharts) kan teste raw features uden at gaa gennem
# composition-laget.


#' Extract Orthogonal SPC Feature Axes from bfh_qic_result
#'
#' Internal pure-funktion. Producerer 12 named feature-akser + aux
#' helper-values + render_context fra et `bfh_qic_result`-objekt.
#' Deterministisk: samme input + metadata SHALL altid producere samme
#' output (givet `metadata$analysis_date` er pinned eller `Sys.Date()`
#' er stable).
#'
#' @param x A `bfh_qic_result` object.
#' @param metadata Optional list. Kan indeholde `analysis_date`,
#'   `target` (string eller numeric), `direction`, `data_definition`,
#'   `hospital`, `department`.
#'
#' @return Named list med komponenter:
#'   - `features`: 12 ortogonale akser
#'   - `aux`: computed hjaelpe-vaerdier (sigma_hat, sigma_data, n_points,
#'     centerline, analysis_date, latest_obs_date, baseline_centerline,
#'     baseline_delta, ...)
#'   - `render_context`: preserved render-state (target_display,
#'     y_axis_unit, centerline_formatted, operator_unicode,
#'     outliers_word_key, effective_window, chart_type)
#'   - `_intermediate`: internal pass-through state for composition-lag
#'     (target_direction, target_value, has_target, signal_flags).
#'     Dette felt SKAL ej eksponeres til downstream-konsumenter.
#'
#' @keywords internal
#' @noRd
bfh_extract_spc_features <- function(x, metadata = list()) {
  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object from bfh_qic()", call. = FALSE)
  }

  # Genbrug eksisterende context-builder for at faa Anhoej-stats,
  # sigma_hat/sigma_data, n_on_cl_ratio, target-resolution m.m. i den
  # form spc_analysis.R-helpers forventer.
  context <- bfh_build_analysis_context(x, metadata)

  # Resolve analysis_date via 3-vejs praecedens (Phase 0.4).
  analysis_date <- .resolve_analysis_date(metadata)

  # Detection-lag: signal-flags + target-relation (key-only).
  flags <- .detect_signal_flags(context)
  target_eval <- .evaluate_target_relation(context, flags)

  # Memoize baseline + delta her saa Phase 3+ slices (3, 4, 5) genbruger
  # samme vaerdier istedet for at re-scanne x$summary 3x per bfh_analyse.
  # Tidligere /simplify-fix-1 (efficiency).
  baseline_centerline <- .extract_baseline_centerline(x)
  baseline_delta <- if (!is.na(baseline_centerline) &&
    !is.null(x$summary) && "centerlinje" %in% names(x$summary) &&
    nrow(x$summary) >= 2L) {
    x$summary$centerlinje[nrow(x$summary)] - baseline_centerline
  } else {
    NA_real_
  }
  baseline_delta_pct <- if (!is.na(baseline_delta) && !is.na(baseline_centerline) &&
    abs(baseline_centerline) > 1e-9) {
    100 * baseline_delta / baseline_centerline
  } else {
    NA_real_
  }

  # Injicer baseline_centerline som context-attribut saa .resolve_direction()
  # kan udfoere delta-baseret favorable/unfavorable-vurdering uden ekstra
  # arg-threading.
  attr(context, "baseline_centerline") <- baseline_centerline

  # --- features ---
  # H4 fix: compute confidence_tier foer stability_pattern, saa low-confidence
  # kan returnere "not_evaluable" som feature-value (downstream consumer-
  # contract matcher rendered output).
  confidence_tier <- .compute_confidence_tier(context, x)

  features <- list(
    # AKTIV AKSE (Phase 1 detection):
    stability_pattern = .resolve_stability_pattern(flags, confidence_tier),
    target_relation = target_eval$target_relation,
    confidence_tier = confidence_tier,
    # Cycle 05 finding #5: primary reason for low-confidence (NA naar
    # confidence_tier != "low"). Drives render-lag template-dispatch saa
    # not_evaluable-prose matcher faktisk aarsag (few_obs vs no_centerline
    # vs no_spread).
    low_confidence_reason = if (identical(confidence_tier, "low")) {
      .compute_low_confidence_reason(context)
    } else {
      NA_character_
    },

    # AKTIV AKSE (kan udfyldes af Slice 5 baseline-delta):
    phase_context = .resolve_phase_context(x, baseline_centerline),

    # AKTIV AKSE (Slice 3 magnitude):
    magnitude = .compute_magnitude(
      baseline_delta = baseline_delta,
      sigma_hat = context$sigma_hat,
      sigma_data = context$sigma_data
    ),

    # AKTIV AKSE (Slice 9 CL-disclosure):
    cl_source = .resolve_cl_source(context$spc_stats),

    # Data-quality sub-akser:
    data_quality = list(
      few_obs = isTRUE(context$n_points < N_MIN),
      variable_cl = .detect_variable_cl(x, chart_class = .resolve_chart_class(context$chart_type)),
      discrete_scale = .resolve_discrete_scale_tier(context$n_on_cl_ratio),
      missing_denominators = NA # Slice 6 (SKIP)
    ),

    # SKIP/DEFER-akser: NA-default for schema-stabilitet
    trend_form = NA_character_, # Slice 12 DEFER
    direction = .resolve_direction(context, metadata),
    freshness = NA_character_, # Slice 10 SKIP
    chart_class = .resolve_chart_class(context$chart_type),
    outlier_history = .resolve_outlier_history(context$spc_stats) # Slice 11 DEFER (akse bevares)
  )

  # --- aux ---
  aux <- list(
    sigma_hat = context$sigma_hat,
    sigma_data = context$sigma_data,
    n_points = context$n_points,
    effective_window = context$spc_stats$effective_window %||% NA_integer_,
    centerline = context$centerline,
    target_value = context$target_value, # bevares for render-tid placeholder-computation
    n_on_cl_ratio = context$n_on_cl_ratio,
    analysis_date = analysis_date,
    latest_obs_date = .extract_latest_obs_date(x),
    baseline_centerline = baseline_centerline,
    baseline_delta = baseline_delta,
    baseline_delta_pct = baseline_delta_pct,
    outliers_actual = context$spc_stats$outliers_actual %||% NA_integer_,
    outliers_recent_count = context$spc_stats$outliers_recent_count %||% NA_integer_,
    runs_actual = context$spc_stats$runs_actual,
    runs_expected = context$spc_stats$runs_expected,
    crossings_actual = context$spc_stats$crossings_actual,
    crossings_expected = context$spc_stats$crossings_expected
  )

  # --- render_context ---
  # target_display bevares verbatim fra user-input (eller "" hvis intet).
  # Numerisk target via metadata$target=50 har target_display="" --
  # render-lag fallback'er via format_target_value(target_value, ...)
  # for language-aware formatering. centerline_formatted formaters
  # default i 'da'-format; render-lag re-formaters hvis language="en".
  render_context <- list(
    target_display = context$target_display %||% "",
    centerline_formatted = .format_centerline_for_render(context),
    y_axis_unit = context$y_axis_unit %||% "count",
    operator_unicode = .extract_operator_unicode(context$target_display),
    outliers_word_key = .resolve_outliers_word_key(
      features$data_quality$few_obs,
      aux$outliers_actual,
      aux$outliers_recent_count
    ),
    # N1 fix: effective_window er spec-required i render_context (cycle 04).
    # Dupliceres med aux$effective_window for spec-konform downstream-access.
    effective_window = aux$effective_window %||% NA_integer_,
    chart_type = context$chart_type %||% "i"
  )

  # --- internal pass-through til composition-lag ---
  # Bevarer target-direction-resolution + flags saa bfh_analyse() ej
  # behoever at re-derive disse fra features. Ikke del af public schema;
  # composition-lag stripper feltet inden bfh_spc_analysis-konstruktor.
  cl_above_target <- if (isTRUE(flags$has_target) &&
    is_valid_scalar(context$centerline) &&
    is_valid_scalar(context$target_value)) {
    context$centerline > context$target_value
  } else {
    NA
  }
  intermediate <- list(
    target_direction = context$target_direction,
    has_target = flags$has_target,
    goal_met = target_eval$goal_met,
    at_target = target_eval$at_target,
    near_target = target_eval$near_target,
    cl_above_target = cl_above_target,
    flags = flags
  )

  list(
    features = features,
    aux = aux,
    render_context = render_context,
    `_intermediate` = intermediate
  )
}


# ---------------------------------------------------------------------------
# Stability-pattern (10 vaerdier)
# ---------------------------------------------------------------------------

# Returnerer i18n-noegle for stability-arm baseret paa eksisterende
# flag-detection. Prioritet matcher build_fallback_analysis():
# no_variation > majority_at_centerline > signal-baseret dispatch.
.resolve_stability_pattern <- function(flags, confidence_tier = NULL) {
  # H4 fix: low-confidence (kort serie / manglende spread-estimat) returnerer
  # "not_evaluable" som feature-value -- downstream UI badges baseret paa
  # stability_pattern matcher saa rendered prose. Override-paths
  # (no_variation, majority_at_centerline) bevarer deres egen overlay.
  if (isTRUE(flags$no_variation)) {
    return("no_variation")
  }
  if (isTRUE(flags$majority_at_cl)) {
    return("majority_at_centerline")
  }
  if (identical(confidence_tier, "low")) {
    return("not_evaluable")
  }
  .select_stability_key(flags) # Returnerer 8 signal-baserede noegler
}


# ---------------------------------------------------------------------------
# Target-relation (key-only sibling af .evaluate_target_arm)
# ---------------------------------------------------------------------------

# Returnerer target_relation-enum + goal_met/at_target/near_target-flags
# UDEN at rendere tekst. .evaluate_target_arm() forbliver eksisterende
# kombineret evaluation+render for build_fallback_analysis-vejen.
#
# Returnerer list:
#   target_relation: "met" | "near" | "not_met" | "none"
#   goal_met:        logical (direction-aware grene)
#   at_target:       logical (value-neutral gren)
#   near_target:     logical (tolerance-cascade for begge grene)
.evaluate_target_relation <- function(context, flags) {
  result <- list(
    target_relation = "none",
    goal_met = FALSE,
    at_target = FALSE,
    near_target = FALSE
  )
  if (!isTRUE(flags$has_target)) {
    return(result)
  }

  target_value <- context$target_value
  target_direction <- context$target_direction
  centerline <- context$centerline
  sigma_hat <- context$sigma_hat
  sigma_data <- context$sigma_data
  delta <- abs(centerline - target_value)

  if (!is.null(target_direction)) {
    # Direction-aware: strict goal_met > near_target > goal_not_met.
    result$goal_met <- switch(target_direction,
      "higher" = centerline >= target_value,
      "lower"  = centerline <= target_value,
      FALSE
    )
    if (!result$goal_met) {
      result$near_target <- .within_sigma_tolerance(delta, sigma_hat, sigma_data)
    }
    result$target_relation <- if (result$goal_met) {
      "met"
    } else if (result$near_target) {
      "near"
    } else {
      "not_met"
    }
  } else {
    # Value-neutral: at_target/over/under med sigma-cascade.
    result$at_target <- .within_sigma_tolerance(delta, sigma_hat, sigma_data,
      sigma_multiplier_hat = 3
    )
    result$target_relation <- if (result$at_target) "met" else "not_met"
    # ej near_target i value-neutral gren (eksisterende semantik)
  }

  result
}


# Sigma-tolerance-cascade matcher .evaluate_target_arm():
#   1. sigma_hat > 0 finite: delta <= sigma_multiplier_hat * sigma_hat
#   2. sigma_data > 0 finite: delta <= sigma_data
#   3. ellers: delta < 1e-9 (eksakt match)
.within_sigma_tolerance <- function(delta, sigma_hat, sigma_data,
                                    sigma_multiplier_hat = 3) {
  if (is_valid_scalar(sigma_hat) && is.finite(sigma_hat) && sigma_hat > 0) {
    return(delta <= sigma_multiplier_hat * sigma_hat)
  }
  if (is_valid_scalar(sigma_data) && is.finite(sigma_data) && sigma_data > 0) {
    return(delta <= sigma_data)
  }
  delta < 1e-9
}


# ---------------------------------------------------------------------------
# Confidence-tier (chart-type-aware, spec ADDED requirement)
# ---------------------------------------------------------------------------

# Returnerer "low" | "medium" | "high".
#
# Run-charts har sigma_hat = NA by design (ingen kontrolgraenser).
# is.na(sigma_hat) alene SKAL IKKE udloese "low" -- det ville fejlmarkere
# valide run-charts. Vi tjekker for "any finite spread-estimate"
# (sigma_hat eller sigma_data finite + > 0).
.compute_confidence_tier <- function(context, x) {
  n_points <- context$n_points
  centerline <- context$centerline
  sigma_hat <- context$sigma_hat
  sigma_data <- context$sigma_data

  has_centerline <- is_valid_scalar(centerline) && is.finite(centerline)
  has_spread <- (is_valid_scalar(sigma_hat) && is.finite(sigma_hat) && sigma_hat > 0) ||
    (is_valid_scalar(sigma_data) && is.finite(sigma_data) && sigma_data > 0)

  # "low" hvis n < N_MIN OR ingen centerline OR ingen spread-estimat.
  if (is.null(n_points) || is.na(n_points) || n_points < N_MIN ||
    !has_centerline || !has_spread) {
    return("low")
  }
  if (n_points >= 20L) {
    return("high")
  }
  "medium"
}


# Cycle 05 finding #5 fix: low_confidence_reason-akse.
# Returnerer primaer aarsag til low-confidence:
#   "few_obs"       -- n < N_MIN
#   "no_centerline" -- centerline NA/non-finite
#   "no_spread"     -- baade sigma_hat og sigma_data NA/zero
#   NA_character_   -- confidence_tier != "low"
#
# Prioritets-raekkefoelge: few_obs > no_centerline > no_spread. Naar
# flere aarsager findes vinder den foerste (sandsynligvis dominerende
# klinisk-fortolkning). Render-lag dispatcher template-variant paa
# reason saa not_evaluable-prose matcher faktisk aarsag.
.compute_low_confidence_reason <- function(context) {
  n_points <- context$n_points
  centerline <- context$centerline
  sigma_hat <- context$sigma_hat
  sigma_data <- context$sigma_data

  if (is.null(n_points) || is.na(n_points) || n_points < N_MIN) {
    return("few_obs")
  }
  has_centerline <- is_valid_scalar(centerline) && is.finite(centerline)
  if (!has_centerline) {
    return("no_centerline")
  }
  has_spread <- (is_valid_scalar(sigma_hat) && is.finite(sigma_hat) && sigma_hat > 0) ||
    (is_valid_scalar(sigma_data) && is.finite(sigma_data) && sigma_data > 0)
  if (!has_spread) {
    return("no_spread")
  }
  NA_character_
}


# ---------------------------------------------------------------------------
# Phase-context (single vs multi vs post_intervention)
# ---------------------------------------------------------------------------

# Returnerer "single" hvis kun 1 part i x$summary, ellers "multi".
# "post_intervention" reserveres til Slice 5 (baseline-delta) hvor
# semantik er rigere end blot "multi".
.resolve_phase_context <- function(x, baseline_centerline = NULL) {
  if (is.null(x$summary) || !"fase" %in% names(x$summary)) {
    return("single")
  }
  n_phases <- length(unique(stats::na.omit(x$summary$fase)))
  # Slice 5 INCLUDE: multi-phase med detekterbar baseline tagged som
  # post_intervention (driver baseline-delta-modifier rendering).
  if (n_phases <= 1L) {
    return("single")
  }
  if (is.null(baseline_centerline)) {
    baseline_centerline <- .extract_baseline_centerline(x)
  }
  if (!is.null(baseline_centerline) && !is.na(baseline_centerline)) {
    return("post_intervention")
  }
  "multi"
}


# ---------------------------------------------------------------------------
# CL-source (Slice 9 INCLUDE)
# ---------------------------------------------------------------------------

# Returnerer "data_estimated" | "user_supplied" | "auto_mean".
.resolve_cl_source <- function(spc_stats) {
  if (isTRUE(spc_stats$cl_user_supplied)) {
    return("user_supplied")
  }
  if (isTRUE(spc_stats$cl_auto_mean)) {
    return("auto_mean")
  }
  "data_estimated"
}


# ---------------------------------------------------------------------------
# Direction-akse (Slice 4 INCLUDE)
# ---------------------------------------------------------------------------

# Returnerer "favorable" | "unfavorable" | "neutral" | "unknown".
# Aktiveres af Slice 4-detection i Phase 3. For Phase 1 returnerer vi
# "unknown" som default; metadata$direction-override respekteres dog
# allerede her saa Phase 1 caller kan teste mekanismen.
.resolve_direction <- function(context, metadata) {
  # Slice 4 INCLUDE: direction-aware vurdering uden target.
  # metadata$direction kan vaere "higher_better", "lower_better",
  # eller "neutral". Resulterende features$direction afhaenger af:
  #   - metadata$direction sat: kraever baseline_centerline (part>=2) for
  #     at vurdere favorable vs unfavorable via delta-sign.
  #   - metadata$direction missing: returnerer "unknown".
  #   - metadata$direction == "neutral": returnerer "neutral".
  # Direction-vurdering for single-phase data er for ambitios (kraever
  # changepoint-detection, Slice 12 DEFER). Single-phase + meta-direction
  # returnerer "neutral".

  meta_dir <- metadata$direction %||% NULL
  if (is.null(meta_dir)) {
    return("unknown")
  }
  if (identical(meta_dir, "neutral")) {
    return("neutral")
  }
  if (!meta_dir %in% c("higher_better", "lower_better")) {
    return("unknown")
  }

  # Kraever baseline-CL for delta-baseret vurdering
  baseline <- .extract_baseline_centerline_from_context(context)
  if (is.null(baseline) || is.na(baseline) ||
    !is_valid_scalar(context$centerline)) {
    return("neutral") # metadata-direction sat men single-phase data
  }

  delta <- context$centerline - baseline
  if (abs(delta) < 1e-9) {
    return("neutral")
  }

  # Favorable: data bevaeger sig mod oensket retning
  is_favorable <- (identical(meta_dir, "higher_better") && delta > 0) ||
    (identical(meta_dir, "lower_better") && delta < 0)
  if (is_favorable) "favorable" else "unfavorable"
}


# Helper: baseline-CL er ej i context-objektet -- skal hentes fra x$summary.
# bfh_extract_spc_features-caller har x i scope; .resolve_direction har ej.
# Vi udnytter dog at context er bygget fra x og baseline er beregnet i
# .extract_baseline_centerline(x). For Slice 4 lader vi caller injicere
# baseline via context-attribut (sat i bfh_extract_spc_features).
.extract_baseline_centerline_from_context <- function(context) {
  attr(context, "baseline_centerline", exact = TRUE)
}


# ---------------------------------------------------------------------------
# Chart-class-akse (SKIP-akse, kun NA-default eller minimal mapping)
# ---------------------------------------------------------------------------

# Mapper chart_type til chart_class. Slice 6 SKIP betyder ej brugt til
# prose-modifikatorer, men aksen lagres for schema-stabilitet.
#
# Cycle 05 finding #6 fix: xbar/s mappes til "subgrouped" (ej
# individuals). Klasserne reflekterer hvordan sigma/CL beregnes:
#   individuals  = i/mr (single obs per time)
#   subgrouped   = xbar/s (mean/sd af subgroup ved hvert time-point)
# Variable_cl-detection gating bruger "subgrouped" som indikator for
# varying-n CL.
.resolve_chart_class <- function(chart_type) {
  if (is.null(chart_type) || is.na(chart_type)) {
    return(NA_character_)
  }
  switch(chart_type,
    "run" = "run",
    "i" = "individuals",
    "mr" = "individuals",
    "p" = "proportion",
    "pp" = "proportion",
    "u" = "rate",
    "up" = "rate",
    "c" = "count",
    "g" = "rare_events",
    "t" = "rare_events",
    "xbar" = "subgrouped",
    "s" = "subgrouped",
    NA_character_
  )
}


# ---------------------------------------------------------------------------
# Variable-CL detection (Slice 7 INCLUDE)
# ---------------------------------------------------------------------------

# Returnerer TRUE hvis kontrolgraense-bredden (UCL-LCL) varierer
# vaesentligt over tid -- typisk pga svingende stikproevestoerrelse
# i p/u/xbar-charts. Threshold er coefficient-of-variation > 10%
# (sd(range) / abs(mean(range))). Run-charts har ingen UCL/LCL og
# returnerer FALSE.
#
# Cycle 05 finding #1 fix: chart-class-gate.
# Variable CL caveat-tekst siger eksplicit "svingende stikproeve-
# stoerrelse" -- gaelder kun subgrouped chart-classes (proportion,
# rate, subgrouped-mean). Paa i-charts med phase-split (part=2) er
# CL-variation drevet af phase, ej n -- den signal-type haandteres
# af baseline-delta-modifier (Slice 5), ej variable_cl-caveat.
# Gating fjerner klinisk-misvisende caveat fra i/mr/run/c/g/t-charts.
.detect_variable_cl <- function(x, chart_class = NULL) {
  # Gate: variable_cl caveat-prose forudsaetter subgrouped chart-class.
  # NA chart_class (uventet) -> FALSE for safety.
  subgrouped <- c("proportion", "rate", "subgrouped")
  if (!is_valid_scalar(chart_class) || !chart_class %in% subgrouped) {
    return(FALSE)
  }
  qd <- x$qic_data
  if (is.null(qd) || !all(c("ucl", "lcl") %in% names(qd))) {
    return(FALSE)
  }
  range_w <- qd$ucl - qd$lcl
  range_w <- range_w[!is.na(range_w) & is.finite(range_w)]
  if (length(range_w) < 2L) {
    return(FALSE)
  }
  mean_w <- mean(range_w)
  if (!is.finite(mean_w) || abs(mean_w) < 1e-9) {
    return(FALSE)
  }
  cv <- stats::sd(range_w) / abs(mean_w)
  isTRUE(is.finite(cv) && cv > 0.10)
}


# ---------------------------------------------------------------------------
# Discrete-scale tier (Slice 14 INCLUDE)
# ---------------------------------------------------------------------------

# Mapper n_on_cl_ratio (andel af obs eksakt paa centerlinje) til 4-tier:
#  none:     ratio < 0.20 -- normal proces-spredning
#  mild:     ratio in [0.20, 0.35) -- nogen koncentration paa CL
#  moderate: ratio in [0.35, 0.50) -- udtalt koncentration
#  extreme:  ratio >= 0.50 -- majority_at_centerline-override aktiv,
#            haandteres af stability_pattern == "majority_at_centerline"
#
# Tier "extreme" matcher eksisterende majority_at_cl-detektion -- den
# stability_pattern-override haandterer prose-rendering. mild/moderate
# bidrager via tail-caveat. "none" producerer ingen caveat.
DISCRETE_SCALE_THRESHOLDS <- c(0.20, 0.35, 0.50)
DISCRETE_SCALE_TIERS <- c("none", "mild", "moderate", "extreme")

.resolve_discrete_scale_tier <- function(n_on_cl_ratio) {
  if (!is_valid_scalar(n_on_cl_ratio) || !is.finite(n_on_cl_ratio)) {
    return("none")
  }
  # findInterval(x, [t1, t2, t3]) -> 0 (x<t1), 1 (t1<=x<t2), 2, 3 (x>=t3)
  DISCRETE_SCALE_TIERS[[findInterval(n_on_cl_ratio, DISCRETE_SCALE_THRESHOLDS) + 1L]]
}


# ---------------------------------------------------------------------------
# Outlier-history-akse (DEFER -- bevares for schema-stabilitet)
# ---------------------------------------------------------------------------

# Returnerer "current_only" | "historic_only" | "both" | "none".
# Slice 11 DEFER betyder ej brugt til prose, men aksen lagres.
.resolve_outlier_history <- function(spc_stats) {
  current <- spc_stats$outliers_recent_count %||% NA_integer_
  total <- spc_stats$outliers_actual %||% NA_integer_

  if (is.na(current) || is.na(total)) {
    return(NA_character_)
  }
  historic <- total - current

  if (current > 0L && historic > 0L) {
    return("both")
  }
  if (current > 0L && historic == 0L) {
    return("current_only")
  }
  if (current == 0L && historic > 0L) {
    return("historic_only")
  }
  "none"
}


# ---------------------------------------------------------------------------
# Aux helpers (latest_obs_date, baseline_*)
# ---------------------------------------------------------------------------

# Ekstraherer seneste observation-dato fra x$qic_data hvis x-kolonne er
# Date eller POSIXct. Returnerer NA_Date_ ellers.
.extract_latest_obs_date <- function(x) {
  qd <- x$qic_data
  if (is.null(qd) || !"x" %in% names(qd) || nrow(qd) == 0L) {
    return(as.Date(NA))
  }
  xv <- qd$x
  if (inherits(xv, "Date")) {
    return(max(xv, na.rm = TRUE))
  }
  if (inherits(xv, c("POSIXct", "POSIXlt"))) {
    return(as.Date(max(xv, na.rm = TRUE)))
  }
  as.Date(NA)
}


# Baseline-centerline = centerline fra forrige (ej-sidste) fase i
# x$summary. NA hvis kun en fase. Bruges af Slice 5 baseline-delta.
.extract_baseline_centerline <- function(x) {
  if (is.null(x$summary) || !"centerlinje" %in% names(x$summary) ||
    nrow(x$summary) < 2L) {
    return(NA_real_)
  }
  x$summary$centerlinje[nrow(x$summary) - 1L]
}


# Slice 3 INCLUDE: Magnitude-bucket via sigma-shift-ratio.
# Returnerer "small" | "medium" | "large" | NA_character_.
#   small:  |delta|/sigma < 1.0
#   medium: 1.0 <= |delta|/sigma < 2.0
#   large:  |delta|/sigma >= 2.0
# Sigma-prioritet: sigma_hat (control-limits-based) > sigma_data (sd(y)).
# Returnerer NA naar baseline_delta mangler eller alle sigma-estimater
# er NA/zero.
#
# Cycle 04 H2 fix: ratio-cap. Microscopic sigma (~1e-12) fra near-constant
# data combineret med float-noise baseline-delta kan producere
# astronomical ratios. ratio > MAGNITUDE_RATIO_CAP returnerer NA som
# safety-net (saa magnitude-modifier ej rapporterer falsk "large"
# klassifikation paa support af noisy sigma-estimat). Cap = 100 svarer
# til 100 sigma-shifts -- empirisk usandsynligt klinisk-meaningful,
# klart-ufysisk for kontrolgraense-baseret SPC.
.compute_magnitude <- function(baseline_delta, sigma_hat, sigma_data) {
  if (is.null(baseline_delta) || is.na(baseline_delta) ||
    abs(baseline_delta) < 1e-9) {
    return(NA_character_)
  }
  sigma <- if (is_valid_scalar(sigma_hat) && is.finite(sigma_hat) && sigma_hat > 0) {
    sigma_hat
  } else if (is_valid_scalar(sigma_data) && is.finite(sigma_data) && sigma_data > 0) {
    sigma_data
  } else {
    return(NA_character_)
  }
  ratio <- abs(baseline_delta) / sigma
  if (!is.finite(ratio) || ratio > MAGNITUDE_RATIO_CAP) {
    return(NA_character_)
  }
  if (ratio < 1.0) {
    "small"
  } else if (ratio < 2.0) {
    "medium"
  } else {
    "large"
  }
}


# ---------------------------------------------------------------------------
# Render_context helpers
# ---------------------------------------------------------------------------

# DEPRECATED: kept for backward-compat. Centerline-formatering flyttet til
# render-time i bfh_render_analysis (cycle 04 H1 fix). Aux har raw-vaerdi;
# render-lag formaters med analysis$language.
.format_centerline_for_render <- function(context) {
  ""
}


# Traekker operator-Unicode-tegn ud af target_display hvis stede.
# Returnerer "" hvis ingen operator.
#
# CASCADE-RAEKKEFOELGE ER LOAD-BEARING: ">=" og "<=" SKAL tjekkes foer
# ">" og "<" -- en streng som ">= 90" matcher baade ">" og ">=" via
# grepl(fixed=TRUE), saa skal-tjek-tilstand. Reorder ikke uden test-cover.
.extract_operator_unicode <- function(target_display) {
  if (is.null(target_display) || !nzchar(target_display)) {
    return("")
  }
  td <- target_display
  if (grepl("\U2265", td, fixed = TRUE)) {
    return("\U2265")
  }
  if (grepl("\U2264", td, fixed = TRUE)) {
    return("\U2264")
  }
  if (grepl(">=", td, fixed = TRUE)) {
    return("\U2265")
  }
  if (grepl("<=", td, fixed = TRUE)) {
    return("\U2264")
  }
  if (grepl(">", td, fixed = TRUE)) {
    return(">")
  }
  if (grepl("<", td, fixed = TRUE)) {
    return("<")
  }
  ""
}


# Returnerer "singular" eller "plural" baseret paa outliers-count.
# Render-lag mapper noegle til labels.outliers.singular / .plural.
.resolve_outliers_word_key <- function(few_obs, outliers_actual, outliers_recent) {
  n <- outliers_recent %||% outliers_actual %||% 0L
  if (is.na(n)) n <- 0L
  if (n == 1L) "singular" else "plural"
}
