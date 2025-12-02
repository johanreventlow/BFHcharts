# SPC Analysis Functions
#
# Funktioner til automatisk SPC-analyse og tekstgenerering.
# Disse funktioner bruges til at generere analysetekster til PDF-eksport.


#' Interpret SPC Signals (Anhøj Rules)
#'
#' Generates Danish standard text interpretations based on Anhøj SPC analysis.
#' Used as fallback when AI is not available.
#'
#' @param spc_stats Named list from `bfh_extract_spc_stats()` containing:
#'   - `runs_actual`: Actual longest run (consecutive points on same side of CL)
#'   - `runs_expected`: Expected maximum run length
#'   - `crossings_actual`: Actual number of crossings of centerline
#'   - `crossings_expected`: Expected minimum crossings
#'   - `outliers_actual`: Number of points outside control limits
#'
#' @return Character vector with Danish interpretations. Empty vector if no
#'   signals detected and no stats provided.
#'
#' @examples
#' # Signal detected
#' stats <- list(runs_actual = 9, runs_expected = 7)
#' bfh_interpret_spc_signals(stats)
#'
#' # Normal process
#' stats <- list(runs_actual = 5, runs_expected = 7,
#'               crossings_actual = 8, crossings_expected = 5)
#' bfh_interpret_spc_signals(stats)
#'
#' @export
bfh_interpret_spc_signals <- function(spc_stats) {
  interpretations <- character(0)


# Serielængde-signal (runs)
  if (!is.null(spc_stats$runs_actual) && !is.null(spc_stats$runs_expected)) {
    if (spc_stats$runs_actual > spc_stats$runs_expected) {
      interpretations <- c(
        interpretations,
        sprintf(
          paste0(
            "Serielængde-signal: Længste serie (%d) overstiger forventet ",
            "maksimum (%d). Dette indikerer et skift i procesniveauet."
          ),
          spc_stats$runs_actual,
          spc_stats$runs_expected
        )
      )
    } else {
      interpretations <- c(
        interpretations,
        sprintf(
          "Serielængde inden for forventet variation (%d ≤ %d).",
          spc_stats$runs_actual,
          spc_stats$runs_expected
        )
      )
    }
  }

  # Krydsnings-signal (crossings)
  if (!is.null(spc_stats$crossings_actual) &&
      !is.null(spc_stats$crossings_expected)) {
    if (spc_stats$crossings_actual < spc_stats$crossings_expected) {
      interpretations <- c(
        interpretations,
        sprintf(
          paste0(
            "Krydsnings-signal: Kun %d krydsninger af centerlinjen, under ",
            "forventet minimum (%d). Dette indikerer stratificering eller ",
            "clustering i data."
          ),
          spc_stats$crossings_actual,
          spc_stats$crossings_expected
        )
      )
    } else {
      interpretations <- c(
        interpretations,
        sprintf(
          "Antal krydsninger inden for forventet variation (%d ≥ %d).",
          spc_stats$crossings_actual,
          spc_stats$crossings_expected
        )
      )
    }
  }

  # Outliers
  if (!is.null(spc_stats$outliers_actual) && spc_stats$outliers_actual > 0) {
    interpretations <- c(
      interpretations,
      sprintf(
        paste0(
          "%d observation(er) ligger uden for kontrolgrænserne. ",
          "Disse bør undersøges for særlige årsager."
        ),
        spc_stats$outliers_actual
      )
    )
  }

  # Hvis ingen signaler og ingen fortolkninger
  if (length(interpretations) == 0) {
    interpretations <- "Processen viser stabil adfærd uden særlige signaler."
  }

  return(interpretations)
}


#' Build Analysis Context from bfh_qic_result
#'
#' Collects all relevant context from a `bfh_qic_result` object for analysis
#' generation. Used internally by `bfh_generate_analysis()`.
#'
#' @param x A `bfh_qic_result` object from `bfh_qic()`
#' @param metadata Optional list with additional context:
#'   - `data_definition`: Description of what the data represents
#'   - `target`: Target value for the metric
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
#'   - `signal_interpretations`: Danish interpretations from
#'     `bfh_interpret_spc_signals()`
#'   - `has_signals`: Logical indicating if signals were detected
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
    stop("x must be a bfh_qic_result object from bfh_qic()")
  }

  # Udtræk SPC statistikker
  spc_stats <- bfh_extract_spc_stats(x$summary)

  # Generer standardtekster
  signal_interpretations <- bfh_interpret_spc_signals(spc_stats)

  # Detect om der er signaler
  has_signals <- FALSE
  if (!is.null(spc_stats$runs_actual) && !is.null(spc_stats$runs_expected)) {
    if (spc_stats$runs_actual > spc_stats$runs_expected) {
      has_signals <- TRUE
    }
  }
  if (!is.null(spc_stats$crossings_actual) &&
      !is.null(spc_stats$crossings_expected)) {
    if (spc_stats$crossings_actual < spc_stats$crossings_expected) {
      has_signals <- TRUE
    }
  }
  if (!is.null(spc_stats$outliers_actual) && spc_stats$outliers_actual > 0) {
    has_signals <- TRUE
  }

  # Samle kontekst
  context <- list(
    # Fra config
    chart_title = x$config$chart_title,
    chart_type = x$config$chart_type,
    y_axis_unit = x$config$y_axis_unit,

    # Fra qic_data
    n_points = if (!is.null(x$qic_data)) nrow(x$qic_data) else NA_integer_,
    centerline = if (!is.null(x$qic_data) && "cl" %in% names(x$qic_data)) {
      x$qic_data$cl[1]
    } else {
      NA_real_
    },

    # Anhøj statistikker
    spc_stats = spc_stats,

    # Signal-fortolkninger (standardtekster)
    signal_interpretations = signal_interpretations,
    has_signals = has_signals,

    # Bruger-metadata
    data_definition = metadata$data_definition,
    target_value = metadata$target,
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
#'   - `NULL` (default): Auto-detect BFHllm availability
#'   - `TRUE`: Use AI (requires BFHllm package)
#'   - `FALSE`: Use standard texts only
#' @param max_chars Maximum characters in AI-generated output. Default 350.
#'
#' @return Character string with analysis text suitable for PDF export.
#'
#' @details
#' When `use_ai = TRUE` and BFHllm is installed, the function:
#' 1. Builds context from the `bfh_qic_result` and metadata
#' 2. Calls `BFHllm::bfhllm_spc_suggestion()` for AI-generated analysis
#' 3. Falls back to standard texts if AI call fails
#'
#' When `use_ai = FALSE` or BFHllm is not installed:
#' - Returns Danish standard texts based on Anhøj SPC rules
#'
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#'
#' # Use standard texts (no AI)
#' analysis <- bfh_generate_analysis(result, use_ai = FALSE)
#'
#' # Use AI if available
#' analysis <- bfh_generate_analysis(result,
#'   metadata = list(
#'     data_definition = "Antal infektioner pr. 1000 patientdage",
#'     target = 2.5
#'   ),
#'   use_ai = TRUE
#' )
#' }
#'
#' @export
bfh_generate_analysis <- function(x,
                                   metadata = list(),
                                   use_ai = NULL,
                                   max_chars = 350) {
  # Input validation
  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object from bfh_qic()")
  }

  # Byg kontekst
  context <- bfh_build_analysis_context(x, metadata)

  # Check AI tilgængelighed
  ai_available <- requireNamespace("BFHllm", quietly = TRUE)
  if (is.null(use_ai)) {
    use_ai <- ai_available
  }

  if (use_ai && ai_available) {
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

    # Byg kontekst til BFHllm
    llm_context <- list(
      data_definition = context$data_definition %||% "",
      chart_title = context$chart_title %||% "",
      y_axis_unit = context$y_axis_unit %||% "",
      target_value = context$target_value,
      # Inkluder standardtekster som eksempler
      signal_examples = paste(context$signal_interpretations, collapse = " ")
    )

    # Kald BFHllm
    analysis <- tryCatch(
      {
        BFHllm::bfhllm_spc_suggestion(
          spc_result = spc_result,
          context = llm_context,
          max_chars = max_chars,
          use_rag = TRUE
        )
      },
      error = function(e) {
        warning(
          "AI analyse fejlede, bruger standardtekster: ",
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

  # Kombinér signal-fortolkninger
  if (length(context$signal_interpretations) > 0) {
    analysis <- paste(context$signal_interpretations, collapse = " ")
  } else {
    analysis <- "Processen viser stabil adfærd uden særlige signaler."
  }

  # Tilføj titel hvis tilgængelig
  if (!is.null(context$chart_title) && nchar(context$chart_title) > 0) {
    analysis <- paste0(context$chart_title, ": ", analysis)
  }

  return(analysis)
}
