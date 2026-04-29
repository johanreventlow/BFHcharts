#' Export BFH QIC Chart to PDF via Typst
#'
#' Exports an SPC chart created by \code{bfh_qic()} to a PDF document using
#' Typst templates for hospital branding. Requires Quarto CLI for compilation.
#'
#' @param x A \code{bfh_qic_result} object from \code{bfh_qic()}
#' @param output Character string specifying the output PDF file path
#' @param metadata List with optional metadata fields:
#'   \itemize{
#'     \item \code{hospital}: Hospital name (default: "Bispebjerg og Frederiksberg Hospital")
#'     \item \code{department}: Department/unit name (optional)
#'     \item \code{analysis}: Analysis text with findings (optional)
#'     \item \code{details}: Period info, averages (auto-generated if not provided).
#'       Auto-generated format: "Periode: feb. 2019 - mar. 2022 * Gns. maaned: 58938/97266 *
#'       Seneste maaned: 60756/88509 * Nuvaerende niveau: 64,5\%"
#'     \item \code{author}: Author name (optional)
#'     \item \code{date}: Report date (default: Sys.Date())
#'     \item \code{data_definition}: Data definition text (optional)
#'     \item \code{target}: Target value for analysis context (numeric or character, optional)
#'     \item \code{footer_content}: Additional content to display below the chart (optional).
#'       Supports markdown formatting (bold, italic, line breaks).
#'   }
#' @param template Character string specifying template name (default: "bfh-diagram")
#' @param template_path Optional path to a custom Typst template file. When provided,
#'   this overrides the packaged template. The template must exist and be a valid
#'   Typst file (.typ). Default is NULL (uses packaged BFH template).
#' @param auto_analysis Logical. If TRUE and \code{metadata$analysis} is not provided,
#'   automatically generates analysis text using \code{bfh_generate_analysis()}.
#'   Default is FALSE for backward compatibility.
#' @param use_ai Logical. Controls AI usage for auto-analysis:
#'   \itemize{
#'     \item \code{FALSE} (default): Use standard texts only - no external data sharing
#'     \item \code{TRUE}: Use AI via BFHllm (requires BFHllm installed; error if not)
#'   }
#'   Only used when \code{auto_analysis = TRUE}. See \code{bfh_generate_analysis()}
#'   for security policy details.
#' @param analysis_min_chars Minimum characters for AI-generated analysis. Default 300.
#'   Only used when \code{auto_analysis = TRUE}.
#' @param analysis_max_chars Maximum characters for AI-generated analysis. Default 375.
#'   Only used when \code{auto_analysis = TRUE}.
#' @param dpi Resolution passed to \code{ggplot2::ggsave()}. Default 150.
#'   PDF export currently uses SVG as intermediate format, so this is mainly
#'   relevant if the plot contains rasterized content.
#' @param font_path Optional path to directory containing additional fonts.
#'   Passed as \code{--font-path} to the Typst compiler. Useful when fonts
#'   (e.g., Mari) are bundled in a downstream package and not installed
#'   system-wide on the deployment platform.
#' @param ignore_system_fonts Logical. If \code{TRUE} (default), passes
#'   \code{--ignore-system-fonts} to Typst so only fonts from \code{font_path}
#'   (or bundled template fonts) are used. Prevents inconsistent rendering
#'   when developers have additional Mari variants (e.g., Mari Heavy)
#'   installed system-wide. Passed to the internal Typst compiler.
#' @param inject_assets Optional callback function called after Typst template
#'   structure is created but before compilation. Receives one argument: the path
#'   to the template directory (e.g., \code{<temp_dir>/bfh-template}). Use this
#'   to copy fonts, images, or other assets into the template directory when they
#'   are not bundled in BFHcharts (e.g., proprietary fonts in a private package).
#'   Cannot be combined with \code{batch_session} (pass \code{inject_assets} to
#'   \code{bfh_create_export_session()} instead).
#' @param batch_session Optional \code{bfh_export_session} object from
#'   \code{bfh_create_export_session()}. When provided, the packaged template
#'   assets are reused from the session tmpdir instead of being copied on every
#'   call, which eliminates the dominant I/O cost in batch workflows.
#'   \itemize{
#'     \item Cannot be combined with \code{template_path} or \code{inject_assets}.
#'     \item \code{font_path} here overrides \code{session$font_path}.
#'     \item Close the session with \code{close(session)} after the batch is done.
#'   }
#'
#' @return The input object \code{x} invisibly, enabling pipe chaining
#'
#' @details
#' **Requirements:**
#' - Quarto CLI (>= 1.4.0) must be installed
#' - Install from: https://quarto.org
#'
#' **PDF Generation Process:**
#' 1. Extract chart title from plot (removed from image for template)
#' 2. Export chart to temporary PNG (without title)
#' 3. Extract SPC statistics (runs, crossings, outliers)
#' 4. Generate Typst document (.typ) with template
#' 5. Compile to PDF via Quarto CLI
#' 6. Clean up temporary files
#'
#' **Title Handling:**
#' - Chart title is extracted and passed to Typst template
#' - Title appears in PDF header, NOT in chart image
#' - This differs from PNG export where title is in the image
#'
#' **Plot Optimization for PDF:**
#' - Plot margins are set to 0mm for optimal fit in Typst template
#' - Blank axis titles (NULL or empty) are removed with element_blank()
#' - User-defined axis titles are preserved
#'
#' **SPC Statistics:**
#' - Automatically extracted from bfh_qic_result$summary
#' - Displayed in SPC table on PDF
#' - Includes: runs (serielaengde), crossings (antal kryds), outliers
#'
#' **Auto-Generated Details:**
#' - If \code{metadata$details} is not provided, details are auto-generated
#' - Format: "Periode: start - slut . Gns. interval: values . Seneste interval: values . Nuvaerende niveau: cl"
#' - p/u-charts show numerator/denominator (e.g., "58938/97266")
#' - Other chart types show only values (e.g., "127")
#' - Interval labels adapt to data frequency (month, week, day, etc.)
#'
#' @section Security:
#' Both \code{inject_assets} and \code{template_path} are designed for
#' advanced use cases (proprietary fonts, organization-specific templates)
#' and \strong{must be treated as trusted-code-only}:
#' \itemize{
#'   \item \code{inject_assets} is invoked with full filesystem access in
#'     the template directory. Whatever R code the callback contains runs
#'     with the same privileges as the calling process -- equivalent to
#'     sourcing arbitrary R from disk.
#'   \item \code{template_path} is compiled by the Typst binary. A custom
#'     template can read and write arbitrary paths during compilation.
#' }
#' Treat both parameters with the same trust contract you would apply to
#' \code{source()}: pass only code-reviewed, organizationally controlled
#' values. \strong{Never} forward user-supplied input (Shiny inputs,
#' query parameters, untrusted uploads) to either parameter -- doing so
#' creates a privilege-escalation vector. If your application surface
#' needs to expose template customization to end users, validate against
#' a fixed allow-list of approved templates and callbacks before invoking
#' \code{bfh_export_pdf()}.
#'
#' The same trust requirement applies to \code{inject_assets} when passed
#' to \code{\link{bfh_create_export_session}()}.
#'
#' @export
#' @seealso
#'   - [bfh_qic()] to create SPC charts
#'   - [bfh_export_png()] to export as PNG
#'   - [bfh_create_export_session()] for batch workflows (same trust
#'     requirement applies to its `inject_assets` parameter)
#' @examples
#' \dontrun{
#' library(BFHcharts)
#'
#' # Create sample data
#' data <- data.frame(
#'   month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
#'   infections = rpois(24, lambda = 15)
#' )
#'
#' # Create and export chart to PDF in one pipeline
#' bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Hospital-Acquired Infections"
#' ) |>
#'   bfh_export_pdf(
#'     "infections_report.pdf",
#'     metadata = list(
#'       hospital = "BFH",
#'       department = "Kvalitetsafdeling",
#'       analysis = "Signifikant fald observeret efter intervention",
#'       data_definition = "Antal hospital-erhvervede infektioner per maaned"
#'     )
#'   )
#'
#' # Multiple exports from same chart
#' result <- bfh_qic(data, month, infections,
#'   chart_type = "i",
#'   chart_title = "Infections"
#' )
#'
#' # PNG for email/presentation
#' bfh_export_png(result, "infections.png")
#'
#' # PDF for official report
#' bfh_export_pdf(result, "infections_report.pdf",
#'   metadata = list(department = "ICU")
#' )
#'
#' # Batch export: reuse template assets across multiple exports
#' departments <- c("ICU", "Medicine", "Surgery")
#' session <- bfh_create_export_session()
#' on.exit(close(session))
#' for (dept in departments) {
#'   bfh_export_pdf(result, paste0(dept, "_report.pdf"),
#'     metadata = list(department = dept),
#'     batch_session = session
#'   )
#' }
#' }
bfh_export_pdf <- function(x,
                           output,
                           metadata = list(),
                           template = "bfh-diagram",
                           template_path = NULL,
                           auto_analysis = FALSE,
                           use_ai = FALSE,
                           analysis_min_chars = 300,
                           analysis_max_chars = 375,
                           dpi = 150,
                           font_path = NULL,
                           ignore_system_fonts = TRUE,
                           inject_assets = NULL,
                           batch_session = NULL) {
  # ---- 1. Input-validering (class, metadata, dpi, font_path, session) --------
  validate_bfh_export_pdf_inputs(
    x, output, metadata, dpi, font_path, inject_assets, batch_session, template_path
  )

  # ---- 2. Metadata (auto-analysis + auto-details) ----------------------------
  metadata <- prepare_export_metadata(
    x, metadata, auto_analysis, use_ai, analysis_min_chars, analysis_max_chars
  )

  # ---- 3. Security + fil-validering af custom template -----------------------
  # Alle security-tjek SKAL ske INDEN filsystem-operationer eller Quarto-kald
  template_path <- validate_template_path(template_path)

  # ---- 4. Quarto-tjek --------------------------------------------------------
  if (!quarto_available()) {
    stop(
      "Quarto CLI not found or version too old. PDF export requires Quarto >= 1.4.0.\n",
      "  Install or update from: https://quarto.org\n",
      "  After installation, restart R and try again.\n",
      "  Typst support was added in Quarto 1.4.",
      call. = FALSE
    )
  }

  # ---- 5. Temp-workspace (unikke filnavne per eksport) -----------------------
  workspace <- prepare_temp_workspace(batch_session)
  temp_dir <- workspace$temp_dir
  chart_svg <- workspace$chart_svg
  typst_file <- workspace$typst_file

  # Registrer cleanup i orchestrator-scope (on.exit ser lokale variable)
  if (!is.null(batch_session)) {
    # Batch-mode: ryd kun per-eksport filer op (IKKE temp_dir)
    on.exit(
      {
        unlink(chart_svg)
        unlink(typst_file)
      },
      add = TRUE
    )
  } else {
    # Single-call mode: ryd hele temp_dir op
    # Registreres efter dir.create() — men prepare_temp_workspace() har
    # allerede lavet mappen, så vi registrerer her for at fange fejl i trin 6+
    on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  }

  # ---- 6. Plot-forberedelse (title strip + label recalc + margin) ------------
  plot_for_export <- prepare_export_plot(x)

  # ---- 7. SVG-eksport --------------------------------------------------------
  export_chart_svg(plot_for_export, chart_svg, dpi)

  # ---- 8. SPC-statistik -------------------------------------------------------
  spc_stats <- bfh_extract_spc_stats(x)

  # ---- 9. Typst-dokument + font_path-opløsning --------------------------------
  effective_font_path <- compose_typst_document(
    x, chart_svg, typst_file,
    metadata, spc_stats, template, template_path,
    batch_session, font_path, inject_assets
  )

  # ---- 10. PDF-kompilering via Quarto ----------------------------------------
  compile_pdf_via_quarto(typst_file, output, effective_font_path, ignore_system_fonts)

  invisible(x)
}

# ============================================================================
# LABEL RECALCULATION FOR PDF EXPORT
# ============================================================================

#' Strip Label Layers from Plot
#'
#' Removes marquee label layers from a ggplot object to prepare for
#' recalculation with different viewport dimensions.
#'
#' @param plot A ggplot2 object
#'
#' @return ggplot2 object without marquee label layers
#'
#' @details
#' Identifies layers by checking if the geom class name contains "Marquee".
#' This allows the plot to be re-labeled with correct positions for
#' different export dimensions.
#'
#' @keywords internal
#' @noRd
strip_label_layers <- function(plot) {
  if (!inherits(plot, "ggplot")) {
    return(plot)
  }

  # Identify layers to keep (everything except GeomMarquee)
  layers_to_keep <- vapply(plot$layers, function(layer) {
    geom_class <- class(layer$geom)[1]
    !grepl("Marquee", geom_class, ignore.case = TRUE)
  }, logical(1))

  # Keep only non-marquee layers
  plot$layers <- plot$layers[layers_to_keep]

  return(plot)
}


#' Recalculate SPC Labels for Export Dimensions
#'
#' Removes existing label layers and re-adds them with positions
#' calculated for the target export dimensions. This ensures labels
#' are correctly positioned for PDF output regardless of the original
#' interactive viewport size.
#'
#' @param x A bfh_qic_result object
#' @param target_width_mm Target width in mm for label POSITIONING (visible chart area)
#' @param target_height_mm Target height in mm for label POSITIONING
#' @param label_size Optional fixed label_size. Hvis NULL, beregnes automatisk
#'   fra target-dimensionerne via compute_label_size_for_viewport().
#'
#' @return ggplot object with recalculated label positions
#'
#' @details
#' Label positioning uses target dimensions (the visible chart area in the template).
#' Font sizing is recalculated via `compute_label_size_for_viewport()` from the
#' target dimensions, unless an explicit `label_size` is provided.
#' PDF_LABEL_SIZE (6pt) is the reference value calibrated to the PDF template
#' dimensions (250x140mm).
#'
#' @keywords internal
#' @noRd
recalculate_labels_for_export <- function(x, target_width_mm, target_height_mm,
                                          label_size = NULL) {
  # Validate input
  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object", call. = FALSE)
  }

  # Convert target dimensions to inches for label positioning
  target_width_inches <- target_width_mm / 25.4
  target_height_inches <- target_height_mm / 25.4

  # Strip existing label layers
  plot_stripped <- strip_label_layers(x$plot)

  # Extract configuration
  config <- x$config
  label_config <- config$label_config

  # Beregn label_size: brug eksplicit vaerdi eller beregn fra target-dimensioner
  new_label_size <- label_size %||% compute_label_size_for_viewport(
    target_width_inches, target_height_inches
  )

  # Re-add labels with TARGET dimensions for positioning
  # and fixed PDF_LABEL_SIZE for font sizing
  # Se .muffle_expected_warnings() helper for hvilke warnings der mufles.
  plot_with_labels <- .muffle_expected_warnings(
    add_spc_labels(
      plot = plot_stripped,
      qic_data = x$qic_data,
      y_axis_unit = config$y_axis_unit %||% "count",
      label_size = new_label_size,
      viewport_width = target_width_inches,
      viewport_height = target_height_inches,
      target_text = config$target_text,
      centerline_value = label_config$centerline_value,
      has_frys_column = label_config$has_frys_column,
      has_skift_column = label_config$has_skift_column,
      verbose = FALSE,
      language = config$language %||% "da"
    )
  )

  return(plot_with_labels)
}


#' Prepare Plot for Export with Custom Margins
#'
#' Applies export-specific margin adjustments to a ggplot object.
#' Used primarily by PDF export to override the default 5mm margins
#' (set by apply_spc_theme) to 0mm for Typst template compatibility.
#'
#' Note: Axis title removal is now handled centrally by apply_spc_theme()
#' when the plot is created via bfh_qic().
#'
#' @param plot A ggplot2 object
#' @param margin_mm Numeric. Margin size in millimeters (default: 0 for PDF)
#'
#' @return Modified ggplot2 object with updated margins
#'
#' @details
#' **Usage:**
#' - PDF export: margin_mm = 0 for optimal fit in Typst template
#' - PNG export: No longer needed (default 5mm from bfh_qic is correct)
#'
#' @keywords internal
#' @noRd
prepare_plot_for_export <- function(plot, margin_mm = 0) {
  # Validate inputs
  if (!inherits(plot, "ggplot")) {
    stop("plot must be a ggplot2 object", call. = FALSE)
  }

  if (!is.numeric(margin_mm) || length(margin_mm) != 1 || margin_mm < 0) {
    stop("margin_mm must be a non-negative number", call. = FALSE)
  }

  # Set plot margins (axis title removal is now in apply_spc_theme)
  plot <- plot + ggplot2::theme(
    plot.margin = ggplot2::margin(margin_mm, margin_mm, margin_mm, margin_mm, "mm")
  )

  return(plot)
}
