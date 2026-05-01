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
#' chart image and metadata. Downstream packages (e.g. biSPCharts) can use
#' this function directly instead of accessing it via
#' \code{getFromNamespace()}.
#'
#' @param chart_image Path to chart image (SVG or PNG)
#' @param output Path for output .typ file
#' @param metadata List with template parameters (hospital, department, title,
#'   analysis, details, author, date, data_definition, footer_content).
#'   See \code{\link{bfh_merge_metadata}} for a convenient way to build this
#'   list with defaults filled in.
#' @param spc_stats List with SPC statistics (runs_expected, runs_actual,
#'   crossings_expected, crossings_actual, outliers_expected,
#'   outliers_actual, is_run_chart). See \code{\link{bfh_extract_spc_stats}}
#'   for how to produce this list from a \code{bfh_qic_result} object.
#' @param template Template name (default: "bfh-diagram")
#' @param template_path Optional custom template path. When provided, overrides
#'   the packaged template (default: NULL uses packaged template)
#' @param skip_template_copy Logical. If TRUE, skip copying the template
#'   directory (assumes it is already present in the output directory).
#'   Default: FALSE.
#'
#' @return Path to created .typ file (invisibly)
#'
#' @export
#' @family utility-functions
#' @seealso \code{\link{bfh_extract_spc_stats}}, \code{\link{bfh_merge_metadata}}
#' @examples
#' \dontrun{
#' result <- bfh_qic(data, x = date, y = value, chart_type = "i")
#' metadata <- bfh_merge_metadata(
#'   list(department = "Quality"),
#'   chart_title = result$config$chart_title
#' )
#' spc_stats <- bfh_extract_spc_stats(result)
#' tmp_dir <- tempdir()
#' chart_png <- file.path(tmp_dir, "chart.png")
#' ggplot2::ggsave(chart_png, result$plot, width = 8, height = 5)
#' typ_file <- bfh_create_typst_document(
#'   chart_image = chart_png,
#'   output      = file.path(tmp_dir, "document.typ"),
#'   metadata    = metadata,
#'   spc_stats   = spc_stats
#' )
#' }
bfh_create_typst_document <- function(chart_image,
                                      output,
                                      metadata,
                                      spc_stats,
                                      template = "bfh-diagram",
                                      template_path = NULL,
                                      skip_template_copy = FALSE) {
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

    local_template_dir <- file.path(output_dir, "bfh-template")
    if (!skip_template_copy) {
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
    } else if (!dir.exists(local_template_dir)) {
      stop(
        "Template directory not found in session tmpdir: ", local_template_dir,
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
    chart_image = chart_basename, # Use basename since image is now in output_dir
    metadata = metadata,
    spc_stats = spc_stats,
    template = template,
    template_file = template_basename # Use relative path
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

# Afkorter compile-output til max `max` tegn for at undgaa laekage af
# filsystem-stier i fejlbeskeder. Bruges i begge fejl-branches i
# bfh_compile_typst() saa truncation er konsistent.
.truncate_compile_output <- function(output, max = 500L) {
  substr(paste(output, collapse = "\n"), 1L, max)
}

# Wrapper around system2() that ensures path-like arguments are properly
# shell-quoted when stdout/stderr capture is requested.
#
# Background: R's system2() with stdout=TRUE or stderr=TRUE routes through
# /bin/sh -c on macOS/Linux (the shell is needed for stream capture). This
# means all args are joined into a shell command string. Paths that contain
# shell-special characters (spaces, parens, brackets, $, &, ') will be
# misinterpreted by the shell unless quoted.
#
# Strategy: Apply shQuote() to any arg that does NOT begin with "--" (i.e.
# path-like positional args). Flag args (e.g. "--ignore-system-fonts") are
# safe as-is; quoting them could break Quarto's flag parser.
#
# The .system2 parameter is the dependency-injection hook inherited from
# bfh_compile_typst() so mock injection works end-to-end.
.safe_system2_capture <- function(cmd, args, ..., .system2 = system2) {
  # Determine if any args need quoting (non-flag positional args)
  quoted_args <- vapply(args, function(arg) {
    if (startsWith(arg, "--")) {
      arg
    } else {
      shQuote(arg)
    }
  }, character(1L))
  .system2(cmd, args = quoted_args, ...)
}


#' Compile Typst Document to PDF
#'
#' Compiles a .typ file to PDF using Quarto's bundled Typst compiler.
#'
#' @param typst_file Path to .typ file
#' @param output Path for output PDF file
#' @param font_path Optional path to directory containing additional fonts.
#'   Passed as \code{--font-path} to the Typst compiler. Useful when fonts
#'   are not installed system-wide (e.g., on cloud deployment platforms).
#' @param ignore_system_fonts Logical. If \code{TRUE} (default), passes
#'   \code{--ignore-system-fonts} to Typst, ensuring only fonts from
#'   \code{font_path} are used. Prevents system-installed font variants
#'   (e.g., Mari Heavy with metadata \code{style=Heavy,Regular}) from
#'   leaking into the rendered PDF and causing inconsistent weights between
#'   dev machines and cloud deployment. Set to \code{FALSE} only if relying
#'   on system fonts is intentional.
#' @param .system2 Dependency-injection hook for \code{system2()}. Default is
#'   the real \code{base::system2}. Tests can inject a mock to avoid spawning
#'   live Quarto processes.
#' @param .quarto_path Path to the Quarto executable. When \code{NULL}
#'   (default), resolved via \code{get_quarto_path()}. Tests can supply
#'   \code{"/fake/quarto"} to avoid filesystem lookups.
#'
#' @return Path to created PDF file (invisibly)
#'
#' @keywords internal
#' @noRd
bfh_compile_typst <- function(typst_file, output, font_path = NULL,
                              ignore_system_fonts = TRUE,
                              .system2 = system2, .quarto_path = NULL) {
  if (!file.exists(typst_file)) {
    stop("Typst file not found: ", typst_file, call. = FALSE)
  }

  # Security: Validate paths before passing to system2()
  validate_export_path(typst_file)
  validate_export_path(output)

  # Valider font_path hvis angivet
  if (!is.null(font_path)) {
    if (!is.character(font_path) || length(font_path) != 1) {
      stop("font_path must be a single character string", call. = FALSE)
    }
    .check_traversal(font_path)
    .check_metachars(font_path)
    if (!dir.exists(font_path)) {
      warning("font_path directory does not exist: ", font_path, call. = FALSE)
      font_path <- NULL
    }
  } else {
    # Auto-detect fonts/ subdirectory in the staged template tempdir.
    # Companion packages (e.g. BFHchartsAssets) inject fonts into a fonts/
    # subdirectory alongside the .typ file. Without auto-detect, these are
    # silently ignored and the compile falls back to system fonts only.
    staged_fonts_dir <- file.path(dirname(typst_file), "bfh-template", "fonts")
    if (dir.exists(staged_fonts_dir)) {
      font_extensions <- c("\\.ttf$", "\\.otf$", "\\.woff$", "\\.woff2$")
      font_pattern <- paste(font_extensions, collapse = "|")
      font_files <- list.files(staged_fonts_dir,
        pattern = font_pattern,
        ignore.case = TRUE, full.names = FALSE
      )
      if (length(font_files) > 0) {
        font_path <- staged_fonts_dir
      }
    }
  }

  # Create output directory if needed
  output_dir <- dirname(output)
  if (!dir.exists(output_dir) && output_dir != ".") {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Build compilation args.
  # Note: shQuote() is applied inside .safe_system2_capture() for path-like
  # args. system2(stdout=TRUE, stderr=TRUE) routes through /bin/sh on
  # macOS/Linux for stream capture, so paths with spaces/parens/brackets/$
  # must be quoted. Flag args (--ignore-system-fonts, --font-path) are
  # passed through without quoting so Quarto's flag parser sees them intact.
  compile_args <- c("typst", "compile", typst_file, output)
  if (!is.null(font_path)) {
    compile_args <- c(compile_args, "--font-path", font_path)
  }
  if (isTRUE(ignore_system_fonts)) {
    compile_args <- c(compile_args, "--ignore-system-fonts")
  }

  # Use quarto typst compile (not quarto render which expects .qmd files)
  quarto_cmd <- .quarto_path %||% get_quarto_path()
  result <- tryCatch(
    .safe_system2_capture(
      quarto_cmd,
      args = compile_args,
      stdout = TRUE,
      stderr = TRUE,
      .system2 = .system2
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
    safe_output <- .truncate_compile_output(result)
    stop(
      "Quarto compilation failed with exit code ", exit_status, "\n",
      "  Output: ", safe_output,
      call. = FALSE
    )
  }

  # Check if PDF was created (quarto typst compile outputs directly to target)
  if (!file.exists(output)) {
    safe_output <- .truncate_compile_output(result)
    stop(
      "PDF compilation failed.\n",
      "  Quarto output: ", safe_output,
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
#' @noRd
build_typst_content <- function(chart_image, metadata, spc_stats, template, template_file) {
  # Valider template-identifier mod injection

  if (!grepl("^[a-zA-Z][a-zA-Z0-9_-]*$", template)) {
    stop("template must be a valid Typst identifier (letters, numbers, hyphens, underscores)",
      call. = FALSE
    )
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
    params$title <- sprintf("[%s]", markdown_to_typst(metadata$title))
  }
  if (!is.null(metadata$analysis)) {
    # Analysis supports rich text - use content block [...]
    params$analysis <- sprintf("[%s]", markdown_to_typst(metadata$analysis))
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
    params$footer_content <- sprintf("[%s]", markdown_to_typst(metadata$footer_content))
  }

  # Date parameter - format for Typst template
  if (!is.null(metadata$date)) {
    date_obj <- as.Date(metadata$date)
    params$date <- sprintf(
      "datetime(year: %d, month: %d, day: %d)",
      as.integer(format(date_obj, "%Y")),
      as.integer(format(date_obj, "%m")),
      as.integer(format(date_obj, "%d"))
    )
  }

  # SPC statistics - send "?" for NA (vises i tabel), udelad kun NULL
  spc_val <- function(x) {
    if (is.null(x)) {
      return(NULL)
    }
    if (is.na(x) || is.infinite(x)) {
      return("\"?\"")
    }
    as.character(x)
  }
  if (!is.null(spc_stats$runs_expected)) {
    params$runs_expected <- spc_val(spc_stats$runs_expected)
  }
  if (!is.null(spc_stats$runs_actual)) {
    params$runs_actual <- spc_val(spc_stats$runs_actual)
  }
  if (!is.null(spc_stats$crossings_expected)) {
    params$crossings_expected <- spc_val(spc_stats$crossings_expected)
  }
  if (!is.null(spc_stats$crossings_actual)) {
    params$crossings_actual <- spc_val(spc_stats$crossings_actual)
  }
  if (!is.null(spc_stats$outliers_expected)) {
    params$outliers_expected <- spc_val(spc_stats$outliers_expected)
  }
  if (!is.null(spc_stats$outliers_actual)) {
    params$outliers_actual <- spc_val(spc_stats$outliers_actual)
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
#' @noRd
escape_typst_string <- function(s) {
  if (is.null(s) || length(s) == 0) {
    return("")
  }

  # Fjern/erstat kontroltegn foer andre escapes:
  # \n, \r, \t -> mellemrum (fx afdeling copy-pastet fra Windows med CRLF)
  s <- gsub("[\n\r\t]", " ", s)
  # NUL-byte -> fjern (udefineret adfaerd i Typst)
  # R character-strenge kan normalt ikke indeholde NUL, men defensivt guard:
  # perl-regex \\x00 matcher NUL uden at skulle indlejre literal NUL i kildefil.
  s <- gsub("\\x00", "", s, perl = TRUE)

  # Escape backslashes and quotes
  s <- gsub("\\\\", "\\\\\\\\", s)
  s <- gsub('"', '\\\\"', s)

  # Escape Typst special characters
  s <- gsub("<", "\\\\<", s)
  s <- gsub(">", "\\\\>", s)

  return(s)
}

#' Escape Plain Text for Typst Content Blocks
#'
#' Escapes all Typst markup characters in plain text so they render literally.
#' Must be applied to text nodes only - do not apply to generated Typst markup.
#'
#' @param s Character string to escape
#' @return Escaped string safe for Typst content blocks
#' @keywords internal
#' @noRd
escape_typst_text <- function(s) {
  if (is.null(s) || !nzchar(s)) {
    return(s %||% "")
  }
  # Backslash MUST be escaped first - all others introduce a leading backslash
  s <- gsub("\\", "\\\\", s, fixed = TRUE)
  s <- gsub("#", "\\#", s, fixed = TRUE)
  s <- gsub("$", "\\$", s, fixed = TRUE)
  s <- gsub("@", "\\@", s, fixed = TRUE)
  s <- gsub("_", "\\_", s, fixed = TRUE)
  s <- gsub("*", "\\*", s, fixed = TRUE)
  s <- gsub("[", "\\[", s, fixed = TRUE)
  s <- gsub("]", "\\]", s, fixed = TRUE)
  s <- gsub("<", "\\<", s, fixed = TRUE)
  s <- gsub(">", "\\>", s, fixed = TRUE)
  s <- gsub("`", "\\`", s, fixed = TRUE)
  s <- gsub("~", "\\~", s, fixed = TRUE)
  s <- gsub("^", "\\^", s, fixed = TRUE)
  s
}

escape_typst_raw <- function(s) {
  s <- gsub("\\", "\\\\", s, fixed = TRUE)
  gsub('"', '\\"', s, fixed = TRUE)
}

#' Walk a CommonMark XML Node to Typst Markup
#'
#' Recursive AST walker: maps CommonMark XML node types to Typst content syntax.
#' Text nodes are escaped via escape_typst_text().
#'
#' @param node xml2 node object
#' @return Character string with Typst markup
#' @keywords internal
#' @noRd
walk_typst_node <- function(node) {
  tag <- xml2::xml_name(node)

  switch(tag,
    document = {
      kids <- xml2::xml_children(node)
      sections <- vapply(kids, walk_typst_node, character(1))
      paste(sections, collapse = "\\\n")
    },
    paragraph = {
      kids <- xml2::xml_children(node)
      parts <- vapply(kids, walk_typst_node, character(1))
      paste(parts, collapse = "")
    },
    text = escape_typst_text(xml2::xml_text(node)),
    strong = {
      kids <- xml2::xml_children(node)
      inner <- paste(vapply(kids, walk_typst_node, character(1)), collapse = "")
      sprintf("#strong[%s]", inner)
    },
    emph = {
      kids <- xml2::xml_children(node)
      inner <- paste(vapply(kids, walk_typst_node, character(1)), collapse = "")
      sprintf("#emph[%s]", inner)
    },
    code = sprintf('#raw("%s")', escape_typst_raw(xml2::xml_text(node))),
    code_block = sprintf('#raw(block: true, "%s")', escape_typst_raw(xml2::xml_text(node))),
    softbreak = "\\\n",
    linebreak = "\\\n",
    # Link: render visible text only - hyperlinks are not supported in Typst content blocks
    link = {
      kids <- xml2::xml_children(node)
      paste(vapply(kids, walk_typst_node, character(1)), collapse = "")
    },
    # Image: render alt text only
    image = {
      kids <- xml2::xml_children(node)
      paste(vapply(kids, walk_typst_node, character(1)), collapse = "")
    },
    # Raw HTML: escape content for Typst - strip trailing newline added by CommonMark
    html_block = escape_typst_text(trimws(xml2::xml_text(node), which = "right")),
    html_inline = escape_typst_text(xml2::xml_text(node)),
    list = {
      items <- xml2::xml_children(node)
      parts <- vapply(items, walk_typst_node, character(1))
      paste(parts, collapse = "\\\n")
    },
    item = {
      kids <- xml2::xml_children(node)
      content <- paste(vapply(kids, walk_typst_node, character(1)), collapse = "")
      sprintf("- %s", content)
    },
    # Default: walk children; fall back to escaped text for leaf nodes
    {
      kids <- xml2::xml_children(node)
      if (length(kids) > 0) {
        paste(vapply(kids, walk_typst_node, character(1)), collapse = "")
      } else {
        txt <- xml2::xml_text(node)
        if (nzchar(txt)) escape_typst_text(txt) else ""
      }
    }
  )
}

#' Parse Markdown to Typst via CommonMark AST
#'
#' Internal AST-based markdown parser. Parses markdown with commonmark,
#' then walks the XML AST to produce Typst content markup with all
#' special characters fully escaped.
#'
#' @param text Character string with CommonMark markdown
#' @return Character string with Typst content markup
#' @keywords internal
#' @noRd
parse_markdown_ast <- function(text) {
  xml_str <- commonmark::markdown_xml(text)
  doc <- xml2::read_xml(xml_str)
  walk_typst_node(doc)
}

#' Convert Markdown Rich Text to Typst Content
#'
#' Converts CommonMark markdown to Typst content block markup using an
#' AST-based parser (commonmark + xml2). All Typst special characters in
#' plain text are fully escaped to prevent injection.
#'
#' @param text Character string with markdown formatting
#' @return Character string with Typst content block syntax
#' @keywords internal
#' @noRd
#'
#' @details
#' **Supported Markdown Syntax:**
#' - `**bold text**` -> `#strong[bold text]`
#' - `*italic text*` -> `#emph[italic text]`
#' - `` `code` `` -> `#raw("code")`
#' - Newlines -> Typst line breaks (`\`)
#' - Bullet lists -> Typst list items (`- item`)
#'
#' **Security:**
#' All Typst markup characters (`#`, `$`, `@`, `_`, `*`, `[`, `]`, `<`, `>`,
#' `` ` ``, `~`, `^`, `\`) in plain text are escaped. AST parsing prevents
#' injection via malformed markdown edge cases.
#'
#' @examples
#' \dontrun{
#' markdown_to_typst("This is **important**")
#' # Returns: "This is #strong[important]"
#'
#' markdown_to_typst("Injection: #import malicious")
#' # Returns: "Injection: \#import malicious"
#' }
markdown_to_typst <- function(text) {
  if (is.null(text) || length(text) == 0 || !nzchar(text)) {
    return("")
  }
  parse_markdown_ast(text)
}
