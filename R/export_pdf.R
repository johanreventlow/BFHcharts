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
#'     \item \code{details}: Period info, averages (optional)
#'     \item \code{author}: Author name (optional)
#'     \item \code{date}: Report date (default: Sys.Date())
#'     \item \code{data_definition}: Data definition text (optional)
#'   }
#' @param template Character string specifying template name (default: "bfh-diagram2")
#' @param template_path Optional path to a custom Typst template file. When provided,
#'   this overrides the packaged template. The template must exist and be a valid
#'   Typst file (.typ). Default is NULL (uses packaged BFH template).
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
#' **SPC Statistics:**
#' - Automatically extracted from bfh_qic_result$summary
#' - Displayed in SPC table on PDF
#' - Includes: runs (serielængde), crossings (antal kryds), outliers
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
                           template = "bfh-diagram2",
                           template_path = NULL) {
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

  if (!is.list(metadata)) {
    stop("metadata must be a list", call. = FALSE
    )
  }

  # Validate custom template path if provided
  if (!is.null(template_path)) {
    if (!is.character(template_path) || length(template_path) != 1) {
      stop("template_path must be a single character string", call. = FALSE)
    }
    if (!file.exists(template_path)) {
      stop(
        "Custom template file not found: ", template_path, "\n",
        "  Ensure the file exists and the path is correct.",
        call. = FALSE
      )
    }
  }

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
  dir.create(temp_dir, recursive = TRUE)

  # Ensure cleanup on exit
  on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)

  # Extract chart title from plot (will be used in Typst template)
  chart_title <- x$config$chart_title
  if (is.null(chart_title)) chart_title <- ""

  # Create plot without title for PDF (title goes in Typst template)
  plot_no_title <- x$plot + ggplot2::labs(title = NULL, subtitle = NULL)

  # Export chart to temporary PNG
  chart_png <- file.path(temp_dir, "chart.png")
  ggplot2::ggsave(
    filename = chart_png,
    plot = plot_no_title,
    width = 250 / 25.4,  # 250mm in inches
    height = 140 / 25.4, # 140mm in inches
    dpi = 300,
    units = "in",
    device = "png"
  )

  # Extract SPC statistics from summary
  spc_stats <- extract_spc_stats(x$summary)

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

#' Check if Quarto CLI is Available
#'
#' Checks if Quarto CLI is installed and accessible on the system,
#' and verifies that the version is >= 1.4.0 (required for Typst support).
#'
#' @param min_version Minimum required version as character (default: "1.4.0")
#' @return Logical indicating whether Quarto is available and meets version requirement
#'
#' @keywords internal
#' @export
quarto_available <- function(min_version = "1.4.0") {
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
    return(FALSE)
  }

  # Parse version string (e.g., "1.4.557" or "1.5.0")
  version_check <- check_quarto_version(version_output[1], min_version)

  return(version_check)
}

#' Check Quarto Version Against Minimum
#'
#' @param version_string Version string from quarto --version (e.g., "1.4.557")
#' @param min_version Minimum required version (e.g., "1.4.0")
#' @return Logical indicating whether version meets requirement
#' @keywords internal
check_quarto_version <- function(version_string, min_version) {
  # Extract version numbers using regex
  # Matches patterns like "1.4.557", "1.4", "2.0.0"
  version_match <- regmatches(version_string,
    regexpr("^[0-9]+\\.[0-9]+\\.?[0-9]*", version_string))

  if (length(version_match) == 0 || nchar(version_match) == 0) {
    # If we can't parse version, assume it's OK (graceful fallback)
    warning(
      "Could not parse Quarto version from: ", version_string, "\n",
      "  Assuming version requirement is met.",
      call. = FALSE
    )
    return(TRUE)
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
    # Graceful fallback if parsing fails
    return(TRUE)
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
#' @param template Template name (default: "bfh-diagram2")
#' @param template_path Optional custom template path. When provided, overrides
#'   the packaged template (default: NULL uses packaged template)
#'
#' @return Path to created .typ file (invisibly)
#'
#' @keywords internal
#' @export
bfh_create_typst_document <- function(chart_image,
                                      output,
                                      metadata,
                                      spc_stats,
                                      template = "bfh-diagram2",
                                      template_path = NULL) {
  # Determine template file to use
  if (!is.null(template_path)) {
    # Use custom template provided by user
    template_file <- template_path
    if (!file.exists(template_file)) {
      stop(
        "Custom template file not found: ", template_file, "\n",
        "  Ensure the file exists and the path is correct.",
        call. = FALSE
      )
    }
  } else {
    # Use packaged template
    template_dir <- system.file("templates/typst/bfh-template", package = "BFHcharts")

    if (!dir.exists(template_dir)) {
      stop(
        "Typst template not found at: ", template_dir, "\n",
        "  This should not happen. Please reinstall BFHcharts.",
        call. = FALSE
      )
    }

    template_file <- file.path(template_dir, "bfh-template.typ")

    if (!file.exists(template_file)) {
      stop(
        "Template file not found: ", template_file, "\n",
        "  This should not happen. Please reinstall BFHcharts.",
        call. = FALSE
      )
    }
  }

  # Build Typst document content
  typst_content <- build_typst_content(
    chart_image = chart_image,
    metadata = metadata,
    spc_stats = spc_stats,
    template = template,
    template_file = template_file
  )

  # Write Typst file
  writeLines(typst_content, output)

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
#' @export
bfh_compile_typst <- function(typst_file, output) {
  if (!file.exists(typst_file)) {
    stop("Typst file not found: ", typst_file, call. = FALSE)
  }

  # Create output directory if needed
  output_dir <- dirname(output)
  if (!dir.exists(output_dir) && output_dir != ".") {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Use quarto typst compile (not quarto render which expects .qmd files)
  result <- system2(
    "quarto",
    args = c("typst", "compile", typst_file, output),
    stdout = TRUE,
    stderr = TRUE
  )

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

#' Extract SPC Statistics from Summary
#'
#' @param summary Summary data frame from bfh_qic_result
#' @return List with runs, crossings, outliers (expected and actual)
#' @keywords internal
extract_spc_stats <- function(summary) {
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

#' Merge User Metadata with Defaults
#'
#' @param metadata User-provided metadata list
#' @param chart_title Chart title from config
#' @return Merged metadata list
#' @keywords internal
merge_metadata <- function(metadata, chart_title) {
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

  # Merge: user values override defaults
  merged <- defaults
  for (name in names(metadata)) {
    if (name %in% names(defaults)) {
      merged[[name]] <- metadata[[name]]
    }
  }

  return(merged)
}

#' Build Typst Document Content
#'
#' @param chart_image Path to chart PNG
#' @param metadata Metadata list
#' @param spc_stats SPC statistics list
#' @param template Template name
#' @param template_file Path to template .typ file
#' @return Character vector with Typst content
#' @keywords internal
build_typst_content <- function(chart_image, metadata, spc_stats, template, template_file) {
  # Build import statement with escaped path (fixes Windows backslash issue)
  template_dir <- dirname(template_file)
  escaped_template_path <- escape_typst_path(template_file)
  import_line <- sprintf('#import "%s": %s', escaped_template_path, template)

  # Build template call with parameters
  params <- list()

  # Required parameters - escape image path for cross-platform compatibility
  escaped_chart_path <- escape_typst_path(chart_image)
  params$chart <- sprintf('image("%s")', escaped_chart_path)

  # Optional metadata parameters
  if (!is.null(metadata$hospital)) {
    params$hospital <- sprintf('"%s"', escape_typst_string(metadata$hospital))
  }
  if (!is.null(metadata$department)) {
    params$department <- sprintf('"%s"', escape_typst_string(metadata$department))
  }
  if (!is.null(metadata$title) && nchar(metadata$title) > 0) {
    params$title <- sprintf('"%s"', escape_typst_string(metadata$title))
  }
  if (!is.null(metadata$analysis)) {
    params$analysis <- sprintf('"%s"', escape_typst_string(metadata$analysis))
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

  # Build parameter string
  param_strings <- c()
  for (name in names(params)) {
    param_strings <- c(param_strings, sprintf("  %s: %s", name, params[[name]]))
  }
  param_block <- paste(param_strings, collapse = ",\n")

  # Assemble document
  content <- c(
    import_line,
    "",
    sprintf("#show: %s.with(", template),
    param_block,
    ")",
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

#' Escape File Path for Typst
#'
#' Normalizes and escapes a file path for safe use in Typst documents.
#' Converts Windows backslashes to forward slashes and escapes special characters.
#'
#' @param path Character string with file path
#' @return Escaped path safe for Typst
#' @keywords internal
escape_typst_path <- function(path) {
  if (is.null(path) || length(path) == 0 || nchar(path) == 0) return("")


  # Normalize path: convert to forward slashes, resolve relative paths

  # mustWork = FALSE allows paths that don't exist yet (e.g., output files)
  normalized <- tryCatch(
    normalizePath(path, winslash = "/", mustWork = FALSE),
    error = function(e) path
  )

  # Escape special characters for Typst string literal
  escaped <- escape_typst_string(normalized)

  return(escaped)
}
