# ============================================================================
# INTERNE HELPERS TIL bfh_qic()
# ============================================================================
# Disse helpers isolerer Anhoej signal-postprocessering og return-routing
# fra bfh_qic()-kroppen. Se openspec/changes/refactor-extract-bfh-qic-helpers.

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
