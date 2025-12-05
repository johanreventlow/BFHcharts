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
                           use_ai = NULL) {
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
  if (any(sapply(shell_metachars, function(char) grepl(char, output, fixed = TRUE)))) {
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
  # AUTO-ANALYSIS - Generate analysis text if requested
  # ============================================================================
  if (isTRUE(auto_analysis) && is.null(metadata$analysis)) {
    metadata$analysis <- bfh_generate_analysis(
      x = x,
      metadata = metadata,
      use_ai = use_ai
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
    if (any(sapply(shell_metachars, function(char) grepl(char, template_path, fixed = TRUE)))) {
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
    current_uid <- as.integer(Sys.getenv("UID"))
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
    target_height_mm = PDF_CHART_HEIGHT_MM
  )

  # Apply PDF-specific theme adjustments (zero margins)
  plot_for_export <- prepare_plot_for_export(plot_for_export, margin_mm = 0)

  # Export chart to temporary PNG
  # Note: ggsave uses PDF_IMAGE dimensions (250x140mm) for the actual image size
  # while labels were calculated for PDF_CHART dimensions (202x140mm) which
  # represents the visible area in the Typst template
  chart_png <- file.path(temp_dir, "chart.png")
  tryCatch(
    ggplot2::ggsave(
      filename = chart_png,
      plot = plot_for_export,
      width = PDF_IMAGE_WIDTH_MM / 25.4,  # 250mm - original working size
      height = PDF_IMAGE_HEIGHT_MM / 25.4, # 140mm
      dpi = 150,  # Reduced from 300 for 4x faster generation & 75% smaller files
      units = "in",
      device = "png"
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
  spc_stats <- extract_spc_stats_extended(x)

  # Merge user metadata with defaults
  metadata_full <- merge_metadata(metadata, chart_title)

  # Create Typst document
  typst_file <- file.path(temp_dir, "document.typ")
  bfh_create_typst_document(
    chart_image = chart_png,
    output = typst_file,
    metadata = metadata_full,
    spc_stats = spc_stats,
    template = template,
    template_path = template_path
  )

  # Compile to PDF via Quarto
  bfh_compile_typst(typst_file, output)

  # Return input object invisibly for pipe chaining
  invisible(x)
}

# Session-level cache for Quarto availability checks
.quarto_cache <- new.env(parent = emptyenv())

#' Check if Quarto CLI is Available
#'
#' Checks if Quarto CLI is installed and accessible on the system,
#' and verifies that the version is >= 1.4.0 (required for Typst support).
#' Results are cached for the session to avoid repeated system calls.
#'
#' @param min_version Minimum required version as character (default: "1.4.0")
#' @param use_cache Logical; if TRUE (default), use cached result if available
#' @return Logical indicating whether Quarto is available and meets version requirement
#'
#' @keywords internal
quarto_available <- function(min_version = "1.4.0", use_cache = TRUE) {
  # Check cache first
  cache_key <- paste0("quarto_", min_version)
  if (use_cache && exists(cache_key, envir = .quarto_cache)) {
    return(get(cache_key, envir = .quarto_cache))
  }

  # Try to run quarto --version
  version_output <- tryCatch(
    {
      system2("quarto", args = "--version", stdout = TRUE, stderr = TRUE)
    },
    error = function(e) NULL,
    warning = function(w) NULL
  )

  # Check if quarto command succeeded
  if (is.null(version_output) || length(version_output) == 0) {
    result <- FALSE
  } else {
    # Parse version string (e.g., "1.4.557" or "1.5.0")
    result <- check_quarto_version(version_output[1], min_version)
  }

  # Cache the result
  assign(cache_key, result, envir = .quarto_cache)

  return(result)
}

#' Check Quarto Version Against Minimum
#'
#' @param version_string Version string from quarto --version (e.g., "1.4.557")
#' @param min_version Minimum required version (e.g., "1.4.0")
#' @return Logical indicating whether version meets requirement
#' @keywords internal
check_quarto_version <- function(version_string, min_version) {
  # Extract version numbers using regex
  # Matches patterns like "1.4.557", "1.4", "2.0.0" anywhere in the string
  # (handles "Quarto 1.4.557" format as well as plain "1.4.557")
  version_match <- regmatches(version_string,
    regexpr("[0-9]+\\.[0-9]+\\.?[0-9]*", version_string))

  if (length(version_match) == 0 || nchar(version_match) == 0) {
    # If we can't parse version, warn and return FALSE (fail safe)
    warning(
      "Could not parse Quarto version from: ", version_string, "\n",
      "  Unable to verify version requirement.",
      call. = FALSE
    )
    return(FALSE)
  }

  # Compare versions using package_version
  installed <- tryCatch(
    package_version(version_match),
    error = function(e) NULL
  )

  minimum <- tryCatch(
    package_version(min_version),
    error = function(e) NULL
  )

  if (is.null(installed) || is.null(minimum)) {
    # Fail-safe: if we can't parse version, return FALSE
    return(FALSE)
  }

  return(installed >= minimum)
}

#' Create Typst Document for SPC Chart
#'
#' Generates a Typst document (.typ) using BFH hospital template with
#' chart image and metadata.
#'
#' @param chart_image Path to chart PNG image
#' @param output Path for output .typ file
#' @param metadata List with template parameters (hospital, department, title, etc.)
#' @param spc_stats List with SPC statistics (runs, crossings, outliers)
#' @param template Template name (default: "bfh-diagram")
#' @param template_path Optional custom template path. When provided, overrides
#'   the packaged template (default: NULL uses packaged template)
#'
#' @return Path to created .typ file (invisibly)
#'
#' @export
bfh_create_typst_document <- function(chart_image,
                                      output,
                                      metadata,
                                      spc_stats,
                                      template = "bfh-diagram",
                                      template_path = NULL) {
  # Get output directory (where document.typ will be created)
  output_dir <- dirname(output)

  # Determine template source and copy to output directory
  if (!is.null(template_path)) {
    # Custom template: copy single file to output directory
    if (!file.exists(template_path)) {
      stop(
        "Custom template file not found: ", template_path, "\n",
        "  Ensure the file exists and the path is correct.",
        call. = FALSE
      )
    }
    template_basename <- basename(template_path)
    local_template <- file.path(output_dir, template_basename)
    copy_success <- file.copy(template_path, local_template, overwrite = TRUE)
    if (!copy_success) {
      stop(
        "Failed to copy custom template to output directory.",
        call. = FALSE
      )
    }

    # Security: Verify file copy integrity (size check)
    src_size <- file.info(template_path)$size
    dest_size <- file.info(local_template)$size
    if (is.na(dest_size) || dest_size != src_size) {
      unlink(local_template)
      stop(
        "Template file copy integrity check failed (size mismatch)",
        call. = FALSE
      )
    }
  } else {
    # Packaged template: copy entire template directory (includes fonts, images)
    template_dir <- system.file("templates/typst/bfh-template", package = "BFHcharts")

    if (!dir.exists(template_dir)) {
      stop(
        "Typst template not found at: ", template_dir, "\n",
        "  This should not happen. Please reinstall BFHcharts.",
        call. = FALSE
      )
    }

    # Copy template directory to output directory
    local_template_dir <- file.path(output_dir, "bfh-template")
    if (dir.exists(local_template_dir)) {
      unlink(local_template_dir, recursive = TRUE)
    }

    # Use recursive copy for 5-10x performance improvement
    success <- file.copy(template_dir, output_dir, recursive = TRUE, overwrite = TRUE)
    if (!success) {
      stop(
        "Failed to copy template directory\n",
        "  Source: ", basename(template_dir), "\n",
        "  Destination: ", basename(output_dir),
        call. = FALSE
      )
    }

    local_template <- file.path(local_template_dir, "bfh-template.typ")
    template_basename <- "bfh-template/bfh-template.typ"
  }


  # Copy chart image to output directory (fixes path handling for arbitrary locations)
  if (!file.exists(chart_image)) {
    stop(
      "Chart image not found: ", chart_image, "\n",
      "  Ensure the image file exists.",
      call. = FALSE
    )
  }
  chart_basename <- basename(chart_image)
  local_chart <- file.path(output_dir, chart_basename)

  # Normalize paths to compare (handles relative vs absolute, symlinks, etc.)
  chart_image_norm <- normalizePath(chart_image, mustWork = TRUE)
  local_chart_norm <- normalizePath(local_chart, mustWork = FALSE)

  # Only copy if source and destination are different files
  if (chart_image_norm != local_chart_norm) {
    copy_success <- file.copy(chart_image, local_chart, overwrite = TRUE)
    if (!copy_success) {
      stop(
        "Failed to copy chart image to output directory.",
        call. = FALSE
      )
    }

    # Security: Verify file copy integrity (size check)
    src_size <- file.info(chart_image)$size
    dest_size <- file.info(local_chart)$size
    if (is.na(dest_size) || dest_size != src_size) {
      unlink(local_chart)
      stop(
        "Chart image copy integrity check failed (size mismatch)",
        call. = FALSE
      )
    }
  }
  # If files are the same, local_chart is already correct - no copy needed

  # Build Typst document content with relative paths
  typst_content <- build_typst_content(
    chart_image = chart_basename,  # Use basename since image is now in output_dir
    metadata = metadata,
    spc_stats = spc_stats,
    template = template,
    template_file = template_basename  # Use relative path
  )

  # Write Typst file
  tryCatch(
    writeLines(typst_content, output),
    error = function(e) {
      stop(
        "Failed to write Typst document\n",
        "  Output: ", basename(output), "\n",
        "  Error: ", conditionMessage(e),
        call. = FALSE
      )
    }
  )

  invisible(output)
}

#' Compile Typst Document to PDF
#'
#' Compiles a .typ file to PDF using Quarto's bundled Typst compiler.
#'
#' @param typst_file Path to .typ file
#' @param output Path for output PDF file
#'
#' @return Path to created PDF file (invisibly)
#'
#' @keywords internal
bfh_compile_typst <- function(typst_file, output) {
  if (!file.exists(typst_file)) {
    stop("Typst file not found: ", typst_file, call. = FALSE)
  }

  # Security: Validate paths before passing to system2()
  shell_metachars <- c(";", "|", "&", "$", "`", "(", ")", "{", "}", "<", ">", "\n", "\r")

  if (any(sapply(shell_metachars, function(char) grepl(char, typst_file, fixed = TRUE)))) {
    stop(
      "typst_file path contains potentially unsafe characters\n",
      "  Path: ", basename(typst_file),
      call. = FALSE
    )
  }

  if (any(sapply(shell_metachars, function(char) grepl(char, output, fixed = TRUE)))) {
    stop(
      "output path contains potentially unsafe characters\n",
      "  Path: ", basename(output),
      call. = FALSE
    )
  }

  # Create output directory if needed
  output_dir <- dirname(output)
  if (!dir.exists(output_dir) && output_dir != ".") {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Use quarto typst compile (not quarto render which expects .qmd files)
  result <- tryCatch(
    system2(
      "quarto",
      args = c("typst", "compile", typst_file, output),
      stdout = TRUE,
      stderr = TRUE
    ),
    error = function(e) {
      stop(
        "Failed to execute Quarto command\n",
        "  Error: ", conditionMessage(e),
        call. = FALSE
      )
    }
  )

  # Check exit status
  exit_status <- attr(result, "status")
  if (!is.null(exit_status) && exit_status != 0) {
    stop(
      "Quarto compilation failed with exit code ", exit_status, "\n",
      "  Output: ", paste(result, collapse = "\n"),
      call. = FALSE
    )
  }

  # Check if PDF was created (quarto typst compile outputs directly to target)
  if (!file.exists(output)) {
    stop(
      "PDF compilation failed.\n",
      "  Quarto output: ", paste(result, collapse = "\n"),
      call. = FALSE
    )
  }

  invisible(output)
}

# ============================================================================
# INTERNAL HELPER FUNCTIONS
# ============================================================================

#' Extract SPC Statistics from QIC Summary
#'
#' Extracts statistical process control metrics from a qic summary data frame.
#' This function is useful for downstream packages that need to access SPC
#' statistics without depending on BFHcharts internal functions.
#'
#' @param summary Data frame with SPC statistics (from `bfh_qic_result$summary`),
#'   or NULL
#'
#' @return Named list with SPC statistics:
#' \describe{
#'   \item{runs_expected}{Expected maximum run length (længste_løb_max)}
#'   \item{runs_actual}{Actual longest run length (længste_løb)}
#'   \item{crossings_expected}{Expected minimum crossings (antal_kryds_min)}
#'   \item{crossings_actual}{Actual number of crossings (antal_kryds)}
#'   \item{outliers_expected}{Expected outliers (future)}
#'   \item{outliers_actual}{Actual outliers (future)}
#' }
#'
#' If summary is NULL or empty, all values will be NULL.
#' If specific columns are missing, corresponding values will be NULL.
#'
#' @export
#' @examples
#' \dontrun{
#' # Extract stats from a qic result
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#' stats <- bfh_extract_spc_stats(result$summary)
#'
#' # Stats contain runs and crossings
#' stats$runs_actual
#' stats$crossings_actual
#' }
#'
#' @family utility-functions
#' @seealso [bfh_qic()] for creating SPC charts
bfh_extract_spc_stats <- function(summary) {
  # Parameter validation
  if (!is.null(summary) && !is.data.frame(summary)) {
    stop("summary must be a data frame or NULL", call. = FALSE)
  }

  # Initialize with NULLs (will be conditionally included in Typst)
  stats <- list(
    runs_expected = NULL,
    runs_actual = NULL,
    crossings_expected = NULL,
    crossings_actual = NULL,
    outliers_expected = NULL,
    outliers_actual = NULL
  )

  if (is.null(summary) || nrow(summary) == 0) {
    return(stats)
  }

  # Extract from first row (or aggregate if multiple phases)
  row <- summary[1, ]

  # Runs (serielængde)
  if ("længste_løb_max" %in% names(row)) {
    stats$runs_expected <- row$længste_løb_max
  }
  if ("længste_løb" %in% names(row)) {
    stats$runs_actual <- row$længste_løb
  }

  # Crossings (antal kryds)
  if ("antal_kryds_min" %in% names(row)) {
    stats$crossings_expected <- row$antal_kryds_min
  }
  if ("antal_kryds" %in% names(row)) {
    stats$crossings_actual <- row$antal_kryds
  }

  # Outliers (would need to be added to summary in future)
  # For now, leave as NULL

  return(stats)
}

#' @keywords internal
#' @rdname bfh_extract_spc_stats
extract_spc_stats <- function(summary) {
  bfh_extract_spc_stats(summary)
}

#' Extract Extended SPC Statistics from QIC Result
#'
#' Internal function that extracts SPC statistics including outliers and
#' run chart detection from a complete bfh_qic_result object.
#'
#' @param x A bfh_qic_result object from bfh_qic()
#'
#' @return Named list with extended SPC statistics:
#' \describe{
#'   \item{runs_expected}{Expected maximum run length}
#'   \item{runs_actual}{Actual longest run length}
#'   \item{crossings_expected}{Expected minimum crossings}
#'   \item{crossings_actual}{Actual number of crossings}
#'   \item{outliers_expected}{Expected outliers (0 for non-run charts, NULL for run charts)}
#'   \item{outliers_actual}{Actual outliers count (NULL for run charts)}
#'   \item{is_run_chart}{Logical indicating if this is a run chart}
#' }
#'
#' @keywords internal
#' @noRd
extract_spc_stats_extended <- function(x) {

  # Start with basic stats from summary
  stats <- bfh_extract_spc_stats(x$summary)


  # Determine if this is a run chart
  chart_type <- x$config$chart_type
  is_run_chart <- !is.null(chart_type) && chart_type == "run"
  stats$is_run_chart <- is_run_chart


  # Calculate outliers from qic_data (only for non-run charts)
  if (!is_run_chart && !is.null(x$qic_data) && "sigma.signal" %in% names(x$qic_data)) {
    stats$outliers_expected <- 0
    stats$outliers_actual <- sum(x$qic_data$sigma.signal, na.rm = TRUE)
  }
  # For run charts, outliers remain NULL (row will be hidden in Typst)


  return(stats)
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
    data_definition = NULL
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

#' Build Typst Document Content
#'
#' @param chart_image Filename of chart PNG (relative to document location, already copied)
#' @param metadata Metadata list
#' @param spc_stats SPC statistics list
#' @param template Template name
#' @param template_file Relative path to template .typ file (relative to document location)
#' @return Character vector with Typst content
#' @keywords internal
build_typst_content <- function(chart_image, metadata, spc_stats, template, template_file) {
  # Build import statement with relative path
  # Template file is now relative (e.g., "bfh-template/bfh-template.typ")
  # Apply escaping for special characters (quotes, spaces in filenames)
  escaped_template <- escape_typst_string(template_file)
  import_line <- sprintf('#import "%s": %s', escaped_template, template)

  # Build template call with parameters
  params <- list()

  # Chart image is already a relative filename (copied to output dir by caller)
  # Chart is passed as body content after #show, not as named parameter
  # Escape filename in case it has special characters
  escaped_chart <- escape_typst_string(chart_image)

  # Optional metadata parameters
  # Note: title and analysis support rich text formatting via markdown_to_typst()
  # and use Typst content blocks [...] instead of strings "..."
  if (!is.null(metadata$hospital)) {
    params$hospital <- sprintf('"%s"', escape_typst_string(metadata$hospital))
  }
  if (!is.null(metadata$department)) {
    params$department <- sprintf('"%s"', escape_typst_string(metadata$department))
  }
  if (!is.null(metadata$title) && nchar(metadata$title) > 0) {
    # Title supports rich text - use content block [...]
    params$title <- sprintf('[%s]', markdown_to_typst(metadata$title))
  }
  if (!is.null(metadata$analysis)) {
    # Analysis supports rich text - use content block [...]
    params$analysis <- sprintf('[%s]', markdown_to_typst(metadata$analysis))
  }
  if (!is.null(metadata$details)) {
    params$details <- sprintf('"%s"', escape_typst_string(metadata$details))
  }
  if (!is.null(metadata$author)) {
    params$author <- sprintf('"%s"', escape_typst_string(metadata$author))
  }
  if (!is.null(metadata$data_definition)) {
    params$data_definition <- sprintf('"%s"', escape_typst_string(metadata$data_definition))
  }
  if (!is.null(metadata$footer_content)) {
    # Footer content supports rich text - use content block [...]
    params$footer_content <- sprintf('[%s]', markdown_to_typst(metadata$footer_content))
  }

  # Date parameter - format for Typst template
  if (!is.null(metadata$date)) {
    # Format date as ISO string for Typst
    date_str <- format(as.Date(metadata$date), "%Y-%m-%d")
    params$date <- sprintf('"%s"', date_str)
  }

  # SPC statistics (only include if not NULL)
  if (!is.null(spc_stats$runs_expected)) {
    params$runs_expected <- as.character(spc_stats$runs_expected)
  }
  if (!is.null(spc_stats$runs_actual)) {
    params$runs_actual <- as.character(spc_stats$runs_actual)
  }
  if (!is.null(spc_stats$crossings_expected)) {
    params$crossings_expected <- as.character(spc_stats$crossings_expected)
  }
  if (!is.null(spc_stats$crossings_actual)) {
    params$crossings_actual <- as.character(spc_stats$crossings_actual)
  }
  if (!is.null(spc_stats$outliers_expected)) {
    params$outliers_expected <- as.character(spc_stats$outliers_expected)
  }
  if (!is.null(spc_stats$outliers_actual)) {
    params$outliers_actual <- as.character(spc_stats$outliers_actual)
  }

  # Run chart flag (for hiding outlier row in Typst)
  if (!is.null(spc_stats$is_run_chart)) {
    params$is_run_chart <- if (spc_stats$is_run_chart) "true" else "false"
  }

  # Build parameter string
  param_strings <- c()
  for (name in names(params)) {
    param_strings <- c(param_strings, sprintf("  %s: %s", name, params[[name]]))
  }
  param_block <- paste(param_strings, collapse = ",\n")

  # Assemble document
  # In Typst, the chart (positional param) comes as body content after #show block
  content <- c(
    import_line,
    "",
    sprintf("#show: %s.with(", template),
    param_block,
    ")",
    "",
    "// Chart content (body parameter)",
    sprintf('#image("%s")', escaped_chart),
    ""
  )

  return(content)
}

#' Escape String for Typst
#'
#' @param s Character string to escape
#' @return Escaped string safe for Typst
#' @keywords internal
escape_typst_string <- function(s) {

  if (is.null(s) || length(s) == 0) return("")

  # Escape backslashes and quotes
  s <- gsub("\\\\", "\\\\\\\\", s)
  s <- gsub('"', '\\\\"', s)

  return(s)
}

#' Convert Markdown Rich Text to Typst Content
#'
#' Converts CommonMark/Marquee-style markdown formatting to Typst content blocks.
#' Supports bold (**text**), italic (*text*), and preserves newlines.
#'
#' @param text Character string with markdown formatting
#' @return Character string with Typst content block syntax
#' @keywords internal
#'
#' @details
#' **Supported Markdown Syntax:**
#' - `**bold text**` → `#strong[bold text]`
#' - `*italic text*` → `#emph[italic text]`
#' - Newlines (`\n`) → Typst line breaks (`\`)
#'
#' **Usage:**
#' Text parameters that should support rich text (title, analysis) use this
#' function and are passed as Typst content blocks `[...]` instead of strings.
#'
#' @examples
#' \dontrun{
#' # Bold text
#' markdown_to_typst("This is **important**")
#' # Returns: "This is #strong[important]"
#'
#' # Italic text
#' markdown_to_typst("This is *emphasized*")
#' # Returns: "This is #emph[emphasized]"
#'
#' # Mixed formatting
#' markdown_to_typst("Write a title or\n**conclude what the chart shows**")
#' # Returns: "Write a title or\\ #strong[conclude what the chart shows]"
#' }
markdown_to_typst <- function(text) {
  if (is.null(text) || length(text) == 0 || nchar(text) == 0) return("")

  result <- text


  # Escape Typst special characters in content (but not our formatting markers)
  # Escape hash (#) that's not part of our conversion
  # Don't escape [ ] as we need them for content blocks
  result <- gsub("(?<!\\*)#", "\\\\#", result, perl = TRUE)

  # Convert **bold** to #strong[bold] (must do before single *)
  result <- gsub("\\*\\*([^*]+)\\*\\*", "#strong[\\1]", result)

  # Convert *italic* to #emph[italic] (single asterisks)
  # Use negative lookbehind/lookahead to avoid matching ** patterns
  result <- gsub("(?<!\\*)\\*([^*]+)\\*(?!\\*)", "#emph[\\1]", result, perl = TRUE)

  # Convert \n to Typst line break (backslash + newline)
  result <- gsub("\\n", "\\\\\n", result)

  return(result)
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
#'
#' @return ggplot object with recalculated label positions
#'
#' @details
#' Label positioning uses target dimensions (the visible chart area in the template).
#' Font sizing uses the fixed PDF_LABEL_SIZE constant (6pt), which is calibrated
#' for the PDF template dimensions (250x140mm). This ensures consistent label
#' appearance regardless of how the chart was created (interactive RStudio,
#' batch script, etc.).
#'
#' @keywords internal
#' @noRd
recalculate_labels_for_export <- function(x, target_width_mm, target_height_mm) {
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

  # Use fixed PDF_LABEL_SIZE for consistent sizing regardless of how the
  # chart was created (interactive RStudio window, batch script, etc.)
  # This value is calibrated for the PDF template dimensions (250x140mm)
  new_label_size <- PDF_LABEL_SIZE

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
#' @keywords internal
#' @noRd
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

