# BFHcharts PDF Export Demo
# Demonstrerer run chart og PDF eksport med hospital branding
#
# Kræver:
# - Quarto CLI >= 1.4.0 (https://quarto.org)
# - BFHllm pakke (https://github.com/johanreventlow/BFHllm)
# - GOOGLE_API_KEY eller GEMINI_API_KEY i .Renviron

# Load packages
devtools::load_all()

# Tjek om BFHllm er installeret
if (!requireNamespace("BFHllm", quietly = TRUE)) {
  warning(
    "BFHllm ikke installeret - AI-analyse vil blive sprunget over.\n",
    "  Installer med: pak::pkg_install('johanreventlow/BFHllm')"
  )
  use_ai <- FALSE
} else {
  library(BFHllm)
  use_ai <- BFHllm::bfhllm_chat_available()
  if (!use_ai) {
    warning(
      "BFHllm kræver GOOGLE_API_KEY eller GEMINI_API_KEY i .Renviron.\n",
      "  AI-analyse vil blive sprunget over."
    )
  }
}

# Tjek om Quarto er tilgængelig
if (!quarto_available()) {
  stop("Quarto CLI ikke fundet eller version < 1.4.0.\n",
       "  Installer fra: https://quarto.org\n",
       "  PDF export kræver Quarto med Typst support.")
}

cat("Quarto tilgængelig - PDF export muligt\n")
if (use_ai) {
  cat("BFHllm tilgængelig - AI-analyse aktiveret\n")
} else {
  cat("BFHllm ikke tilgængelig - bruger manuel analyse\n")
}
cat("\n")

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
# GENERER AI-ANALYSE (hvis BFHllm tilgængelig)
# =============================================================================

if (use_ai) {
  cat("Genererer AI-analyse med BFHllm...\n")

  # Ekstraher SPC metadata fra resultat
  # BFHcharts returnerer allerede metadata i resultat$summary
  # Vi skal pakke det ind i den struktur BFHllm forventer
  spc_metadata <- list(
    metadata = list(
      chart_type = resultat$config$chart_type,
      n_points = nrow(resultat$qic_data),
      signals_detected = sum(resultat$summary$løbelængde_signal,
                           resultat$summary$sigma_signal,
                           na.rm = TRUE),
      anhoej_rules = list(
        longest_run = resultat$summary$længste_løb,
        n_crossings = resultat$summary$antal_kryds,
        n_crossings_min = resultat$summary$antal_kryds_min
      )
    ),
    qic_data = resultat$qic_data,
    summary = resultat$summary  # Gem også for visning senere
  )

  # Definer kontekst for AI-analysen
  ai_context <- list(
    data_definition = "Gennemsnitlig ventetid fra ankomst til første lægekontakt, målt ugentligt fra EPJ",
    chart_title = "Ventetid på Akutmodtagelsen",
    y_axis_unit = "minutter",
    target_value = 45  # Mål: max 45 minutter ventetid
  )

  # Generer AI-forbedringsforslag baseret på Anhøj-regler
  ai_analyse <- BFHllm::bfhllm_spc_suggestion(
    spc_result = spc_metadata,
    context = ai_context,
    max_chars = 350,
    use_rag = TRUE  # Brug SPC knowledge base
  )

  cat("AI-analyse genereret:\n")
  cat(ai_analyse, "\n\n")
} else {
  # Fallback: Manuel analyse hvis BFHllm ikke tilgængelig
  ai_analyse <- "Lean-projektet har reduceret ventetiden med gennemsnitligt 15 minutter.
                  Forbedringen er statistisk signifikant og vedvarende."
}

# =============================================================================
# EKSPORT TIL PDF
# =============================================================================

cat("Eksporterer til PDF...\n")

# Definer output sti
pdf_fil <- "ventetid_rapport.pdf"

# Eksporter med metadata (inkl. AI-genereret analyse)
resultat |>
  bfh_export_pdf(
    output = pdf_fil,
    metadata = list(
      hospital = "Bispebjerg og Frederiksberg Hospital",
      department = "Akutmodtagelsen",
      analysis = ai_analyse,  # Brug AI-genereret analyse
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

if (use_ai) {
  cat("\nAI-Analyse Input (BFHllm):\n")
  cat("  - Titel:", ai_context$chart_title, "\n")
  cat("  - Data definition:", ai_context$data_definition, "\n")
  cat("  - Anhøj-regler metadata:\n")
  if (!is.null(spc_metadata$summary)) {
    anhoj <- spc_metadata$summary
    cat("    · Centerline:", round(anhoj$centerlinje, 1), "minutter\n")
    cat("    · Længste løb:", anhoj$længste_løb, "/", anhoj$længste_løb_max, "\n")
    cat("    · Antal kryds:", anhoj$antal_kryds, "/", anhoj$antal_kryds_min, "\n")
    cat("    · Løbelængde signal:", anhoj$løbelængde_signal, "\n")
    cat("    · Sigma signal:", anhoj$sigma_signal, "\n")
  }
  cat("\nGenereret AI-analyse:\n")
  cat(strwrap(ai_analyse, width = 70, prefix = "  "), sep = "\n")
  cat("\n")
}

cat("\nRun chart data:\n")
print(resultat$summary)

cat("\nFiler oprettet:\n")
cat("  - PDF rapport:", pdf_fil, "\n")
cat("  - PNG billede:", png_fil, "\n")

if (use_ai) {
  cat("\nBFHllm integration:\n")
  cat("  ✓ AI-analyse inkluderet i PDF\n")
  cat("  ✓ Baseret på Anhøj-regler og SPC knowledge base\n")
  cat("  ✓ Max 350 tegn, dansk, handlingsorienteret\n")
}
