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
#' @param use_ai Logical or NULL. Controls AI usage for auto-analysis:
#'   \itemize{
#'     \item \code{NULL} (default): Auto-detect BFHllm availability
#'     \item \code{TRUE}: Use AI via BFHllm (with fallback to standard texts)
#'     \item \code{FALSE}: Use standard texts only (no AI)
#'   }
#'   Only used when \code{auto_analysis = TRUE}.
#' @param analysis_min_chars Minimum characters for AI-generated analysis. Default 300.
#'   Only used when \code{auto_analysis = TRUE}.
#' @param analysis_max_chars Maximum characters for AI-generated analysis. Default 375.
#'   Only used when \code{auto_analysis = TRUE}.
#' @param font_path Optional path to directory containing additional fonts.
#'   Passed as \code{--font-path} to the Typst compiler. Useful when fonts
#'   (e.g., Mari) are bundled in a downstream package and not installed
#'   system-wide on the deployment platform.
#' @param inject_assets Optional callback function called after Typst template
#'   structure is created but before compilation. Receives one argument: the path
#'   to the template directory (e.g., \code{<temp_dir>/bfh-template}). Use this
#'   to copy fonts, images, or other assets into the template directory when they
#'   are not bundled in BFHcharts (e.g., proprietary fonts in a private package).
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
#' result <- bfh_qic(data, month, infections, chart_type = "i",
#'                   chart_title = "Infections")
#'
#' # PNG for email/presentation
#' bfh_export_png(result, "infections.png")
#'
#' # PDF for official report
#' bfh_export_pdf(result, "infections_report.pdf",
#'                metadata = list(department = "ICU"))
#' }
bfh_export_pdf <- function(x,
                           output,
                           metadata = list(),
                           template = "bfh-diagram",
                           template_path = NULL,
                           auto_analysis = FALSE,
                           use_ai = NULL,
                           analysis_min_chars = 300,
                           analysis_max_chars = 375,
                           font_path = NULL,
                           inject_assets = NULL) {
  # Input validation
  if (!inherits(x, "bfh_qic_result")) {
    stop(
      "x must be a bfh_qic_result object from bfh_qic().\n",
      "  Got class: ", paste(class(x), collapse = ", "),
      call. = FALSE
    )
  }

  if (!is.character(output) || length(output) != 1 || nchar(output) == 0) {
    stop("output must be a non-empty character string specifying the PDF file path",
      call. = FALSE
    )
  }

  # Security: Prevent path traversal attacks (check BEFORE file operations)
  if (grepl("..", output, fixed = TRUE)) {
    stop(
      "output path cannot contain '..' (path traversal attempt detected)\n",
      "  Provided path: ", basename(output),
      call. = FALSE
    )
  }

  # Security: Prevent shell metacharacter injection
  shell_metachars <- c(";", "|", "&", "$", "`", "(", ")", "{", "}", "<", ">", "\n", "\r")
  if (any(vapply(shell_metachars, function(char) grepl(char, output, fixed = TRUE), logical(1)))) {
    stop(
      "output path contains potentially unsafe characters\n",
      "  Path: ", basename(output),
      call. = FALSE
    )
  }

  if (!is.list(metadata)) {
    stop("metadata must be a list", call. = FALSE
    )
  }

  # ============================================================================
  # METADATA VALIDATION - Type checking and length limits
  # ============================================================================
  known_fields <- c("hospital", "department", "analysis", "details", "author",
                    "date", "data_definition", "target", "footer_content")

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
          next  # Allow Date objects for date field
        }
        # Special case: target can be numeric
        if (field == "target" && is.numeric(value)) {
          next  # Allow numeric values for target field
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

    # Security: Prevent path traversal in template_path (check BEFORE file.exists)
    if (grepl("..", template_path, fixed = TRUE)) {
      stop(
        "template_path cannot contain '..' (path traversal attempt detected)",
        call. = FALSE
      )
    }

    # Security: Prevent shell metacharacters in template path
    if (any(vapply(shell_metachars, function(char) grepl(char, template_path, fixed = TRUE), logical(1)))) {
      stop(
        "template_path contains potentially unsafe characters",
        call. = FALSE
      )
    }
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

    # Resolve symlinks to prevent TOCTOU attacks and path confusion
    # normalizePath() resolves symlinks and returns absolute path
    template_path <- normalizePath(template_path, winslash = "/", mustWork = TRUE)

    # Re-check for path traversal AFTER symlink resolution
    # (Symlink could point to ../../../etc/passwd)
    if (grepl("..", template_path, fixed = TRUE)) {
      stop(
        "template_path resolves to a path containing '..' (path traversal attempt detected)",
        call. = FALSE
      )
    }

    # Reject directories (file.exists returns TRUE for directories)
    if (dir.exists(template_path)) {
      stop(
        "template_path must be a file, not a directory: ", basename(template_path),
        call. = FALSE
      )
    }
    # Validate .typ extension
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

  # Create temporary directory for intermediate files
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
      width = PDF_IMAGE_WIDTH_MM / 25.4,  # 250mm - original working size
      height = PDF_IMAGE_HEIGHT_MM / 25.4, # 140mm
      units = "in",
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
  metadata_full <- merge_metadata(metadata, chart_title)

  # Create Typst document
  typst_file <- file.path(temp_dir, "document.typ")
  bfh_create_typst_document(
    chart_image = chart_svg,
    output = typst_file,
    metadata = metadata_full,
    spc_stats = spc_stats,
    template = template,
    template_path = template_path
  )

  # Inject external assets (fonts, images) if callback provided
  if (is.function(inject_assets)) {
    inject_assets(file.path(temp_dir, "bfh-template"))

    # Auto-detect font path fra injicerede assets hvis ikke eksplicit angivet
    if (is.null(font_path)) {
      injected_fonts <- file.path(temp_dir, "bfh-template", "fonts")
      if (dir.exists(injected_fonts)) {
        font_path <- injected_fonts
      }
    }
  }

  # Compile to PDF via Quarto (with optional font path)
  bfh_compile_typst(typst_file, output, font_path = font_path)

  # Return input object invisibly for pipe chaining
  invisible(x)
}

# ============================================================================
# SPC STATISTICS AND METADATA
# ============================================================================

#' Extract SPC Statistics
#'
#' S3 generic that extracts statistical process control metrics. The extraction
#' logic depends on the input type:
#'
#' * `data.frame` (typically `bfh_qic_result$summary`): Returns runs and
#'   crossings from the summary. `outliers_actual` and `outliers_recent_count`
#'   remain `NULL` because outlier counts require access to `qic_data`.
#' * `bfh_qic_result`: Returns runs, crossings, and outlier counts. Outliers are
#'   split into two fields so that the PDF table and the analysis text can be
#'   driven from consistent — but distinct — numbers.
#' * `NULL`: Returns an empty stats list (backward compatible).
#'
#' Downstream packages should prefer the `bfh_qic_result` method so the PDF
#' export and any on-screen preview agree on the outlier count.
#'
#' @param x Either a data frame (typically `bfh_qic_result$summary`), a
#'   `bfh_qic_result` object from [bfh_qic()], or `NULL`.
#'
#' @return Named list with SPC statistics:
#' \describe{
#'   \item{runs_expected}{Expected maximum run length (`længste_løb_max`)}
#'   \item{runs_actual}{Actual longest run length (`længste_løb`)}
#'   \item{crossings_expected}{Expected minimum crossings (`antal_kryds_min`)}
#'   \item{crossings_actual}{Actual number of crossings (`antal_kryds`)}
#'   \item{outliers_expected}{Expected number of outliers (0 for non-run charts,
#'     `NULL` otherwise)}
#'   \item{outliers_actual}{Total number of points outside control limits in the
#'     latest part (used by the PDF table). `NULL` for `data.frame` input, run
#'     charts, or when `sigma.signal` is unavailable.}
#'   \item{outliers_recent_count}{Number of outliers within the last 6
#'     observations of the latest part (used by the analysis text, so stale
#'     outliers are not discussed as if they were current). Present only for
#'     `bfh_qic_result` input on non-run charts.}
#'   \item{is_run_chart}{Logical indicating run chart. Present only for
#'     `bfh_qic_result` input.}
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#'
#' # Full stats (recommended — populates outliers_actual for the table)
#' stats <- bfh_extract_spc_stats(result)
#'
#' # Backward-compatible summary-only dispatch
#' stats_summary_only <- bfh_extract_spc_stats(result$summary)
#' }
#'
#' @family utility-functions
#' @seealso [bfh_qic()] for creating SPC charts
bfh_extract_spc_stats <- function(x) {
  UseMethod("bfh_extract_spc_stats")
}

#' @export
#' @rdname bfh_extract_spc_stats
bfh_extract_spc_stats.default <- function(x) {
  if (is.null(x)) return(empty_spc_stats())
  stop(
    "bfh_extract_spc_stats(): x must be a data.frame (summary) or a ",
    "bfh_qic_result object, not a ", paste(class(x), collapse = "/"),
    call. = FALSE
  )
}

#' @export
#' @rdname bfh_extract_spc_stats
bfh_extract_spc_stats.data.frame <- function(x) {
  stats <- empty_spc_stats()

  if (nrow(x) == 0) return(stats)

  # Brug seneste part (sidste række) for aktuel proces-statistik
  row <- x[nrow(x), ]

  # Runs (serielængde)
  if ("længste_løb_max" %in% names(row)) {
    stats$runs_expected <- clean_spc_value(row$længste_løb_max)
  }
  if ("længste_løb" %in% names(row)) {
    stats$runs_actual <- clean_spc_value(row$længste_løb)
  }

  # Crossings (antal kryds)
  if ("antal_kryds_min" %in% names(row)) {
    stats$crossings_expected <- clean_spc_value(row$antal_kryds_min)
  }
  if ("antal_kryds" %in% names(row)) {
    stats$crossings_actual <- clean_spc_value(row$antal_kryds)
  }

  # Outliers kan ikke udledes af summary alene (kræver sigma.signal fra qic_data).
  # Brug bfh_extract_spc_stats(bfh_qic_result) hvis outliers skal udfyldes.

  stats
}

#' @export
#' @rdname bfh_extract_spc_stats
bfh_extract_spc_stats.bfh_qic_result <- function(x) {
  # Start med runs/crossings fra summary
  stats <- bfh_extract_spc_stats(x$summary)

  is_run_chart <- identical(x$config$chart_type, "run")
  stats$is_run_chart <- is_run_chart

  # Run charts har ingen kontrolgrænser → outlier-felter forbliver NULL
  if (is_run_chart) return(stats)

  if (is.null(x$qic_data) || !"sigma.signal" %in% names(x$qic_data)) {
    # Uden sigma.signal kan vi ikke tælle outliers; lad felterne forblive NULL
    # så Typst-templaten skjuler rækken i stedet for at vise "-".
    return(stats)
  }

  qd <- x$qic_data
  if ("part" %in% names(qd)) {
    latest_part <- max(qd$part, na.rm = TRUE)
    qd <- qd[qd$part == latest_part, ]
  }

  stats$outliers_expected <- 0

  # TABEL: total antal outliers i seneste part.
  stats$outliers_actual <- sum(qd$sigma.signal, na.rm = TRUE)

  # ANALYSETEKST: kun outliers i de seneste 6 obs af seneste part
  # (ældre outliers vises stadig visuelt i diagrammet, men bør ikke
  # beskrives som aktuelle i analysen).
  n_obs <- nrow(qd)
  recent_start <- max(1, n_obs - 5)
  stats$outliers_recent_count <- sum(
    qd$sigma.signal[recent_start:n_obs], na.rm = TRUE
  )

  stats
}

#' @keywords internal
#' @rdname bfh_extract_spc_stats
extract_spc_stats <- function(x) {
  bfh_extract_spc_stats(x)
}

# Internal helpers ============================================================

# Returner tom SPC-stats-liste (alle felter NULL).
# Bruges af data.frame-methoden og default-methoden (for NULL-input).
empty_spc_stats <- function() {
  list(
    runs_expected = NULL,
    runs_actual = NULL,
    crossings_expected = NULL,
    crossings_actual = NULL,
    outliers_expected = NULL,
    outliers_actual = NULL
  )
}

# Konverter NA, NaN og Inf til NA_real_; returnér NULL for tomme værdier.
clean_spc_value <- function(x) {
  if (is.null(x) || length(x) == 0) return(NULL)
  if (is.na(x) || is.nan(x) || is.infinite(x)) return(NA_real_)
  x
}

#' Merge User Metadata with Defaults
#'
#' Merges user-provided metadata with package defaults for PDF generation.
#' This function is useful for downstream packages that need consistent
#' metadata handling without depending on BFHcharts internal functions.
#'
#' @param metadata Named list with user-provided metadata fields.
#'   Valid fields: hospital, department, title, analysis, details, author,
#'   date, data_definition. Other fields are ignored.
#' @param chart_title Character string with chart title. Used as default
#'   for metadata$title if not provided by user.
#'
#' @return Named list with merged metadata containing:
#' \describe{
#'   \item{hospital}{Hospital name (default: "Bispebjerg og Frederiksberg Hospital")}
#'   \item{department}{Department name (default: NULL)}
#'   \item{title}{Chart title (from chart_title or metadata)}
#'   \item{analysis}{Analysis description (default: NULL)}
#'   \item{details}{Additional details (default: NULL)}
#'   \item{author}{Author name (default: NULL)}
#'   \item{date}{Report date (default: Sys.Date())}
#'   \item{data_definition}{Data definition (default: NULL)}
#' }
#'
#' User-provided values override defaults. Fields not in the default list
#' are silently ignored.
#'
#' @export
#' @examples
#' \dontrun{
#' # Basic usage
#' metadata <- list(
#'   department = "Kvalitetsafdeling",
#'   analysis = "Signifikant fald observeret"
#' )
#' merged <- bfh_merge_metadata(metadata, chart_title = "Infektioner")
#'
#' # merged$hospital = "Bispebjerg og Frederiksberg Hospital" (default)
#' # merged$department = "Kvalitetsafdeling" (user override)
#' # merged$title = "Infektioner" (from chart_title)
#' }
#'
#' @family utility-functions
#' @seealso [bfh_export_pdf()] for PDF export functionality
bfh_merge_metadata <- function(metadata, chart_title) {
  # Parameter validation
  if (!is.null(metadata) && (!is.list(metadata) || is.data.frame(metadata))) {
    stop("metadata must be a list or NULL", call. = FALSE)
  }

  # Define default metadata values
  defaults <- list(
    hospital = "Bispebjerg og Frederiksberg Hospital",
    department = NULL,
    title = chart_title,
    analysis = NULL,
    details = NULL,
    author = NULL,
    date = Sys.Date(),
    data_definition = NULL,
    footer_content = NULL
  )

  # Handle NULL metadata
  if (is.null(metadata)) {
    return(defaults)
  }

  # Merge: user values override defaults
  merged <- defaults
  for (name in names(metadata)) {
    if (name %in% names(defaults)) {
      merged[[name]] <- metadata[[name]]
    }
  }

  return(merged)
}

#' @keywords internal
#' @rdname bfh_merge_metadata
merge_metadata <- function(metadata, chart_title) {
  bfh_merge_metadata(metadata, chart_title)
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
    verbose = FALSE
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


# ============================================================================
# AUTO-GENERATED DETAILS
# ============================================================================

#' Generate Details Text for PDF Export
#'
#' Automatically generates a details string based on chart data, including
#' period range, averages, latest values, and current level (centerline).
#'
#' @param x A \code{bfh_qic_result} object from \code{bfh_qic()}
#'
#' @return Character string with formatted details, e.g.:
#'   "Periode: feb. 2019 – mar. 2022 • Gns. måned: 58938/97266 •
#'    Seneste måned: 60756/88509 • Nuværende niveau: 64,5%"
#'
#' @details
#' **Format:**
#' - Period range with Danish date formatting
#' - Average values per interval (numerator/denominator for p/u-charts)
#' - Latest period values
#' - Current level (centerline value) with appropriate unit formatting
#'
#' **Chart Type Handling:**
#' - p-chart, u-chart: Shows numerator/denominator (e.g., "58938/97266")
#' - Other chart types: Shows only the value (e.g., "127")
#'
#' **Interval Detection:**
#' - Uses detect_date_interval() to determine the interval type
#' - Labels adapt: "måned", "uge", "dag", "kvartal", "år"
#'
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#' details <- bfh_generate_details(result)
#' # "Periode: jan. 2024 – dec. 2024 • Gns. måned: 50 • ..."
#' }
#'
#' @family utility-functions
#' @seealso [bfh_export_pdf()] for PDF export functionality
#' @export
bfh_generate_details <- function(x) {
  # Validate input

  if (!inherits(x, "bfh_qic_result")) {
    stop("x must be a bfh_qic_result object from bfh_qic()", call. = FALSE)
  }

  qic_data <- x$qic_data
  config <- x$config

  # 1. Detect interval type from x-axis data
  interval_info <- detect_date_interval(qic_data$x)
  interval_label <- get_danish_interval_label(interval_info$type)

  # 2. Format period range
  start_date <- format_danish_date_short(min(qic_data$x, na.rm = TRUE))
  end_date <- format_danish_date_short(max(qic_data$x, na.rm = TRUE))
  periode <- sprintf("Periode: %s \u2013 %s", start_date, end_date)  # en-dash

  # 3. Calculate averages (numerator/denominator or value only)
  chart_type <- config$chart_type

  # Check if denominator data is available
  has_denominator_data <- "y.sum" %in% names(qic_data) &&
                          "n" %in% names(qic_data) &&
                          !all(is.na(qic_data$n))

  # Use numerator/denominator format for:
  # - p/u-charts (always)
  # - run charts IF they have denominator data (i.e., created from proportion data)
  uses_denominator <- (chart_type %in% c("p", "u")) ||
                      (chart_type == "run" && has_denominator_data)

  if (uses_denominator) {
    # Charts with denominator: show numerator/denominator
    avg_num <- round(mean(qic_data$y.sum, na.rm = TRUE))
    avg_den <- round(mean(qic_data$n, na.rm = TRUE))
    gns <- sprintf("Gns. %s: %s/%s", interval_label,
                   format(avg_num, big.mark = ".", decimal.mark = ","),
                   format(avg_den, big.mark = ".", decimal.mark = ","))
  } else {
    # Other chart types: show only value
    avg_val <- round(mean(qic_data$y, na.rm = TRUE))
    gns <- sprintf("Gns. %s: %s", interval_label,
                   format(avg_val, big.mark = ".", decimal.mark = ","))
  }

  # 4. Get latest period values
  last_row <- utils::tail(qic_data, 1)

  if (uses_denominator) {
    last_num <- round(last_row$y.sum)
    last_den <- round(last_row$n)
    seneste <- sprintf("Seneste %s: %s/%s", interval_label,
                       format(last_num, big.mark = ".", decimal.mark = ","),
                       format(last_den, big.mark = ".", decimal.mark = ","))
  } else {
    last_val <- round(last_row$y)
    seneste <- sprintf("Seneste %s: %s", interval_label,
                       format(last_val, big.mark = ".", decimal.mark = ","))
  }

  # 5. Get current level (centerline value) with proper formatting
  cl_value <- last_row$cl
  y_axis_unit <- config$y_axis_unit %||% "count"

  niveau <- format_centerline_for_details(cl_value, y_axis_unit)

  # 6. Combine with bullet separator
  paste(periode, gns, seneste, niveau, sep = " \u2022 ")  # bullet character
}

#' Format Centerline Value for Details
#'
#' Formats the centerline value based on y_axis_unit with appropriate
#' decimal places and unit suffix.
#'
#' @param cl_value Numeric centerline value
#' @param y_axis_unit Character string: "percent", "count", "rate", etc.
#'
#' @return Formatted string, e.g., "Nuværende niveau: 64,5%"
#'
#' @keywords internal
#' @noRd
format_centerline_for_details <- function(cl_value, y_axis_unit) {
  if (is.null(cl_value) || is.na(cl_value)) {
    return("Nuværende niveau: -")
  }

  formatted <- switch(y_axis_unit,
    "percent" = {
      # Percentage: multiply by 100 if needed, show 1 decimal
      if (cl_value <= 1) {
        sprintf("%.1f%%", cl_value * 100)
      } else {
        sprintf("%.1f%%", cl_value)
      }
    },
    "rate" = {
      # Rate: typically per 1000 or similar, show 1 decimal
      sprintf("%.1f", cl_value)
    },
    "time" = {
      # Time: show as-is with 1 decimal
      sprintf("%.1f", cl_value)
    },
    # Default (count and others): show as integer or 1 decimal
    {
      if (cl_value == round(cl_value)) {
        format(round(cl_value), big.mark = ".", decimal.mark = ",")
      } else {
        format(round(cl_value, 1), big.mark = ".", decimal.mark = ",", nsmall = 1)
      }
    }
  )

  # Replace . with , for Danish decimal notation (if not already done)
  formatted <- gsub("\\.", ",", formatted)

  sprintf("Nuværende niveau: %s", formatted)
}

