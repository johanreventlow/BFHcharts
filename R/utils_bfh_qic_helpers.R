# ============================================================================
# INTERNE HELPERS TIL bfh_qic()
# ============================================================================
# Disse helpers isolerer Anhoej signal-postprocessering og return-routing
# fra bfh_qic()-kroppen. Se openspec/changes/refactor-bfh_qic-orchestrator.

#' Normaliser anhoej.signal i qic_data
#'
#' Deriverer en altid-boolean `anhoej.signal`-kolonne fra qicharts2-output,
#' uanset hvilke signal-kolonner der er til stede.
#'
#' Fallback-priority:
#' `anhoej.signal` -> `anhoej.signals` -> `runs.signal | crossings.signal`
#' -> `runs.signal` -> `FALSE`
#'
#' @param qic_data data.frame fra `qicharts2::qic()`, eller NULL
#' @return qic_data med normaliseret `anhoej.signal` (logical, aldrig NA),
#'   eller NULL hvis input er NULL
#' @keywords internal
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

  # Downstream kraever altid TRUE/FALSE - aldrig NA
  qic_data$anhoej.signal <- ifelse(
    is.na(qic_data$anhoej.signal), FALSE, qic_data$anhoej.signal
  )

  qic_data
}

#' Byg bfh_qic() returvaerdi
#'
#' Haandterer alle fire returkombinationer af `return.data` og `print.summary`,
#' inkl. deprecation-warnings for legacy paths.
#'
#' @param qic_data data.frame med raa qic-beregninger
#' @param plot ggplot2-objekt
#' @param summary_result data.frame med SPC-summary
#' @param config liste med konfigurationsparametre
#' @param return.data logical
#' @param print.summary logical
#' @return En af: `bfh_qic_result` S3-objekt (default), `qic_data` data.frame,
#'   `list(plot, summary)`, eller `list(data, summary)`
#' @keywords internal
build_bfh_qic_return <- function(qic_data, plot, summary_result, config,
                                 return.data, print.summary) {
  if (print.summary) {
    warning(
      "The 'print.summary' parameter is deprecated as of BFHcharts 0.3.0.\n",
      "  The summary is now always included in the result object.\n",
      "  Access it via result$summary instead of using print.summary = TRUE.\n",
      "  This parameter will be removed in a future version.",
      call. = FALSE
    )
  }

  if (return.data && print.summary) {
    return(list(data = qic_data, summary = summary_result))
  } else if (return.data) {
    return(qic_data)
  } else if (print.summary) {
    warning(
      "Returning legacy list(plot, summary) format.\n",
      "  Consider using the new bfh_qic_result object instead:\n",
      "  result <- bfh_qic(...)\n",
      "  result$plot     # Access plot\n",
      "  result$summary  # Access summary\n",
      "  This legacy format will be removed in a future version.",
      call. = FALSE
    )
    return(list(plot = plot, summary = summary_result))
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

#' Validér og normaliser et NSE kolonne-udtryk til et symbol
#'
#' Tager et allerede fanget udtryk (fra `substitute()` i bfh_qic()-scopet)
#' og validerer at det er et simpelt identifier. Understøtter direkte symboler
#' (month) og quoted symboler (quote(month)) til programmatisk brug.
#'
#' Denne funktion kalder IKKE selv `substitute()` — det SKAL ske i bfh_qic().
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
  valid_pattern <- "^[a-zA-Z][a-zA-Z0-9._]*$"
  if (!is.symbol(normalized_expr) || !grepl(valid_pattern, as.character(normalized_expr))) {
    stop(sprintf(
      "%s must be a simple column name, got: %s\nAvoid special characters, spaces, or expressions",
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
#' bfh_qic() via substitute() FØR dette kald — aldrig inde i denne helper.
#'
#' @param data Data frame med maalinger
#' @param chart_type Charttype-streng
#' @param y_axis_unit Y-akse enhed
#' @param x_expr Symbol for x-kolonne (allerede valideret via validate_column_name)
#' @param y_expr Symbol for y-kolonne (allerede valideret via validate_column_name)
#' @param n_expr Symbol for n-kolonne eller NULL
#' @param part Vektor af fase-positioner eller NULL
#' @param freeze Freeze-position eller NULL
#' @param base_size Basisskriftstørrelse
#' @param width Plotbredde eller NULL
#' @param height Plothøjde eller NULL
#' @param exclude Ekskluderingspositioner eller NULL
#' @param cl Brugerdefineret centerlinje eller NULL
#' @param multiply Multiplikator
#' @param agg_fun_supplied Logical — om agg.fun er eksplicit angivet af bruger
#' @param agg.fun Aggregeringsfunktionsstreng
#' @param return.data Logical
#' @param print.summary Logical
#' @param plot_margin Margin-objekt eller numerisk vektor
#' @param target_value Numerisk maalvaerdi eller NULL
#' @param y_expr_char Karakterstreng af y-kolonnenavnet (til denominator-validering)
#' @param n_expr_char Karakterstreng af n-kolonnenavnet eller NULL
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
                                    print.summary,
                                    plot_margin,
                                    target_value,
                                    y_expr_char,
                                    n_expr_char) {
  if (!is.data.frame(data)) {
    stop("data must be a data frame")
  }

  if (!chart_type %in% CHART_TYPES_EN) {
    stop(sprintf(
      "chart_type must be one of: %s",
      paste(CHART_TYPES_EN, collapse = ", ")
    ))
  }

  valid_units <- c("count", "percent", "rate", "time")
  if (!y_axis_unit %in% valid_units) {
    stop(sprintf(
      "y_axis_unit must be one of: %s",
      paste(valid_units, collapse = ", ")
    ))
  }

  validate_numeric_parameter(part, "part",
    min = 1, max = nrow(data),
    allow_null = TRUE, context = sprintf("1-%d", nrow(data))
  )
  validate_numeric_parameter(freeze, "freeze",
    min = 1, max = nrow(data),
    allow_null = TRUE, context = sprintf("1-%d", nrow(data))
  )
  validate_numeric_parameter(base_size, "base_size",
    min = 1, max = 100,
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
  validate_numeric_parameter(exclude, "exclude",
    min = 1, max = nrow(data),
    allow_null = TRUE, context = sprintf("1-%d", nrow(data))
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
  if (!is.logical(print.summary) || length(print.summary) != 1 || is.na(print.summary)) {
    stop("print.summary must be TRUE or FALSE", call. = FALSE)
  }

  if (!is.null(plot_margin)) {
    if (inherits(plot_margin, "ggplot2::margin") || inherits(plot_margin, "margin")) {
      # margin()-objekt — trust brugerens input
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
#' bfh_qic() FØR dette kald.
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
# KALD qicharts2 + ANHØJ POST-PROCESSING
# ============================================================================

#' Kald qicharts2::qic() og normaliser Anhøj-signal
#'
#' Wrapper om `do.call(qicharts2::qic, qic_args)` efterfulgt af
#' `add_anhoej_signal()`. `envir` skal vaere `parent.frame()` evalueret i
#' bfh_qic()-scopet — aldrig i denne helpers scope.
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
#' @param height Plothøjde (raa bruger-input, NULL eller numerisk)
#' @param units Enhedstype eller NULL (smart auto-detection)
#' @param dpi DPI til pixel-konvertering
#' @param base_size Eksplicit base_size fra bruger
#' @param base_size_supplied Logical — om bruger eksplicit angav base_size
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
#' @param base_size Basisskriftstørrelse
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
                            plot_margin) {
  plot_config <- spc_plot_config(
    chart_type = chart_type,
    y_axis_unit = y_axis_unit,
    chart_title = chart_title,
    target_value = target_value,
    target_text = target_text,
    ylab = ylab,
    xlab = xlab,
    subtitle = subtitle,
    caption = caption
  )

  viewport <- viewport_dims(base_size = base_size)

  withCallingHandlers(
    bfh_spc_plot(
      qic_data = qic_data,
      plot_config = plot_config,
      viewport = viewport,
      plot_margin = plot_margin
    ),
    warning = function(w) {
      if (grepl("numeric|datetime|scale_[xy]_date|PostScript font database",
        conditionMessage(w),
        ignore.case = TRUE
      )) {
        invokeRestart("muffleWarning")
      }
    }
  )
}

# ============================================================================
# TILFØJ SPC LABELS TIL EXPORT
# ============================================================================

#' Tilføj SPC-labels til plot med viewport-skaleret labelstørrelse
#'
#' Beregner responsiv label_size baseret paa viewport-dimensioner og
#' kalder add_spc_labels() med PostScript font warning-suppression.
#'
#' @param plot ggplot2-objekt fra render_bfh_plot()
#' @param qic_data data.frame fra invoke_qicharts2()
#' @param y_axis_unit Y-akse enhed
#' @param viewport_width_inches Plotbredde i inches eller NULL
#' @param viewport_height_inches Plothøjde i inches eller NULL
#' @param target_text Maaltekst eller NULL
#' @param language Sprogkode ("da" eller "en")
#' @return ggplot2-objekt med labels tilføjet
#' @keywords internal
#' @noRd
apply_spc_labels_to_export <- function(plot,
                                       qic_data,
                                       y_axis_unit,
                                       viewport_width_inches,
                                       viewport_height_inches,
                                       target_text,
                                       language) {
  if (!is.null(viewport_width_inches) && !is.null(viewport_height_inches)) {
    label_size <- compute_label_size_for_viewport(
      viewport_width_inches, viewport_height_inches
    )
  } else {
    label_size <- PDF_LABEL_SIZE
  }

  withCallingHandlers(
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
    ),
    warning = function(w) {
      if (grepl("PostScript font database", conditionMessage(w), fixed = TRUE)) {
        invokeRestart("muffleWarning")
      }
    }
  )
}
