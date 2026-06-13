# SPC Analysis Orchestration
#
# Exported analysis functions: bfh_build_analysis_context() and
# bfh_generate_analysis(). Internal helpers live in:
#   - analysis_helpers.R  (target utilities, resolve_target, format_target_value)
#   - analysis_signals.R  (signal detection, text-budget, i18n key selection)


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
#' @seealso
#' This function is a single-step convenience wrapper. For the two-step
#' pipeline that gives more control, use:
#' \itemize{
#'   \item \code{\link{bfh_analyse}} -- composes the structured
#'         \code{bfh_spc_analysis} object (analysis layer).
#'   \item \code{\link{bfh_render_analysis}} -- renders that object to
#'         character output (render layer).
#'   \item \code{\link{bfh_build_analysis_context}} -- lower-level helper
#'         used internally to extract chart context.
#'   \item \code{\link{bfh_generate_details}} -- generates the companion
#'         detail row string from the same \code{bfh_qic_result} input.
#'   \item \code{\link{bfh_qic}} for producing the \code{bfh_qic_result}
#'         input object.
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

  # Byg struktureret analyse-objekt via bfh_analyse + bfh_render_analysis.
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
