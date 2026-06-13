# Target Utilities and Value Formatting Helpers
#
# Internal helpers for target resolution, operator normalisation, percent
# scale normalisation, and target value formatting. Used by analysis_core.R
# (orchestration), spc_render.R, spc_features.R, and utils_export_helpers.R.


# Konverter ASCII-operatorer (>=, <=) til Unicode-sammentrukne tegn
# (\U2265, \U2264) i target-display-strenge til klinisk prose-rendering.
# Bruges af spc_render.R (struktureret pipeline). Holder operator-mappingen
# i en enkelt autoritativ kilde.
.normalize_target_operators <- function(x) {
  if (is.null(x) || !nzchar(x)) {
    return(x)
  }
  x <- gsub(">=", "\U2265", x, fixed = TRUE)
  gsub("<=", "\U2264", x, fixed = TRUE)
}

# Compute target-relativ position af centerlinje som i18n-key-triplet.
# Returnerer list(direction_key, vs_target_key) hvor begge er strenge
# "at" | "over" | "under" -- eller NULL hvis target ej sat. Caller
# resolverer keys via i18n_lookup(paste0("labels.level_*.", key)).
#
# Shared helper for spc_render.R (.compute_level_direction +
# .compute_level_vs_target).
.compute_level_keys <- function(centerline, target_value, has_target,
                                y_axis_unit = NULL) {
  if (!isTRUE(has_target) || !is_valid_scalar(centerline) ||
    !is_valid_scalar(target_value)) {
    return(NULL)
  }
  # Percent-units: "at" naar CL og target afrunder til samme chart-display
  # vaerdi (fx CL=0.0103 og target=0.01 begge vises som "1%"/"1,0%").
  # Matcher hvad laeseren ser, ikke ren numerisk lighed.
  is_at <- if (identical(y_axis_unit, "percent")) {
    .cl_displays_at_target_pct(centerline, target_value)
  } else {
    abs(centerline - target_value) < 1e-9
  }
  pos <- if (isTRUE(is_at)) {
    "at"
  } else if (centerline > target_value) {
    "over"
  } else {
    "under"
  }
  list(direction_key = pos, vs_target_key = pos)
}

# Tjek om CL og target afrunder til samme chart-display-vaerdi paa
# procent-skala. Matcher format_percent_contextual() i utils_label_formatting.R:
#   - CL vises med 1 decimal hvis |CL - target| <= NEAR_TARGET_DISPLAY_THRESHOLD,
#     ellers hele procent.
#   - Target vises altid med hele procent (target alene har ikke et "target"-
#     reference for kontekstuel praecision).
# Returnerer TRUE naar de to display-strenge repraesenterer samme tal.
#
# Brugt af .compute_level_keys() til at flippe
# "lige over" -> "paa maalet"/"goal_met" naar visuel lighed gaelder.
.cl_displays_at_target_pct <- function(centerline, target_value) {
  if (!is_valid_scalar(centerline) || !is_valid_scalar(target_value)) {
    return(FALSE)
  }
  delta <- abs(centerline - target_value)
  target_pct_whole <- round(target_value * 100)
  if (delta <= NEAR_TARGET_DISPLAY_THRESHOLD) {
    # CL vises med 1 decimal; sammenlign mod target's hele procent.
    cl_pct_show <- round(centerline * 100, 1)
    return(isTRUE(cl_pct_show == target_pct_whole))
  }
  cl_pct_whole <- round(centerline * 100)
  isTRUE(cl_pct_whole == target_pct_whole)
}

# Resolve target for analysis context via fallback chain.
#
# Order of precedence:
#   1. metadata$target  (explicit caller-provided override)
#   2. config$target_text  (string from bfh_qic(target_text = ">= 90%"))
#   3. config$target_value (numeric from bfh_qic(target_value = 0.9))
#   4. NULL (no target)
#
# Returns raw target input (numeric or character). resolve_target()
# handles downstream operator parsing and percent normalisation.
.resolve_analysis_target <- function(metadata, config) {
  if (!is.null(metadata) && !is.null(metadata$target)) {
    return(metadata$target)
  }
  if (!is.null(config)) {
    if (!is.null(config$target_text) && length(config$target_text) > 0 &&
      nzchar(trimws(as.character(config$target_text)))) {
      return(config$target_text)
    }
    if (!is.null(config$target_value)) {
      return(config$target_value)
    }
  }
  NULL
}


# Parse metadata$target til numerisk vaerdi + optional retning.
# Genbruger parse_target_input() fra utils_label_helpers.R for at undgaa
# duplikeret parser-logik. Returnerer altid en liste med value/direction/display.
#
# Direction-mapping:
#   >=, >=, up  -> "higher" (higher is better)
#   <=, <=, down  -> "lower"  (lower is better)
#   >, <      -> "higher" / "lower" (naar efterfulgt af tal)
#   ingen op. -> NULL (vaerdineutral)
resolve_target <- function(target_input) {
  empty <- list(value = NA_real_, direction = NULL, display = "")
  if (is.null(target_input)) {
    return(empty)
  }

  # Numerisk input: bagudkompatibelt - ingen retning
  if (is.numeric(target_input)) {
    return(list(value = as.numeric(target_input), direction = NULL, display = ""))
  }

  if (!is.character(target_input) || length(target_input) == 0 ||
    nchar(trimws(target_input)) == 0) {
    return(empty)
  }

  # Normaliser Unicode-operatorer til ASCII foer parsing, saa parse_target_input()
  # (der er testet mod ASCII-input fra chart-labels) kan genbruges uaendret.
  # <= -> <=, >= -> >=, up -> >, down -> <
  normalized <- target_input
  normalized <- gsub("\U2264", "<=", normalized)
  normalized <- gsub("\U2265", ">=", normalized)
  normalized <- gsub("\U2191", ">", normalized)
  normalized <- gsub("\U2193", "<", normalized)

  parsed <- parse_target_input(normalized)

  direction <- switch(parsed$operator,
    "\U2265" = "higher",
    "\U2191" = "higher",
    ">"      = "higher",
    "\U2264" = "lower",
    "\U2193" = "lower",
    "<"      = "lower",
    NULL
  )

  # Ekstraher numerisk vaerdi fra value-delen.
  # Accepterer baade dansk komma og engelsk punktum som decimaltegn.
  raw_value <- parsed$value
  clean <- gsub(",", ".", raw_value)
  clean <- gsub("[^0-9.\\-]", "", clean)
  val <- suppressWarnings(as.numeric(clean))
  if (length(val) == 0) val <- NA_real_

  list(value = val, direction = direction, display = target_input)
}


#' Normalize percent target to proportion scale
#'
#' Internal helper. When `y_axis_unit` is `"percent"` and the target appears
#' to be expressed on the 0-100 scale (either because `display` contains a
#' literal `"%"` character, or because `value > 1.5` for a numeric-only input),
#' the value is divided by 100 so downstream comparisons work on the same
#' 0-1 proportion scale as the centerline.
#'
#' `target_display` is intentionally **not** modified -- user-facing text
#' continues to show `">= 90%"` rather than `">= 0.90"`.
#'
#' **Heuristic:**
#' Normalize when `y_axis_unit == "percent"` AND
#'   (`grepl("%", display)` OR `value > 1.5`)
#' Preserve otherwise (proportion already correct, or stretch-target on
#' proportion scale, or non-percent chart). The 1.5 threshold matches
#' `validate_target_for_unit()`'s upper bound for `multiply = 1`, so
#' legitimate stretch-targets like 1.05 (=105% on proportion scale) are
#' preserved instead of being misclassified as percent-scale input.
#'
#' @param value Numeric target value as parsed by `resolve_target()`.
#' @param display Character display string (may be empty `""` for numeric input).
#' @param y_axis_unit Character y-axis unit (`"percent"`, `"count"`, `"rate"`, etc.).
#'
#' @return Numeric: `value / 100` when normalization applies, `value` otherwise.
#'
#' @examples
#' # Percent target expressed as 0-100 (normaliseres)
#' BFHcharts:::.normalize_percent_target(90, ">= 90%", "percent") # 0.90
#'
#' # Numerisk input >= 1 paa percent-chart (normaliseres)
#' BFHcharts:::.normalize_percent_target(90, "", "percent") # 0.90
#'
#' # Allerede paa proportionsskala (bevares)
#' BFHcharts:::.normalize_percent_target(0.9, "", "percent") # 0.9
#'
#' # Ingen % i display og value <= 1: power-user proportion-override (bevares)
#' BFHcharts:::.normalize_percent_target(0.9, ">= 0.9", "percent") # 0.9
#'
#' # Ikke et percent-diagram: altid uaendret
#' BFHcharts:::.normalize_percent_target(90, ">= 90", "count") # 90
#'
#' @keywords internal
#' @noRd
.normalize_percent_target <- function(value, display, y_axis_unit) {
  if (is.null(y_axis_unit) || !identical(y_axis_unit, "percent")) {
    return(value)
  }
  if (is.na(value) || !is.numeric(value)) {
    return(value)
  }
  # Normalise when display contains "%" OR value > 1.5
  # (OR heuristic covers both string input and numeric input on a 0-100 scale)
  #
  # Threshold rationale: validate_target_for_unit() allows target_value up to
  # multiply * 1.5 = 1.5 (default multiply=1) for percent charts, supporting
  # legitimate stretch-targets > 100% on the proportion scale. The previous
  # threshold (value > 1) misclassified such stretch-targets (1.0, 1.5] as
  # 0-100 input and divided by 100, producing wrong narrative text in
  # bfh_generate_analysis(). 1.5 is the validator's max bound -- values above
  # are unambiguously 0-100 input that needs normalising.
  should_normalize <- isTRUE(grepl("%", display, fixed = TRUE)) || isTRUE(value > 1.5)
  if (should_normalize) value / 100 else value
}


# Formater maalvaerdi til visning
# Delegates to format_y_value() for chart-label/analysis-text consistency
# (fixes #426: two formatting kernels produced different output for same value).
#
# NULL guard: returns "" for NULL/NA (callers expect ""; format_y_value returns
# NA_character_ for NA and errors for NULL y_unit).
#
# NULL y_axis_unit fallback: format_y_value requires a non-NULL y_unit.
# When y_axis_unit is NULL (no unit context), fall back to generic locale-aware
# formatting so existing callers are not broken.
format_target_value <- function(x, y_axis_unit = NULL, language = "da",
                                target = NULL) {
  if (is.null(x) || is.na(x)) {
    return("")
  }

  # Delegate to format_y_value when unit is known (canonical formatting path).
  # NULL y_axis_unit: format_y_value errors on NULL y_unit, use generic fallback.
  if (!is.null(y_axis_unit)) {
    return(format_y_value(x,
      y_unit = y_axis_unit, target = target,
      language = language
    ))
  }

  # Generic fallback (NULL y_axis_unit): locale-aware, no unit-specific logic.
  if (is_effective_integer(x)) {
    as.character(as.integer(x))
  } else {
    decimal_mark <- if (identical(language, "en")) "." else ","
    format(round(x, 2), decimal.mark = decimal_mark, nsmall = 1)
  }
}
