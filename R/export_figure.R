# ============================================================================
# FIGURE PDF EXPORT
#
# Full-width branded PDF page for arbitrary ggplot figures (not SPC charts).
# Reuses the PDF pipeline of bfh_export_pdf() (workspace, template staging,
# inject_assets, font_path, batch_session, Typst compile) and skips everything
# SPC-specific. The Typst template is put in full-width mode via
# metadata$spc_panel = FALSE, set here AFTER bfh_merge_metadata() so callers
# cannot control it.
#
# See openspec: add-figure-pdf-export (pdf-export capability).
# ============================================================================

#' Export a ggplot Figure to a Branded PDF Page
#'
#' Renders an arbitrary \code{ggplot} object -- a distribution, bar chart or
#' plain time series that is \emph{not} an SPC chart -- to a single-page PDF
#' with the BFH template: blue header (hospital, department, title), analysis
#' row, details line, footer and logo. The figure fills the full width of the
#' chart row; the SPC statistics column of \code{\link{bfh_export_pdf}} is not
#' rendered.
#'
#' Requires Quarto CLI (>= 1.4.0) for compilation, like
#' \code{\link{bfh_export_pdf}}. For SPC charts (\code{bfh_qic_result}), use
#' \code{\link{bfh_export_pdf}} instead.
#'
#' @param plot A single \code{ggplot} object. Composite plots (class
#'   \code{patchwork}) are rejected: title stripping and margins would only
#'   reach the last sub-plot.
#' @param output Character string specifying the output PDF file path.
#' @param metadata Named list of template metadata. \code{title} is
#'   \strong{required} (single non-empty character string): it is rendered in
#'   the blue header, and the plot's own title and subtitle are stripped so the
#'   title only appears once. Optional fields: \code{hospital},
#'   \code{department}, \code{analysis}, \code{details}, \code{author},
#'   \code{date}, \code{footer_content}, \code{logo_path}. Unlike
#'   \code{\link{bfh_export_pdf}}, \code{details} is not auto-generated.
#'   \code{data_definition} is accepted but \strong{not rendered} in
#'   full-width mode; a non-empty value triggers a warning so the text does
#'   not vanish silently.
#' @param template Character string specifying template name
#'   (default: "bfh-diagram").
#' @param template_path Optional path to a custom Typst template file. Requires
#'   \code{restrict_template = FALSE}; see \code{\link{bfh_export_pdf}} for the
#'   trust model.
#' @param restrict_template Logical. When \code{TRUE} (default), any non-NULL
#'   \code{template_path} is rejected.
#' @param dpi Resolution passed to \code{ggplot2::ggsave()}. Default 150.
#' @param font_path Optional path to a directory with additional fonts, passed
#'   as \code{--font-path} to the Typst compiler.
#' @param ignore_system_fonts Logical. If \code{TRUE} (default), passes
#'   \code{--ignore-system-fonts} to Typst so only fonts from \code{font_path}
#'   (or bundled template fonts) are used.
#' @param inject_assets Optional callback receiving the path to the staged
#'   template directory, used to add fonts and images before compilation.
#'   Cannot be combined with \code{batch_session}. Same trust requirement as
#'   in \code{\link{bfh_export_pdf}}.
#' @param batch_session Optional \code{bfh_export_session} object from
#'   \code{\link{bfh_create_export_session}}. Reuses the staged template
#'   directory across calls. Cannot be combined with \code{template_path} or
#'   \code{inject_assets}.
#'
#' @return The input \code{plot} invisibly, enabling pipe chaining.
#'
#' @details
#' **What the function changes about your plot:** it removes the plot title
#' and subtitle, removes axis titles that are blank (\code{NULL}, \code{""} or
#' whitespace; titles derived from \code{aes()} are kept), and sets the plot
#' margins to 0 mm. Nothing else: the caller owns the figure's theme and
#' typography. The chart is rendered at 264 x 109 mm (the full chart row).
#'
#' **Fonts:** text inside the figure is rendered with the font family the plot
#' declares, resolved against the fonts available to the Typst compile
#' (\code{font_path}, injected assets, and system fonts only when
#' \code{ignore_system_fonts = FALSE}). A default ggplot theme declares
#' "Arial"; when that font is not available the figure text falls back to
#' Typst's default font. Add \code{BFHtheme::theme_bfh()} to the plot for
#' typography consistent with SPC pages.
#'
#' @section Security:
#' Same guards as \code{\link{bfh_export_pdf}}: output path validation,
#' \code{restrict_template} semantics, \code{inject_assets} validation and
#' temp-workspace protection. \code{inject_assets} is full code execution and
#' MUST NOT come from user input.
#'
#' @export
#' @family export-functions
#' @seealso
#'   - [bfh_export_pdf()] for SPC charts
#'   - [bfh_stage_figure_page()] to stage a figure page for batch reports
#'   - [bfh_create_export_session()] for batch workflows
#' @examples
#' \dontrun{
#' library(ggplot2)
#'
#' p <- ggplot(mtcars, aes(factor(cyl))) +
#'   geom_bar() +
#'   labs(x = "Cylinders", y = "Cars") +
#'   BFHtheme::theme_bfh()
#'
#' bfh_export_figure_pdf(
#'   p, "cylinders.pdf",
#'   metadata = list(
#'     title = "Most cars have four or eight cylinders",
#'     department = "Kvalitetsafdeling",
#'     analysis = "Distribution of cylinders in the sample.",
#'     details = "Source: mtcars"
#'   )
#' )
#' }
bfh_export_figure_pdf <- function(plot,
                                  output,
                                  metadata = list(),
                                  template = "bfh-diagram",
                                  template_path = NULL,
                                  restrict_template = TRUE,
                                  dpi = 150,
                                  font_path = NULL,
                                  ignore_system_fonts = TRUE,
                                  inject_assets = NULL,
                                  batch_session = NULL) {
  rlang::check_installed(
    c("commonmark", "xml2"),
    reason = "for PDF/Typst export (markdown rendering in document fields)"
  )

  # ---- 0. restrict_template guard (before any filesystem operation) ----------
  validate_restrict_template(restrict_template, template_path)

  # ---- 1. Input validation (plot, title, path, dpi, font_path, session) ------
  validate_bfh_export_figure_inputs(
    plot, output, metadata, dpi, font_path, inject_assets, batch_session,
    template_path
  )

  # ---- 1a. Runtime security guard for inject_assets --------------------------
  .validate_inject_assets(inject_assets)

  # ---- 1b. Data definition is not rendered in full-width mode ----------------
  .warn_figure_data_definition(metadata)

  # ---- 2. Custom template validation ------------------------------------------
  template_path <- validate_template_path(template_path)

  # ---- 3. Quarto check --------------------------------------------------------
  if (!quarto_available()) {
    bfh_abort(
      paste0(
        "Quarto CLI not found or version too old. PDF export requires Quarto >= 1.4.0.\n",
        "  Install or update from: https://quarto.org\n",
        "  After installation, restart R and try again.\n",
        "  Typst support was added in Quarto 1.4."
      ),
      class = "bfhcharts_export_error"
    )
  }

  # ---- 4. Temp workspace (unique file names per export) -----------------------
  workspace <- prepare_temp_workspace(batch_session)
  temp_dir <- workspace$temp_dir
  chart_svg <- workspace$chart_svg
  typst_file <- workspace$typst_file

  if (!is.null(batch_session)) {
    # Batch mode: only clean per-export files (NOT the shared temp_dir)
    on.exit(
      {
        unlink(chart_svg)
        unlink(typst_file)
      },
      add = TRUE
    )
  } else {
    on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  }

  # ---- 5. Plot preparation + full-width SVG -----------------------------------
  plot_for_export <- prepare_figure_plot(plot)
  export_chart_svg(
    plot_for_export, chart_svg, dpi,
    width_mm = PDF_IMAGE_WIDTH_FULL_MM
  )

  # ---- 6. Typst document + font_path resolution --------------------------------
  metadata_full <- build_figure_metadata(metadata)
  effective_font_path <- compose_typst_from_parts(
    metadata_full, empty_spc_stats(), chart_svg, typst_file, template,
    template_path, batch_session, font_path, inject_assets
  )

  # ---- 7. Compile ----------------------------------------------------------------
  compile_pdf_via_quarto(typst_file, output, effective_font_path, ignore_system_fonts)

  invisible(plot)
}


# ============================================================================
# SHARED HELPERS (bfh_export_figure_pdf + bfh_stage_figure_page)
# ============================================================================

#' Validate the plot argument of the figure export functions
#'
#' Requires a single ggplot. Composite plots (patchwork) inherit from ggplot
#' but are rejected: `+ labs(title = NULL)` and `+ theme(plot.margin = ...)`
#' only reach the last sub-plot, so the page would silently violate the
#' "title only in the header" rule. The class name is checked directly so
#' patchwork is not a dependency.
#'
#' @noRd
.validate_figure_plot <- function(plot) {
  if (!inherits(plot, "ggplot")) {
    bfh_abort(
      paste0(
        "plot must be a ggplot object.\n",
        "  Got class: ", paste(class(plot), collapse = ", ")
      ),
      class = "bfhcharts_export_error"
    )
  }
  if (inherits(plot, "patchwork")) {
    bfh_abort(
      paste0(
        "plot must be a single ggplot object: composite plots are not supported.\n",
        "  Got a patchwork object; title and margin handling would only reach",
        " the last sub-plot."
      ),
      class = "bfhcharts_export_error"
    )
  }
  invisible(plot)
}


#' Validate metadata$title for the figure export functions
#'
#' Figures have no `x$config$chart_title`, so the template title has no other
#' source. An empty title would make the template render its placeholder text.
#'
#' @noRd
.validate_figure_title <- function(metadata) {
  title <- metadata[["title"]]
  if (!is.character(title) || length(title) != 1L || is.na(title) ||
    !nzchar(trimws(title))) {
    bfh_abort(
      paste0(
        "metadata$title is required: a single non-NA character string with at ",
        "least one non-whitespace character.\n",
        "  Got: ",
        if (is.null(title)) {
          "NULL"
        } else {
          paste0(paste(class(title), collapse = "/"), " (length ", length(title), ")")
        }
      ),
      class = "bfhcharts_export_error"
    )
  }
  invisible(metadata)
}


#' Validate inputs to bfh_export_figure_pdf()
#'
#' @noRd
validate_bfh_export_figure_inputs <- function(plot, output, metadata, dpi,
                                              font_path, inject_assets,
                                              batch_session, template_path) {
  .validate_figure_plot(plot)
  if (!is.list(metadata)) {
    bfh_abort("metadata must be a list", class = "bfhcharts_export_error")
  }
  # Title first: the common validator's per-field length check is not NA-safe,
  # so a malformed title must be rejected here with a classed error.
  .validate_figure_title(metadata)
  validate_export_common_inputs(
    output, metadata, dpi, font_path, inject_assets, batch_session,
    template_path,
    known_fields = c(EXPORT_KNOWN_METADATA_FIELDS, "title")
  )
}


#' Warn when a data definition would be dropped silently
#'
#' Full-width mode does not render data_definition (design D7). The text is
#' caller-supplied clinical content and must not vanish without notice.
#'
#' @noRd
.warn_figure_data_definition <- function(metadata) {
  data_definition <- metadata[["data_definition"]]
  if (is.character(data_definition) &&
    any(nzchar(trimws(data_definition)), na.rm = TRUE)) {
    bfh_warn(
      paste0(
        "metadata$data_definition is not rendered in full-width figure mode ",
        "and is omitted from the page."
      ),
      class = "bfhcharts_export_warning"
    )
  }
  invisible(NULL)
}


#' Build the finalized template metadata for a figure page
#'
#' Merges caller metadata with defaults (title from metadata$title) and sets
#' the full-width flag AFTER the merge. bfh_merge_metadata() whitelists its
#' fields, so a caller-supplied spc_panel can never reach the template.
#'
#' @noRd
build_figure_metadata <- function(metadata) {
  metadata_full <- bfh_merge_metadata(metadata, chart_title = metadata$title)
  metadata_full$spc_panel <- FALSE
  metadata_full
}


#' Prepare a ggplot for full-width figure export
#'
#' Strips title/subtitle (the title goes in the blue header), removes blank
#' axis titles and sets 0 mm margins. The caller's theme is otherwise left
#' untouched, and no SPC label recalculation is performed.
#'
#' Blank axis titles are judged on the *resolved* labels: since ggplot2 4.0
#' `plot$labels$x` is NULL when the title is derived from `aes()`, so reading
#' it would wrongly remove valid axis titles from almost every figure.
#'
#' @noRd
prepare_figure_plot <- function(plot) {
  plot <- plot + ggplot2::labs(title = NULL, subtitle = NULL)

  labels <- .resolved_plot_labels(plot)
  if (.is_blank_axis_title(labels$x)) {
    plot <- plot + ggplot2::theme(axis.title.x.bottom = ggplot2::element_blank())
  }
  if (.is_blank_axis_title(labels$y)) {
    plot <- plot + ggplot2::theme(axis.title.y.left = ggplot2::element_blank())
  }

  prepare_plot_for_export(plot, margin_mm = 0)
}


#' Resolved plot labels across supported ggplot2 versions
#'
#' Uses ggplot2::get_labs() when the installed ggplot2 exports it, otherwise
#' the labels of the built plot. Falls back to `plot$labels` if building fails
#' (the failure then surfaces with a proper message during ggsave()).
#'
#' @noRd
.resolved_plot_labels <- function(plot) {
  get_labs_fn <- tryCatch(
    getExportedValue("ggplot2", "get_labs"),
    error = function(e) NULL
  )
  tryCatch(
    if (is.function(get_labs_fn)) {
      get_labs_fn(plot)
    } else {
      ggplot2::ggplot_build(plot)$plot$labels
    },
    error = function(e) plot$labels
  )
}


#' Is an axis title NULL or blank?
#'
#' @noRd
.is_blank_axis_title <- function(title) {
  if (is.null(title)) {
    return(TRUE)
  }
  is.character(title) && all(is.na(title) | !nzchar(trimws(title)))
}
