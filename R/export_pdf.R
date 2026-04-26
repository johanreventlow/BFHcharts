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
#'       Auto-generated format: "Periode: feb. 2019 – mar. 2022 • Gns. måned: 58938/97266 •
#'       Seneste måned: 60756/88509 • Nuværende niveau: 64,5\%"
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
#'     \item \code{FALSE} (default): Use standard texts only — no external data sharing
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
#' - Includes: runs (serielængde), crossings (antal kryds), outliers
#'
#' **Auto-Generated Details:**
#' - If \code{metadata$details} is not provided, details are auto-generated
#' - Format: "Periode: start - slut . Gns. interval: values . Seneste interval: values . Nuvaerende niveau: cl"
#' - p/u-charts show numerator/denominator (e.g., "58938/97266")
#' - Other chart types show only values (e.g., "127")
#' - Interval labels adapt to data frequency (month, week, day, etc.)
#'
#' @export
#' @seealso
#'   - [bfh_qic()] to create SPC charts
#'   - [bfh_export_png()] to export as PNG
#'   - [bfh_create_typst_document()] for low-level Typst generation
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
#'       data_definition = "Antal hospital-erhvervede infektioner per måned"
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
                           inject_assets = NULL,
                           batch_session = NULL) {
  # Input validation
  if (!inherits(x, "bfh_qic_result")) {
    stop(
      "x must be a bfh_qic_result object from bfh_qic().\n",
      "  Got class: ", paste(class(x), collapse = ", "),
      call. = FALSE
    )
  }

  validate_export_path(output, extension = "pdf", ext_action = "stop")

  if (!is.list(metadata)) {
    stop("metadata must be a list", call. = FALSE)
  }

  # ============================================================================
  # METADATA VALIDATION - Type checking and length limits
  # ============================================================================
  known_fields <- c(
    "hospital", "department", "analysis", "details", "author",
    "date", "data_definition", "target", "footer_content"
  )

  # Warn about unknown metadata fields (may indicate typos or misuse)
  unknown_fields <- setdiff(names(metadata), known_fields)
  if (length(unknown_fields) > 0) {
    warning(
      "Unknown metadata fields will be ignored: ",
      paste(unknown_fields, collapse = ", "),
      call. = FALSE
    )
  }

  # Validate each known field's type and length
  for (field in names(metadata)) {
    if (field %in% known_fields) {
      value <- metadata[[field]]

      # Type validation: Must be character or NULL (with special cases)
      if (!is.null(value) && !is.character(value)) {
        # Special case: date can be Date object
        if (field == "date" && inherits(value, "Date")) {
          next # Allow Date objects for date field
        }
        # Special case: target can be numeric
        if (field == "target" && is.numeric(value)) {
          next # Allow numeric values for target field
        }
        stop(
          "metadata$", field, " must be a character string",
          if (field == "date") " (or Date object)" else "",
          if (field == "target") " (or numeric)" else "",
          "\n  Got: ", class(value)[1],
          call. = FALSE
        )
      }

      # Length validation: Max 10,000 characters to prevent DoS
      if (is.character(value) && nchar(value) > 10000) {
        stop(
          "metadata$", field, " exceeds maximum length of 10,000 characters\n",
          "  Current length: ", nchar(value),
          call. = FALSE
        )
      }
    }
  }

  # ============================================================================
  # VALIDATE OPTIONAL PARAMETERS - font_path, inject_assets
  # ============================================================================
  if (!is.null(inject_assets) && !is.function(inject_assets)) {
    stop("inject_assets must be a function or NULL", call. = FALSE)
  }

  if (!is.null(font_path)) {
    if (!is.character(font_path) || length(font_path) != 1) {
      stop("font_path must be a single character string or NULL", call. = FALSE)
    }
  }

  if (!is.numeric(dpi) || length(dpi) != 1 || is.na(dpi) || dpi <= 0) {
    stop("dpi must be a single positive numeric value", call. = FALSE)
  }

  # ============================================================================
  # BATCH SESSION VALIDATION
  # ============================================================================
  if (!is.null(batch_session)) {
    if (!inherits(batch_session, "bfh_export_session")) {
      stop(
        "batch_session must be a bfh_export_session object from bfh_create_export_session()",
        call. = FALSE
      )
    }
    if (batch_session$closed()) {
      stop("batch_session is already closed", call. = FALSE)
    }
    if (!is.null(template_path)) {
      stop(
        "batch_session cannot be combined with template_path.\n",
        "  Custom templates are not supported in batch sessions.",
        call. = FALSE
      )
    }
    if (!is.null(inject_assets)) {
      stop(
        "batch_session cannot be combined with inject_assets.\n",
        "  Pass inject_assets to bfh_create_export_session() instead.",
        call. = FALSE
      )
    }
  }

  # ============================================================================
  # AUTO-ANALYSIS - Generate analysis text if requested
  # ============================================================================
  if (isTRUE(auto_analysis) && is.null(metadata$analysis)) {
    metadata$analysis <- bfh_generate_analysis(
      x = x,
      metadata = metadata,
      use_ai = use_ai,
      min_chars = analysis_min_chars,
      max_chars = analysis_max_chars
    )
  }

  # ============================================================================
  # AUTO-DETAILS - Generate details text if not provided
  # ============================================================================
  if (is.null(metadata$details)) {
    metadata$details <- bfh_generate_details(x)
  }

  # ============================================================================
  # SECURITY VALIDATION - Custom template path
  # All security checks MUST happen BEFORE file system operations or Quarto calls
  # ============================================================================
  if (!is.null(template_path)) {
    if (!is.character(template_path) || length(template_path) != 1) {
      stop("template_path must be a single character string", call. = FALSE)
    }
    validate_export_path(template_path)
  }

  # ============================================================================
  # FILE VALIDATION - After security checks pass
  # ============================================================================
  if (!is.null(template_path)) {
    if (!file.exists(template_path)) {
      stop(
        "Custom template file not found: ", basename(template_path), "\n",
        "  Ensure the file exists and the path is correct.",
        call. = FALSE
      )
    }
    template_path <- validate_export_path(template_path, normalize = TRUE)
    if (dir.exists(template_path)) {
      stop(
        "template_path must be a file, not a directory: ", basename(template_path),
        call. = FALSE
      )
    }
    if (!grepl("\\.typ$", template_path, ignore.case = TRUE)) {
      stop(
        "template_path must be a .typ file: ", basename(template_path), "\n",
        "  Typst templates require the .typ extension.",
        call. = FALSE
      )
    }
  }

  # ============================================================================
  # SYSTEM CHECKS - After all security and file validation
  # ============================================================================
  # Check Quarto availability and version
  if (!quarto_available()) {
    stop(
      "Quarto CLI not found or version too old. PDF export requires Quarto >= 1.4.0.\n",
      "  Install or update from: https://quarto.org\n",
      "  After installation, restart R and try again.\n",
      "  Typst support was added in Quarto 1.4.",
      call. = FALSE
    )
  }

  # Create or reuse temporary directory for intermediate files
  if (!is.null(batch_session)) {
    # Batch mode: reuse session tmpdir — template already staged there
    temp_dir <- batch_session$tmpdir
    # Register per-export file cleanup only (do NOT unlink session tmpdir)
    on.exit(
      {
        unlink(file.path(temp_dir, "chart.svg"))
        unlink(file.path(temp_dir, "document.typ"))
      },
      add = TRUE
    )
  } else {
    temp_dir <- tempfile("bfh_pdf_")

    # Register cleanup BEFORE dir.create() to ensure cleanup on any error
    on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

    dir.create(temp_dir, recursive = TRUE)

    # Security: Set restrictive permissions (owner-only: rwx------)
    # Prevents other users from reading sensitive healthcare data in temp files
    Sys.chmod(temp_dir, mode = "0700", use_umask = FALSE)

    # Security: Verify directory ownership on Unix systems
    # Prevents TOCTOU attacks where attacker replaces our temp dir
    if (.Platform$OS.type == "unix") {
      dir_info <- file.info(temp_dir)
      current_uid <- suppressWarnings(as.integer(Sys.getenv("UID")))
      # Only verify if UID is available and valid (not NA or 0)
      if (length(current_uid) > 0 && !is.na(current_uid) && current_uid > 0) {
        if (dir_info$uid != current_uid) {
          unlink(temp_dir, recursive = TRUE)
          stop(
            "Temp directory ownership mismatch (possible security issue)",
            call. = FALSE
          )
        }
      }
    }
  }

  # Extract chart title from plot (will be used in Typst template)
  chart_title <- x$config$chart_title
  if (is.null(chart_title)) chart_title <- ""

  # Create plot without title for PDF (title goes in Typst template)
  plot_no_title <- x$plot + ggplot2::labs(title = NULL, subtitle = NULL)

  # Update the bfh_qic_result object with the title-stripped plot
  # This is needed for recalculate_labels_for_export()
  x_for_export <- x
  x_for_export$plot <- plot_no_title

  # Recalculate label positions for PDF export
  # - target dimensions (PDF_CHART): used for label POSITIONING (visible chart area)
  # - font sizing uses fixed PDF_LABEL_SIZE constant (calibrated for 250x140mm)
  plot_for_export <- recalculate_labels_for_export(
    x = x_for_export,
    target_width_mm = PDF_CHART_WIDTH_MM,
    target_height_mm = PDF_CHART_HEIGHT_MM,
    label_size = PDF_LABEL_SIZE
  )

  # Apply PDF-specific theme adjustments (zero margins)
  plot_for_export <- prepare_plot_for_export(plot_for_export, margin_mm = 0)

  # Export chart to temporary SVG (vector format for sharp rendering in PDF)
  # Note: ggsave uses PDF_IMAGE dimensions (250x140mm) for the actual image size
  # while labels were calculated for PDF_CHART dimensions (202x140mm) which
  # represents the visible area in the Typst template
  chart_svg <- file.path(temp_dir, "chart.svg")
  tryCatch(
    ggplot2::ggsave(
      filename = chart_svg,
      plot = plot_for_export,
      width = PDF_IMAGE_WIDTH_MM / 25.4, # 250mm - original working size
      height = PDF_IMAGE_HEIGHT_MM / 25.4, # 140mm
      units = "in",
      dpi = dpi,
      device = "svg"
    ),
    error = function(e) {
      stop(
        "Failed to save chart image\n",
        "  Error: ", conditionMessage(e),
        call. = FALSE
      )
    }
  )

  # Extract SPC statistics (including outliers and run chart detection)
  spc_stats <- bfh_extract_spc_stats(x)

  # Merge user metadata with defaults
  metadata_full <- bfh_merge_metadata(metadata, chart_title)

  # Resolve font_path: per-export arg > session default > NULL
  effective_font_path <- font_path %||% batch_session$font_path

  # Create Typst document
  typst_file <- file.path(temp_dir, "document.typ")
  bfh_create_typst_document(
    chart_image = chart_svg,
    output = typst_file,
    metadata = metadata_full,
    spc_stats = spc_stats,
    template = template,
    template_path = template_path,
    skip_template_copy = !is.null(batch_session)
  )

  # Inject external assets (fonts, images) if callback provided (single-call mode only)
  if (is.function(inject_assets)) {
    inject_assets(file.path(temp_dir, "bfh-template"))

    # Auto-detect font path fra injicerede assets hvis ikke eksplicit angivet
    if (is.null(effective_font_path)) {
      injected_fonts <- file.path(temp_dir, "bfh-template", "fonts")
      if (dir.exists(injected_fonts)) {
        effective_font_path <- injected_fonts
      }
    }
  }

  # Compile to PDF via Quarto (with optional font path)
  bfh_compile_typst(typst_file, output, font_path = effective_font_path)

  # Return input object invisibly for pipe chaining
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

  # Beregn label_size: brug eksplicit værdi eller beregn fra target-dimensioner
  new_label_size <- label_size %||% compute_label_size_for_viewport(
    target_width_inches, target_height_inches
  )

  # Re-add labels with TARGET dimensions for positioning
  # and fixed PDF_LABEL_SIZE for font sizing
  plot_with_labels <- add_spc_labels(
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
