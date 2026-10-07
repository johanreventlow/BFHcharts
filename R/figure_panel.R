# ============================================================================
# FIGURE SIDE PANEL
#
# Right-hand column for figure pages (bfh_export_figure_pdf() /
# bfh_stage_figure_page()): key figures, a colour legend drawn by the template
# and the data definition. Same 72.6 mm column as the SPC statistics panel.
#
# See openspec: add-figure-side-panel (pdf-export capability).
# ============================================================================

#' Side Panel for Figure Pages
#'
#' Describes the right-hand column of a figure page: large key figures, a
#' colour legend and the data definition. Pass the result as \code{panel} to
#' \code{\link{bfh_export_figure_pdf}} or \code{\link{bfh_stage_figure_page}}.
#' The panel has the same width (72.6 mm) as the SPC statistics column of
#' \code{\link{bfh_export_pdf}}, so the figure is rendered 191.4 mm wide.
#'
#' The legend is drawn by the Typst template, not by ggplot2: remove the plot's
#' own legend (e.g. \code{guide = "none"}) and list the same colours here.
#' A group heading is shown each time \code{group} changes, so sort the legend
#' in the order it should be read (typically the stacking order, top first).
#'
#' With a panel, \code{metadata$data_definition} is rendered at the bottom of
#' the panel (no warning, unlike full-width mode).
#'
#' With \code{placement = "bottom"} the figure uses the full page width and
#' the panel becomes a row below it: key figures side by side (number above,
#' label below), then the legend, then the data definition to the right.
#' Legend group headings are not shown in that row.
#'
#' @param legend Optional data frame with columns \code{label} and
#'   \code{colour} (hex, e.g. \code{"#007dbb"}) and optionally \code{group},
#'   \code{key} (\code{"box"}, the default; \code{"line"} for a line
#'   series; \code{"arrow_up"} or \code{"arrow_down"} for a thick vertical
#'   arrow), \code{linewidth} (ggplot2 linewidth of a \code{"line"} key,
#'   default 0.5) and \code{outline} (hex colour of a thin border around a
#'   \code{"box"} key, e.g. a band drawn with an outline).
#' @param kpis Optional data frame with columns \code{label} and \code{value}
#'   (numbers are formatted as text) and optionally \code{colour} and
#'   \code{label_colour} (colour of the label below the number in the bottom
#'   panel; default grey). A \code{"\\n"} in a label is a line break in the
#'   bottom panel.
#' @param legend_title Heading above the legend. Default \code{NULL} uses the
#'   template default ("Tegnforklaring"); \code{""} shows no heading.
#' @param kpi_title Optional heading above the key figures.
#' @param definition_height_mm Optional height of the data definition block in
#'   millimetres (template default 39.6). Text that does not fit is clipped
#'   with an ellipsis. Ignored with \code{placement = "bottom"}.
#' @param placement \code{"side"} (default): a 72.6 mm column right of the
#'   figure. \code{"bottom"}: a row below a full-width figure.
#' @param kpi_columns Bottom placement only: number of columns in a grid of
#'   key figures, filled column by column (e.g. 2 gives a 2 x 2 grid for four
#'   key figures). Default \code{NULL}: all key figures in one row.
#' @param kpi_size_pt Bottom placement only: font size of the key figure
#'   numbers in points. Default \code{NULL} (26 pt).
#' @param kpi_labels Bottom placement only: show the label below each number.
#'   Set to \code{FALSE} when a legend explains the colours.
#' @param legend_rows Bottom placement only: number of legend rows, filled
#'   column by column. Default \code{NULL}: one column up to three entries,
#'   otherwise two columns. The legend has the same height as the key
#'   figures, with the rows spread evenly.
#' @param legend_label_width_mm Bottom placement only: maximum width of a
#'   legend label in millimetres; longer labels wrap onto more lines, which
#'   leaves more room for the data definition. Default \code{NULL}: no limit.
#' @param kpi_width_mm,kpi_label_size_pt,kpi_label_gap_mm Bottom placement
#'   only: minimum width of each key figure column (mm), font size of the
#'   labels (pt, default 7.5) and the space between number and label (mm,
#'   default 1.4). With \code{kpi_width_mm} labels wrap only at \code{"\\n"}
#'   and the columns stand closer together.
#' @param kpis_end,kpi_end_title Bottom placement only: a second group of
#'   key figures (same columns as \code{kpis}) with its own heading, shown in
#'   one column at the far right of the row, after the data definition (as on
#'   the old occupancy sheets). Uses the same size and label settings as
#'   \code{kpis}. Ignored with \code{placement = "side"}.
#' @param definition_first Side placement only: show the data definition at
#'   the top of the column in its natural height, followed by the key figures
#'   and the legend. Default \code{FALSE}: the definition is a fixed-height
#'   block at the bottom (see \code{definition_height_mm}).
#'
#' @return An object of class \code{bfh_figure_panel}.
#' @export
#' @family export-functions
#' @seealso [bfh_export_figure_pdf()], [bfh_stage_figure_page()]
#' @examples
#' bfh_figure_panel(
#'   legend = data.frame(
#'     label = c("Inden for 30 dage", "Frist overskredet"),
#'     colour = c("#007dbb", "#c0392b"),
#'     group = c("Overholdt", "Overskredet")
#'   ),
#'   kpis = data.frame(label = "Ikke udredte", value = 37)
#' )
bfh_figure_panel <- function(legend = NULL,
                             kpis = NULL,
                             legend_title = NULL,
                             kpi_title = NULL,
                             definition_height_mm = NULL,
                             placement = c("side", "bottom"),
                             kpi_columns = NULL,
                             kpi_size_pt = NULL,
                             kpi_labels = TRUE,
                             legend_rows = NULL,
                             legend_label_width_mm = NULL,
                             definition_first = FALSE,
                             kpi_width_mm = NULL,
                             kpi_label_size_pt = NULL,
                             kpi_label_gap_mm = NULL,
                             kpis_end = NULL,
                             kpi_end_title = NULL) {
  placement <- match.arg(placement)
  legend_in <- legend
  legend <- .validate_panel_table(legend, "legend",
    required = c("label", "colour"), optional = "group"
  )
  if (!is.null(legend)) {
    legend$key <- if ("key" %in% names(legend_in)) as.character(legend_in$key) else "box"
    legend$key[is.na(legend$key)] <- "box"
    if (!all(legend$key %in% .legend_keys)) {
      bfh_abort(
        sprintf("legend$key must be one of %s.",
                paste0("\"", .legend_keys, "\"", collapse = ", ")),
        class = "bfhcharts_export_error"
      )
    }
    legend$outline <- if ("outline" %in% names(legend_in)) {
      as.character(legend_in$outline)
    } else {
      NA_character_
    }
    if (any(!is.na(legend$outline) & !.is_hex_colour(legend$outline))) {
      bfh_abort("legend$outline must contain hex colours or NA.",
        class = "bfhcharts_export_error"
      )
    }
    legend$linewidth <- if ("linewidth" %in% names(legend_in)) {
      as.numeric(legend_in$linewidth)
    } else {
      NA_real_
    }
    bad_lw <- !is.na(legend$linewidth) & legend$linewidth <= 0
    if (any(bad_lw)) {
      bfh_abort("legend$linewidth must be positive or NA.",
        class = "bfhcharts_export_error"
      )
    }
  }
  if (!is.null(legend) && !all(.is_hex_colour(legend$colour))) {
    bfh_abort(
      "legend$colour must contain hex colours like \"#007dbb\" (no NA).",
      class = "bfhcharts_export_error"
    )
  }
  # Noegletal valideres ens, hvad enten de staar foerst eller yderst til hoejre
  validate_kpis <- function(kpis, name) {
    kpis_in <- kpis
    kpis <- .validate_panel_table(kpis, name,
      required = c("label", "value"), optional = "colour"
    )
    if (!is.null(kpis)) {
      kpis$value <- as.character(kpis$value)
      if (anyNA(kpis$value)) {
        bfh_abort(sprintf("%s$value must not contain NA.", name), class = "bfhcharts_export_error")
      }
      bad <- !is.na(kpis$colour) & !.is_hex_colour(kpis$colour)
      if (any(bad)) {
        bfh_abort(
          sprintf("%s$colour must contain hex colours like \"#333333\" or NA.", name),
          class = "bfhcharts_export_error"
        )
      }
      kpis$label_colour <- if ("label_colour" %in% names(kpis_in)) {
        as.character(kpis_in$label_colour)
      } else {
        NA_character_
      }
      if (any(!is.na(kpis$label_colour) & !.is_hex_colour(kpis$label_colour))) {
        bfh_abort(sprintf("%s$label_colour must contain hex colours or NA.", name),
          class = "bfhcharts_export_error"
        )
      }
    }
    kpis
  }
  kpis <- validate_kpis(kpis, "kpis")
  kpis_end <- validate_kpis(kpis_end, "kpis_end")
  for (arg in c("legend_title", "kpi_title", "kpi_end_title")) {
    val <- get(arg)
    if (!is.null(val) && (!is.character(val) || length(val) != 1L || is.na(val))) {
      bfh_abort(sprintf("%s must be a single string or NULL.", arg),
        class = "bfhcharts_export_error"
      )
    }
  }
  for (arg in c("kpi_columns", "legend_rows")) {
    val <- get(arg)
    if (!is.null(val) && (!is.numeric(val) || length(val) != 1L || is.na(val) ||
      val < 1 || val != round(val))) {
      bfh_abort(sprintf("%s must be a single positive whole number or NULL.", arg),
        class = "bfhcharts_export_error"
      )
    }
  }
  for (arg in c("kpi_size_pt", "legend_label_width_mm", "kpi_width_mm",
                "kpi_label_size_pt", "kpi_label_gap_mm")) {
    val <- get(arg)
    if (!is.null(val) && (!is.numeric(val) || length(val) != 1L || is.na(val) || val <= 0)) {
      bfh_abort(sprintf("%s must be a single positive number or NULL.", arg),
        class = "bfhcharts_export_error"
      )
    }
  }
  for (arg in c("kpi_labels", "definition_first")) {
    val <- get(arg)
    if (!is.logical(val) || length(val) != 1L || is.na(val)) {
      bfh_abort(sprintf("%s must be TRUE or FALSE.", arg), class = "bfhcharts_export_error")
    }
  }
  if (!is.null(definition_height_mm) &&
    (!is.numeric(definition_height_mm) || length(definition_height_mm) != 1L ||
      is.na(definition_height_mm) || definition_height_mm <= 0)) {
    bfh_abort("definition_height_mm must be a single positive number or NULL.",
      class = "bfhcharts_export_error"
    )
  }

  structure(
    list(
      legend = legend,
      kpis = kpis,
      legend_title = legend_title,
      kpi_title = kpi_title,
      definition_height_mm = definition_height_mm,
      placement = placement,
      kpi_columns = if (is.null(kpi_columns)) NULL else as.integer(kpi_columns),
      kpi_size_pt = kpi_size_pt,
      kpi_labels = kpi_labels,
      legend_rows = if (is.null(legend_rows)) NULL else as.integer(legend_rows),
      legend_label_width_mm = legend_label_width_mm,
      definition_first = definition_first,
      kpi_width_mm = kpi_width_mm,
      kpi_label_size_pt = kpi_label_size_pt,
      kpi_label_gap_mm = kpi_label_gap_mm,
      kpis_end = kpis_end,
      kpi_end_title = kpi_end_title
    ),
    class = "bfh_figure_panel"
  )
}


#' @export
print.bfh_figure_panel <- function(x, ...) {
  n_legend <- if (is.null(x$legend)) 0L else nrow(x$legend)
  n_kpis <- if (is.null(x$kpis)) 0L else nrow(x$kpis)
  cat(sprintf(
    "<bfh_figure_panel> %d legend entr%s, %d key figure%s\n",
    n_legend, if (n_legend == 1L) "y" else "ies",
    n_kpis, if (n_kpis == 1L) "" else "s"
  ))
  invisible(x)
}


# Legend key shapes the Typst template can draw
.legend_keys <- c("box", "line", "arrow_up", "arrow_down")


#' Validate one table argument of bfh_figure_panel()
#'
#' Returns NULL for NULL or zero rows, otherwise a plain data.frame with the
#' required columns as character and the optional column filled with NA.
#'
#' @noRd
.validate_panel_table <- function(x, name, required, optional) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.data.frame(x)) {
    bfh_abort(sprintf("%s must be a data frame or NULL.", name),
      class = "bfhcharts_export_error"
    )
  }
  missing <- setdiff(required, names(x))
  if (length(missing) > 0) {
    bfh_abort(
      sprintf("%s is missing column(s): %s", name, paste(missing, collapse = ", ")),
      class = "bfhcharts_export_error"
    )
  }
  if (nrow(x) == 0) {
    return(NULL)
  }
  out <- data.frame(
    label = as.character(x$label),
    stringsAsFactors = FALSE
  )
  for (col in setdiff(required, "label")) {
    out[[col]] <- if (col == "value") x[[col]] else as.character(x[[col]])
  }
  out[[optional]] <- if (optional %in% names(x)) {
    as.character(x[[optional]])
  } else {
    NA_character_
  }
  if (anyNA(out$label) || !all(nzchar(trimws(out$label)))) {
    bfh_abort(sprintf("%s$label must be non-empty strings.", name),
      class = "bfhcharts_export_error"
    )
  }
  out
}


#' @noRd
.is_hex_colour <- function(x) {
  !is.na(x) & grepl("^#[0-9A-Fa-f]{6}$", x)
}


#' Validate the panel argument of the figure export functions
#'
#' @noRd
.validate_figure_panel <- function(panel) {
  if (!is.null(panel) && !inherits(panel, "bfh_figure_panel")) {
    bfh_abort(
      paste0(
        "panel must be NULL or created with bfh_figure_panel().\n",
        "  Got class: ", paste(class(panel), collapse = ", ")
      ),
      class = "bfhcharts_export_error"
    )
  }
  invisible(panel)
}


#' Chart SVG size for a figure page
#'
#' Width: 191.4 mm next to a side panel, 264 mm full width (no panel or a
#' bottom panel). Height: 130.8 mm when the page has no analysis text (the
#' template then drops the analysis row), otherwise 109 mm; a bottom panel
#' takes PDF_FIGURE_BOTTOM_PANEL_MM of that. Must stay in sync with
#' bfh-template.typ.
#'
#' @param metadata_full Finalized metadata from build_figure_metadata().
#' @noRd
figure_chart_dims <- function(metadata_full) {
  panel <- metadata_full$figure_panel
  bottom <- !is.null(panel) && identical(panel$placement, "bottom")
  height <- if (is.null(metadata_full$analysis)) {
    PDF_IMAGE_HEIGHT_FIGURE_MM
  } else {
    PDF_IMAGE_HEIGHT_MM
  }
  list(
    width_mm = if (is.null(panel) || bottom) {
      PDF_IMAGE_WIDTH_FULL_MM
    } else {
      PDF_IMAGE_WIDTH_MM
    },
    height_mm = if (bottom) height - PDF_FIGURE_BOTTOM_PANEL_MM else height
  )
}
