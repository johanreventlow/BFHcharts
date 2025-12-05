# BFHcharts PDF Export Demo - AI-Assisteret SPC Analyse (v0.6.0)
# Demonstrerer automatisk analyse-generering med BFHcharts og BFHllm

# Load packages
devtools::load_all()

library(BFHllm)
library(tidyverse)

dat <- readr::read_csv2("inst/extdata/spc_exampledata_utf8.csv") |> janitor::clean_names() |> 
  mutate(dato = dmy(dato))

# =============================================================================
# OPRET RUN CHART
# =============================================================================

result <-
  bfh_qic(
  data = dat,
  x = dato,
  y = taeller,
  n = naevner,
  target_value = 0.95,
  chart_type = "run",
  y_axis_unit = "percent",
  ylab = "Procent",
  # xlab = "Måned",
  chart_title = "Andel FMK ajourført til tiden efter indlæggelse"
) 

# result$plot <- result$plot +
#   ggplot2::theme(#plot.margin = ggplot2::margin(5, 5, 5, 5, "mm"),
#     plot.background = element_rect(fill = "red")
#                  )

# Vis chart i viewer (interaktiv mode)
if (interactive()) {
  print(result)
}


# =============================================================================
# DEMO 1: AUTOMATISK ANALYSE (NEMMESTE MÅDE)
# =============================================================================
result |>
  bfh_export_pdf(
    output = "FMK_analyse.pdf",
    metadata = list(
      hospital = "Bispebjerg og Frederiksberg Hospital",
      department = "Akutafdelingen",
      data_definition = "Andel udskrevne patienter der har fået ajourført deres medicinkort via FMK inden for den aftalte tid ud af alle indlæggelser, hvor medicin er ordineret, udleveret eller administreret. K",
      target = 0.95,  # Mål: max 45 minutter
      author = "Kvalitetsafdelingen",
      footer_content = "Kilde: Sundhedsdatastyrelsen\n**Bemærk:** Data er foreløbige",
      date = Sys.Date()
    ),
    auto_analysis = TRUE,  # ⭐ NY FUNKTION: Automatisk analyse-generering
    use_ai = NULL  # NULL = auto-detect BFHllm (default)
  )

# =============================================================================
# DEMO 2: MANUEL ANALYSE-GENERERING (MERE KONTROL)
# =============================================================================
# 
# analyse_tekst <-
#   bfh_generate_analysis(
#   x = resultat,
#   metadata = list(
#     hospital = "Bispebjerg og Frederiksberg Hospital",
#     department = "Akutmodtagelsen",
#     data_definition = "Andel udskrevne patienter der har fået ajourført deres medicinkort via FMK inden for den aftalte tid",
#     target = 0.99,  # Mål: max 45 minutter
#     author = "Kvalitetsafdelingen",
#     date = Sys.Date()
#   ),
#   use_ai = NULL,  # NULL = auto-detect, TRUE = force AI, FALSE = force standardtekster
#   max_chars = 375
# )
# 
# resultat |>
#   bfh_export_pdf(
#     output = "ventetid_manuel_analyse.pdf",
#     metadata = list(
#       hospital = "Bispebjerg og Frederiksberg Hospital",
#       department = "Akutmodtagelsen",
#       analysis = analyse_tekst,  # Brug pre-genereret analyse
#       data_definition = "Gennemsnitlig ventetid fra ankomst til første lægekontakt, målt ugentligt fra EPJ",
#       author = "Kvalitetsafdelingen",
#       date = Sys.Date()
#     )
#     # auto_analysis = FALSE er default når metadata$analysis er angivet
#   )
# 
# # =============================================================================
# # DEMO 3: FORCE STANDARDTEKSTER (UDEN AI)
# # =============================================================================
# 
# cat("=== DEMO 3: Tvungen brug af standardtekster (uden AI) ===\n\n")
# 
# standardtekst_analyse <- bfh_generate_analysis(
#   x = resultat,
#   metadata = list(
#     data_definition = "Ventetid i minutter",
#     target = 45
#   ),
#   use_ai = FALSE,  # ⭐ Tving brug af danske standardtekster
#   max_chars = 350
# )
# 
# cat("Standardtekst-analyse:\n")
# cat(strrep("─", 70), "\n")
# cat(strwrap(standardtekst_analyse, width = 68, prefix = "│ "), sep = "\n")
# cat(strrep("─", 70), "\n\n")
# 
# resultat |>
#   bfh_export_pdf(
#     output = "ventetid_standardtekst.pdf",
#     metadata = list(
#       hospital = "Bispebjerg og Frederiksberg Hospital",
#       department = "Akutmodtagelsen",
#       data_definition = "Gennemsnitlig ventetid fra ankomst til første lægekontakt, målt ugentligt fra EPJ",
#       author = "Kvalitetsafdelingen"
#     ),
#     auto_analysis = TRUE,
#     use_ai = FALSE  # ⭐ Tving brug af standardtekster
#   )
# 
# cat("✅ PDF eksporteret til: ventetid_standardtekst.pdf\n")
# cat("   (Analyse genereret med danske standardtekster - ingen AI)\n\n")
# 
# # =============================================================================
# # BONUS: PNG EKSPORT (uændret fra før)
# # =============================================================================
# 
# cat("=== BONUS: PNG eksport ===\n\n")
# 
# png_fil <- "ventetid_chart.png"
# 
# resultat |>
#   bfh_export_png(
#     output = png_fil,
#     width_mm = 250,
#     height_mm = 150,
#     dpi = 300
#   )

