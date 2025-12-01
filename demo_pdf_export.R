# BFHcharts PDF Export Demo
# Demonstrerer run chart og PDF eksport med hospital branding
#
# Kræver: Quarto CLI >= 1.4.0 (https://quarto.org)

# Load package
devtools::load_all()

# Tjek om Quarto er tilgængelig
if (!quarto_available()) {
  stop("Quarto CLI ikke fundet eller version < 1.4.0.\n",
       "  Installer fra: https://quarto.org\n",
       "  PDF export kræver Quarto med Typst support.")
}

cat("Quarto tilgængelig - PDF export muligt\n\n")

# =============================================================================
# EKSEMPEL DATA: Ventetider på akutmodtagelsen
# =============================================================================

set.seed(42)

ventetider <- data.frame(
  uge = seq(as.Date("2024-01-01"), by = "week", length.out = 24),
  minutter = c(
    # Første 12 uger - før forbedringsprojekt
    45, 52, 48, 55, 50, 58, 47, 53, 49, 56, 51, 54,
    # Sidste 12 uger - efter forbedringsprojekt (lavere gennemsnit)
    42, 38, 44, 36, 41, 35, 39, 37, 40, 34, 38, 36
  )
)

# =============================================================================
# OPRET RUN CHART
# =============================================================================

cat("Opretter run chart...\n")

resultat <- bfh_qic(
  data = ventetider,
  x = uge,
  y = minutter,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Ventetid på Akutmodtagelsen",
  notes = c(rep(NA, 11), "Lean projekt startet", rep(NA, 12))
)

# Vis chart i viewer (interaktiv mode)
if (interactive()) {
  print(resultat)
}

# =============================================================================
# EKSPORT TIL PDF
# =============================================================================

cat("Eksporterer til PDF...\n")

# Definer output sti
pdf_fil <- "ventetid_rapport.pdf"

# Eksporter med metadata
resultat |>
  bfh_export_pdf(
    output = pdf_fil,
    metadata = list(
      hospital = "Bispebjerg og Frederiksberg Hospital",
      department = "Akutmodtagelsen",
      analysis = "Lean-projektet har reduceret ventetiden med gennemsnitligt 15 minutter.
                  Forbedringen er statistisk signifikant og vedvarende.",
      data_definition = "Gennemsnitlig ventetid fra ankomst til første lægekontakt,
                         målt ugentligt fra EPJ.",
      author = "Kvalitetsafdelingen",
      date = Sys.Date()
    )
  )

cat("\n✅ PDF eksporteret til:", normalizePath(pdf_fil), "\n")

# =============================================================================
# BONUS: Eksporter også til PNG
# =============================================================================

png_fil <- "ventetid_chart.png"

resultat |>
  bfh_export_png(
    output = png_fil,
    width_mm = 250,
    height_mm = 150,
    dpi = 300
  )

cat("✅ PNG eksporteret til:", normalizePath(png_fil), "\n")

# =============================================================================
# VIS OPSUMMERING
# =============================================================================

cat("\n=== Eksport Fuldført ===\n")
cat("Run chart data:\n")
print(resultat$summary)

cat("\nFiler oprettet:\n")
cat("  - PDF rapport:", pdf_fil, "\n")
cat("  - PNG billede:", png_fil, "\n")
