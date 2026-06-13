# Signal Detection and Text-Budget Functions
#
# Internal helpers for SPC signal detection (Anhoej rules), text-budget
# allocation, and i18n key selection for the fallback analysis pipeline.
# Used by spc_analysis.R (orchestration), spc_features.R, spc_compose.R,
# and spc_render.R.


# Detect SPC signal flags from a context object.
#
# Returnerer named list med:
#   has_runs, has_crossings, has_outliers (logical)
#   is_stable                              (logical, derived: ingen signaler)
#   no_variation                          (logical, derived: alle signal-stats NA)
#   has_target                            (logical, derived: target_value + centerline gyldige)
#   outliers_for_text                     (numeric, til pluralize_da + placeholder)
#
# Pure: samme input -> samme output. Driver cascade-dispatch og budget-
# allokering uden at flade detection-logikken sammen med i18n-opslag.
# Atomic Anhoej-signal-detectors. Shared mellem .detect_signal_flags()
# (feature-extraction) og AI-path has_signals (LLM-egress gate). Holder
# semantik konsistent paa tvaers af call-sites -- ej re-implement risiko
# (cycle 05 finding #4: tidligere drift mellem stability_pattern og
# AI-signal-set).
.has_runs_signal <- function(runs_actual, runs_expected) {
  is_valid_scalar(runs_actual) && is_valid_scalar(runs_expected) &&
    runs_actual > runs_expected
}

.has_crossings_signal <- function(crossings_actual, crossings_expected) {
  is_valid_scalar(crossings_actual) && is_valid_scalar(crossings_expected) &&
    crossings_actual < crossings_expected
}

.has_outliers_signal <- function(outliers_recent_count, outliers_actual) {
  # Brug recent_count (seneste 6 obs) saa analyseteksten kun beskriver AKTUELLE
  # outliers. Fald tilbage til outliers_actual naar kun summary-baserede stats
  # er tilgaengelige.
  outliers_for_text <- outliers_recent_count %||% outliers_actual
  is_valid_scalar(outliers_for_text) && outliers_for_text > 0
}


.detect_signal_flags <- function(context) {
  spc_stats <- context$spc_stats
  target_value <- context$target_value
  centerline <- context$centerline

  has_runs <- .has_runs_signal(spc_stats$runs_actual, spc_stats$runs_expected)
  has_crossings <- .has_crossings_signal(
    spc_stats$crossings_actual, spc_stats$crossings_expected
  )
  outliers_for_text <- spc_stats$outliers_recent_count %||% spc_stats$outliers_actual
  has_outliers <- .has_outliers_signal(
    spc_stats$outliers_recent_count, spc_stats$outliers_actual
  )

  is_stable <- !has_runs && !has_crossings && !has_outliers

  runs_missing <- is.null(spc_stats$runs_actual) ||
    length(spc_stats$runs_actual) == 0 ||
    is.na(spc_stats$runs_actual)
  crossings_missing <- is.null(spc_stats$crossings_actual) ||
    length(spc_stats$crossings_actual) == 0 ||
    is.na(spc_stats$crossings_actual)
  no_variation <- runs_missing && crossings_missing

  # majority_at_cl: >= 50% af datapunkter ligger eksakt paa centerlinjen
  # (uden at alle er identiske -- no_variation har fortrinsret). Flag'er
  # typisk grov maaleskala eller diskret rapportering der forringer SPC-
  # tolkning. Eksakt-match (1e-9) per spec; ingen sigma-relativ tolerance.
  n_on_cl_ratio <- context$n_on_cl_ratio
  majority_at_cl <- !no_variation &&
    is_valid_scalar(n_on_cl_ratio) && is.finite(n_on_cl_ratio) &&
    n_on_cl_ratio >= 0.5

  # auto_mean_unstable: bfh_qic() auto-skiftede CL fra median til
  # gennemsnit (>= 50% af punkterne laa paa medianen), men processen
  # viser stadig signaler efter skiftet. SPC-tolkningen er forringet:
  # signalerne kan vaere artefakter af skiftet eller af den diskrete
  # maaleskala der udloeste skiftet. Render-lag erstatter stability-base
  # med en warning-tekst i samme toneleje som majority_at_centerline.
  #
  # Prioritet: no_variation > majority_at_cl > auto_mean_unstable.
  # no_variation og majority_at_cl er mere specifikke beskrivelser af
  # det underliggende data-problem; auto_mean_unstable er en bredere
  # "SPC fungerer ikke godt her"-warning.
  cl_auto_mean <- isTRUE(spc_stats$cl_auto_mean)
  auto_mean_unstable <- cl_auto_mean && !is_stable &&
    !no_variation && !majority_at_cl

  has_target <- !is.null(target_value) && !is.na(target_value) &&
    is.numeric(target_value) &&
    !is.null(centerline) && !is.na(centerline)

  list(
    has_runs = has_runs,
    has_crossings = has_crossings,
    has_outliers = has_outliers,
    is_stable = is_stable,
    no_variation = no_variation,
    majority_at_cl = majority_at_cl,
    auto_mean_unstable = auto_mean_unstable,
    has_target = has_target,
    outliers_for_text = outliers_for_text
  )
}


# Allokerer tegnbudget til stability/target/action dele af fallback-analysen.
#
# Med target: stability ~45%, target ~20%, action ~35%.
# Uden target: target-budgettet realloceres til stability (55%) + action (45%).
#
# Target-armen har differentierede short/standard/detailed-varianter (40-130
# tegn raa template-laengde) og kraever ~20% for at standard/detailed kan
# vinde over short-fallback. Stability-armen har mellem-lange detailed-
# varianter (129-334 tegn) og taeller derfor 45%. Action-armens detailed-
# varianter (90-176 tegn) faar de resterende 35%. Ratio 45/20/35 valgt efter
# brug af differentierede target-varianter -- giver 0 overflow og maksimerer
# antal detailed-valg under denne YAML-tekst-fordeling.
#
# Returnerer named integer list: stability_budget, target_budget, action_budget.
.allocate_text_budget <- function(max_chars, has_target) {
  if (has_target) {
    stability_budget <- floor(max_chars * 0.45)
    target_budget <- floor(max_chars * 0.20)
    action_budget <- max_chars - stability_budget - target_budget
  } else {
    stability_budget <- floor(max_chars * 0.55)
    target_budget <- 0L
    action_budget <- max_chars - stability_budget
  }
  list(
    stability_budget = stability_budget,
    target_budget = target_budget,
    action_budget = action_budget
  )
}


# Vaelg i18n-noegle til stabilitets-arm af fallback-analysen.
#
# Pure dispatch: tager named-logical flags (has_runs, has_crossings,
# has_outliers) og returnerer character scalar, der refererer til
# `texts$stability[[key]]` i sprog-YAML'en. Caller haandterer
# no_variation-grenen separat (den bruger sin egen no_variation key
# med centerline-placeholder).
#
# Mulige returvaerdier: "no_signals", "runs_only", "crossings_only",
# "outliers_only", "runs_crossings", "runs_outliers",
# "crossings_outliers", "all_signals".
.select_stability_key <- function(flags) {
  if (!flags$has_runs && !flags$has_crossings && !flags$has_outliers) {
    "no_signals"
  } else if (flags$has_runs && !flags$has_crossings && !flags$has_outliers) {
    "runs_only"
  } else if (!flags$has_runs && flags$has_crossings && !flags$has_outliers) {
    "crossings_only"
  } else if (!flags$has_runs && !flags$has_crossings && flags$has_outliers) {
    "outliers_only"
  } else if (flags$has_runs && flags$has_crossings && !flags$has_outliers) {
    "runs_crossings"
  } else if (flags$has_runs && !flags$has_crossings && flags$has_outliers) {
    "runs_outliers"
  } else if (!flags$has_runs && flags$has_crossings && flags$has_outliers) {
    "crossings_outliers"
  } else {
    "all_signals"
  }
}


# Vaelg i18n-noegle til handlings-arm af fallback-analysen.
#
# Pure dispatch: tager flags + target-evaluation og returnerer character
# scalar key til `texts$action[[key]]`. Tre dispatch-veje:
#
#   1. has_target + target_direction (fra fx "<= 2,5"): retningsbevidst
#      cascade -> "stable_goal_met", "stable_goal_not_met",
#      "unstable_goal_met", "unstable_goal_not_met"
#   2. has_target uden target_direction: vaerdineutral cascade ->
#      "stable_at_target", "stable_not_at_target", "unstable_at_target",
#      "unstable_not_at_target"
#   3. !has_target: simple cascade -> "stable_no_target",
#      "unstable_no_target"
#
# goal_met, at_target og near_target er evalueret af caller; helper er pure
# dispatch. Prioritet i direction-aware gren: goal_met > near_target >
# goal_not_met.
.select_action_key <- function(flags, target_direction, goal_met, at_target,
                               near_target = FALSE) {
  is_stable <- flags$is_stable
  has_target <- flags$has_target

  # auto_mean_unstable overrider standard cascade: action-armen skal
  # tale om at forbedre maaleskalaen i stedet for "stabiliser processen"
  # (sidstnaevnte modsiger stability-tekstens "SPC ikke velegnet"-
  # konklusion). To varianter afhaengigt af target-relation:
  #   - goal_met / at_target / near_target -> goal_met-variant
  #     ("bevar praksis, men forbedr maaleskalaen")
  #   - alle andre (inkl. no_target) -> goal_not_met-variant
  #     ("foer indsats besluttes, forbedr maaleskalaen")
  if (isTRUE(flags$auto_mean_unstable)) {
    if (isTRUE(goal_met) || isTRUE(at_target) || isTRUE(near_target)) {
      return("auto_mean_unstable_goal_met")
    }
    return("auto_mean_unstable_goal_not_met")
  }

  if (has_target && !is.null(target_direction)) {
    if (is_stable && goal_met) {
      "stable_goal_met"
    } else if (is_stable && near_target) {
      "stable_near_target"
    } else if (is_stable && !goal_met) {
      "stable_goal_not_met"
    } else if (!is_stable && goal_met) {
      "unstable_goal_met"
    } else if (!is_stable && near_target) {
      "unstable_near_target"
    } else {
      "unstable_goal_not_met"
    }
  } else if (has_target) {
    if (is_stable && at_target) {
      "stable_at_target"
    } else if (is_stable && !at_target) {
      "stable_not_at_target"
    } else if (!is_stable && at_target) {
      "unstable_at_target"
    } else {
      "unstable_not_at_target"
    }
  } else {
    if (is_stable) "stable_no_target" else "unstable_no_target"
  }
}
