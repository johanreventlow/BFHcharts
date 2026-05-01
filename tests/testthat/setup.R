# ============================================================================
# Test Setup — determinism og miljø-kontrol
# ============================================================================
#
# Kører automatisk før alle tests. Sikrer at tests er reproducerbare på tværs
# af platforme (macOS dev / Ubuntu CI / Windows CI) ved at pin'e:
#   - Locale til C.UTF-8 (undgår dansk vs. engelsk comma separator, månedsnavne)
#   - Timezone til Europe/Copenhagen (undgår dato-skifter omkring midnat)
#   - RNGkind til Mersenne-Twister (undgår R 3.6 → 4.0 sample-kind-skift)
#   - OutDec til "." (konsistent decimal separator ved print)
#
# Reference: openspec/changes/strengthen-test-infrastructure (task 6.1, Fase 2)
# Spec: test-infrastructure, "Test fixtures SHALL be centralized and deterministic"

# Locale: UTF-8 for dansk tegn-håndtering. Fall-back-kæde for platform-forskelle.
# macOS: en_US.UTF-8, Ubuntu: C.UTF-8, Windows: en_US.utf8 / Danish_Denmark.1252
.set_utf8_locale <- function() {
  candidates <- c("C.UTF-8", "en_US.UTF-8", "en_US.utf8", "C")
  for (loc in candidates) {
    res <- tryCatch(
      suppressWarnings(Sys.setlocale("LC_ALL", loc)),
      error = function(e) ""
    )
    if (nzchar(res)) {
      return(invisible(res))
    }
  }
  invisible(NULL)
}
.set_utf8_locale()

# Timezone: alle dato-aware tests skal have samme tidsbånd
Sys.setenv(TZ = "Europe/Copenhagen")

# RNGkind: eksplicit pinning så set.seed() giver samme sekvenser på tværs
# af R-versioner. Default ændrede sig mellem R 3.6 og R 4.0.
suppressWarnings(
  RNGkind(
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
)

# Decimal separator: "." for konsistens (nogle tests kontrollerer print-output)
options(OutDec = ".")

# Collation: "C" sikrer stabil sort-rækkefølge på tværs af miljøer
Sys.setlocale("LC_COLLATE", "C")

# Graphics device: open a persistent null device for the test session so that
# ggplot2/grid rendering (including internal ggplot_gtable calls inside bfh_qic)
# never triggers creation of Rplots.pdf in tests/testthat/.
# withr::defer(expr, envir = teardown_env()) runs cleanup after all tests.
local({
  tmp <- tempfile(fileext = ".pdf")
  tryCatch(
    {
      grDevices::pdf(tmp, width = 7, height = 5)
      dev_id <- grDevices::dev.cur()
      withr::defer(
        {
          tryCatch(grDevices::dev.off(dev_id), error = function(e) NULL)
          unlink(tmp)
        },
        envir = teardown_env()
      )
    },
    error = function(e) NULL
  )
})

# Registrer proprietære fonts som aliaser i PostScript- og PDF-font-databaser.
# BFHtheme bruger Mari-fonts der eksisterer som screen-fonts men ikke er
# registreret i R's interne font-databaser. Manglende registrering giver
# ~1600 harmlose "font family '...' not found in PostScript font database"
# warnings per full test-kørsel (fra grid::C_stringMetric font-metric-lookup).
# Mapping til Helvetica giver korrekte metrics under SVG/PDF-rendering.
#
# Font-sæt matcher zzz.R register_bfh_font_aliases() + CI fallback-sti:
#   - Lokal (Mari installeret): zzz.R registrerer ved package-load, setup.R
#     supplerer Roboto der kan mangle i R-intern database selv når screen-font findes
#   - CI (ingen Mari): liberation/dejavu installeret via apt-get i R-CMD-check.yaml;
#     Helvetica-alias sikrer grid-metric-lookup ikke kaster warnings
local({
  ps_fonts <- grDevices::postscriptFonts()
  pdf_fonts <- grDevices::pdfFonts()
  helv_ps <- ps_fonts[["Helvetica"]]
  helv_pdf <- pdf_fonts[["Helvetica"]]
  # Synkroniseret med zzz.R register_bfh_font_aliases() — Mari/Arial/Roboto
  for (fname in c("Mari", "Arial", "Roboto")) {
    if (!fname %in% names(ps_fonts)) {
      tryCatch(
        do.call(grDevices::postscriptFonts, setNames(list(helv_ps), fname)),
        error = function(e) NULL
      )
    }
    if (!fname %in% names(pdf_fonts)) {
      tryCatch(
        do.call(grDevices::pdfFonts, setNames(list(helv_pdf), fname)),
        error = function(e) NULL
      )
    }
  }
})
