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
#'     \item \code{target}: Target value for analysis context. Must be either
#'       NULL, a single finite numeric (`length 1`, no NA/Inf/NaN), or a
#'       single character string (`length 1`, not NA). Multi-element vectors
#'       and non-finite numerics are rejected with an informative error. The
#'       target also auto-flows from `bfh_qic(target_text=, target_value=)`
#'       via the analysis-context fallback chain (since v0.12.0).
#'     \item \code{footer_content}: Additional content to display below the chart (optional).
#'       Supports markdown formatting (bold, italic, line breaks).
#'     \item \code{logo_path}: Path to hospital logo image rendered in the
#'       template's foreground slot (optional). When NULL (default), no logo
#'       is rendered -- the PDF compiles successfully without proprietary
#'       branding assets. Companion packages (e.g. \code{BFHchartsAssets})
#'       inject the logo via \code{inject_assets} callback, and
#'       \code{compose_typst_document()} auto-detects a staged logo at
#'       \code{<staged-template>/images/Hospital_Maerke_RGB_A1_str.png} --
#'       no caller intervention required. Explicit \code{logo_path} overrides
#'       auto-detect. Path must be a non-empty character string; existence is
#'       not pre-validated (Typst surfaces the file-not-found error at compile).
#'   }
#' @param template Character string specifying template name (default: "bfh-diagram")
#' @param template_path Optional path to a custom Typst template file. When provided,
#'   this overrides the packaged template. The template must exist and be a valid
#'   Typst file (.typ). Default is NULL (uses packaged BFH template).
#' @param restrict_template Logical. When \code{TRUE} (default), any non-NULL
#'   \code{template_path} is rejected with an error. Use \code{FALSE} only in
#'   trusted contexts where a custom Typst template is intentionally supplied.
#'
#'   \strong{Threat model:} A custom Typst template is compiled by the Typst
#'   binary and can read or write arbitrary paths during compilation. This is
#'   equivalent to \code{source()} in trust requirements. \code{restrict_template
#'   = TRUE} prevents a compromised configuration pipeline from injecting a
#'   malicious template via \code{template_path}.
#'
#'   Default: \code{TRUE} (production-safe -- custom templates require explicit
#'   opt-in).
#'
#'   \strong{Migration from BFHcharts <= 0.15.x:} Callers passing
#'   \code{template_path} without \code{restrict_template} now receive a clear
#'   validation error. Migration is mechanical:
#'   \preformatted{
#'   # Before (BFHcharts <= 0.15.x): custom template silently allowed
#'   bfh_export_pdf(result, "out.pdf", template_path = "/my/template.typ")
#'
#'   # After (BFHcharts >= 0.16.0): explicit opt-out required
#'   bfh_export_pdf(result, "out.pdf",
#'                  template_path = "/my/template.typ",
#'                  restrict_template = FALSE)
#'   }
#' @param auto_analysis Logical. If TRUE and \code{metadata$analysis} is not provided,
#'   automatically generates analysis text using \code{bfh_generate_analysis()}.
#'   Default is FALSE for backward compatibility.
#' @param use_ai Logical. Controls AI usage for auto-analysis:
#'   \itemize{
#'     \item \code{FALSE} (default): Use standard texts only - no external data sharing
#'     \item \code{TRUE}: Use AI via BFHllm (requires BFHllm installed and \code{data_consent = "explicit"}; error if not satisfied)
#'   }
#'   Only used when \code{auto_analysis = TRUE}. See \code{bfh_generate_analysis()}
#'   for security policy details.
#' @param data_consent Character. Required when \code{use_ai = TRUE} and
#'   \code{auto_analysis = TRUE}. Must be \code{"explicit"} to acknowledge that
#'   clinical data is sent to \code{BFHllm}. Passed through to
#'   \code{bfh_generate_analysis()}. Ignored when \code{use_ai = FALSE}.
#'   See \code{\link{bfh_generate_analysis}} for full GDPR/HIPAA context.
#' @param use_rag Logical. Controls RAG for AI analysis. Default \code{FALSE}
#'   (privacy-preserving). Only used when \code{auto_analysis = TRUE} and
#'   \code{use_ai = TRUE}. See \code{\link{bfh_generate_analysis}}.
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
#' @param strict_baseline Logical. When TRUE (default), the function errors
#'   before render if \code{x$config$freeze < MIN_BASELINE_N} (8) or if any
#'   phase in \code{x$qic_data} contains fewer than \code{MIN_BASELINE_N}
#'   points. When FALSE, the export proceeds and the legacy warning-only
#'   behavior of \code{bfh_qic()} is preserved.
#'
#'   \strong{Rationale:} PDFs from this function typically reach
#'   quality-improvement leadership where R warnings never surface.
#'   Anhoej & Olesen (2014) recommend >= 8 baseline points for reliable
#'   run/crossing detection; charts with shorter baselines have tight but
#'   statistically unreliable control limits. Strict-by-default forces
#'   explicit acknowledgement of short-baseline output; the interactive
#'   \code{bfh_qic()} path remains warning-only because the analyst is
#'   present.
#'
#'   \strong{Inheritance:} When \code{batch_session} is supplied without an
#'   explicit per-call value, the session's \code{strict_baseline} is used.
#'   An explicit per-call value overrides the session.
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
#' \strong{\code{inject_assets} is full code execution.} The supplied function
#' runs with the same privileges as the calling R session, with full file-system
#' and network access. It MUST NOT come from user input (Shiny inputs, REST API
#' parameters, configuration files of unknown provenance).
#'
#' Acceptable sources:
#' \itemize{
#'   \item A function exported from a controlled companion package installed via
#'     \code{pak::pkg_install("private/repo")}.
#'   \item A function defined in your application's source code, version-controlled.
#' }
#'
#' Unacceptable sources:
#' \itemize{
#'   \item \code{parse(text = input$user_code)}
#'   \item A function loaded from an unverified URL
#'   \item A function deserialized from an untrusted RDS file
#' }
#'
#' When in doubt, do not pass \code{inject_assets}.
#'
#' \code{template_path} is compiled by the Typst binary. A custom
#' template can read and write arbitrary paths during compilation -- treat
#' it with the same trust contract as \code{source()}.
#'
#' \strong{Default since 0.16.0:} \code{restrict_template = TRUE} -- any
#' non-NULL \code{template_path} is rejected at validation time. Power users
#' supplying a trusted in-process template MUST opt-in with
#' \code{restrict_template = FALSE}. The default-safe posture eliminates the
#' silent privilege-escalation vector that would otherwise exist if a
#' configuration pipeline forwarded user-controlled input to
#' \code{template_path}. See ADR-003 for the warning-blind-clinical-reader
#' risk model that drove this default.
#'
#' \strong{Never} forward user-supplied input (Shiny inputs,
#' query parameters, untrusted uploads) to either parameter -- doing so
#' creates a privilege-escalation vector. If your application surface
#' needs to expose template customization to end users, validate against
#' a fixed allow-list of approved templates and callbacks before invoking
#' \code{bfh_export_pdf()}.
#'
#' A runtime heuristic warns when \code{inject_assets} originates from
#' \code{.GlobalEnv} or a direct child environment (typical of
#' accidental Shiny exposure). Suppress with
#' \code{options(BFHcharts.allow_globalenv_inject = TRUE)} in development.
#'
#' The same trust requirement applies to \code{inject_assets} when passed
#' to \code{\link{bfh_create_export_session}()}.
#'
#' \strong{Recommended: companion package for proprietary branding.}
#' Organizations deploying BFHcharts-based applications that need consistent
#' proprietary branding (custom fonts, hospital logos) should distribute those
#' assets via a private companion R package. The companion package exposes a
#' single function compatible with \code{inject_assets}, e.g.
#' \code{inject_bfh_assets(template_dir)}. Consumer applications then call
#' \code{bfh_export_pdf(..., inject_assets = MyAssetsPkg::inject_bfh_assets)}.
#' This keeps proprietary assets out of public BFHcharts distribution while
#' preserving full branding in production. The companion package is still
#' subject to the trusted-code-only contract above. For the BFH/Region
#' Hovedstaden reference deployment, the \code{BFHchartsAssets} private
#' companion package implements this pattern. See
#' \code{vignette("organizational-deployments")} (when available) or the
#' BFHchartsAssets repository documentation.
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
                           restrict_template = TRUE,
                           auto_analysis = FALSE,
                           use_ai = FALSE,
                           data_consent = NULL,
                           use_rag = FALSE,
                           analysis_min_chars = 300,
                           analysis_max_chars = 375,
                           dpi = 150,
                           font_path = NULL,
                           ignore_system_fonts = TRUE,
                           inject_assets = NULL,
                           batch_session = NULL,
                           strict_baseline) {
  # strict_baseline: per-call > session > default(TRUE).
  # missing()-flag fanges FOERST i orchestrator-scopet (NSE-sensitive).
  strict_baseline_supplied <- !missing(strict_baseline)

  # ---- 0. restrict_template guard --------------------------------------------
  # Threat model: template_path compiles arbitrary Typst code with the privileges
  # of the calling R session (equivalent to source()). When restrict_template=TRUE,
  # only the packaged template is allowed, preventing custom-template injection
  # from untrusted Shiny inputs or API parameters.
  if (isTRUE(restrict_template) && !is.null(template_path)) {
    stop(
      "template_path is not allowed when restrict_template = TRUE. ",
      "Only the packaged BFHcharts template may be used in this configuration.",
      call. = FALSE
    )
  }

  # ---- 1. Input-validering (class, metadata, dpi, font_path, session) --------
  validate_bfh_export_pdf_inputs(
    x, output, metadata, dpi, font_path, inject_assets, batch_session, template_path
  )

  # ---- 1a. Runtime security guard for inject_assets --------------------------
  .validate_inject_assets(inject_assets)

  # ---- 1b. Resolv strict_baseline + valider strict-mode --------------------
  if (!strict_baseline_supplied) {
    strict_baseline <- if (!is.null(batch_session) &&
      !is.null(batch_session$strict_baseline)) {
      batch_session$strict_baseline
    } else {
      TRUE
    }
  }
  if (!is.logical(strict_baseline) || length(strict_baseline) != 1L ||
    is.na(strict_baseline)) {
    stop("strict_baseline must be TRUE or FALSE", call. = FALSE)
  }
  .validate_strict_baseline(x, strict_baseline)

  # ---- 2. Metadata (auto-analysis + auto-details) ----------------------------
  metadata <- prepare_export_metadata(
    x, metadata, auto_analysis, use_ai, analysis_min_chars, analysis_max_chars,
    data_consent = data_consent, use_rag = use_rag
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
    # Single-call mode: clean up the entire temp_dir
    # Registered after dir.create() -- prepare_temp_workspace() has
    # already created the directory, so we register here to catch errors in step 6+
    on.exit(unlink(temp_dir, recursive = TRUE), add = TRUE)
  }

  # ---- 6. Plot-forberedelse (title strip + label recalc + margin) ------------
  plot_for_export <- prepare_export_plot(x)

  # ---- 7. SVG-eksport --------------------------------------------------------
  export_chart_svg(plot_for_export, chart_svg, dpi)

  # ---- 8. SPC-statistik -------------------------------------------------------
  spc_stats <- bfh_extract_spc_stats(x)

  # ---- 9. Typst document + font_path resolution ------------------------------
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

  # Beregn label_size: brug eksplicit vaerdi eller resolve fra target-dimensioner
  new_label_size <- label_size %||% resolve_label_size(
    target_width_inches, target_height_inches
  )

  # Re-add labels with TARGET dimensions for positioning
  # and fixed PDF_LABEL_SIZE for font sizing
  # Se .muffle_expected_warnings() helper for hvilke warnings der mufles.
  # centerline_value, has_frys_column, has_skift_column laeses fra top-niveau
  # config fields (single source of truth -- see build_bfh_qic_config()).
  plot_with_labels <- .muffle_expected_warnings(
    add_spc_labels(
      plot = plot_stripped,
      qic_data = x$qic_data,
      y_axis_unit = config$y_axis_unit %||% "count",
      label_size = new_label_size,
      viewport_width = target_width_inches,
      viewport_height = target_height_inches,
      target_text = config$target_text,
      centerline_value = config$cl,
      has_frys_column = !is.null(config$freeze),
      has_skift_column = !is.null(config$part),
      verbose = FALSE,
      language = config$language %||% "da"
    )
  )

  return(plot_with_labels)
}


# ============================================================================
# INJECT_ASSETS RUNTIME GUARD
# ============================================================================

# Validate inject_assets argument: must be NULL or a function from a trusted
# namespace. Errors (does not warn) when the function environment indicates it
# originates from .GlobalEnv or a direct child, which prevents accidental
# privilege-escalation vectors in Shiny apps (e.g. a reactive binding a
# top-level helper to inject_assets).
#
# Threat model: inject_assets executes arbitrary code with the privileges of the
# calling R session. Accepting functions from .GlobalEnv creates an
# easy-to-trigger RCE vector when the Shiny input pipeline is compromised.
# Requiring a package namespace enforces that the function is version-controlled
# and reviewed code, not an ad-hoc closure assembled at runtime.
#
# Suppress with options(BFHcharts.allow_globalenv_inject = TRUE) in dev flows
# where functions are defined interactively.
#
# @param fn The inject_assets argument (NULL or function).
# @param allowed_namespaces Character vector of package namespaces allowed as
#   the top-level environment. Defaults to BFHcharts and biSPCharts.
# @return fn invisibly.
# @noRd
.validate_inject_assets <- function(
  fn,
  allowed_namespaces = c("BFHcharts", "biSPCharts")
) {
  if (is.null(fn)) {
    return(invisible(NULL))
  }
  if (!is.function(fn)) {
    stop("inject_assets must be a function or NULL", call. = FALSE)
  }

  if (!isTRUE(getOption(BFHCHARTS_OPT_ALLOW_GLOBALENV_INJECT, default = FALSE))) {
    fn_env <- environment(fn)
    # Primitives have NULL environment; treat as trusted (they are base R builtins).
    if (!is.null(fn_env)) {
      top_name <- environmentName(topenv(fn_env))
      if (!top_name %in% allowed_namespaces) {
        stop(
          "inject_assets must come from a trusted package namespace ",
          "(e.g., MyOrgAssets::inject_my_assets), not from '", top_name, "'. ",
          "Accepting functions from arbitrary environments is a privilege-escalation ",
          "risk in production. If this is intentional in development, suppress with ",
          "options(BFHcharts.allow_globalenv_inject = TRUE).",
          call. = FALSE
        )
      }
    }
  }

  invisible(fn)
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
