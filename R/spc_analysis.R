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
  if (is_valid_scalar(spc_stats$runs_actual) && is_valid_scalar(spc_stats$runs_expected)) {
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
  if (is_valid_scalar(spc_stats$crossings_actual) && is_valid_scalar(spc_stats$crossings_expected)) {
    if (spc_stats$crossings_actual < spc_stats$crossings_expected) {
      interpretations <- c(
        interpretations,
        sprintf(
          paste0(
            "Krydsnings-signal: Kun %d krydsninger af centerlinjen, under ",
            "forventet minimum (%d). Dette indikerer gruppering i data."
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
  if (is_valid_scalar(spc_stats$outliers_actual) && spc_stats$outliers_actual > 0) {
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
    interpretations <- "Processen er stabil uden s\u00e6rlige signaler."
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

  # Udtræk SPC statistikker (inkl. outliers fra qic_data)
  spc_stats <- extract_spc_stats_extended(x)

  # Generer standardtekster
  signal_interpretations <- bfh_interpret_spc_signals(spc_stats)

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
  if (is_valid_scalar(spc_stats$outliers_actual) && spc_stats$outliers_actual > 0) {
    has_signals <- TRUE
  }

  # Samle kontekst
  context <- list(
    # Fra config
    chart_title = x$config$chart_title,
    chart_type = x$config$chart_type,
    y_axis_unit = x$config$y_axis_unit,

    # Fra qic_data (seneste part hvis median-knaek)
    n_points = if (!is.null(x$qic_data)) {
      if ("part" %in% names(x$qic_data)) {
        sum(x$qic_data$part == max(x$qic_data$part, na.rm = TRUE))
      } else {
        nrow(x$qic_data)
      }
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
#' @param min_chars Minimum characters in AI-generated output. Default 300.
#' @param max_chars Maximum characters in AI-generated output. Default 375.
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
                                   min_chars = 300,
                                   max_chars = 375) {
  # Input validation
  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object from bfh_qic()")
  }

  # Validate min_chars < max_chars

  if (min_chars >= max_chars) {
    stop("min_chars must be less than max_chars")
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

    # Byg fallback-analyse som baseline for AI
    baseline_analysis <- build_fallback_analysis(context,
                                                 min_chars = min_chars,
                                                 max_chars = max_chars)

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
      # Fagligt korrekt baseline-analyse baseret p\u00e5 Anh\u00f8j-regler
      baseline_analysis = baseline_analysis
    )

    # Kald BFHllm
    analysis <- tryCatch(
      {
        BFHllm::bfhllm_spc_suggestion(
          spc_result = spc_result,
          context = llm_context,
          min_chars = min_chars,
          max_chars = max_chars,
          use_rag = TRUE,
          timeout = 30
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
  analysis <- build_fallback_analysis(context,
                                      min_chars = min_chars,
                                      max_chars = max_chars)
  return(analysis)
}


# Intern funktion: Byg komplet fallback-analysetekst
# Kombinerer stabilitetsvurdering + målvurdering + handlingsforslag
# og justerer til min_chars-max_chars intervallet.
build_fallback_analysis <- function(context,
                                    min_chars = 300,
                                    max_chars = 375) {
  spc_stats <- context$spc_stats
  target_value <- context$target_value
  centerline <- context$centerline
  n_points <- context$n_points

  # --- Detect signaler (sikker mod NULL og NA) ---
  has_runs <- is_valid_scalar(spc_stats$runs_actual) &&
    is_valid_scalar(spc_stats$runs_expected) &&
    spc_stats$runs_actual > spc_stats$runs_expected

  has_crossings <- is_valid_scalar(spc_stats$crossings_actual) &&
    is_valid_scalar(spc_stats$crossings_expected) &&
    spc_stats$crossings_actual < spc_stats$crossings_expected

  has_outliers <- is_valid_scalar(spc_stats$outliers_actual) &&
    spc_stats$outliers_actual > 0

  is_stable <- !has_runs && !has_crossings && !has_outliers

  # --- Detect ingen variation (alle SPC-stats er NA eller NULL) ---
  runs_missing <- is.null(spc_stats$runs_actual) ||
    length(spc_stats$runs_actual) == 0 ||
    is.na(spc_stats$runs_actual)
  crossings_missing <- is.null(spc_stats$crossings_actual) ||
    length(spc_stats$crossings_actual) == 0 ||
    is.na(spc_stats$crossings_actual)
  no_variation <- runs_missing && crossings_missing

  if (no_variation) {
    cl_fmt <- if (!is.null(centerline) && !is.na(centerline)) {
      format_target_value(centerline, y_axis_unit = context$y_axis_unit)
    } else {
      "ukendt"
    }

    texts <- load_spc_texts()
    stability <- pick_text(
      texts$stability$no_variation,
      data = list(centerline = cl_fmt)
    )
  }

  # --- 1. Stabilitetstekst (kun hvis ikke ingen-variation) ---
  if (!no_variation) {
    stability <- fallback_stability_text(
      spc_stats, has_runs, has_crossings, has_outliers
    )
  }

  # --- 2. M\u00e5lvurdering ---
  has_target <- !is.null(target_value) && !is.na(target_value) &&
    is.numeric(target_value) &&
    !is.null(centerline) && !is.na(centerline)

  target_text <- ""
  at_target <- FALSE

  if (has_target) {
    fmt <- format_target_value(target_value, y_axis_unit = context$y_axis_unit)
    tolerance <- max(abs(target_value) * 0.05, 0.01)
    texts <- load_spc_texts()

    if (abs(centerline - target_value) <= tolerance) {
      target_text <- pick_text(texts$target$at_target, data = list(target = fmt))
      at_target <- TRUE
    } else if (centerline > target_value) {
      target_text <- pick_text(texts$target$over_target, data = list(target = fmt))
    } else {
      target_text <- pick_text(texts$target$under_target, data = list(target = fmt))
    }
  }

  # --- 3. Handlingsforslag ---
  action <- fallback_action_text(is_stable, has_target, at_target)

  # --- Kombinér ---
  parts <- c(stability, target_text, action)
  parts <- parts[nchar(parts) > 0]
  text <- paste(parts, collapse = " ")

  # --- Justér længde ---
  text <- adjust_fallback_length(text, min_chars, max_chars, n_points)

  return(text)
}


# Stabilitetstekst baseret på signalkombination (fra YAML)
fallback_stability_text <- function(spc_stats,
                                    has_runs,
                                    has_crossings,
                                    has_outliers) {
  texts <- load_spc_texts()
  if (length(texts) == 0) return("Processen er under vurdering.")

  key <- if (!has_runs && !has_crossings && !has_outliers) {
    "no_signals"
  } else if (has_runs && !has_crossings && !has_outliers) {
    "runs_only"
  } else if (!has_runs && has_crossings && !has_outliers) {
    "crossings_only"
  } else if (!has_runs && !has_crossings && has_outliers) {
    "outliers_only"
  } else if (has_runs && has_crossings && !has_outliers) {
    "runs_crossings"
  } else if (has_runs && !has_crossings && has_outliers) {
    "runs_outliers"
  } else if (!has_runs && has_crossings && has_outliers) {
    "crossings_outliers"
  } else {
    "all_signals"
  }

  pick_text(texts$stability[[key]], data = list(
    runs_actual = spc_stats$runs_actual,
    runs_expected = spc_stats$runs_expected,
    crossings_actual = spc_stats$crossings_actual,
    crossings_expected = spc_stats$crossings_expected,
    outliers_actual = spc_stats$outliers_actual
  ))
}


# Handlingsforslag baseret på stabilitet og mål (fra YAML)
fallback_action_text <- function(is_stable, has_target, at_target) {
  texts <- load_spc_texts()
  if (length(texts) == 0) return("")

  key <- if (is_stable && has_target && at_target) {
    "stable_at_target"
  } else if (is_stable && has_target && !at_target) {
    "stable_not_at_target"
  } else if (is_stable && !has_target) {
    "stable_no_target"
  } else if (!is_stable && has_target && at_target) {
    "unstable_at_target"
  } else if (!is_stable && has_target && !at_target) {
    "unstable_not_at_target"
  } else {
    "unstable_no_target"
  }

  pick_text(texts$action[[key]])
}


# Formatér målværdi til visning
# y_axis_unit bruges til at afgøre om værdien skal vises som procent
format_target_value <- function(x, y_axis_unit = NULL) {
  if (is.null(x) || is.na(x)) return("")

  # Konverter proportion til procent hvis relevant
  # x i [0, 1] → proportion, multiplicer med 100. x > 1 → allerede procent.
  if (!is.null(y_axis_unit) && y_axis_unit == "percent") {
    if (x >= 0 && x <= 1) {
      return(paste0(round(x * 100), "%"))
    } else if (x > 1) {
      return(paste0(round(x), "%"))
    }
  }

  if (x == round(x)) {
    as.character(as.integer(x))
  } else {
    format(round(x, 2), decimal.mark = ",", nsmall = 1)
  }
}


# Justér tekst til min/max længde
adjust_fallback_length <- function(text, min_chars, max_chars, n_points) {
  current <- nchar(text)
  texts <- load_spc_texts()

  if (current < min_chars && !is.null(n_points) && !is.na(n_points)) {
    padding <- pick_text(texts$padding$data_points,
                         data = list(n_points = n_points))
    text <- paste(text, padding)
    current <- nchar(text)
  }

  if (current < min_chars) {
    text <- paste(text, pick_text(texts$padding$generic))
    current <- nchar(text)
  }

  # Trim hvis for lang: find sidste punktum inden for max_chars
  if (current > max_chars) {
    truncated <- substr(text, 1, max_chars)
    last_period <- max(gregexpr("\\.", truncated)[[1]])
    if (last_period > min_chars) {
      text <- substr(text, 1, last_period)
    }
  }

  return(text)
}


# Cache-environment for YAML-tekster (indlæses kun én gang per session)
.spc_text_cache <- new.env(parent = emptyenv())

# Indlæs SPC-analysetekster fra YAML
load_spc_texts <- function() {
  if (!is.null(.spc_text_cache$texts)) {
    return(.spc_text_cache$texts)
  }

  yaml_path <- system.file("texts", "spc_analysis.yml",
                           package = "BFHcharts")
  if (yaml_path == "") {
    warning("spc_analysis.yml not found, using empty texts")
    return(list())
  }

  texts <- yaml::read_yaml(yaml_path)
  .spc_text_cache$texts <- texts
  return(texts)
}


# Vælg variant og erstat {placeholders} med værdier.
# Deterministisk: vælger altid første variant for reproducerbare rapporter.
pick_text <- function(variants, data = list()) {
  if (length(variants) == 0) return("")

  text <- variants[[1]]

  for (key in names(data)) {
    text <- gsub(
      paste0("\\{", key, "\\}"),
      as.character(data[[key]] %||% ""),
      text
    )
  }

  return(text)
}
