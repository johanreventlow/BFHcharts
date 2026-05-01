# ============================================================================
# INTERNE HELPERS TIL bfh_export_pdf()
# Opdelt fra export_pdf.R for at reducere kompleksitet i orchestrator.
# ============================================================================

# Valider strikt-baseline-mode for PDF-eksport.
#
# Bypass: strict_baseline = FALSE (interaktivt warning-mode bevares for bfh_qic()).
# Strict-mode (default for export):
#   - config$freeze < MIN_BASELINE_N (8) -> stop med klar besked
#   - Enhver fase i qic_data med faerre end MIN_BASELINE_N raekker -> stop
# Begrundelse: PDF'er fra bfh_export_pdf() havner typisk paa QI-leadership-
# borde hvor R-warnings aldrig naar en menneskelig laeser. Anhoej & Olesen 2014
# anbefaler >=8 baseline-punkter for paalidelig run/crossing-detection.
# Spec: pdf-export, change strict-baseline-mode-for-export (Codex 2026-04-30 #4)
.validate_strict_baseline <- function(x, strict_baseline) {
  if (!isTRUE(strict_baseline)) {
    return(invisible(NULL))
  }
  freeze_val <- x$config$freeze
  if (!is.null(freeze_val) && length(freeze_val) == 1L &&
    is.numeric(freeze_val) && !is.na(freeze_val) &&
    freeze_val < MIN_BASELINE_N) {
    stop(
      sprintf(
        "freeze = %s: baseline har faerre end %d punkter (MIN_BASELINE_N). ",
        as.integer(freeze_val), MIN_BASELINE_N
      ),
      "Saet strict_baseline = FALSE for at acceptere kortere baseline ",
      "(kontrolgraenser kan vaere statistisk usikre).",
      call. = FALSE
    )
  }
  qd <- x$qic_data
  if (!is.null(qd) && "part" %in% names(qd)) {
    phase_sizes <- as.integer(table(qd$part))
    short_phases <- which(phase_sizes < MIN_BASELINE_N)
    if (length(short_phases) > 0L) {
      stop(
        sprintf(
          "Fase(r) %s har faerre end %d punkter (MIN_BASELINE_N). ",
          paste(short_phases, collapse = ", "), MIN_BASELINE_N
        ),
        "Saet strict_baseline = FALSE for at acceptere kortere faser ",
        "(kontrolgraenser kan vaere statistisk usikre).",
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}


# Valider metadata$target som scalar finit numerisk eller scalar character.
# Bruges fra bfh_export_pdf(), bfh_generate_analysis() og
# bfh_build_analysis_context(). Tidlig + klar fejl forhindrer kryptiske
# downstream-fejl i resolve_target() / qicharts2.
#
# Kontrakt:
#   NULL              -> OK (intet target)
#   length-1 numeric  -> skal vaere finit (ikke NA/Inf/NaN)
#   length-1 character -> skal ikke vaere NA; tom streng tillades
#                        (resolve_target() returnerer empty for "")
#   Alt andet         -> error med specifik aarsag
.validate_metadata_target <- function(x) {
  if (is.null(x)) {
    return(invisible(NULL))
  }
  if (is.numeric(x)) {
    if (length(x) != 1L) {
      stop(
        "metadata$target must be a scalar (length 1), got length ", length(x),
        call. = FALSE
      )
    }
    if (!is.finite(x)) {
      stop(
        "metadata$target must be a finite numeric (no NA/Inf/NaN), got: ", x,
        call. = FALSE
      )
    }
    return(invisible(NULL))
  }
  if (is.character(x)) {
    if (length(x) != 1L) {
      stop(
        "metadata$target must be a scalar (length 1), got length ", length(x),
        call. = FALSE
      )
    }
    if (is.na(x)) {
      stop("metadata$target must not be NA", call. = FALSE)
    }
    return(invisible(NULL))
  }
  stop(
    "metadata$target must be NULL, a single finite numeric, or a single character string.\n",
    "  Got class: ", paste(class(x), collapse = "/"),
    call. = FALSE
  )
}


#' Valider inputs til bfh_export_pdf()
#'
#' Kaster fejl ved ugyldige input-vaerdier. Daekker class, metadata,
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

      if (field == "target") {
        # target har sin egen scalar/finit-validering
        .validate_metadata_target(value)
        next
      }

      if (!is.null(value) && !is.character(value)) {
        if (field == "date" && inherits(value, "Date")) next
        stop(
          "metadata$", field, " must be a character string",
          if (field == "date") " (or Date object)" else "",
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
                                    analysis_min_chars, analysis_max_chars,
                                    data_consent = NULL, use_rag = FALSE) {
  if (isTRUE(auto_analysis) && is.null(metadata$analysis)) {
    metadata$analysis <- bfh_generate_analysis(
      x = x,
      metadata = metadata,
      use_ai = use_ai,
      data_consent = data_consent,
      use_rag = use_rag,
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
#' Koerer security-validering og fil-tjek paa template_path.
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
#' Returnerer en liste med navnene paa de midlertidige filer:
#' - temp_dir: mappe-sti (ny per eksport, eller genbrugt fra session)
#' - chart_svg: unik SVG-fil-sti (unik per eksport via tempfile())
#' - typst_file: unik .typ-fil-sti (unik per eksport via tempfile())
#'
#' Cleanup (on.exit) registreres af orchestratoren baseret paa batch-mode.
#'
#' @noRd
prepare_temp_workspace <- function(batch_session) {
  if (!is.null(batch_session)) {
    temp_dir <- batch_session$tmpdir
    return(list(
      temp_dir   = temp_dir,
      chart_svg  = tempfile(pattern = "chart-", tmpdir = temp_dir, fileext = ".svg"),
      typst_file = tempfile(pattern = "document-", tmpdir = temp_dir, fileext = ".typ")
    ))
  }

  temp_dir <- tempfile("bfh_pdf_")
  chart_svg <- tempfile(pattern = "chart-", tmpdir = temp_dir, fileext = ".svg")
  typst_file <- tempfile(pattern = "document-", tmpdir = temp_dir, fileext = ".typ")

  dir.create(temp_dir, recursive = TRUE)

  # Sikkerhed: tempfile() leverer en per-bruger isoleret sti i tempdir(),
  # og Sys.chmod(0700) fjerner group/other-permissions. UID-baseret
  # ownership-validering udelades bevidst -- UID er shell-intern og typisk
  # ikke eksporteret til R-processer (Rscript, RStudio Server, knitr,
  # Shiny, GitHub Actions), saa saadanne checks evaluerer til NA og skippes
  # silently uden reel beskyttelse.
  Sys.chmod(temp_dir, mode = "0700", use_umask = FALSE)

  list(temp_dir = temp_dir, chart_svg = chart_svg, typst_file = typst_file)
}


#' Forbered plot til PDF-eksport (title strip + label recalc + margin)
#'
#' Fjerner title/subtitle fra plottet, recalkulerer label-positioner
#' til PDF-dimensioner, og saetter 0 mm margins.
#'
#' @noRd
prepare_export_plot <- function(x) {
  # Strip titel fra plottet (titel gaar i Typst-skabelonen, ikke billedet)
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

  # Saet 0 mm margins til Typst-skabelon
  prepare_plot_for_export(plot_for_export, margin_mm = 0)
}


#' Eksporter chart til SVG via ggsave
#'
#' @noRd
export_chart_svg <- function(plot_for_export, chart_svg, dpi) {
  tryCatch(
    ggplot2::ggsave(
      filename = chart_svg,
      plot     = plot_for_export,
      width    = PDF_IMAGE_WIDTH_MM / 25.4, # 250mm original arbejdsstoerrelse
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


#' Sammensaet Typst-dokument og loes font_path op
#'
#' Kalder bfh_create_typst_document(), koerer inject_assets callback
#' (single-call mode), og auto-detekterer font_path fra injicerede assets.
#'
#' Returnerer den effektive font_path (kan vaere NULL).
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

  # Injicer eksterne assets (single-call mode kun)
  if (is.function(inject_assets)) {
    temp_dir <- dirname(typst_file)
    inject_assets(file.path(temp_dir, "bfh-template"))

    # Auto-detekter font_path fra injicerede fonts/ hvis ikke eksplicit angivet
    if (is.null(effective_font_path)) {
      injected_fonts <- file.path(temp_dir, "bfh-template", "fonts")
      if (dir.exists(injected_fonts)) {
        effective_font_path <- injected_fonts
      }
    }
  }

  effective_font_path
}


#' Kompiler Typst-dokument til PDF via Quarto
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
