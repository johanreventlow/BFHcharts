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

  # Udtræk SPC statistikker (inkl. outliers fra qic_data)
  spc_stats <- extract_spc_stats_extended(x)

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
  safe_check <- function(x) !is.null(x) && length(x) > 0 && !is.na(x)

  has_runs <- safe_check(spc_stats$runs_actual) &&
    safe_check(spc_stats$runs_expected) &&
    spc_stats$runs_actual > spc_stats$runs_expected

  has_crossings <- safe_check(spc_stats$crossings_actual) &&
    safe_check(spc_stats$crossings_expected) &&
    spc_stats$crossings_actual < spc_stats$crossings_expected

  has_outliers <- safe_check(spc_stats$outliers_actual) &&
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
    # Alle datapunkter er identiske — SPC kan ikke anvendes
    cl_fmt <- if (!is.null(centerline) && !is.na(centerline)) {
      format_target_value(centerline, y_axis_unit = context$y_axis_unit)
    } else {
      "ukendt"
    }

    stability <- sprintf(
      paste0(
        "Niveauet ligger konstant p\u00e5 %s. Da alle datapunkter er ",
        "identiske, kan processen ikke vurderes med statistisk ",
        "proceskontrol."
      ),
      cl_fmt
    )

    # M\u00e5lvurdering og handling h\u00e5ndteres nedenfor som normalt
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

    if (abs(centerline - target_value) <= tolerance) {
      target_text <- sprintf("Niveauet ligger t\u00e6t p\u00e5 m\u00e5let (%s).", fmt)
      at_target <- TRUE
    } else if (centerline > target_value) {
      target_text <- sprintf("Niveauet ligger over m\u00e5let (%s).", fmt)
    } else {
      target_text <- sprintf("Niveauet ligger under m\u00e5let (%s).", fmt)
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


# Stabilitetstekst baseret på signalkombination
fallback_stability_text <- function(spc_stats,
                                    has_runs,
                                    has_crossings,
                                    has_outliers) {
  if (!has_runs && !has_crossings && !has_outliers) {
    paste0(
      "Processen er stabil og forudsigelig. Variationen er ",
      "naturlig, og der er ingen tegn p\u00e5 systematiske \u00e6ndringer i ",
      "hverken seriel\u00e6ngde, antal krydsninger eller kontrolgr\u00e6nser."
    )

  } else if (has_runs && !has_crossings && !has_outliers) {
    sprintf(
      paste0(
        "Der er tegn p\u00e5 et skift i procesniveauet. L\u00e6ngste serie ",
        "(%d) overstiger forventet maksimum (%d), hvilket indikerer at ",
        "processen har \u00e6ndret sig. Unders\u00f8g hvad der kan have ",
        "for\u00e5rsaget \u00e6ndringen."
      ),
      spc_stats$runs_actual, spc_stats$runs_expected
    )

  } else if (!has_runs && has_crossings && !has_outliers) {
    sprintf(
      paste0(
        "Der er tegn p\u00e5 gruppering i data. Antal krydsninger (%d) er ",
        "under forventet minimum (%d), hvilket tyder p\u00e5 at ",
        "datapunkterne klumper sig i stedet for at variere tilf\u00e6ldigt ",
        "omkring centrallinjen."
      ),
      spc_stats$crossings_actual, spc_stats$crossings_expected
    )

  } else if (!has_runs && !has_crossings && has_outliers) {
    sprintf(
      paste0(
        "Der er fundet %d observation(er) uden for kontrolgr\u00e6nserne. ",
        "Disse enkeltstående afvigelser b\u00f8r unders\u00f8ges for ",
        "s\u00e6rlige \u00e5rsager, da de kan skyldes us\u00e6dvanlige ",
        "h\u00e6ndelser eller m\u00e5lefejl."
      ),
      spc_stats$outliers_actual
    )

  } else if (has_runs && has_crossings && !has_outliers) {
    sprintf(
      paste0(
        "Processen viser systematisk ustabilitet. B\u00e5de seriel\u00e6ngde ",
        "(%d > %d) og antal krydsninger (%d < %d) afviger fra det ",
        "forventede, hvilket peger p\u00e5 en grundl\u00e6ggende ",
        "proces\u00e6ndring."
      ),
      spc_stats$runs_actual, spc_stats$runs_expected,
      spc_stats$crossings_actual, spc_stats$crossings_expected
    )

  } else if (has_runs && !has_crossings && has_outliers) {
    sprintf(
      paste0(
        "Processen viser et niveauskift (seriel\u00e6ngde %d > %d) og %d ",
        "observation(er) uden for kontrolgr\u00e6nserne. Unders\u00f8g om ",
        "niveauskiftet og de ekstreme v\u00e6rdier har samme underliggende ",
        "\u00e5rsag."
      ),
      spc_stats$runs_actual, spc_stats$runs_expected,
      spc_stats$outliers_actual
    )

  } else if (!has_runs && has_crossings && has_outliers) {
    sprintf(
      paste0(
        "Processen viser gruppering (krydsninger %d < %d) og %d ",
        "observation(er) uden for kontrolgr\u00e6nserne. Dette m\u00f8nster ",
        "kan indikere at processen p\u00e5virkes af skiftende betingelser."
      ),
      spc_stats$crossings_actual, spc_stats$crossings_expected,
      spc_stats$outliers_actual
    )

  } else {
    # Alle tre signaler
    sprintf(
      paste0(
        "Processen er ustabil med flere samtidige signaler: niveauskift ",
        "(seriel\u00e6ngde %d > %d), gruppering (krydsninger %d < %d) og ",
        "%d observation(er) uden for kontrolgr\u00e6nserne. En grundig ",
        "analyse anbefales."
      ),
      spc_stats$runs_actual, spc_stats$runs_expected,
      spc_stats$crossings_actual, spc_stats$crossings_expected,
      spc_stats$outliers_actual
    )
  }
}


# Handlingsforslag baseret på stabilitet og mål
fallback_action_text <- function(is_stable, has_target, at_target) {
  if (is_stable && has_target && at_target) {
    paste0(
      "Forts\u00e6t den nuv\u00e6rende praksis og overv\u00e5g processen ",
      "l\u00f8bende for at fastholde det gode niveau."
    )

  } else if (is_stable && has_target && !at_target) {
    paste0(
      "Processen er stabil men n\u00e5r ikke m\u00e5let. Forbedring ",
      "kr\u00e6ver en bevidst \u00e6ndring af processen \u2013 den ",
      "nuv\u00e6rende praksis vil levere samme resultat."
    )

  } else if (is_stable && !has_target) {
    paste0(
      "Overvej at fasts\u00e6tte et m\u00e5l for indikatoren for at ",
      "kunne vurdere om det aktuelle niveau er tilfredsstillende og om ",
      "der er behov for forbedring."
    )

  } else if (!is_stable && has_target && at_target) {
    paste0(
      "Selvom m\u00e5let aktuelt er opfyldt, er processen ustabil. ",
      "Identific\u00e9r og adress\u00e9r \u00e5rsagerne til variationen ",
      "for at sikre at niveauet kan fastholdes."
    )

  } else if (!is_stable && has_target && !at_target) {
    paste0(
      "Priorit\u00e9r at identificere og fjerne de s\u00e6rlige ",
      "\u00e5rsager til variationen f\u00f8r yderligere ",
      "forbedringstiltag iv\u00e6rks\u00e6ttes."
    )

  } else {
    # Ustabil, intet mål
    paste0(
      "Identific\u00e9r og unders\u00f8g \u00e5rsagerne til den ",
      "us\u00e6dvanlige variation. N\u00e5r processen er bragt under ",
      "kontrol, kan der fasts\u00e6ttes et realistisk m\u00e5l."
    )
  }
}


# Formatér målværdi til visning
# y_axis_unit bruges til at afgøre om værdien skal vises som procent
format_target_value <- function(x, y_axis_unit = NULL) {
  if (is.null(x) || is.na(x)) return("")

  # Konverter proportion til procent hvis relevant
  if (!is.null(y_axis_unit) && y_axis_unit == "percent" && x <= 1 && x > 0) {
    return(paste0(round(x * 100), "%"))
  }
  if (!is.null(y_axis_unit) && y_axis_unit == "percent" && x > 1) {
    return(paste0(round(x), "%"))
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

  # Pad hvis for kort
  if (current < min_chars) {
    if (!is.null(n_points) && !is.na(n_points)) {
      padding <- sprintf(
        "Analysen er baseret p\u00e5 %d datapunkter.", n_points
      )
      text <- paste(text, padding)
      current <- nchar(text)
    }
  }

  # Pad med generisk tekst hvis stadig for kort
  if (current < min_chars) {
    extra <- paste0(
      "Fortsat monitorering anbefales for at f\u00f8lge processens ",
      "udvikling over tid."
    )
    text <- paste(text, extra)
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
