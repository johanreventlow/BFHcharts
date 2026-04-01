#' Prepare SPC Data for Observable JS
#'
#' Extracts data from a \code{bfh_qic_result} object into a JSON-serializable
#' list suitable for passing to Observable JS via \code{ojs_define()}.
#'
#' @param result A \code{bfh_qic_result} object from \code{create_spc_chart()}
#'
#' @return A list with components:
#'   \item{data}{data.frame with columns: x, y, cl, ucl, lcl, target, part,
#'     sigma_signal, anhoej_signal, notes}
#'   \item{config}{list with chart_type, y_axis_unit, chart_title,
#'     target_value, target_text}
#'   \item{colors}{named list of hex color strings}
#'   \item{summary}{summary tibble from the result object}
#'
#' @keywords internal
bfh_prepare_ojs_data <- function(result) {
  # Validér input

  if (!is_bfh_qic_result(result)) {
    stop("result must be a bfh_qic_result object", call. = FALSE)
  }

  qic_data <- result$qic_data

  # Byg data.frame med OJS-venlige kolonnenavne
  ojs_data <- data.frame(
    x = format(qic_data$x, "%Y-%m-%d"),
    y = qic_data$y,
    cl = if ("cl" %in% names(qic_data)) qic_data$cl else NA_real_,
    ucl = if ("ucl" %in% names(qic_data)) qic_data$ucl else NA_real_,
    lcl = if ("lcl" %in% names(qic_data)) qic_data$lcl else NA_real_,
    target = if ("target" %in% names(qic_data)) qic_data$target else NA_real_,
    part = if ("part" %in% names(qic_data)) as.integer(qic_data$part) else 1L,
    sigma_signal = if ("sigma.signal" %in% names(qic_data)) {
      as.logical(qic_data$sigma.signal)
    } else {
      FALSE
    },
    anhoej_signal = if ("anhoej.signal" %in% names(qic_data)) {
      as.logical(qic_data$anhoej.signal)
    } else {
      FALSE
    },
    notes = if ("notes" %in% names(qic_data)) {
      as.character(qic_data$notes)
    } else {
      NA_character_
    },
    stringsAsFactors = FALSE
  )

  # Byg config fra result$config

cfg <- result$config
  ojs_config <- list(
    chart_type = cfg$chart_type,
    y_axis_unit = cfg$y_axis_unit,
    chart_title = cfg$chart_title,
    target_value = cfg$target_value,
    target_text = cfg$target_text
  )

  # Hent BFHtheme farver med fallback
  colors <- tryCatch(
    {
      list(
        hospital_blue = as.character(BFHtheme::bfh_cols("hospital_blue")),
        hospital_grey = as.character(BFHtheme::bfh_cols("hospital_grey")),
        hospital_dark_grey = as.character(BFHtheme::bfh_cols("hospital_dark_grey")),
        light_blue = as.character(BFHtheme::bfh_cols("light_blue")),
        very_light_blue = as.character(BFHtheme::bfh_cols("very_light_blue"))
      )
    },
    error = function(e) {
      # Fallback farver hvis BFHtheme ikke er tilgængelig
      list(
        hospital_blue = "#007DBB",
        hospital_grey = "#888888",
        hospital_dark_grey = "#565656",
        light_blue = "#009CE8",
        very_light_blue = "#E1EDFB"
      )
    }
  )

  list(
    data = ojs_data,
    config = ojs_config,
    colors = colors,
    summary = result$summary
  )
}


#' Pass SPC Data to Observable JS via ojs_define
#'
#' Bridge function for Quarto documents. Converts a \code{bfh_qic_result}
#' object to a format suitable for Observable JS and makes it available
#' in OJS cells via \code{ojs_define()}.
#'
#' @param result A \code{bfh_qic_result} object from \code{create_spc_chart()}
#' @param name Character string. The variable name to use in OJS cells.
#'   Defaults to \code{"spc_data"}.
#'
#' @return The prepared data list (invisibly), useful for testing.
#'
#' @details
#' This function requires a Quarto rendering context where \code{ojs_define()}
#' is available. It will not work in a plain R session.
#'
#' @examples
#' \dontrun{
#' # In a Quarto document (.qmd):
#' result <- create_spc_chart(data, x = month, y = infections,
#'                            chart_type = "run", y_axis_unit = "count")
#' bfh_ojs_define(result, name = "spc_data")
#' }
#'
#' @export
bfh_ojs_define <- function(result, name = "spc_data") {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    stop(
      "Package 'knitr' is required for bfh_ojs_define().\n",
      "Install it with: install.packages('knitr')",
      call. = FALSE
    )
  }

  ojs_data <- bfh_prepare_ojs_data(result)

  # ojs_define() er tilgængelig i Quarto rendering-kontekst
  # Byg kald dynamisk for at tillade vilkårligt variabelnavn
  args <- stats::setNames(list(ojs_data), name)

  # Forsøg at finde ojs_define i kaldende miljø eller Quarto-kontekst
  ojs_define_fn <- NULL

  # Tjek parent frames for ojs_define
  for (i in seq_len(sys.nframe())) {
    env <- sys.frame(i)
    if (exists("ojs_define", envir = env, inherits = FALSE)) {
      ojs_define_fn <- get("ojs_define", envir = env)
      break
    }
  }

  # Fallback: søg i global environment

  if (is.null(ojs_define_fn) && exists("ojs_define", envir = globalenv())) {
    ojs_define_fn <- get("ojs_define", envir = globalenv())
  }

  if (is.null(ojs_define_fn)) {
    stop(
      "ojs_define() not found. This function must be called within a ",
      "Quarto document rendering context.",
      call. = FALSE
    )
  }

  do.call(ojs_define_fn, args)

  invisible(ojs_data)
}


#' Get Path to OJS Source Files
#'
#' Returns the file system path to Observable JS source files bundled
#' with the BFHcharts package.
#'
#' @param file Character string. Name of the OJS file.
#'   Defaults to \code{"bfh-spc.js"}.
#'
#' @return Character string with the absolute file path.
#'
#' @examples
#' \dontrun{
#' # Copy OJS files to your Quarto project
#' file.copy(bfh_ojs_path("bfh-spc.js"), "bfh-spc.js")
#' file.copy(bfh_ojs_path("bfh-spc-utils.js"), "bfh-spc-utils.js")
#' file.copy(bfh_ojs_path("bfh-spc-scales.js"), "bfh-spc-scales.js")
#' }
#'
#' @export
bfh_ojs_path <- function(file = "bfh-spc.js") {
  system.file("ojs", file, package = "BFHcharts", mustWork = TRUE)
}
