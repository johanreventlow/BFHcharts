#' Typst Document Generation and Compilation
#'
#' Internal utilities for generating Typst documents, compiling to PDF,
#' and handling Typst string escaping and markdown conversion.
#'
#' @name utils_typst
#' @keywords internal
#' @noRd
NULL

#' Create Typst Document for SPC Chart
#'
#' Generates a Typst document (.typ) using BFH hospital template with
#' chart image and metadata.
#'
#' @param chart_image Path to chart image (SVG or PNG)
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

  if (any(vapply(shell_metachars, function(char) grepl(char, typst_file, fixed = TRUE), logical(1)))) {
    stop(
      "typst_file path contains potentially unsafe characters\n",
      "  Path: ", basename(typst_file),
      call. = FALSE
    )
  }

  if (any(vapply(shell_metachars, function(char) grepl(char, output, fixed = TRUE), logical(1)))) {
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
      get_quarto_path(),
      args = c("typst", "compile", shQuote(typst_file), shQuote(output)),
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
    # Begræns output for at undgå lækage af filsystem-stier i fejlbeskeder
    safe_output <- substr(paste(result, collapse = "\n"), 1, 500)
    stop(
      "Quarto compilation failed with exit code ", exit_status, "\n",
      "  Output: ", safe_output,
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

#' Build Typst Document Content
#'
#' @param chart_image Filename of chart image (relative to document location, already copied)
#' @param metadata Metadata list
#' @param spc_stats SPC statistics list
#' @param template Template name
#' @param template_file Relative path to template .typ file (relative to document location)
#' @return Character vector with Typst content
#' @keywords internal
build_typst_content <- function(chart_image, metadata, spc_stats, template, template_file) {
  # Validér template-identifier mod injection

  if (!grepl("^[a-zA-Z][a-zA-Z0-9_-]*$", template)) {
    stop("template must be a valid Typst identifier (letters, numbers, hyphens, underscores)",
         call. = FALSE)
  }

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

  # SPC statistics — send "?" for NA (vises i tabel), udelad kun NULL
  spc_val <- function(x) {
    if (is.null(x)) return(NULL)
    if (is.na(x) || is.infinite(x)) return("\"?\"")
    as.character(x)
  }
  if (!is.null(spc_stats$runs_expected))
    params$runs_expected <- spc_val(spc_stats$runs_expected)
  if (!is.null(spc_stats$runs_actual))
    params$runs_actual <- spc_val(spc_stats$runs_actual)
  if (!is.null(spc_stats$crossings_expected))
    params$crossings_expected <- spc_val(spc_stats$crossings_expected)
  if (!is.null(spc_stats$crossings_actual))
    params$crossings_actual <- spc_val(spc_stats$crossings_actual)
  if (!is.null(spc_stats$outliers_expected))
    params$outliers_expected <- spc_val(spc_stats$outliers_expected)
  if (!is.null(spc_stats$outliers_actual))
    params$outliers_actual <- spc_val(spc_stats$outliers_actual)

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

  # Escape Typst special characters
  s <- gsub("<", "\\\\<", s)
  s <- gsub(">", "\\\\>", s)

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
#' - `**bold text**` -> `#strong[bold text]`
#' - `*italic text*` -> `#emph[italic text]`
#' - Newlines (`\n`) -> Typst line breaks (`\`)
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

  # Escape Typst special characters i bruger-content FØR markdown-konvertering.
  # Rækkefølge er vigtig: brackets escapes først, derefter konverterer vi
  # markdown til Typst-markup (som indsætter sine egne uescapede brackets).
  result <- gsub("<", "\\\\<", result)
  result <- gsub(">", "\\\\>", result)
  result <- gsub("@", "\\\\@", result)
  result <- gsub("\\[", "\\\\[", result)  # Bracket injection prevention
  result <- gsub("\\]", "\\\\]", result)
  result <- gsub("(?<!\\*)#", "\\\\#", result, perl = TRUE)

  # Convert **bold** to #strong[bold] (EFTER escaping - vores brackets er uescaped)
  result <- gsub("\\*\\*([^*]+)\\*\\*", "#strong[\\1]", result)

  # Convert *italic* to #emph[italic] (single asterisks)
  # Use negative lookbehind/lookahead to avoid matching ** patterns
  result <- gsub("(?<!\\*)\\*([^*]+)\\*(?!\\*)", "#emph[\\1]", result, perl = TRUE)

  # Convert \n to Typst line break (backslash + newline)
  result <- gsub("\\n", "\\\\\n", result)

  return(result)
}
