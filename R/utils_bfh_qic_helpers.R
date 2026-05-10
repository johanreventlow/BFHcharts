# ============================================================================
# INTERNE HELPERS TIL bfh_qic()
# ============================================================================
# Disse helpers isolerer Anhoej signal-postprocessering og return-routing
# fra bfh_qic()-kroppen. Se openspec/changes/refactor-bfh_qic-orchestrator.

# Valider position-indekser (part / freeze / exclude) som heltal-positioner
# i data. Strengere end validate_numeric_parameter:
# - Heltal: x == floor(x) (numerisk fra parent.frame() er ofte double)
# - Bounds: [min, max] inkl. begge ender
# - Unik (require_unique): ingen dubletter
# - Sorteret (require_sorted): strengt voksende
# - Scalar (require_scalar): laengde 1
#
# Brugt i validate_bfh_qic_inputs():
#   part:    require_sorted = TRUE, require_unique = TRUE, min = 2, max = nrow
#   freeze:  require_scalar = TRUE, require_unique = TRUE, min = 1, max = nrow-1
#   exclude: require_unique = TRUE, min = 1, max = nrow
#' @keywords internal
#' @noRd
validate_position_indices <- function(x,
                                      name,
                                      nrow_data,
                                      require_sorted = FALSE,
                                      require_unique = TRUE,
                                      require_scalar = FALSE,
                                      min = 1L,
                                      max = nrow_data) {
  if (is.null(x)) {
    return(invisible(NULL))
  }
  if (!is.numeric(x) || anyNA(x)) {
    stop(
      sprintf(
        "%s must be numeric without NAs, got: %s",
        name, paste(x, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (require_scalar && length(x) != 1L) {
    stop(
      sprintf("%s must be a single integer value, got length %d", name, length(x)),
      call. = FALSE
    )
  }
  # Heltals-tjek: tillader 3.0 men ikke 3.5
  if (any(x != floor(x))) {
    stop(
      sprintf(
        "%s must contain only integer position indices (got non-integer: %s)",
        name, paste(x[x != floor(x)], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (any(x < min) || any(x > max)) {
    # Bevar bagudkompatibel ordlyd ("positive integer"/"positive integers")
    # som testes af eksisterende test-security-bounds-validation.R
    plural_phrase <- if (require_scalar) {
      sprintf("%s position must be a positive integer", name)
    } else {
      sprintf("%s positions must be positive integers", name)
    }
    stop(
      sprintf(
        "%s within data bounds (%d-%d), got: %s",
        plural_phrase, as.integer(min), as.integer(max), paste(x, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (require_unique && any(duplicated(x))) {
    stop(
      sprintf(
        "%s must contain unique values (got duplicates: %s)",
        name,
        paste(x[duplicated(x)], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (require_sorted && length(x) > 1L && any(diff(x) <= 0)) {
    stop(
      sprintf(
        "%s must be strictly increasing (sorted ascending), got: %s",
        name, paste(x, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

# Muffle known harmless ggplot2/scales/BFHtheme warnings during plot generation
# and label placement. Only explicit, anchored patterns are muffled -- no
# unbounded substring matches like "numeric" or "datetime" that would hide
# data-quality issues from clinical users.
#
# Pattern sources:
#   scale_[xy]_(continuous|date|datetime).* -- ggplot2/scales: scale warnings
#     when rows are removed / axes are empty (e.g. scale_x_date: Removed 3 rows)
#   font family.*not found in PostScript font database -- BFHtheme: Mari font
#     not installed; registered via .onLoad(), but grDevices lookup can
#     still trigger this per text element
#   Removed [0-9]+ rows containing -- ggplot2 geom_*: missing values
#     removed at render time (e.g. geom_point, geom_line)
#
# Genuine warnings (e.g. "NAs introduced by coercion to numeric",
# "non-numeric argument to binary operator") are propagated unchanged to caller.
#' @keywords internal
.muffle_expected_warnings <- function(expr) {
  withCallingHandlers(
    expr,
    warning = function(w) {
      msg <- conditionMessage(w)
      if (grepl(
        paste0(
          "scale_[xy]_(continuous|date|datetime).*",
          "|font family.*not found in PostScript font database",
          "|Removed [0-9]+ rows containing"
        ),
        msg,
        ignore.case = TRUE
      )) {
        invokeRestart("muffleWarning")
      }
    }
  )
}

#' Normaliser anhoej.signal i qic_data
#'
#' Deriverer en altid-boolean `anhoej.signal`-kolonne fra qicharts2-output,
#' uanset hvilke signal-kolonner der er til stede.
#'
#' Fallback-priority:
#' `anhoej.signal` -> `anhoej.signals` -> `runs.signal | crossings.signal`
#' -> `runs.signal` -> `FALSE`
#'
#' @param qic_data data.frame from `qicharts2::qic()`, or NULL
#' @return qic_data with a normalised `anhoej.signal` (logical, may be NA when
#'   the series is too short for reliable Anhoej evaluation),
#'   or NULL if input is NULL
#' @keywords internal
#' @noRd
add_anhoej_signal <- function(qic_data) {
  if (is.null(qic_data)) {
    return(NULL)
  }

  cols <- names(qic_data)

  if ("anhoej.signal" %in% cols) {
    qic_data$anhoej.signal <- as.logical(qic_data$anhoej.signal)
  } else if ("anhoej.signals" %in% cols) {
    qic_data$anhoej.signal <- as.logical(qic_data$anhoej.signals)
  } else if ("runs.signal" %in% cols && "crossings.signal" %in% cols) {
    qic_data$anhoej.signal <- as.logical(qic_data$runs.signal | qic_data$crossings.signal)
  } else if ("runs.signal" %in% cols) {
    qic_data$anhoej.signal <- as.logical(qic_data$runs.signal)
  } else {
    qic_data$anhoej.signal <- rep(FALSE, nrow(qic_data))
  }

  # NA is preserved deliberately -- signals that the series is too short for evaluation.
  # Downstream code (plot_core.R, utils_qic_summary.R) handles NA explicitly.
  qic_data
}

#' Byg bfh_qic() returvaerdi
#'
#' Returnerer enten `bfh_qic_result` S3-objekt (default) eller raa qic_data
#' data.frame (legacy `return.data = TRUE`).
#'
#' @param qic_data data.frame med raa qic-beregninger
#' @param plot ggplot2-objekt
#' @param summary_result data.frame med SPC-summary
#' @param config liste med konfigurationsparametre
#' @param return.data logical
#' @return En af: `bfh_qic_result` S3-objekt (default) eller `qic_data` data.frame
#' @keywords internal
#' @noRd
build_bfh_qic_return <- function(qic_data, plot, summary_result, config,
                                 return.data) {
  # Mark whether the centerline was user-supplied (vs data-estimated).
  # Surfaces in PDF caveat + downstream consumers without polluting the
  # column-iteration surface (lapply(summary, ...) patterns unaffected).
  cl_user_supplied <- !is.null(config$cl)
  attr(summary_result, "cl_user_supplied") <- cl_user_supplied

  if (return.data) {
    # Attach to raw data.frame too for parity with the S3 path.
    attr(qic_data, "cl_user_supplied") <- cl_user_supplied
    return(qic_data)
  } else {
    return(
      new_bfh_qic_result(
        plot = plot,
        summary = summary_result,
        qic_data = qic_data,
        config = config
      )
    )
  }
}

# ============================================================================
# NSE KOLONNE-NAVN VALIDATOR
# ============================================================================

#' Validate and normalise an NSE column expression to a symbol
#'
#' Takes an already-captured expression (from `substitute()` in bfh_qic()'s scope)
#' and validates that it is a simple identifier. Supports direct symbols
#' (month) and quoted symbols (quote(month)) for programmatic use.
#'
#' This function does NOT itself call `substitute()` -- it MUST happen in bfh_qic().
#'
#' @param col_expr Et R-udtryk fanget via substitute() i bfh_qic()
#' @param param_name Parameternavn til fejlbesked
#' @return as.name() symbol klar til NSE-videregivelse
#' @keywords internal
#' @noRd
validate_column_name_expr <- function(col_expr, param_name) {
  normalized_expr <- col_expr
  if (is.call(col_expr) &&
    identical(col_expr[[1]], as.name("quote")) &&
    length(col_expr) == 2) {
    normalized_expr <- col_expr[[2]]
  }
  col_str <- deparse(col_expr)
  # Unicode letter class \p{L} accepts Danish (aeoeaa) and other non-ASCII
  # letters in column names. Continuation chars: letters, digits, dot, underscore.
  # Using perl = TRUE for \p{L} / \p{N} support.
  valid_pattern <- "^\\p{L}[\\p{L}\\p{N}._]*$"
  col_char <- if (is.symbol(normalized_expr)) as.character(normalized_expr) else ""
  if (!is.symbol(normalized_expr) ||
    !grepl(valid_pattern, col_char, perl = TRUE)) {
    stop(sprintf(
      "%s must be a simple column name, got: %s\nAvoid special characters (other than letters, digits, dot, underscore), spaces, or expressions",
      param_name, col_str
    ), call. = FALSE)
  }
  as.name(as.character(normalized_expr))
}

# ============================================================================
# VALIDER bfh_qic() INPUTS
# ============================================================================

#' Valider inputs til bfh_qic()
#'
#' Konsoliderer alle input-valideringer fra bfh_qic()-kroppen i en enkelt
#' funktion. NSE-udtryk (x_expr, y_expr, n_expr) skal vaere fanget i
#' bfh_qic() via substitute() BEFORE this call -- never inside this helper.
#'
#' @param data Data frame med maalinger
#' @param chart_type Charttype-streng
#' @param y_axis_unit Y-akse enhed
#' @param x_expr Symbol for x-kolonne (allerede valideret via validate_column_name)
#' @param y_expr Symbol for y-kolonne (allerede valideret via validate_column_name)
#' @param n_expr Symbol for n-kolonne eller NULL
#' @param part Vektor af fase-positioner eller NULL
#' @param freeze Freeze-position eller NULL
#' @param base_size Base font size
#' @param width Plot width or NULL
#' @param height Plot height or NULL
#' @param exclude Exclusion positions or NULL
#' @param cl User-defined centerline or NULL
#' @param multiply Multiplier
#' @param agg_fun_supplied Logical -- whether agg.fun is explicitly supplied by user
#' @param agg.fun Aggregeringsfunktionsstreng
#' @param return.data Logical
#' @param plot_margin Margin-objekt eller numerisk vektor
#' @param target_value Numerisk maalvaerdi eller NULL
#' @param y_expr_char Karakterstreng af y-kolonnenavnet (til denominator-validering)
#' @param n_expr_char Karakterstreng af n-kolonnenavnet eller NULL
#' @param x_expr_char Karakterstreng af x-kolonnenavnet eller NULL
#' @param notes Notats-vektor eller NULL
#' @param target_text Target-label-tekst eller NULL
#' @return Normaliseret `agg.fun`-vaerdi (NULL hvis ikke angivet, ellers matchet streng)
#' @keywords internal
#' @noRd
validate_bfh_qic_inputs <- function(data,
                                    chart_type,
                                    y_axis_unit,
                                    part,
                                    freeze,
                                    base_size,
                                    width,
                                    height,
                                    exclude,
                                    cl,
                                    multiply,
                                    agg_fun_supplied,
                                    agg.fun,
                                    return.data,
                                    plot_margin,
                                    target_value,
                                    y_expr_char,
                                    n_expr_char,
                                    x_expr_char = NULL,
                                    notes = NULL,
                                    target_text = NULL) {
  if (!is.data.frame(data)) {
    stop("data must be a data frame", call. = FALSE)
  }

  if (nrow(data) == 0L) {
    stop(
      "'data' is empty; bfh_qic() requires at least one row",
      call. = FALSE
    )
  }

  # x column must exist and be of an x-axis-compatible type. Early
  # error prevents cryptic qicharts2 failures on e.g. character input.
  if (!is.null(x_expr_char)) {
    if (!x_expr_char %in% names(data)) {
      stop(
        sprintf("Column '%s' not found in data", x_expr_char),
        call. = FALSE
      )
    }
    x_data <- data[[x_expr_char]]
    if (!(is.numeric(x_data) || inherits(x_data, "Date") ||
      inherits(x_data, "POSIXct") || is.integer(x_data))) {
      stop(
        sprintf(
          "Column '%s' has class '%s'. x must be numeric, Date, or POSIXct. Use as.Date() or as.POSIXct() to convert.",
          x_expr_char, class(x_data)[1]
        ),
        call. = FALSE
      )
    }
  }

  # y column must be numeric (or integer). Early error prevents
  # cryptic qicharts2 chain failures on e.g. character/factor input.
  if (!is.null(y_expr_char) && y_expr_char %in% names(data)) {
    y_data <- data[[y_expr_char]]
    if (!is.numeric(y_data)) {
      stop(
        sprintf(
          "column '%s' (y) must be numeric, got: %s",
          y_expr_char, paste(class(y_data), collapse = "/")
        ),
        call. = FALSE
      )
    }

    # Cycle 01 finding E8: count-style charts (c, g, t, p, pp, u, up)
    # require non-negative y. qicharts2 silently rendered negative counts
    # without warning, producing statistically meaningless charts that
    # appeared valid to clinicians. Catch at validation time with a
    # clear chart-type-aware error.
    count_chart_types <- c("c", "g", "t", "p", "pp", "u", "up")
    if (chart_type %in% count_chart_types) {
      neg_idx <- which(!is.na(y_data) & y_data < 0)
      if (length(neg_idx) > 0L) {
        stop(
          sprintf(
            paste0(
              "column '%s' (y) contains negative values at row(s): %s. ",
              "Chart type '%s' requires non-negative counts/proportions."
            ),
            y_expr_char,
            paste(utils::head(neg_idx, 5), collapse = ", "),
            chart_type
          ),
          call. = FALSE
        )
      }
    }
  }

  # notes must be a character vector (or all-NA) with same length as data.
  if (!is.null(notes)) {
    if (!is.character(notes) && !all(is.na(notes))) {
      stop("`notes` must be a character vector or NULL", call. = FALSE)
    }
    if (length(notes) != nrow(data)) {
      stop(
        sprintf(
          "`notes` must have same length as data (got %d, expected %d)",
          length(notes), nrow(data)
        ),
        call. = FALSE
      )
    }
  }

  # target_text must be a single character string (scalar) when provided.
  if (!is.null(target_text)) {
    if (!is.character(target_text) || length(target_text) != 1L) {
      stop(
        "`target_text` must be a single character string or NULL",
        call. = FALSE
      )
    }
  }

  if (!chart_type %in% CHART_TYPES_EN) {
    stop(sprintf(
      "chart_type must be one of: %s",
      paste(CHART_TYPES_EN, collapse = ", ")
    ), call. = FALSE)
  }

  valid_units <- Y_AXIS_UNITS
  if (!y_axis_unit %in% valid_units) {
    stop(sprintf(
      "y_axis_unit must be one of: %s",
      paste(valid_units, collapse = ", ")
    ), call. = FALSE)
  }

  validate_position_indices(part, "part", nrow(data),
    require_sorted = TRUE, require_unique = TRUE,
    min = 2L, max = nrow(data)
  )
  # Cycle 01 finding E7: previously max = max(nrow(data) - 1L, 1L), which
  # admitted freeze = 1 on 1-row data (max(0, 1) = 1, freeze == nrow). That
  # left zero rows after the baseline and produced a cryptic qicharts2
  # error downstream. Remove the floor so 1-row data fails cleanly with
  # the validator's own bounds-message ("freeze must be within data bounds").
  validate_position_indices(freeze, "freeze", nrow(data),
    require_sorted = FALSE, require_unique = TRUE,
    require_scalar = TRUE,
    min = 1L, max = nrow(data) - 1L
  )

  # Warn if freeze baseline is too short for reliable signal detection
  if (!is.null(freeze) && freeze < MIN_BASELINE_N) {
    warning(
      "freeze = ", freeze, ": baseline has fewer than ", MIN_BASELINE_N,
      " observations. Control limits are statistically unreliable.",
      call. = FALSE
    )
  }

  # Warn for phases with too few observations
  if (!is.null(part)) {
    n_total <- nrow(data)
    # Compute start positions for each phase
    phase_starts <- c(1L, as.integer(part) + 1L)
    phase_ends <- c(as.integer(part), n_total)
    phase_sizes <- phase_ends - phase_starts + 1L
    short_phases <- which(phase_sizes < MIN_BASELINE_N)
    if (length(short_phases) > 0) {
      warning(
        "Phase(s) ", paste(short_phases, collapse = ", "),
        " have fewer than ", MIN_BASELINE_N,
        " observations. Control limits may be statistically unreliable.",
        call. = FALSE
      )
    }
  }
  validate_numeric_parameter(base_size, "base_size",
    min = 1, max = FONT_SCALING_CONFIG$max_size,
    allow_null = FALSE, len = 1
  )
  validate_numeric_parameter(width, "width",
    min = 0.1, max = 3000,
    allow_null = TRUE, len = 1
  )
  validate_numeric_parameter(height, "height",
    min = 0.1, max = 3000,
    allow_null = TRUE, len = 1
  )
  validate_position_indices(exclude, "exclude", nrow(data),
    require_sorted = FALSE, require_unique = TRUE,
    min = 1L, max = nrow(data)
  )
  validate_numeric_parameter(cl, "cl",
    min = -Inf, max = Inf,
    allow_null = TRUE, len = 1
  )
  validate_numeric_parameter(multiply, "multiply",
    min = 0.1, max = 1000,
    allow_null = FALSE, len = 1
  )

  # Normaliser agg.fun kun naar eksplicit angivet
  agg_fun_out <- if (agg_fun_supplied) match.arg(agg.fun, c("mean", "median", "sum", "sd")) else NULL

  if (!is.logical(return.data) || length(return.data) != 1 || is.na(return.data)) {
    stop("return.data must be TRUE or FALSE", call. = FALSE)
  }

  if (!is.null(plot_margin)) {
    if (inherits(plot_margin, "ggplot2::margin") || inherits(plot_margin, "margin")) {
      # margin()-objekt -- trust brugerens input
    } else if (is.numeric(plot_margin)) {
      if (length(plot_margin) != 4) {
        stop(
          "plot_margin must be either:\n",
          "  - A numeric vector of length 4: c(top, right, bottom, left) in mm\n",
          "  - A margin object: margin(t, r, b, l, unit = '...')",
          call. = FALSE
        )
      }
      if (any(plot_margin < 0)) {
        stop("plot_margin values must be non-negative", call. = FALSE)
      }
      if (any(plot_margin > 100)) {
        warning(
          "plot_margin values > 100mm detected. This may result in very large margins.\n",
          "Consider using smaller values or checking your input.",
          call. = FALSE
        )
      }
    } else {
      stop(
        "plot_margin must be either:\n",
        "  - A numeric vector of length 4: c(top, right, bottom, left) in mm\n",
        "  - A margin object: margin(t, r, b, l, unit = '...')\n",
        "Got: ", class(plot_margin)[1],
        call. = FALSE
      )
    }
  }

  validate_denominator_data(
    chart_type = chart_type,
    data = data,
    y_col = y_expr_char,
    n_col = n_expr_char
  )

  if (!is.null(target_value) && is.numeric(target_value)) {
    validate_target_for_unit(target_value, y_axis_unit, multiply)
  }

  invisible(agg_fun_out)
}

# ============================================================================
# BYGG qic_args LIST
# ============================================================================

#' Byg argument-liste til qicharts2::qic()
#'
#' Konstruerer den komplette `qic_args`-liste der sendes til
#' `do.call(qicharts2::qic, ...)`. NSE-symboler skal vaere fanget i
#' bfh_qic() FOeR dette kald.
#'
#' @param data Data frame
#' @param x_expr Symbol for x-kolonne
#' @param y_expr Symbol for y-kolonne
#' @param n_expr Symbol for n-kolonne eller NULL
#' @param chart_type Charttype-streng
#' @param part Fase-positioner eller NULL
#' @param freeze Freeze-position eller NULL
#' @param target_value Maalvaerdi eller NULL
#' @param notes Notats-vektor eller NULL
#' @param exclude Ekskluderingspositioner eller NULL
#' @param cl Brugerdefineret centerlinje eller NULL
#' @param multiply Multiplikator
#' @param agg.fun Normaliseret aggregeringsfunktionsstreng eller NULL
#' @param y_axis_unit Y-akse enhed (benyttes til y.percent-flag)
#' @return Liste klar til do.call(qicharts2::qic, .)
#' @keywords internal
#' @noRd
build_qic_args <- function(data,
                           x_expr,
                           y_expr,
                           n_expr,
                           chart_type,
                           part,
                           freeze,
                           target_value,
                           notes,
                           exclude,
                           cl,
                           multiply,
                           agg.fun,
                           y_axis_unit) {
  qic_args <- list(
    data = data,
    x = x_expr,
    y = y_expr,
    chart = chart_type,
    return.data = TRUE
  )

  if (!is.null(n_expr)) qic_args$n <- n_expr
  if (!is.null(part)) qic_args$part <- part
  if (!is.null(freeze)) qic_args$freeze <- freeze
  if (!is.null(target_value) && is.numeric(target_value)) qic_args$target <- target_value
  if (!is.null(notes)) qic_args$notes <- notes
  if (!is.null(exclude)) qic_args$exclude <- exclude
  if (!is.null(cl)) qic_args$cl <- cl
  if (!is.null(multiply) && multiply != 1) qic_args$multiply <- multiply
  if (!is.null(agg.fun)) qic_args$agg.fun <- agg.fun
  if (identical(y_axis_unit, "percent")) qic_args$y.percent <- TRUE

  qic_args
}

# ============================================================================
# KALD qicharts2 + ANHOeJ POST-PROCESSING
# ============================================================================

#' Kald qicharts2::qic() og normaliser Anhoej-signal
#'
#' Wrapper om `do.call(qicharts2::qic, qic_args)` efterfulgt af
#' `add_anhoej_signal()`. `envir` skal vaere `parent.frame()` evalueret i
#' bfh_qic()-scopet -- aldrig i denne helpers scope.
#'
#' @param qic_args Liste af argumenter til qicharts2::qic()
#' @param envir Environment hvori qic_args evalueres (typisk bfh_qic()'s parent.frame)
#' @return data.frame med raa qic-beregninger + normaliseret anhoej.signal
#' @keywords internal
#' @noRd
invoke_qicharts2 <- function(qic_args, envir) {
  qic_data <- do.call(qicharts2::qic, qic_args, envir = envir)
  add_anhoej_signal(qic_data)
}

# ============================================================================
# VIEWPORT OG BASE_SIZE BEREGNING
# ============================================================================

#' Konverter viewport-dimensioner og beregn responsiv base_size
#'
#' Haandterer hele viewport-pipeline: enhedskonvertering (cm/mm/px/in),
#' responsiv base_size-beregning og normalisering af tomme akse-labels.
#'
#' @param width Plotbredde (raa bruger-input, NULL eller numerisk)
#' @param height Plothoejde (raa bruger-input, NULL eller numerisk)
#' @param units Enhedstype eller NULL (smart auto-detection)
#' @param dpi DPI til pixel-konvertering
#' @param base_size Eksplicit base_size fra bruger
#' @param base_size_supplied Logical -- om bruger eksplicit angav base_size
#' @param xlab X-akse label (streng)
#' @param ylab Y-akse label (streng)
#' @return Liste: width_inches, height_inches, base_size, xlab, ylab
#' @keywords internal
#' @noRd
compute_viewport_base_size <- function(width,
                                       height,
                                       units,
                                       dpi,
                                       base_size,
                                       base_size_supplied,
                                       xlab,
                                       ylab) {
  # Enhedskonvertering
  if (!is.null(width) && !is.null(height)) {
    conv <- convert_to_inches(width, height, units, dpi)
    width_inches <- conv$width_inches
    height_inches <- conv$height_inches
  } else {
    width_inches <- NULL
    height_inches <- NULL
  }

  # Responsiv base_size naar viewport kendes og bruger ikke eksplicit satte vaerdi
  if (!is.null(width_inches) && !is.null(height_inches) && !base_size_supplied) {
    base_size <- calculate_base_size(width_inches, height_inches)
  }

  # Normaliser tomme akse-labels til NULL for robust downstream theming
  if (is.character(xlab) && length(xlab) == 1 && nchar(trimws(xlab)) == 0) xlab <- NULL
  if (is.character(ylab) && length(ylab) == 1 && nchar(trimws(ylab)) == 0) ylab <- NULL

  list(
    width_inches = width_inches,
    height_inches = height_inches,
    base_size = base_size,
    xlab = xlab,
    ylab = ylab
  )
}

# ============================================================================
# RENDER PLOT
# ============================================================================

#' Opret BFH SPC-plot fra qic_data
#'
#' Bygger plot_config + viewport og kalder bfh_spc_plot() med warning-
#' suppression for kendte ufarlige warnings (datetime-scale, PostScript font).
#'
#' @param qic_data data.frame fra invoke_qicharts2()
#' @param chart_type Charttype-streng
#' @param y_axis_unit Y-akse enhed
#' @param chart_title Plottitel eller NULL
#' @param target_value Maalvaerdi eller NULL
#' @param target_text Maaltekst eller NULL
#' @param ylab Y-akse label eller NULL
#' @param xlab X-akse label eller NULL
#' @param subtitle Undertitel eller NULL
#' @param caption Billedtekst eller NULL
#' @param base_size Basisskriftstoerrelse
#' @param plot_margin Margin-objekt eller NULL
#' @return ggplot2-objekt
#' @keywords internal
#' @noRd
render_bfh_plot <- function(qic_data,
                            chart_type,
                            y_axis_unit,
                            chart_title,
                            target_value,
                            target_text,
                            ylab,
                            xlab,
                            subtitle,
                            caption,
                            base_size,
                            plot_margin,
                            language = "da") {
  plot_config <- spc_plot_config(
    chart_type = chart_type,
    y_axis_unit = y_axis_unit,
    chart_title = chart_title,
    target_value = target_value,
    target_text = target_text,
    ylab = ylab,
    xlab = xlab,
    subtitle = subtitle,
    caption = caption,
    language = language
  )

  viewport <- viewport_dims(base_size = base_size)

  # Se .muffle_expected_warnings() helper for hvilke warnings der mufles.
  .muffle_expected_warnings(
    bfh_spc_plot(
      qic_data = qic_data,
      plot_config = plot_config,
      viewport = viewport,
      plot_margin = plot_margin
    )
  )
}

# ============================================================================
# TILFOeJ SPC LABELS TIL EXPORT
# ============================================================================

#' Tilfoej SPC-labels til plot med viewport-skaleret labelstoerrelse
#'
#' Beregner responsiv label_size baseret paa viewport-dimensioner og
#' kalder add_spc_labels() med PostScript font warning-suppression.
#'
#' @param plot ggplot2-objekt fra render_bfh_plot()
#' @param qic_data data.frame fra invoke_qicharts2()
#' @param y_axis_unit Y-akse enhed
#' @param viewport_width_inches Plotbredde i inches eller NULL
#' @param viewport_height_inches Plothoejde i inches eller NULL
#' @param target_text Maaltekst eller NULL
#' @param language Sprogkode ("da" eller "en")
#' @return ggplot2-objekt med labels tilfoejet
#' @keywords internal
#' @noRd
apply_spc_labels_to_export <- function(plot,
                                       qic_data,
                                       y_axis_unit,
                                       viewport_width_inches,
                                       viewport_height_inches,
                                       target_text,
                                       language) {
  label_size <- resolve_label_size(viewport_width_inches, viewport_height_inches)

  # Se .muffle_expected_warnings() helper for hvilke warnings der mufles.
  .muffle_expected_warnings(
    add_spc_labels(
      plot = plot,
      qic_data = qic_data,
      y_axis_unit = y_axis_unit,
      label_size = label_size,
      viewport_width = viewport_width_inches,
      viewport_height = viewport_height_inches,
      target_text = target_text,
      verbose = FALSE,
      language = language
    )
  )
}

# ============================================================================
# BYGG KONFIGURATIONSLISTE
# ============================================================================

#' Byg bfh_qic() konfigurationsliste
#'
#' Samler chart-parametre og label-konfiguration til et enkelt config-objekt
#' der returneres som del af bfh_qic()-output.
#'
#' @param chart_type Charttype-streng
#' @param chart_title Plottitel eller NULL
#' @param y_axis_unit Y-akse enhed
#' @param language Sprogkode
#' @param target_value Maalvaerdi eller NULL
#' @param target_text Maaltekst eller NULL
#' @param part Fase-positioner eller NULL
#' @param freeze Freeze-position eller NULL
#' @param exclude Ekskluderingspositioner eller NULL
#' @param cl Brugerdefineret centerlinje eller NULL
#' @param multiply Multiplikator
#' @param agg.fun Normaliseret aggregeringsfunktionsstreng eller NULL
#' @param viewport_width_inches Plotbredde i inches eller NULL
#' @param viewport_height_inches Plothoejde i inches eller NULL
#' @return Liste med chart-konfiguration inkl. label_config
#' @keywords internal
#' @noRd
build_bfh_qic_config <- function(chart_type,
                                 chart_title,
                                 y_axis_unit,
                                 language,
                                 target_value,
                                 target_text,
                                 part,
                                 freeze,
                                 exclude,
                                 cl,
                                 multiply,
                                 agg.fun,
                                 viewport_width_inches,
                                 viewport_height_inches) {
  label_size <- resolve_label_size(viewport_width_inches, viewport_height_inches)

  # label_config$centerline_value, $has_frys_column og $has_skift_column er
  # fjernet som statiske kopier for at undgaa desync ved mutation af
  # top-niveau cl/freeze/part. Laes dem fra config$cl, config$freeze,
  # config$part i stedet (se export_pdf.R).
  list(
    chart_type = chart_type,
    chart_title = chart_title,
    y_axis_unit = y_axis_unit,
    language = language,
    target_value = target_value,
    target_text = target_text,
    part = part,
    freeze = freeze,
    exclude = exclude,
    cl = cl,
    multiply = multiply,
    agg.fun = agg.fun,
    label_config = list(
      original_viewport_width = viewport_width_inches,
      original_viewport_height = viewport_height_inches,
      original_label_size = label_size
    )
  )
}
