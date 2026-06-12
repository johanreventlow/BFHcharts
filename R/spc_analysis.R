# SPC Analysis Functions
#
# Funktioner til automatisk SPC-analyse og tekstgenerering.
# Disse funktioner bruges til at generere analysetekster til PDF-eksport.


# ---------------------------------------------------------------------------
# Interne helpers (resolve_target, pluralize_da, ensure_within_max)
# ---------------------------------------------------------------------------

# Konverter ASCII-operatorer (>=, <=) til Unicode-sammentrukne tegn
# (\U2265, \U2264) i target-display-strenge til klinisk prose-rendering.
# Bruges af baade .evaluate_target_arm() (legacy) og spc_render.R
# (struktureret pipeline). Holder operator-mappingen i en enkelt
# autoritativ kilde.
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
# Erstatter dual-computation i build_fallback_analysis() (linje 990-1013)
# og struktureret spc_render.R (.compute_level_direction +
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
# Brugt af .compute_level_keys() + .evaluate_target_arm() til at flippe
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

# Beregn near_target / at_target tolerance via sigma-cascade.
#
# Cascade (uaendret fra original logik):
#   1. sigma_hat tilgaengelig     -> 3*sigma_hat (kontrolgraense-bredde / 2)
#   2. sigma_data tilgaengelig    -> sd(y)
#   3. ingen sigma                -> 1e-9 (kraever eksakt match)
#
# Percent-units (is_percent=TRUE): tolerance capes ved
#   min(3*sigma_hat, NEAR_TARGET_PCT_CAP, NEAR_TARGET_PCT_RELATIVE * target).
# Absolut cap (3pp) haandterer noisy processes; relativ cap (25% af target)
# haandterer smaa-target-cases hvor 3pp stadig er klinisk for stor.
# Eksempler:
#   target=15%, CL=19%, delta=4pp: cap=min(sigma,3pp,3.75pp)=3pp; 4pp>3pp -> NOT near
#   target=3%,  CL=7%,  delta=4pp: cap=min(sigma,3pp,0.75pp)=0.75pp; 4pp>0.75pp -> NOT near
#   target=90%, CL=87%, delta=3pp: cap=min(sigma,3pp,22.5pp)=3pp; 3pp<=3pp -> NEAR
.near_target_tolerance <- function(sigma_hat, sigma_data, is_percent,
                                   target_value = NULL) {
  sigma_tol <- if (is_valid_scalar(sigma_hat) && is.finite(sigma_hat) &&
    sigma_hat > 0) {
    3 * sigma_hat
  } else if (is_valid_scalar(sigma_data) && is.finite(sigma_data) &&
    sigma_data > 0) {
    sigma_data
  } else {
    1e-9
  }
  if (isTRUE(is_percent)) {
    caps <- c(sigma_tol, NEAR_TARGET_PCT_CAP)
    if (is_valid_scalar(target_value) && is.finite(target_value) &&
      target_value > 0) {
      caps <- c(caps, NEAR_TARGET_PCT_RELATIVE * target_value)
    }
    return(min(caps))
  }
  sigma_tol
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


#' Build Analysis Context from bfh_qic_result
#'
#' Collects all relevant context from a `bfh_qic_result` object for analysis
#' generation. Used internally by `bfh_generate_analysis()`.
#'
#' @param x A `bfh_qic_result` object from `bfh_qic()`
#' @param metadata Optional list with additional context:
#'   - `data_definition`: Description of what the data represents
#'   - `target`: Target value for the metric. Accepts either numeric (backward
#'     compatible) or character with optional operator prefix (`"<= 2,5"`,
#'     `">= 90%"`). Operators are parsed to derive `target_direction`.
#'     **Fallback chain:** when `metadata$target` is NULL the function falls
#'     back to `x$config$target_text`, then `x$config$target_value`. This means
#'     a target supplied to `bfh_qic(target_text = ..., target_value = ...)`
#'     automatically reaches the analysis context without callers duplicating
#'     it in `metadata`.
#'   - `hospital`: Hospital name
#'   - `department`: Department name
#'
#' @return Named list with complete context including:
#'   - `chart_title`: Chart title from config
#'   - `chart_type`: Chart type (i, p, c, u, etc.)
#'   - `y_axis_unit`: Y-axis unit label
#'   - `n_points`: Number of data points
#'   - `centerline`: Centerline value
#'   - `spc_stats`: SPC statistics from `bfh_extract_spc_stats()`
#'   - `has_signals`: Logical indicating if signals were detected
#'   - `target_value`: Numeric target value (NA if absent). **Percent-target
#'     normalization:** when `y_axis_unit == "percent"` and the parsed target
#'     value appears to be on the 0-100 scale (display contains `"%"` or
#'     `value > 1`), `target_value` is divided by 100 so downstream
#'     comparisons are on the same 0-1 proportion scale as `centerline`.
#'     `target_display` is always preserved unchanged for user-facing text.
#'   - `target_direction`: `"higher"`, `"lower"`, or `NULL` derived from
#'     operator in `metadata$target` (NULL for numeric input)
#'   - `target_display`: Original target string for display purposes
#'   - User-provided metadata fields
#'
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#' ctx <- bfh_build_analysis_context(result, metadata = list(hospital = "BFH"))
#' str(ctx)
#' }
#'
#' @export
bfh_build_analysis_context <- function(x, metadata = list()) {
  # Input validation
  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object from bfh_qic()", call. = FALSE)
  }
  .validate_metadata_target(metadata$target)

  # Resolve target-input til value + retning (genbruger parse_target_input).
  # Fallback chain: metadata$target -> config$target_text -> config$target_value.
  # Sikrer at target sat via bfh_qic(target_text=, target_value=) automatisk
  # flyder til analyseteksten uden at caller skal duplikere i metadata-lista.
  resolved_target <- .resolve_analysis_target(metadata, x$config)
  target_info <- resolve_target(resolved_target)

  # Normaliser percent-target fra 0-100 til 0-1 proportionsskala naar relevant.
  # Bevarer target_display uaendret (brugervendt tekst fortsat ">= 90%").
  normalized_target_value <- .normalize_percent_target(
    value = target_info$value,
    display = target_info$display,
    y_axis_unit = x$config$y_axis_unit
  )

  # Udtraek SPC statistikker (inkl. outliers fra qic_data)
  spc_stats <- bfh_extract_spc_stats(x)

  # Detect om der er signaler. Delegerer til atomic-detectors (cycle 06
  # M2 DRY-cleanup) -- samme detection som .detect_signal_flags() +
  # AI-egress-gate. Behavior-neutral refactor; field bevares for test/
  # fixture-kontrakt.
  has_signals <-
    .has_runs_signal(spc_stats$runs_actual, spc_stats$runs_expected) ||
      .has_crossings_signal(
        spc_stats$crossings_actual, spc_stats$crossings_expected
      ) ||
      .has_outliers_signal(
        spc_stats$outliers_recent_count, spc_stats$outliers_actual
      )

  # Filtrer qic_data til sidste fase (matcher centerline-valget nedenfor).
  # Bruges baade til n_points og til sigma-estimater i value-neutral
  # at_target-klassifikation.
  qd_last_phase <- filter_qic_to_last_phase(x$qic_data)

  # sigma_hat: gennemsnitlig sigma-estimat fra kontrolgraenser (gns((UCL-LCL)/6))
  # over sidste fase. NA naar kontrolgraenser ikke findes (run charts).
  sigma_hat <- if (!is.null(qd_last_phase) &&
    all(c("ucl", "lcl") %in% names(qd_last_phase))) {
    val <- mean((qd_last_phase$ucl - qd_last_phase$lcl) / 6, na.rm = TRUE)
    if (is.finite(val)) val else NA_real_
  } else {
    NA_real_
  }
  # sigma_data: sd(y) over sidste fase, fallback naar sigma_hat mangler.
  sigma_data <- if (!is.null(qd_last_phase) && "y" %in% names(qd_last_phase)) {
    val <- stats::sd(qd_last_phase$y, na.rm = TRUE)
    if (is.finite(val)) val else NA_real_
  } else {
    NA_real_
  }

  # n_on_cl_ratio: andel af datapunkter der ligger EKSAKT paa centerlinjen
  # (|y - cl| < 1e-9). Bruges af .detect_signal_flags() til
  # majority_at_centerline-detection. Strikt eksakt-match (ikke sigma-
  # relativ) -- vi flagger kun klart diskrete data-symptomer.
  n_on_cl_ratio <- if (!is.null(qd_last_phase) &&
    all(c("y", "cl") %in% names(qd_last_phase))) {
    y <- qd_last_phase$y
    cl_vals <- qd_last_phase$cl
    on_cl <- abs(y - cl_vals) < 1e-9
    n_valid <- sum(!is.na(on_cl))
    if (n_valid > 0) sum(on_cl, na.rm = TRUE) / n_valid else NA_real_
  } else {
    NA_real_
  }

  # Samle kontekst
  context <- list(
    # Fra config
    chart_title = x$config$chart_title,
    chart_type = x$config$chart_type,
    y_axis_unit = x$config$y_axis_unit,

    # Fra qic_data (seneste part hvis median-knaek)
    n_points = if (!is.null(qd_last_phase)) {
      nrow(qd_last_phase)
    } else {
      NA_integer_
    },
    # Brug summary (har korrekt per-part centerlinje) fremfor qic_data
    # (som har samme cl i alle raekker uanset part)
    centerline = if (!is.null(x$summary) && "centerlinje" %in% names(x$summary) &&
      nrow(x$summary) > 0) {
      x$summary$centerlinje[nrow(x$summary)]
    } else if (!is.null(x$qic_data) && "cl" %in% names(x$qic_data)) {
      x$qic_data$cl[1]
    } else {
      NA_real_
    },

    # Anhoej statistikker
    spc_stats = spc_stats,
    has_signals = has_signals,

    # Processpredning (til value-neutral at_target-klassifikation)
    sigma_hat = sigma_hat,
    sigma_data = sigma_data,
    n_on_cl_ratio = n_on_cl_ratio,

    # Bruger-metadata
    data_definition = metadata$data_definition,
    target_value = normalized_target_value,
    target_direction = target_info$direction,
    target_display = target_info$display,
    hospital = metadata$hospital,
    department = metadata$department
  )

  return(context)
}


#' Generate SPC Analysis Text
#'
#' Generates analysis text for PDF export using AI (BFHllm) if available,
#' with automatic fallback to Danish standard texts.
#'
#' @param x A `bfh_qic_result` object from `bfh_qic()`
#' @param metadata Optional list with additional context for AI:
#'   - `data_definition`: Description of what the data represents
#'   - `target`: Target value for the metric
#'   - `hospital`: Hospital name
#'   - `department`: Department name
#'   - `chart_title`: Override chart title
#'   - `y_axis_unit`: Override y-axis unit
#' @param use_ai Logical. Should AI be used for analysis generation?
#'   **Security note:** Default is `FALSE` (explicit opt-in required). AI
#'   analysis sends `qic_data`, metadata, baseline, department and hospital
#'   data to `BFHllm::bfhllm_spc_suggestion()`. In healthcare contexts,
#'   implicit external data processing is unacceptable. Always set
#'   `use_ai = TRUE` deliberately, and always supply `data_consent = "explicit"`.
#'   - `FALSE` (default): Use standard texts only - no external data sharing
#'   - `TRUE`: Use AI (requires BFHllm package and `data_consent = "explicit"`; error if not satisfied)
#' @param data_consent Character. Required when `use_ai = TRUE`. Must be
#'   `"explicit"` to acknowledge that `qic_data`, metadata, and context are
#'   transmitted to `BFHllm::bfhllm_spc_suggestion()`. Any other value
#'   (including the default `NULL`) raises an error. Ignored when
#'   `use_ai = FALSE`.
#'
#'   **GDPR/HIPAA context:** `qic_data` may contain aggregated clinical
#'   indicators, department names, and hospital identifiers. In healthcare
#'   deployments, processing this data via an external AI service requires
#'   documented consent and a data processing agreement. Setting
#'   `data_consent = "explicit"` is the caller's attestation that the
#'   appropriate legal basis exists. An audit event is emitted automatically
#'   via `.emit_audit_event()` for traceability.
#' @param use_rag Logical. Controls whether `BFHllm::bfhllm_spc_suggestion()`
#'   is invoked with retrieval-augmented generation (RAG) enabled.
#'   Default is `FALSE` (privacy-preserving: one-shot LLM call only).
#'   Set `TRUE` to allow broader context from a vector store.
#'
#'   **Privacy implication:** When `use_rag = TRUE`, query data may be stored
#'   in or matched against a vector store maintained by BFHllm's backend.
#'   This is a separate compliance concern from the one-shot LLM call.
#'   Only enable when your data processing agreement explicitly covers
#'   vector-store usage. The value is always recorded in the audit event.
#' @param min_chars Minimum characters in AI-generated output. Default 300.
#' @param max_chars Maximum characters in AI-generated output. Default 375.
#' @param target_tolerance Deprecated. Argument is preserved in the signature
#'   for backward compatibility but is no longer used. The `at_target`
#'   classification now uses process variation (`mean((UCL - LCL) / 6)` over
#'   the last phase, with `sd(y)` as fallback for run charts) instead of a
#'   relative-to-target tolerance. Passing a non-default value emits a
#'   deprecation warning. The parameter will be removed in the next major
#'   release.
#' @param language Character string specifying output language. One of \code{"da"} (Danish, default) or \code{"en"} (English). Default \code{"da"} preserves backward compatibility.
#' @param texts_loader Function that returns SPC analysis text templates.
#'   Defaults to \code{load_spc_texts(language)}. Primarily intended for tests/mocking.
#'
#' @return Character string with analysis text suitable for PDF export.
#'
#' @details
#' **Security policy:** AI analysis is opt-in only (`use_ai = FALSE` by
#' default). Setting `use_ai = TRUE` requires BFHllm to be installed and
#' `data_consent = "explicit"` to be supplied; an informative error is raised
#' if either condition is not met. This prevents accidental data exposure in
#' environments where BFHllm uses network calls, RAG, or third-party services.
#'
#' **Installing BFHllm:** BFHllm is not on CRAN and must be installed
#' manually from GitHub before using `use_ai = TRUE`:
#' \preformatted{remotes::install_github("johanreventlow/BFHllm")}
#'
#' When `use_ai = TRUE` and all preconditions are met, the function:
#' 1. Validates `data_consent = "explicit"`
#' 2. Emits a structured audit event via `.emit_audit_event()`
#' 3. Builds context from the `bfh_qic_result` and metadata
#' 4. Calls `BFHllm::bfhllm_spc_suggestion()` for AI-generated analysis
#' 5. Falls back to standard texts if AI call fails
#'
#' When `use_ai = FALSE` (default):
#' - Returns Danish standard texts based on Anhoej SPC rules
#' - `data_consent` is not checked
#'
#' @section AI audit event:
#' When `use_ai = TRUE` and BFHllm is installed, a structured audit event is
#' emitted via `.emit_audit_event()` before calling
#' `BFHllm::bfhllm_spc_suggestion()`. The event includes: timestamp, event
#' type (`"ai_egress"`), package, target function, fields transmitted,
#' `use_rag` value, hostname, and user.
#'
#' If `options(BFHcharts.audit_log = "/path/to/audit.jsonl")` is set, the
#' event is appended as a JSON line. Otherwise it is emitted via `message()`
#' with prefix `[BFHcharts/audit]`.
#'
#' **Rationale:** Hospital deployments need an audit trail when patient-context
#' SPC data is sent to an external LLM. The structured event is parseable and
#' cannot be globally suppressed unlike `message()`.
#'
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#'
#' # Use standard texts (no AI)
#' analysis <- bfh_generate_analysis(result, use_ai = FALSE)
#'
#' # Use AI with explicit data consent
#' analysis <- bfh_generate_analysis(result,
#'   metadata = list(
#'     data_definition = "Antal infektioner pr. 1000 patientdage",
#'     target = 2.5
#'   ),
#'   use_ai = TRUE,
#'   data_consent = "explicit"
#' )
#'
#' # Use AI with RAG enabled (vector-store context)
#' analysis <- bfh_generate_analysis(result,
#'   use_ai = TRUE,
#'   data_consent = "explicit",
#'   use_rag = TRUE
#' )
#' }
#'
#' @export
bfh_generate_analysis <- function(x,
                                  metadata = list(),
                                  use_ai = FALSE,
                                  data_consent = NULL,
                                  use_rag = FALSE,
                                  min_chars = 300,
                                  max_chars = 375,
                                  target_tolerance = 0.05,
                                  language = "da",
                                  texts_loader = NULL) {
  # target_tolerance er deprecated -- value-neutral at_target-klassifikation
  # bruger nu processens variation (sigma_hat / sd(y)) i stedet for relativ-
  # til-target tolerance. Parameteren bevares i signaturen for backward
  # compatibility men ignoreres internt. Fjernes endeligt i naeste major release.
  if (!missing(target_tolerance)) {
    rlang::warn(
      c(
        "`target_tolerance` is deprecated.",
        i = paste(
          "Classification now uses process variation (UCL/LCL or sd(y));",
          "the argument is ignored."
        ),
        i = "Remove the argument from your call to silence this warning."
      ),
      class = "lifecycle_warning_deprecated"
    )
  }

  # Input validation
  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object from bfh_qic()", call. = FALSE)
  }

  validate_language(language)

  # texts_loader = NULL: brug language-aware standard; ellers brug custom loader
  if (is.null(texts_loader)) {
    texts_loader <- function() load_spc_texts(language)
  }

  # Validate min_chars < max_chars

  if (min_chars >= max_chars) {
    stop("min_chars must be less than max_chars", call. = FALSE)
  }

  # Byg struktureret analyse-objekt (Phase 2 cut-over: bfh_analyse +
  # bfh_render_analysis erstatter monolitisk build_fallback_analysis).
  # Public-API-signatur uaendret -- intern delegation til ny pipeline.
  spc_analysis <- bfh_analyse(x, metadata = metadata, language = language)
  baseline_analysis <- bfh_render_analysis(
    spc_analysis,
    max_chars = max_chars,
    texts_loader = texts_loader
  )

  # Check AI availability and consent - explicit opt-in required
  if (isTRUE(use_ai)) {
    # data_consent must be "explicit" before any AI egress
    if (!identical(data_consent, DATA_CONSENT_EXPLICIT)) {
      stop(
        "AI analysis requires data_consent = \"explicit\".\n",
        "  Set data_consent = \"explicit\" to acknowledge that qic_data, metadata,\n",
        "  and context are sent to BFHllm::bfhllm_spc_suggestion().\n",
        "  In healthcare settings, ensure a data processing agreement is in place\n",
        "  before enabling AI analysis. Use use_ai = FALSE for local-only analysis.",
        call. = FALSE
      )
    }

    if (!requireNamespace("BFHllm", quietly = TRUE)) {
      stop(
        "use_ai = TRUE requires the BFHllm package to be installed.\n",
        "  Install it with: pak::pkg_install(\"BFHllm\")\n",
        "  Or set use_ai = FALSE to use standard template-based analysis.",
        call. = FALSE
      )
    }
  }

  if (isTRUE(use_ai)) {
    # === AI-GENERERET ANALYSE ===
    # baseline_analysis-contract uaendret: rendered character bevares
    # som anker for BFHllm. Struktureret objekt sendes IKKE til AI i
    # denne change (separat fremtidig change kan introducere det).

    # signals_detected: TRUE kun naar Anhoej-flags (runs/crossings/outliers)
    # rent faktisk er aktive -- data-quality states (not_evaluable,
    # majority_at_centerline, no_variation) er IKKE SPC-signaler men
    # evaluerbarhed/data-form-issues og maa ikke sendes som "signal" til
    # BFHllm (cycle 05 finding #4 fix). Delegerer til samme atomare
    # detectors som .detect_signal_flags() -- forhindrer drift mellem
    # feature-extraction og AI-egress-gate.
    aux <- spc_analysis$aux
    has_signals <-
      .has_runs_signal(aux$runs_actual, aux$runs_expected) ||
        .has_crossings_signal(aux$crossings_actual, aux$crossings_expected) ||
        .has_outliers_signal(aux$outliers_recent_count, aux$outliers_actual)

    # Byg SPC metadata til BFHllm
    spc_result <- list(
      metadata = list(
        chart_type = spc_analysis$render_context$chart_type,
        n_points = spc_analysis$aux$n_points,
        signals_detected = if (has_signals) 1L else 0L,
        anhoej_rules = list(
          longest_run = spc_analysis$aux$runs_actual,
          n_crossings = spc_analysis$aux$crossings_actual,
          n_crossings_min = spc_analysis$aux$crossings_expected
        )
      ),
      qic_data = x$qic_data
    )

    # Byg kontekst til BFHllm
    llm_context <- list(
      data_definition = metadata$data_definition %||% "",
      chart_title = x$config$chart_title %||% "",
      y_axis_unit = spc_analysis$render_context$y_axis_unit %||% "",
      target_value = spc_analysis$aux$target_value,
      hospital = metadata$hospital %||% "",
      department = metadata$department %||% "",
      n_points = spc_analysis$aux$n_points,
      centerline = spc_analysis$aux$centerline,
      # Fagligt korrekt baseline-analyse baseret paa Anhoej-regler
      baseline_analysis = baseline_analysis
    )

    # Structured audit event: always emitted before AI egress (non-suppressible).
    # Written as JSON-line to BFHcharts.audit_log if set, else via message().
    .emit_audit_event(list(
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z"),
      event = AUDIT_EVENT_AI_EGRESS,
      package = "BFHcharts",
      target = "BFHllm::bfhllm_spc_suggestion",
      fields_sent = names(spc_result),
      context_keys = names(llm_context),
      use_rag = use_rag,
      hostname = Sys.info()[["nodename"]],
      user = Sys.info()[["user"]]
    ))

    # Call BFHllm
    ai_text <- tryCatch(
      {
        BFHllm::bfhllm_spc_suggestion(
          spc_result = spc_result,
          context = llm_context,
          min_chars = min_chars,
          max_chars = max_chars,
          use_rag = use_rag,
          timeout = 30
        )
      },
      error = function(e) {
        warning(
          "AI analysis failed; falling back to default text: ",
          conditionMessage(e)
        )
        NULL
      }
    )

    if (!is.null(ai_text) && nchar(ai_text) > 0) {
      return(ai_text)
    }
  }

  # === FALLBACK: STANDARDTEKSTER ===
  baseline_analysis
}


# Detect SPC signal flags from a context object.
#
# Returnerer named list med:
#   has_runs, has_crossings, has_outliers (logical)
#   is_stable                              (logical, derived: ingen signaler)
#   no_variation                          (logical, derived: alle signal-stats NA)
#   has_target                            (logical, derived: target_value + centerline gyldige)
#   outliers_for_text                     (numeric, til pluralize_da + placeholder)
#
# Pure: samme input -> samme output. Bruges af build_fallback_analysis() til
# at drive cascade-dispatch og budget-allokering uden at flade detection-
# logikken sammen med i18n-opslag.
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
# goal_not_met (matcher .evaluate_target_arm() priority).
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


# Evaluer maalvurderings-arm af fallback-analysen.
#
# Returnerer named list (target_text, goal_met, at_target, near_target).
# Bruges af orchestrator + .select_action_key().
#
# Tre dispatch-veje (matcher .select_action_key()'s tre cascade-grene):
#   1. has_target + target_direction: retningsbevidst goal_met-evaluering
#      via centerline-vs-target sammenligning + sigma-cascade for
#      near_target naar strict-condition fejler.
#   2. has_target uden target_direction: vaerdineutral at_target/over/under
#      med tolerance.
#   3. !has_target: target_text = "".
#
# i18n-lookup foregaar her (ikke i orchestrator) for at holde
# orchestrator fri af cascade-strukturer.
.evaluate_target_arm <- function(context, flags, texts, target_budget,
                                 language = "da",
                                 extra_placeholders = list()) {
  result <- list(
    target_text = "", goal_met = FALSE,
    at_target = FALSE, near_target = FALSE
  )
  if (!flags$has_target) {
    return(result)
  }

  target_value <- context$target_value
  target_direction <- context$target_direction
  centerline <- context$centerline

  # Foretraek display-streng fra input (fx "<= 2,5"), ellers format numerisk.
  # language threades igennem til format_target_value() saa engelsk
  # analyse-tekst faar "1.5" og dansk faar "1,5" (cycle 01 finding E4).
  display_target <- if (!is.null(context$target_display) &&
    nzchar(context$target_display)) {
    context$target_display
  } else {
    format_target_value(target_value,
      y_axis_unit = context$y_axis_unit,
      language = language
    )
  }

  # Erstat ASCII-operatorer med Unicode-sammentrukne tegn i analyseteksten.
  # context$target_display selv bevares uaendret (invariant fra resolve_target()).
  display_target <- .normalize_target_operators(display_target)

  # Merge target-display med globale placeholders (level_direction, level_vs_target).
  # Target tager precedence saa specifik target-display ikke kan overskrives.
  data <- modifyList(extra_placeholders, list(target = display_target))

  y_axis_unit <- context$y_axis_unit
  is_percent <- identical(y_axis_unit, "percent")

  if (!is.null(target_direction)) {
    # Retningsbevidst: prioritet er strikt goal_met > near_target >
    # goal_not_met. CL paa korrekt side af target laeses altid som
    # "opfyldt" uanset afstand; near_target reserveres for "forkert side
    # men inden for proces-stoej" (sigma-cascade matcher path A).
    #
    # Percent-units: display-precision-equality check foer strikt-numeric.
    # CL og target der afrunder til samme chart-display-vaerdi (fx 1,0%
    # vs 1%) klassificeres som goal_met. Forhindrer "lige over"-tekst
    # naar laeseren visuelt ser CL paa maalstregen.
    display_equal <- is_percent &&
      .cl_displays_at_target_pct(centerline, target_value)
    result$goal_met <- display_equal || switch(target_direction,
      "higher" = centerline >= target_value,
      "lower"  = centerline <= target_value,
      FALSE
    )
    if (!result$goal_met) {
      # Strict-condition fejler -- check om delta er inden for tolerance.
      # Samme tre-vejs cascade som value-neutral gren (sigma_hat ->
      # sigma_data -> eksakt). Tolerance-faldet for higher/lower er
      # symmetrisk om target; retningen kodes via {level_direction}.
      delta <- abs(centerline - target_value)
      tolerance <- .near_target_tolerance(
        context$sigma_hat, context$sigma_data, is_percent,
        target_value = target_value
      )
      result$near_target <- delta <= tolerance
    }
    key <- if (result$goal_met) {
      "goal_met"
    } else if (result$near_target) {
      "near_target"
    } else {
      "goal_not_met"
    }
    result$target_text <- pick_text(texts$target[[key]],
      data = data,
      budget = target_budget
    )
  } else {
    # Vaerdineutral: at/over/under target med processkala-tolerance.
    # Tre-vejs cascade (se openspec change at-target-tolerance-process-variation):
    #   1. Kontrolgraense-baseret: |CL - target| <= 3 * sigma_hat
    #      (svarer trivielt til LCL <= target <= UCL ved konstante 3-sigma-graenser)
    #   2. Data-sigma fallback:    |CL - target| <= sd(y)
    #      (run charts og no_variation hvor kontrolgraenser mangler)
    #   3. Eksakt-match:           |CL - target| < 1e-9
    #      (degenereret: konstant y, n=1, eller begge sigma er 0)
    # Percent-units: capped ved NEAR_TARGET_PCT_CAP saa stoejende processer
    # ej ratiionaliserer fjern-CL som "taet paa" (parity med direction-aware).
    delta <- abs(centerline - target_value)
    display_equal <- is_percent &&
      .cl_displays_at_target_pct(centerline, target_value)
    is_at_target <- display_equal ||
      delta <= .near_target_tolerance(
        context$sigma_hat, context$sigma_data, is_percent,
        target_value = target_value
      )
    if (is_at_target) {
      result$target_text <- pick_text(texts$target$at_target,
        data = data,
        budget = target_budget
      )
      result$at_target <- TRUE
    } else if (centerline > target_value) {
      result$target_text <- pick_text(texts$target$over_target,
        data = data,
        budget = target_budget
      )
    } else {
      result$target_text <- pick_text(texts$target$under_target,
        data = data,
        budget = target_budget
      )
    }
  }

  result
}


# Intern funktion: Byg komplet fallback-analysetekst.
#
# BACKWARD-COMPAT LAYER (post-Phase-2 cut-over):
# Primary path for bfh_generate_analysis() er nu bfh_analyse() +
# bfh_render_analysis() (R/spc_compose.R + R/spc_render.R).
# build_fallback_analysis bevares som intern fallback for direct-callere
# (test-spc_analysis.R + eventuelle eksterne :::-konsumenter) -- vil
# blive fjernet i naeste major release efter mindst et stabilt release-
# cycle med den nye pipeline.
#
# Allokerer tegnbudget til stability/target/action dele og vaelger
# passende variant for hver del. Naar context$target_direction er
# non-NULL (udledt fra fx "<= 2,5"), bruges retningsbevidst maal-
# vurdering (goal_met/goal_not_met) i stedet for vaerdineutral
# at/over/under. ensure_within_max garanterer max_chars-graensen.
#
# @keywords internal
# @noRd
build_fallback_analysis <- function(context,
                                    max_chars = 375,
                                    language = "da",
                                    texts_loader = NULL) {
  if (is.null(texts_loader)) {
    texts_loader <- function() load_spc_texts(language)
  }
  spc_stats <- context$spc_stats
  target_value <- context$target_value
  target_direction <- context$target_direction
  centerline <- context$centerline
  n_points <- context$n_points

  # --- Detect signaler + target-tilstand ---
  flags <- .detect_signal_flags(context)
  has_runs <- flags$has_runs
  has_crossings <- flags$has_crossings
  has_outliers <- flags$has_outliers
  is_stable <- flags$is_stable
  no_variation <- flags$no_variation
  has_target <- flags$has_target
  outliers_for_text <- flags$outliers_for_text

  # --- Budget-allokering ---
  budgets <- .allocate_text_budget(max_chars, has_target)
  stability_budget <- budgets$stability_budget
  target_budget <- budgets$target_budget
  action_budget <- budgets$action_budget

  if (!is.function(texts_loader)) {
    stop("texts_loader must be a function", call. = FALSE)
  }
  texts <- texts_loader()
  # outliers_actual i placeholder_data bruger recent_count-vaerdien, saa YAML-
  # skabelonernes {outliers_actual} placeholder ogsaa foelger "seneste 6 obs"-
  # reglen. outliers_word giver korrekt dansk ental/flertal for 1 vs n.
  outliers_n <- if (is_valid_scalar(outliers_for_text)) outliers_for_text else 0L

  # level_direction / level_vs_target: target-relative position af centerlinje.
  # Bruges som placeholders til at sammensaette saetninger som
  # "Niveauet {level_vs_target} ({target})" -> "Niveauet ligger under maalet (90%)".
  # For percent-units: "paa" rendres naar CL og target afrunder til samme
  # chart-display-vaerdi (display-precision-equality). For andre units:
  # strikt lighedstest (delta < 1e-9). Tomme strenge naar target ikke er
  # sat, saa placeholderne kan staa i templates uden at generere fejl,
  # men bor kun bruges i target-/goal-specifikke varianter for at give
  # meningsfuld tekst.
  level_keys <- .compute_level_keys(centerline, target_value, flags$has_target,
    y_axis_unit = context$y_axis_unit)
  level_direction <- if (!is.null(level_keys)) {
    i18n_lookup(paste0("labels.level_direction.", level_keys$direction_key), language)
  } else {
    ""
  }
  level_vs_target <- if (!is.null(level_keys)) {
    i18n_lookup(paste0("labels.level_vs_target.", level_keys$vs_target_key), language)
  } else {
    ""
  }

  # Formateret centerline-vaerdi til {centerline}-placeholder. Bruger
  # format_target_value() saa centerline rendres pa samme skala som y-aksen
  # (fx 85% paa percent-charts, 3.2 paa numeric-charts). target threades
  # gennem saa percent-CL bevarer en decimal naar |CL - target| <= 2pp --
  # matcher chart-label-praecision (format_y_value via
  # format_percent_contextual). Tom-fallback til "ukendt"-label naar
  # centerline er NULL/NA (degenereret data-tilfaelde).
  cl_fmt <- if (!is.null(centerline) && !is.na(centerline)) {
    format_target_value(centerline,
      y_axis_unit = context$y_axis_unit,
      language = language,
      target = target_value
    )
  } else {
    i18n_lookup("labels.misc.ukendt", language)
  }

  placeholder_data <- list(
    runs_actual = spc_stats$runs_actual,
    runs_expected = spc_stats$runs_expected,
    crossings_actual = spc_stats$crossings_actual,
    crossings_expected = spc_stats$crossings_expected,
    outliers_actual = outliers_for_text,
    outliers_word = pluralize_da(
      outliers_n,
      i18n_lookup("labels.outliers.singular", language),
      i18n_lookup("labels.outliers.plural", language)
    ),
    effective_window = spc_stats$effective_window %||% RECENT_OBS_WINDOW,
    centerline = cl_fmt,
    level_direction = level_direction,
    level_vs_target = level_vs_target
  )

  # --- 1. Stabilitetstekst ---
  # Prioritet: no_variation > majority_at_centerline > auto_mean_unstable >
  # signal-baseret dispatch.
  # no_variation kraever Anhoej-stats er NA (alle identiske); majority_at_cl
  # tillader normal variation men flagger >= 50% punkter eksakt paa CL;
  # auto_mean_unstable fyrer naar CL er auto-skiftet til gennemsnit pga
  # majoritets-paa-median, men signaler stadig er til stede.
  if (no_variation) {
    stability <- pick_text(
      texts$stability$no_variation,
      data = list(centerline = cl_fmt),
      budget = stability_budget
    )
  } else if (isTRUE(flags$majority_at_cl)) {
    stability <- pick_text(
      texts$stability$majority_at_centerline,
      data = list(centerline = cl_fmt),
      budget = stability_budget
    )
  } else if (isTRUE(flags$auto_mean_unstable)) {
    stability <- pick_text(
      texts$stability$auto_mean_unstable,
      data = list(centerline = cl_fmt),
      budget = stability_budget
    )
  } else {
    key <- .select_stability_key(flags)
    stability <- pick_text(texts$stability[[key]],
      data = placeholder_data,
      budget = stability_budget
    )
  }

  # --- 2. Maalvurdering ---
  # extra_placeholders giver target-templates adgang til {level_direction},
  # {level_vs_target} og {centerline} ved siden af det allerede formaterede
  # {target}.
  target_eval <- .evaluate_target_arm(
    context, flags, texts,
    target_budget,
    language = language,
    extra_placeholders = list(
      centerline = cl_fmt,
      level_direction = level_direction,
      level_vs_target = level_vs_target
    )
  )
  target_text <- target_eval$target_text
  goal_met <- target_eval$goal_met
  at_target <- target_eval$at_target
  near_target <- target_eval$near_target

  # --- 3. Handlingsforslag ---
  # action-templates faar ogsaa adgang til level_*- og centerline-placeholders
  # saa goal_met/goal_not_met-tekster kan beskrive niveau-position i forhold
  # til maal.
  action_key <- .select_action_key(flags, target_direction, goal_met,
    at_target,
    near_target = near_target
  )
  action <- pick_text(texts$action[[action_key]],
    data = list(
      centerline = cl_fmt,
      level_direction = level_direction,
      level_vs_target = level_vs_target
    ),
    budget = action_budget
  )

  # --- Kombiner ---
  parts <- c(stability, target_text, action)
  parts <- parts[nchar(parts) > 0]
  text <- paste(parts, collapse = " ")

  # --- Garanter max_chars-graensen (trim ved saetnings-/klausulgraense) ---
  text <- ensure_within_max(text, max_chars)

  return(text)
}


# Formater maalvaerdi til visning
# y_axis_unit bruges til at afgoere om vaerdien skal vises som procent.
# language styrer decimal-separator: "da" -> "," (default), "en" -> "."
# (cycle 01 finding E4: previously hardcoded "," produced danish decimals
# in english analysis-text, eg. "1,5" instead of "1.5").
#
# target: optional 0-1-skala maal-vaerdi. Naar sat OG x er i [0,1] med
# y_axis_unit="percent", delegeres formatering til format_percent_contextual()
# saa praecision matcher chart-labels: en decimal vises naar |x - target|
# <= 2 procentpoint, ellers afrundes til hele procent. Sikrer at
# {centerline}/{target}-placeholders i analyse-tekst rendres med samme
# antal decimaler som CL-label paa selve grafen.
format_target_value <- function(x, y_axis_unit = NULL, language = "da",
                                target = NULL) {
  if (is.null(x) || is.na(x)) {
    return("")
  }

  # Konverter proportion til procent hvis relevant
  # x i [0, 1] -> proportion, multiplicer med 100. x > 1 -> allerede procent.
  if (!is.null(y_axis_unit) && y_axis_unit == "percent") {
    if (x >= 0 && x <= 1) {
      return(format_percent_contextual(x, target = target, language = language))
    } else if (x > 1) {
      return(paste0(round(x), "%"))
    }
  }

  if (is_effective_integer(x)) {
    as.character(as.integer(x))
  } else {
    decimal_mark <- if (identical(language, "en")) "." else ","
    format(round(x, 2), decimal.mark = decimal_mark, nsmall = 1)
  }
}
