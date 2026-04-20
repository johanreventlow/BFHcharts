# SPC Analysis Functions
#
# Funktioner til automatisk SPC-analyse og tekstgenerering.
# Disse funktioner bruges til at generere analysetekster til PDF-eksport.


# ---------------------------------------------------------------------------
# Interne helpers (resolve_target, pluralize_da, ensure_within_max)
# ---------------------------------------------------------------------------

# Parse metadata$target til numerisk værdi + optional retning.
# Genbruger parse_target_input() fra utils_label_helpers.R for at undgå
# duplikeret parser-logik. Returnerer altid en liste med value/direction/display.
#
# Direction-mapping:
#   >=, ≥, ↑  → "higher" (higher is better)
#   <=, ≤, ↓  → "lower"  (lower is better)
#   >, <      → "higher" / "lower" (når efterfulgt af tal)
#   ingen op. → NULL (værdineutral)
resolve_target <- function(target_input) {
  empty <- list(value = NA_real_, direction = NULL, display = "")
  if (is.null(target_input)) return(empty)

  # Numerisk input: bagudkompatibelt — ingen retning
  if (is.numeric(target_input)) {
    return(list(value = as.numeric(target_input), direction = NULL, display = ""))
  }

  if (!is.character(target_input) || length(target_input) == 0 ||
      nchar(trimws(target_input)) == 0) {
    return(empty)
  }

  # Normalisér Unicode-operatorer til ASCII før parsing, så parse_target_input()
  # (der er testet mod ASCII-input fra chart-labels) kan genbruges uændret.
  # ≤ → <=, ≥ → >=, ↑ → >, ↓ → <
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

  # Ekstraher numerisk værdi fra value-delen.
  # Accepterer både dansk komma og engelsk punktum som decimaltegn.
  raw_value <- parsed$value
  clean <- gsub(",", ".", raw_value)
  clean <- gsub("[^0-9.\\-]", "", clean)
  val <- suppressWarnings(as.numeric(clean))
  if (length(val) == 0) val <- NA_real_

  list(value = val, direction = direction, display = target_input)
}


# Vælg ental eller flertal ud fra n. n == 1 → singular, alt andet → plural.
# NA og NULL behandles som flertal (neutral default).
pluralize_da <- function(n, singular, plural) {
  if (is.null(n) || length(n) == 0 || is.na(n)) return(plural)
  if (n == 1) singular else plural
}


# Garantér at tekst ikke overskrider max_chars. Trim ved sidste sætnings- eller
# klausulgrænse (punktum, komma) før grænsen. Undgå at klippe midt i et ord.
ensure_within_max <- function(text, max_chars) {
  if (is.null(text) || is.na(text)) return("")
  if (nchar(text) <= max_chars) return(text)

  cut <- substr(text, 1, max_chars)

  # Prøv først at trimme ved sidste punktum-grænse
  last_period <- max(
    gregexpr("\\.\\s", cut, perl = TRUE)[[1]],
    gregexpr("\\.$", cut, perl = TRUE)[[1]]
  )
  if (is.finite(last_period) && last_period > 0) {
    return(trimws(substr(text, 1, last_period)))
  }

  # Ellers trim ved sidste komma
  last_comma <- max(gregexpr(",\\s", cut, perl = TRUE)[[1]])
  if (is.finite(last_comma) && last_comma > 0) {
    trimmed <- trimws(substr(text, 1, last_comma - 1))
    if (!grepl("[.!?]$", trimmed)) trimmed <- paste0(trimmed, ".")
    return(trimmed)
  }

  # Sidste udvej: trim ved sidste space
  last_space <- max(gregexpr("\\s", cut, perl = TRUE)[[1]])
  if (is.finite(last_space) && last_space > 0) {
    trimmed <- trimws(substr(text, 1, last_space - 1))
    if (!grepl("[.!?]$", trimmed)) trimmed <- paste0(trimmed, ".")
    return(trimmed)
  }

  # Fallback (ord uden spaces): hård trim
  substr(text, 1, max_chars)
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
#'   - `target_value`: Numeric target value (NA if absent)
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
    stop("x must be a bfh_qic_result object from bfh_qic()")
  }

  # Resolve target-input til value + retning (genbruger parse_target_input)
  target_info <- resolve_target(metadata$target)

  # Udtræk SPC statistikker (inkl. outliers fra qic_data)
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
  # has_signals skal afspejle om AKTUELLE signaler eksisterer — brug samme
  # recent-count som analyseteksten (fallback til outliers_actual hvis ukendt).
  outliers_for_flag <- spc_stats$outliers_recent_count %||% spc_stats$outliers_actual
  if (is_valid_scalar(outliers_for_flag) && outliers_for_flag > 0) {
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

    has_signals = has_signals,

    # Bruger-metadata
    data_definition = metadata$data_definition,
    target_value = target_info$value,
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
#'   - `NULL` (default): Auto-detect BFHllm availability
#'   - `TRUE`: Use AI (requires BFHllm package)
#'   - `FALSE`: Use standard texts only
#' @param min_chars Minimum characters in AI-generated output. Default 300.
#' @param max_chars Maximum characters in AI-generated output. Default 375.
#' @param target_tolerance Fractional tolerance for `at_target` classification
#'   when `target_direction` is unknown (default 0.05 = 5%). Ignored when the
#'   user provides `metadata$target` with an operator (retning er da kendt).
#' @param texts_loader Function that returns SPC analysis text templates.
#'   Defaults to [load_spc_texts()]. Primarily intended for tests/mocking.
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
                                   max_chars = 375,
                                   target_tolerance = 0.05,
                                   texts_loader = load_spc_texts) {
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
                                                 max_chars = max_chars,
                                                 target_tolerance = target_tolerance,
                                                 texts_loader = texts_loader)

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
                                      max_chars = max_chars,
                                      target_tolerance = target_tolerance,
                                      texts_loader = texts_loader)
  return(analysis)
}


# Intern funktion: Byg komplet fallback-analysetekst
# Allokerer tegnbudget til stability/target/action dele
# og vælger passende variant for hver del. Når context$target_direction
# er non-NULL (udledt fra fx "<= 2,5"), bruges retningsbevidst mål-
# vurdering (goal_met/goal_not_met) i stedet for værdineutral
# at/over/under. ensure_within_max garanterer max_chars-grænsen.
build_fallback_analysis <- function(context,
                                    min_chars = 300,
                                    max_chars = 375,
                                    target_tolerance = 0.05,
                                    texts_loader = load_spc_texts) {
  spc_stats <- context$spc_stats
  target_value <- context$target_value
  target_direction <- context$target_direction
  centerline <- context$centerline
  n_points <- context$n_points

  # --- Detect signaler (sikker mod NULL og NA) ---
  has_runs <- is_valid_scalar(spc_stats$runs_actual) &&
    is_valid_scalar(spc_stats$runs_expected) &&
    spc_stats$runs_actual > spc_stats$runs_expected

  has_crossings <- is_valid_scalar(spc_stats$crossings_actual) &&
    is_valid_scalar(spc_stats$crossings_expected) &&
    spc_stats$crossings_actual < spc_stats$crossings_expected

  # Brug recent_count (seneste 6 obs) så analyseteksten kun beskriver AKTUELLE
  # outliers. Fald tilbage til outliers_actual når kun summary-baserede stats
  # er tilgængelige.
  outliers_for_text <- spc_stats$outliers_recent_count %||% spc_stats$outliers_actual
  has_outliers <- is_valid_scalar(outliers_for_text) &&
    outliers_for_text > 0

  is_stable <- !has_runs && !has_crossings && !has_outliers

  # --- Detect ingen variation (alle SPC-stats er NA eller NULL) ---
  runs_missing <- is.null(spc_stats$runs_actual) ||
    length(spc_stats$runs_actual) == 0 ||
    is.na(spc_stats$runs_actual)
  crossings_missing <- is.null(spc_stats$crossings_actual) ||
    length(spc_stats$crossings_actual) == 0 ||
    is.na(spc_stats$crossings_actual)
  no_variation <- runs_missing && crossings_missing

  # --- Target-tilstand (afgør budget-fordelingen) ---
  has_target <- !is.null(target_value) && !is.na(target_value) &&
    is.numeric(target_value) &&
    !is.null(centerline) && !is.na(centerline)

  # --- Budget-allokering ---
  # Med target: stability ~50%, target ~25%, action ~25%.
  # Uden target: target-budget realloceres til stability (65%) + action (35%).
  if (has_target) {
    stability_budget <- floor(max_chars * 0.50)
    target_budget <- floor(max_chars * 0.25)
    action_budget <- max_chars - stability_budget - target_budget
  } else {
    stability_budget <- floor(max_chars * 0.65)
    target_budget <- 0L
    action_budget <- max_chars - stability_budget
  }

  if (!is.function(texts_loader)) {
    stop("texts_loader must be a function", call. = FALSE)
  }
  texts <- texts_loader()
  # outliers_actual i placeholder_data bruger recent_count-værdien, så YAML-
  # skabelonernes {outliers_actual} placeholder også følger "seneste 6 obs"-
  # reglen. outliers_word giver korrekt dansk ental/flertal for 1 vs n.
  outliers_n <- if (is_valid_scalar(outliers_for_text)) outliers_for_text else 0L
  placeholder_data <- list(
    runs_actual = spc_stats$runs_actual,
    runs_expected = spc_stats$runs_expected,
    crossings_actual = spc_stats$crossings_actual,
    crossings_expected = spc_stats$crossings_expected,
    outliers_actual = outliers_for_text,
    outliers_word = pluralize_da(outliers_n, "observation", "observationer")
  )

  # --- 1. Stabilitetstekst ---
  if (no_variation) {
    cl_fmt <- if (!is.null(centerline) && !is.na(centerline)) {
      format_target_value(centerline, y_axis_unit = context$y_axis_unit)
    } else {
      "ukendt"
    }
    stability <- pick_text(
      texts$stability$no_variation,
      data = list(centerline = cl_fmt),
      budget = stability_budget
    )
  } else {
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
    stability <- pick_text(texts$stability[[key]],
                           data = placeholder_data,
                           budget = stability_budget)
  }

  # --- 2. Målvurdering ---
  target_text <- ""
  at_target <- FALSE   # bruges af værdineutral action-sti
  goal_met <- FALSE    # bruges af retningsbevidst action-sti

  if (has_target) {
    # Foretræk display-streng fra input (fx "<= 2,5"), ellers format numerisk
    display_target <- if (!is.null(context$target_display) &&
                          nzchar(context$target_display)) {
      context$target_display
    } else {
      format_target_value(target_value, y_axis_unit = context$y_axis_unit)
    }

    if (!is.null(target_direction)) {
      # === RETNINGSBEVIDST LOGIK ===
      # "higher" → CL skal være >= target for at opfylde målet.
      # "lower"  → CL skal være <= target.
      goal_met <- switch(target_direction,
        "higher" = centerline >= target_value,
        "lower"  = centerline <= target_value,
        FALSE
      )
      key <- if (goal_met) "goal_met" else "goal_not_met"
      target_text <- pick_text(texts$target[[key]],
                               data = list(target = display_target),
                               budget = target_budget)
    } else {
      # === VÆRDINEUTRAL LOGIK (bagudkompatibel) ===
      tolerance <- max(abs(target_value) * target_tolerance, 0.01)
      if (abs(centerline - target_value) <= tolerance) {
        target_text <- pick_text(texts$target$at_target,
                                 data = list(target = display_target),
                                 budget = target_budget)
        at_target <- TRUE
      } else if (centerline > target_value) {
        target_text <- pick_text(texts$target$over_target,
                                 data = list(target = display_target),
                                 budget = target_budget)
      } else {
        target_text <- pick_text(texts$target$under_target,
                                 data = list(target = display_target),
                                 budget = target_budget)
      }
    }
  }

  # --- 3. Handlingsforslag ---
  if (has_target && !is.null(target_direction)) {
    # Retningsbevidste action-keys
    action_key <- if (is_stable && goal_met) {
      "stable_goal_met"
    } else if (is_stable && !goal_met) {
      "stable_goal_not_met"
    } else if (!is_stable && goal_met) {
      "unstable_goal_met"
    } else {
      "unstable_goal_not_met"
    }
  } else if (has_target) {
    # Værdineutrale action-keys (bagudkompatible)
    action_key <- if (is_stable && at_target) {
      "stable_at_target"
    } else if (is_stable && !at_target) {
      "stable_not_at_target"
    } else if (!is_stable && at_target) {
      "unstable_at_target"
    } else {
      "unstable_not_at_target"
    }
  } else {
    action_key <- if (is_stable) "stable_no_target" else "unstable_no_target"
  }
  action <- pick_text(texts$action[[action_key]], budget = action_budget)

  # --- Kombinér ---
  parts <- c(stability, target_text, action)
  parts <- parts[nchar(parts) > 0]
  text <- paste(parts, collapse = " ")

  # --- Garantér max_chars-grænsen (trim ved sætnings-/klausulgrænse) ---
  text <- ensure_within_max(text, max_chars)

  # --- Padding hvis under minimum ---
  text <- pad_to_minimum(text, min_chars, n_points, texts, max_chars)

  return(text)
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

  if (is_effective_integer(x)) {
    as.character(as.integer(x))
  } else {
    format(round(x, 2), decimal.mark = ",", nsmall = 1)
  }
}


# Tilføj padding-tekst hvis teksten er under minimumlængde.
# max_chars sikrer at padding ikke sprænger det absolutte loft.
pad_to_minimum <- function(text, min_chars, n_points, texts, max_chars = Inf) {
  if (nchar(text) >= min_chars) return(text)

  # Plads til padding: respektér både min og max
  available <- max_chars - nchar(text) - 1L  # -1 for space-separator

  if (!is.null(n_points) && !is.na(n_points) && available > 0) {
    padding <- pick_text(texts$padding$data_points,
                         data = list(n_points = n_points),
                         budget = min(min_chars - nchar(text), available))
    if (nchar(padding) > 0 && nchar(text) + nchar(padding) + 1L <= max_chars) {
      text <- paste(text, padding)
    }
  }

  available <- max_chars - nchar(text) - 1L
  if (nchar(text) < min_chars && available > 0) {
    padding <- pick_text(texts$padding$generic,
                         budget = min(min_chars - nchar(text), available))
    if (nchar(padding) > 0 && nchar(text) + nchar(padding) + 1L <= max_chars) {
      text <- paste(text, padding)
    }
  }

  text
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


# Vælg tekstvariant baseret på pladsbudget og erstat {placeholders}.
# Named variants (short/standard/detailed): vælg længste der passer.
# Bagudkompatibel med gammelt format (liste af strenge).
pick_text <- function(variants, data = list(), budget = Inf) {
  if (length(variants) == 0) return("")

  # Bagudkompatibilitet: gammelt format er en unamed liste af strenge
  if (is.null(names(variants)) && is.character(variants[[1]])) {
    text <- variants[[1]]
    return(substitute_placeholders(text, data))
  }

  # Nyt format: named list (short, standard, detailed)
  # Prøv fra længst til kortest, vælg den længste der passer i budgettet
  candidates <- c("detailed", "standard", "short")
  for (candidate in candidates) {
    if (!is.null(variants[[candidate]])) {
      text <- substitute_placeholders(variants[[candidate]], data)
      if (nchar(text) <= budget) return(text)
    }
  }

  # Fallback: korteste tilgængelige variant (selv hvis den overstiger budget)
  available <- intersect(rev(candidates), names(variants))
  if (length(available) > 0) {
    return(substitute_placeholders(variants[[available[1]]], data))
  }

  return("")
}


# Erstat {placeholders} med faktiske værdier i en tekststreng
substitute_placeholders <- function(text, data = list()) {
  for (key in names(data)) {
    text <- gsub(
      paste0("\\{", key, "\\}"),
      as.character(data[[key]] %||% ""),
      text
    )
  }
  text
}
