# BFHcharts PDF Export Demo - AI-Assisteret SPC Analyse (v0.6.0)
# Demonstrerer automatisk analyse-generering med BFHcharts og BFHllm
#
# Kræver:
# - Quarto CLI >= 1.4.0 (https://quarto.org)
# - BFHllm pakke (valgfri - https://github.com/johanreventlow/BFHllm)
# - GOOGLE_API_KEY eller GEMINI_API_KEY i .Renviron (kun for AI)

# Load packages
devtools::load_all()

# Tjek om BFHllm er installeret
bfhllm_available <- requireNamespace("BFHllm", quietly = TRUE)
if (bfhllm_available) {
  library(BFHllm)
  ai_ready <- BFHllm::bfhllm_chat_available()
  if (ai_ready) {
    cat("✓ BFHllm tilgængelig - AI-analyse aktiveret\n")
  } else {
    cat("⚠ BFHllm installeret, men API key mangler\n")
    cat("  Tilføj GOOGLE_API_KEY eller GEMINI_API_KEY til .Renviron\n")
  }
} else {
  cat("ℹ BFHllm ikke installeret - bruger danske standardtekster\n")
  cat("  Installer med: pak::pkg_install('johanreventlow/BFHllm')\n")
  ai_ready <- FALSE
}

# Tjek om Quarto er tilgængelig
if (!quarto_available()) {
  stop("Quarto CLI ikke fundet eller version < 1.4.0.\n",
       "  Installer fra: https://quarto.org\n",
       "  PDF export kræver Quarto med Typst support.")
}
cat("✓ Quarto tilgængelig - PDF export muligt\n\n")

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
# DEMO 1: AUTOMATISK ANALYSE (NEMMESTE MÅDE)
# =============================================================================

cat("\n=== DEMO 1: Automatisk analyse med auto_analysis = TRUE ===\n\n")

cat("Eksporterer til PDF med automatisk analyse...\n")

# Den simpleste måde: Lad bfh_export_pdf() generere analysen automatisk
resultat |>
  bfh_export_pdf(
    output = "ventetid_auto_analyse.pdf",
    metadata = list(
      hospital = "Bispebjerg og Frederiksberg Hospital",
      department = "Akutmodtagelsen",
      data_definition = "Gennemsnitlig ventetid fra ankomst til første lægekontakt, målt ugentligt fra EPJ",
      target = 45,  # Mål: max 45 minutter
      author = "Kvalitetsafdelingen",
      date = Sys.Date()
    ),
    auto_analysis = TRUE,  # ⭐ NY FUNKTION: Automatisk analyse-generering
    use_ai = NULL  # NULL = auto-detect BFHllm (default)
  )

cat("✅ PDF eksporteret til: ventetid_auto_analyse.pdf\n")
cat("   (Analyse genereret automatisk - AI hvis tilgængelig, ellers standardtekster)\n\n")

# =============================================================================
# DEMO 2: MANUEL ANALYSE-GENERERING (MERE KONTROL)
# =============================================================================

cat("=== DEMO 2: Manuel analyse-generering med bfh_generate_analysis() ===\n\n")

# Generer analyse separat for at se output først
cat("Genererer analyse...\n")

analyse_tekst <- bfh_generate_analysis(
  x = resultat,
  metadata = list(
    data_definition = "Gennemsnitlig ventetid fra ankomst til første lægekontakt, målt ugentligt fra EPJ",
    target = 45
  ),
  use_ai = NULL,  # NULL = auto-detect, TRUE = force AI, FALSE = force standardtekster
  max_chars = 350
)

cat("\nGenereret analyse:\n")
cat(strrep("─", 70), "\n")
cat(strwrap(analyse_tekst, width = 68, prefix = "│ "), sep = "\n")
cat(strrep("─", 70), "\n\n")

# Brug den genererede analyse i PDF
cat("Eksporterer til PDF med manuel analyse...\n")

resultat |>
  bfh_export_pdf(
    output = "ventetid_manuel_analyse.pdf",
    metadata = list(
      hospital = "Bispebjerg og Frederiksberg Hospital",
      department = "Akutmodtagelsen",
      analysis = analyse_tekst,  # Brug pre-genereret analyse
      data_definition = "Gennemsnitlig ventetid fra ankomst til første lægekontakt, målt ugentligt fra EPJ",
      author = "Kvalitetsafdelingen",
      date = Sys.Date()
    )
    # auto_analysis = FALSE er default når metadata$analysis er angivet
  )

cat("✅ PDF eksporteret til: ventetid_manuel_analyse.pdf\n")
cat("   (Analyse genereret manuelt og inkluderet i metadata)\n\n")

# =============================================================================
# DEMO 3: FORCE STANDARDTEKSTER (UDEN AI)
# =============================================================================

cat("=== DEMO 3: Tvungen brug af standardtekster (uden AI) ===\n\n")

standardtekst_analyse <- bfh_generate_analysis(
  x = resultat,
  metadata = list(
    data_definition = "Ventetid i minutter",
    target = 45
  ),
  use_ai = FALSE,  # ⭐ Tving brug af danske standardtekster
  max_chars = 350
)

cat("Standardtekst-analyse:\n")
cat(strrep("─", 70), "\n")
cat(strwrap(standardtekst_analyse, width = 68, prefix = "│ "), sep = "\n")
cat(strrep("─", 70), "\n\n")

resultat |>
  bfh_export_pdf(
    output = "ventetid_standardtekst.pdf",
    metadata = list(
      hospital = "Bispebjerg og Frederiksberg Hospital",
      department = "Akutmodtagelsen",
      data_definition = "Gennemsnitlig ventetid fra ankomst til første lægekontakt, målt ugentligt fra EPJ",
      author = "Kvalitetsafdelingen"
    ),
    auto_analysis = TRUE,
    use_ai = FALSE  # ⭐ Tving brug af standardtekster
  )

cat("✅ PDF eksporteret til: ventetid_standardtekst.pdf\n")
cat("   (Analyse genereret med danske standardtekster - ingen AI)\n\n")

# =============================================================================
# BONUS: PNG EKSPORT (uændret fra før)
# =============================================================================

cat("=== BONUS: PNG eksport ===\n\n")

png_fil <- "ventetid_chart.png"

resultat |>
  bfh_export_png(
    output = png_fil,
    width_mm = 250,
    height_mm = 150,
    dpi = 300
  )

cat("✅ PNG eksporteret til:", normalizePath(png_fil), "\n\n")

# =============================================================================
# SAMMENFATNING
# =============================================================================

cat(strrep("═", 70), "\n")
cat("DEMO FULDFØRT\n")
cat(strrep("═", 70), "\n\n")

cat("Nye funktioner i BFHcharts v0.6.0:\n\n")

cat("1. bfh_generate_analysis()\n")
cat("   - Genererer analyse-tekst automatisk\n")
cat("   - Bruger AI (BFHllm) hvis tilgængelig\n")
cat("   - Falder tilbage til danske standardtekster\n")
cat("   - Parametre: use_ai, max_chars\n\n")

cat("2. bfh_export_pdf() med auto_analysis\n")
cat("   - auto_analysis = TRUE → genererer analyse automatisk\n")
cat("   - use_ai = NULL → auto-detect BFHllm\n")
cat("   - use_ai = FALSE → tving standardtekster\n")
cat("   - Overskriver ALDRIG bruger-angivet metadata$analysis\n\n")

cat("3. Graceful degradation\n")
cat("   - Virker uden BFHllm (bruger standardtekster)\n")
cat("   - Fanger AI-fejl og falder tilbage automatisk\n")
cat("   - Ingen breaking changes - fuld bagudkompatibilitet\n\n")

cat("Oprettede filer:\n")
cat("  • ventetid_auto_analyse.pdf    (automatisk - AI eller standardtekst)\n")
cat("  • ventetid_manuel_analyse.pdf  (pre-genereret analyse)\n")
cat("  • ventetid_standardtekst.pdf   (tvungen standardtekst)\n")
cat("  • ventetid_chart.png           (PNG billede)\n\n")

if (ai_ready) {
  cat("AI-status: ✓ BFHllm aktiveret\n")
  cat("           Alle PDF'er bruger AI-genereret analyse\n")
} else if (bfhllm_available) {
  cat("AI-status: ⚠ BFHllm installeret, men API key mangler\n")
  cat("           Alle PDF'er bruger danske standardtekster\n")
} else {
  cat("AI-status: ℹ BFHllm ikke installeret\n")
  cat("           Alle PDF'er bruger danske standardtekster\n")
}

cat("\nRun chart summary:\n")
print(resultat$summary)

cat("\n", strrep("═", 70), "\n")
