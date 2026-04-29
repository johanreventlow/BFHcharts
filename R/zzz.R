# nocov start
# Package load hooks
# nocov end

#' Register Proprietary Font Aliases in PostScript/PDF Font Databases
#'
#' BFHtheme bruger Mari-fonts (proprietaere) der eksisterer som screen-fonts
#' men som standard ikke er registreret i R's interne PostScript/PDF
#' font-databaser. Manglende registrering producerer harmlose
#' "font family '...' not found in PostScript font database" warnings fra
#' grid::C_stringMetric font-metric-lookup hver gang ggplot2-grobs renderes
#' under SVG/PDF/PostScript-output (bl.a. ggplot_gtable, geom_text,
#' label-placement-pipelinen i bfh_qic()).
#'
#' Funktionen registrerer Mari og Arial som **Helvetica-aliaser** i
#' \code{grDevices::postscriptFonts()} og \code{grDevices::pdfFonts()} -- men
#' kun hvis de ikke allerede er til stede. Brugere der har konfigureret rigtige
#' Mari-fonts (fx via systemfonts) faar derfor deres eksisterende registrering
#' bevaret.
#'
#' Helvetica-metrics er en sikker fallback: character-width forskellene mellem
#' Mari og Helvetica er smaa nok til at label-placering, target-tekster m.m.
#' fortsat ser korrekt ud. Den fulde rendering er fortsat afhaengig af at den
#' rigtige Mari findes i system-font-DB'en (Typst/PNG/PDF-output via Quarto +
#' \code{font_path}-mekanismen) -- denne registrering er KUN for grid's interne
#' metric-lookup.
#'
#' @keywords internal
#' @noRd
register_bfh_font_aliases <- function() {
  ps_fonts <- tryCatch(grDevices::postscriptFonts(), error = function(e) NULL)
  pdf_fonts <- tryCatch(grDevices::pdfFonts(), error = function(e) NULL)
  if (is.null(ps_fonts) || is.null(pdf_fonts)) {
    return(invisible(FALSE))
  }

  helv_ps <- ps_fonts[["Helvetica"]]
  helv_pdf <- pdf_fonts[["Helvetica"]]
  if (is.null(helv_ps) || is.null(helv_pdf)) {
    return(invisible(FALSE))
  }

  for (fname in c("Mari", "Arial")) {
    if (!fname %in% names(ps_fonts)) {
      tryCatch(
        do.call(
          grDevices::postscriptFonts,
          stats::setNames(list(helv_ps), fname)
        ),
        error = function(e) NULL
      )
    }
    if (!fname %in% names(pdf_fonts)) {
      tryCatch(
        do.call(
          grDevices::pdfFonts,
          stats::setNames(list(helv_pdf), fname)
        ),
        error = function(e) NULL
      )
    }
  }
  invisible(TRUE)
}

# nocov start
.onLoad <- function(libname, pkgname) {
  register_bfh_font_aliases()
}
# nocov end
