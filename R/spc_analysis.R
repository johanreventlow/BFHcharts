# SPC Analysis Functions
#
# Funktioner til automatisk SPC-analyse og tekstgenerering.
# Disse funktioner bruges til at generere analysetekster til PDF-eksport.


# ---------------------------------------------------------------------------
# Interne helpers (resolve_target, pluralize_da, ensure_within_max)
# ---------------------------------------------------------------------------

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

  # Detect om der er signaler (sikker mod NULL og NA)
  has_signals <- FALSE
  if (is_valid_scalar(spc_stats$runs_actual) && is_valid_scalar(spc_stats$runs_expected)) {
    if (spc_stats$runs_actual > spc_stats$runs_expected) {
      has_signals <- TRUE
    }
  }
  if (is_valid_scalar(spc_stats$crossings_actual) && is_valid_scalar(spc_stats$crossings_expected)) {
    if (spc_stats$crossings_actual < spc_stats$crossings_expected) {
      has_signals <- TRUE
    }
  }
  # has_signals skal afspejle om AKTUELLE signaler eksisterer - brug samme
  # recent-count som analyseteksten (fallback til outliers_actual hvis ukendt).
  outliers_for_flag <- spc_stats$outliers_recent_count %||% spc_stats$outliers_actual
  if (is_valid_scalar(outliers_for_flag) && outliers_for_flag > 0) {
    has_signals <- TRUE
  }

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

  # Byg kontekst
  context <- bfh_build_analysis_context(x, metadata)

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

    # Byg SPC metadata til BFHllm
    spc_result <- list(
      metadata = list(
        chart_type = context$chart_type,
        n_points = context$n_points,
        signals_detected = if (context$has_signals) 1L else 0L,
        anhoej_rules = list(
          longest_run = context$spc_stats$runs_actual,
          n_crossings = context$spc_stats$crossings_actual,
          n_crossings_min = context$spc_stats$crossings_expected
        )
      ),
      qic_data = x$qic_data
    )

    # Byg fallback-analyse som baseline for AI
    baseline_analysis <- build_fallback_analysis(context,
      max_chars = max_chars,
      language = language,
      texts_loader = texts_loader
    )

    # Byg kontekst til BFHllm
    llm_context <- list(
      data_definition = context$data_definition %||% "",
      chart_title = context$chart_title %||% "",
      y_axis_unit = context$y_axis_unit %||% "",
      target_value = context$target_value,
      hospital = context$hospital %||% "",
      department = context$department %||% "",
      n_points = context$n_points,
      centerline = context$centerline,
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
    analysis <- tryCatch(
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

    if (!is.null(analysis) && nchar(analysis) > 0) {
      return(analysis)
    }
  }

  # === FALLBACK: STANDARDTEKSTER ===
  analysis <- build_fallback_analysis(context,
    max_chars = max_chars,
    language = language,
    texts_loader = texts_loader
  )
  return(analysis)
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
.detect_signal_flags <- function(context) {
  spc_stats <- context$spc_stats
  target_value <- context$target_value
  centerline <- context$centerline

  has_runs <- is_valid_scalar(spc_stats$runs_actual) &&
    is_valid_scalar(spc_stats$runs_expected) &&
    spc_stats$runs_actual > spc_stats$runs_expected

  has_crossings <- is_valid_scalar(spc_stats$crossings_actual) &&
    is_valid_scalar(spc_stats$crossings_expected) &&
    spc_stats$crossings_actual < spc_stats$crossings_expected

  # Brug recent_count (seneste 6 obs) saa analyseteksten kun beskriver AKTUELLE
  # outliers. Fald tilbage til outliers_actual naar kun summary-baserede stats
  # er tilgaengelige.
  outliers_for_text <- spc_stats$outliers_recent_count %||% spc_stats$outliers_actual
  has_outliers <- is_valid_scalar(outliers_for_text) && outliers_for_text > 0

  is_stable <- !has_runs && !has_crossings && !has_outliers

  runs_missing <- is.null(spc_stats$runs_actual) ||
    length(spc_stats$runs_actual) == 0 ||
    is.na(spc_stats$runs_actual)
  crossings_missing <- is.null(spc_stats$crossings_actual) ||
    length(spc_stats$crossings_actual) == 0 ||
    is.na(spc_stats$crossings_actual)
  no_variation <- runs_missing && crossings_missing

  has_target <- !is.null(target_value) && !is.na(target_value) &&
    is.numeric(target_value) &&
    !is.null(centerline) && !is.na(centerline)

  list(
    has_runs = has_runs,
    has_crossings = has_crossings,
    has_outliers = has_outliers,
    is_stable = is_stable,
    no_variation = no_variation,
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
# goal_met og at_target er evalueret af caller; helper er pure dispatch.
.select_action_key <- function(flags, target_direction, goal_met, at_target) {
  is_stable <- flags$is_stable
  has_target <- flags$has_target

  if (has_target && !is.null(target_direction)) {
    if (is_stable && goal_met) {
      "stable_goal_met"
    } else if (is_stable && !goal_met) {
      "stable_goal_not_met"
    } else if (!is_stable && goal_met) {
      "unstable_goal_met"
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
# Returnerer named list (target_text, goal_met, at_target). Bruges af
# orchestrator + .select_action_key().
#
# Tre dispatch-veje (matcher .select_action_key()'s tre cascade-grene):
#   1. has_target + target_direction: retningsbevidst goal_met-evaluering
#      via centerline-vs-target sammenligning.
#   2. has_target uden target_direction: vaerdineutral at_target/over/under
#      med tolerance.
#   3. !has_target: target_text = "".
#
# i18n-lookup foregaar her (ikke i orchestrator) for at holde
# orchestrator fri af cascade-strukturer.
.evaluate_target_arm <- function(context, flags, texts, target_budget,
                                 language = "da",
                                 extra_placeholders = list()) {
  result <- list(target_text = "", goal_met = FALSE, at_target = FALSE)
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

  # Erstat ASCII-operatorer med Unicode-sammentrukne tegn i analyseteksten,
  # saa ">= 90%" rendres som "\U2265 90%" og "<= 2,5" som "\U2264 2,5".
  # context$target_display selv bevares uaendret (invariant fra resolve_target()).
  display_target <- gsub(">=", "\U2265", display_target, fixed = TRUE)
  display_target <- gsub("<=", "\U2264", display_target, fixed = TRUE)

  # Merge target-display med globale placeholders (level_direction, level_vs_target).
  # Target tager precedence saa specifik target-display ikke kan overskrives.
  data <- modifyList(extra_placeholders, list(target = display_target))

  if (!is.null(target_direction)) {
    # Retningsbevidst: "higher" -> CL >= target, "lower" -> CL <= target
    result$goal_met <- switch(target_direction,
      "higher" = centerline >= target_value,
      "lower"  = centerline <= target_value,
      FALSE
    )
    key <- if (result$goal_met) "goal_met" else "goal_not_met"
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
    delta <- abs(centerline - target_value)
    sigma_hat <- context$sigma_hat
    sigma_data <- context$sigma_data
    is_at_target <- if (is_valid_scalar(sigma_hat) && is.finite(sigma_hat) &&
      sigma_hat > 0) {
      delta <= 3 * sigma_hat
    } else if (is_valid_scalar(sigma_data) && is.finite(sigma_data) &&
      sigma_data > 0) {
      delta <= sigma_data
    } else {
      delta < 1e-9
    }
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


# Intern funktion: Byg komplet fallback-analysetekst
# Allokerer tegnbudget til stability/target/action dele
# og vaelger passende variant for hver del. Naar context$target_direction
# er non-NULL (udledt fra fx "<= 2,5"), bruges retningsbevidst maal-
# vurdering (goal_met/goal_not_met) i stedet for vaerdineutral
# at/over/under. ensure_within_max garanterer max_chars-graensen.
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
  # Strikt lighedstest (delta < 1e-9) for "paa" -- ikke sigma-tolerance, saa
  # "ligger paa maalet" kun matcher praecis lighed mellem centerlinje og target.
  # Tomme strenge naar target ikke er sat, saa placeholderne kan staa i
  # templates uden at generere fejl, men bor kun bruges i target-/goal-
  # specifikke varianter for at give meningsfuld tekst.
  level_direction <- if (flags$has_target) {
    delta <- abs(centerline - target_value)
    if (delta < 1e-9) {
      i18n_lookup("labels.level_direction.at", language)
    } else if (centerline > target_value) {
      i18n_lookup("labels.level_direction.over", language)
    } else {
      i18n_lookup("labels.level_direction.under", language)
    }
  } else {
    ""
  }
  level_vs_target <- if (flags$has_target) {
    key <- if (abs(centerline - target_value) < 1e-9) {
      "labels.level_vs_target.at"
    } else if (centerline > target_value) {
      "labels.level_vs_target.over"
    } else {
      "labels.level_vs_target.under"
    }
    i18n_lookup(key, language)
  } else {
    ""
  }

  # Formateret centerline-vaerdi til {centerline}-placeholder. Bruger
  # format_target_value() saa centerline rendres pa samme skala som y-aksen
  # (fx 85% paa percent-charts, 3.2 paa numeric-charts). Tom-fallback til
  # "ukendt"-label naar centerline er NULL/NA (degenereret data-tilfaelde).
  cl_fmt <- if (!is.null(centerline) && !is.na(centerline)) {
    format_target_value(centerline,
      y_axis_unit = context$y_axis_unit,
      language = language
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
  if (no_variation) {
    stability <- pick_text(
      texts$stability$no_variation,
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

  # --- 3. Handlingsforslag ---
  # action-templates faar ogsaa adgang til level_*- og centerline-placeholders
  # saa goal_met/goal_not_met-tekster kan beskrive niveau-position i forhold
  # til maal.
  action_key <- .select_action_key(flags, target_direction, goal_met, at_target)
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
format_target_value <- function(x, y_axis_unit = NULL, language = "da") {
  if (is.null(x) || is.na(x)) {
    return("")
  }

  # Konverter proportion til procent hvis relevant
  # x i [0, 1] -> proportion, multiplicer med 100. x > 1 -> allerede procent.
  if (!is.null(y_axis_unit) && y_axis_unit == "percent") {
    if (x >= 0 && x <= 1) {
      return(paste0(round(x * 100), "%"))
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
