# ============================================================================
# INTERNE HELPERS TIL bfh_export_pdf()
# Opdelt fra export_pdf.R for at reducere kompleksitet i orchestrator.
# ============================================================================

#' Valider inputs til bfh_export_pdf()
#'
#' Kaster fejl ved ugyldige input-værdier. Dækker class, metadata,
#' dpi, font_path, inject_assets og batch_session validering.
#'
#' @noRd
validate_bfh_export_pdf_inputs <- function(x, output, metadata, dpi,
                                           font_path, inject_assets,
                                           batch_session, template_path) {
  # Klasse-tjek
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

  # Metadata felt-validering
  known_fields <- c(
    "hospital", "department", "analysis", "details", "author",
    "date", "data_definition", "target", "footer_content"
  )

  unknown_fields <- setdiff(names(metadata), known_fields)
  if (length(unknown_fields) > 0) {
    warning(
      "Unknown metadata fields will be ignored: ",
      paste(unknown_fields, collapse = ", "),
      call. = FALSE
    )
  }

  for (field in names(metadata)) {
    if (field %in% known_fields) {
      value <- metadata[[field]]

      if (!is.null(value) && !is.character(value)) {
        if (field == "date" && inherits(value, "Date")) next
        if (field == "target" && is.numeric(value)) next
        stop(
          "metadata$", field, " must be a character string",
          if (field == "date") " (or Date object)" else "",
          if (field == "target") " (or numeric)" else "",
          "\n  Got: ", class(value)[1],
          call. = FALSE
        )
      }

      if (is.character(value) && nchar(value) > 10000) {
        stop(
          "metadata$", field, " exceeds maximum length of 10,000 characters\n",
          "  Current length: ", nchar(value),
          call. = FALSE
        )
      }
    }
  }

  # Valgfrie parameter-validering
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

  # batch_session validering
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
}


#' Forbered eksport metadata (auto-analysis + auto-details)
#'
#' Muterer metadata-listen med auto-genereret analyse og/eller detaljer
#' hvis de ikke allerede er tilvejebragt af kalderen.
#'
#' @noRd
prepare_export_metadata <- function(x, metadata, auto_analysis, use_ai,
                                    analysis_min_chars, analysis_max_chars) {
  if (isTRUE(auto_analysis) && is.null(metadata$analysis)) {
    metadata$analysis <- bfh_generate_analysis(
      x = x,
      metadata = metadata,
      use_ai = use_ai,
      min_chars = analysis_min_chars,
      max_chars = analysis_max_chars
    )
  }

  if (is.null(metadata$details)) {
    metadata$details <- bfh_generate_details(x)
  }

  metadata
}


#' Valider custom template-sti (security + file-checks)
#'
#' Kører security-validering og fil-tjek på template_path.
#' Returnerer normaliseret sti eller NULL.
#'
#' @noRd
validate_template_path <- function(template_path) {
  if (is.null(template_path)) {
    return(NULL)
  }

  if (!is.character(template_path) || length(template_path) != 1) {
    stop("template_path must be a single character string", call. = FALSE)
  }
  validate_export_path(template_path)

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

  template_path
}


#' Opret midlertidigt arbejdsmappe til en enkelt eksport
#'
#' Returnerer en liste med navnene på de midlertidige filer:
#' - temp_dir: mappe-sti (ny per eksport, eller genbrugt fra session)
#' - chart_svg: unik SVG-fil-sti (unik per eksport via tempfile())
#' - typst_file: unik .typ-fil-sti (unik per eksport via tempfile())
#'
#' Cleanup (on.exit) registreres af orchestratoren baseret på batch-mode.
#'
#' @noRd
prepare_temp_workspace <- function(batch_session) {
  if (!is.null(batch_session)) {
    # Batch-mode: genbrug session-tmpdir; statiske filnavne (samme som single-call)
    temp_dir <- batch_session$tmpdir
    chart_svg <- file.path(temp_dir, "chart.svg")
    typst_file <- file.path(temp_dir, "document.typ")
  } else {
    # Single-call mode: ny temp-mappe per eksport
    temp_dir <- tempfile("bfh_pdf_")
    chart_svg <- file.path(temp_dir, "chart.svg")
    typst_file <- file.path(temp_dir, "document.typ")

    dir.create(temp_dir, recursive = TRUE)

    # Sikkerhed: restriktive rettigheder (kun ejer: rwx------)
    Sys.chmod(temp_dir, mode = "0700", use_umask = FALSE)

    # Sikkerhed: verificer ejerskab på Unix (TOCTOU-beskyttelse)
    if (.Platform$OS.type == "unix") {
      dir_info <- file.info(temp_dir)
      current_uid <- suppressWarnings(as.integer(Sys.getenv("UID")))
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

  list(temp_dir = temp_dir, chart_svg = chart_svg, typst_file = typst_file)
}


#' Forbered plot til PDF-eksport (title strip + label recalc + margin)
#'
#' Fjerner title/subtitle fra plottet, recalkulerer label-positioner
#' til PDF-dimensioner, og sætter 0 mm margins.
#'
#' @noRd
prepare_export_plot <- function(x) {
  # Strip titel fra plottet (titel går i Typst-skabelonen, ikke billedet)
  plot_no_title <- x$plot + ggplot2::labs(title = NULL, subtitle = NULL)
  x_for_export <- x
  x_for_export$plot <- plot_no_title

  # Recalkuler label-positioner til PDF-dimensioner
  plot_for_export <- recalculate_labels_for_export(
    x                = x_for_export,
    target_width_mm  = PDF_CHART_WIDTH_MM,
    target_height_mm = PDF_CHART_HEIGHT_MM,
    label_size       = PDF_LABEL_SIZE
  )

  # Sæt 0 mm margins til Typst-skabelon
  prepare_plot_for_export(plot_for_export, margin_mm = 0)
}


#' Eksportér chart til SVG via ggsave
#'
#' @noRd
export_chart_svg <- function(plot_for_export, chart_svg, dpi) {
  tryCatch(
    ggplot2::ggsave(
      filename = chart_svg,
      plot     = plot_for_export,
      width    = PDF_IMAGE_WIDTH_MM / 25.4, # 250mm original arbejdsstørrelse
      height   = PDF_IMAGE_HEIGHT_MM / 25.4, # 140mm
      units    = "in",
      dpi      = dpi,
      device   = "svg"
    ),
    error = function(e) {
      stop(
        "Failed to save chart image\n",
        "  Error: ", conditionMessage(e),
        call. = FALSE
      )
    }
  )
}


#' Sammensæt Typst-dokument og løs font_path op
#'
#' Kalder bfh_create_typst_document(), kører inject_assets callback
#' (single-call mode), og auto-detekterer font_path fra injicerede assets.
#'
#' Returnerer den effektive font_path (kan være NULL).
#'
#' @noRd
compose_typst_document <- function(x, chart_svg, typst_file,
                                   metadata, spc_stats, template,
                                   template_path, batch_session,
                                   font_path, inject_assets) {
  # Merge metadata med defaults
  chart_title <- x$config$chart_title
  if (is.null(chart_title)) chart_title <- ""
  metadata_full <- bfh_merge_metadata(metadata, chart_title)

  # Effektiv font_path: per-eksport arg > session default > NULL
  effective_font_path <- font_path %||% batch_session$font_path

  # Opret Typst-dokument
  bfh_create_typst_document(
    chart_image        = chart_svg,
    output             = typst_file,
    metadata           = metadata_full,
    spc_stats          = spc_stats,
    template           = template,
    template_path      = template_path,
    skip_template_copy = !is.null(batch_session)
  )

  # Injicér eksterne assets (single-call mode kun)
  if (is.function(inject_assets)) {
    temp_dir <- dirname(typst_file)
    inject_assets(file.path(temp_dir, "bfh-template"))

    # Auto-detektér font_path fra injicerede fonts/ hvis ikke eksplicit angivet
    if (is.null(effective_font_path)) {
      injected_fonts <- file.path(temp_dir, "bfh-template", "fonts")
      if (dir.exists(injected_fonts)) {
        effective_font_path <- injected_fonts
      }
    }
  }

  effective_font_path
}


#' Kompilér Typst-dokument til PDF via Quarto
#'
#' @noRd
compile_pdf_via_quarto <- function(typst_file, output,
                                   effective_font_path,
                                   ignore_system_fonts) {
  bfh_compile_typst(
    typst_file,
    output,
    font_path           = effective_font_path,
    ignore_system_fonts = ignore_system_fonts
  )
}
