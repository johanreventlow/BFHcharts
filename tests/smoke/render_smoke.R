#!/usr/bin/env Rscript
# =============================================================================
# PDF Smoke Render Script — BFHcharts
# =============================================================================
#
# Kører 1-3 repræsentative bfh_export_pdf()-kald og verificerer at PDF-
# pipelinen (Quarto + Typst) producerer gyldige PDF-filer. Bruges af:
#   - .github/workflows/pdf-smoke.yaml  (PR-blocking CI job)
#   - Lokal udvikling: Rscript tests/smoke/render_smoke.R
#
# Hvad testes:
#   1. p-chart (proportioner) fra eksempeldata i inst/extdata/
#   2. i-chart med metadata (tekst-felter i Typst-template)
#   3. run-chart med target
#
# Hvad testes IKKE:
#   - Visuel korrekthed (kræver Mari-fonts — håndteres af vdiffr)
#   - Tekst-præcision i PDF-output (håndteres af render-tests.yaml)
#
# Font-strategi på CI:
#   Env-var BFHCHARTS_SMOKE_FONT_PATH kan pege på system-font-mappe med
#   åbne fallback-fonts (DejaVu/Liberation/Noto installeret i pdf-smoke.yaml).
#   Smoke-scriptet sætter font_path til denne sti hvis env-var er sat.
#   ignore_system_fonts=TRUE (default i bfh_export_pdf) sikrer at Typst
#   kun bruger de fonts vi eksplicit leverer.
#
# Kilde: openspec/changes/add-pr-blocking-pdf-smoke-render (Task 4)
# =============================================================================

# ---- Setup ------------------------------------------------------------------

# Load pakke
if (!requireNamespace("BFHcharts", quietly = TRUE)) {
  # Kør som script fra package root: load fra kildekode
  pkgload::load_all(".", quiet = TRUE)
} else {
  library(BFHcharts)
}

if (!requireNamespace("pdftools", quietly = TRUE)) {
  stop("pdftools-pakken mangler. Installer med: install.packages('pdftools')", call. = FALSE)
}

# Registrer temp-filer til cleanup
smoke_files <- character(0)
on.exit(
  {
    if (length(smoke_files) > 0) {
      unlink(smoke_files, force = TRUE)
      cat("Smoke filer ryddet op:", length(smoke_files), "filer\n")
    }
  },
  add = TRUE
)

# Hjælpefunktion: verificer PDF-output
check_pdf <- function(path, label) {
  if (!file.exists(path)) {
    stop(sprintf("[SMOKE FAIL] %s: PDF-fil eksisterer ikke: %s", label, path), call. = FALSE)
  }
  fsize <- file.info(path)$size
  if (is.na(fsize) || fsize == 0) {
    stop(sprintf("[SMOKE FAIL] %s: PDF-fil er tom (0 bytes): %s", label, path), call. = FALSE)
  }
  info <- tryCatch(
    pdftools::pdf_info(path),
    error = function(e) {
      stop(sprintf("[SMOKE FAIL] %s: pdftools::pdf_info() fejlede: %s", label, e$message), call. = FALSE)
    }
  )
  npages <- info$pages
  if (is.null(npages) || npages < 1) {
    stop(sprintf("[SMOKE FAIL] %s: PDF har 0 sider: %s", label, path), call. = FALSE)
  }
  cat(sprintf("[SMOKE OK]  %s: %d side(r), %d bytes\n", label, npages, fsize))
  invisible(TRUE)
}

# Font-path: brug åbne fallback-fonts på CI hvis env-var er sat
font_path_override <- Sys.getenv("BFHCHARTS_SMOKE_FONT_PATH", unset = NA_character_)
if (is.na(font_path_override) || !nzchar(font_path_override)) {
  font_path_override <- NULL
}

# ---- Eksempeldata -----------------------------------------------------------
example_csv <- system.file("extdata", "spc_exampledata_utf8.csv", package = "BFHcharts")
if (!nzchar(example_csv) || !file.exists(example_csv)) {
  # Fallback: find fra working directory (ved load_all())
  example_csv <- file.path("inst", "extdata", "spc_exampledata_utf8.csv")
}
if (!file.exists(example_csv)) {
  stop("Kan ikke finde inst/extdata/spc_exampledata_utf8.csv", call. = FALSE)
}

raw_data <- read.csv2(example_csv, encoding = "UTF-8", stringsAsFactors = FALSE)
# Kolonner: Skift, Frys, Dato, Tæller, Nævner, Kommentarer
colnames(raw_data) <- c("skift", "frys", "dato", "taeller", "naevner", "kommentarer")
raw_data$dato <- as.Date(raw_data$dato, format = "%d-%m-%Y")

# ---- Smoke test 1: p-chart fra eksempeldata ---------------------------------
cat("\n--- Smoke 1: p-chart (eksempeldata) ---\n")
tmp1 <- tempfile(pattern = "bfhcharts_smoke_pchart_", fileext = ".pdf")
smoke_files <- c(smoke_files, tmp1)

result1 <- suppressWarnings(
  bfh_qic(
    raw_data,
    x = dato,
    y = taeller,
    n = naevner,
    chart_type = "p",
    y_axis_unit = "percent",
    chart_title = "Smoke: P-chart"
  )
)
bfh_export_pdf(
  result1,
  output = tmp1,
  metadata = list(
    hospital = "Smoke Hospital",
    department = "Smoke Afdeling"
  ),
  font_path = font_path_override
)
check_pdf(tmp1, "Smoke 1 (p-chart)")

# ---- Smoke test 2: i-chart med metadata tekst -------------------------------
cat("\n--- Smoke 2: i-chart med metadata ---\n")
tmp2 <- tempfile(pattern = "bfhcharts_smoke_ichart_", fileext = ".pdf")
smoke_files <- c(smoke_files, tmp2)

set.seed(42)
data2 <- data.frame(
  maaned = seq(as.Date("2023-01-01"), by = "month", length.out = 24),
  vaerdi = c(
    18, 22, 19, 21, 20, 17, 23, 19, 21, 18, 20, 22,
    15, 14, 16, 13, 15, 14, 16, 13, 14, 15, 13, 14
  )
)

result2 <- bfh_qic(
  data2,
  x = maaned,
  y = vaerdi,
  chart_type = "i",
  y_axis_unit = "count",
  chart_title = "Smoke: I-chart"
)
bfh_export_pdf(
  result2,
  output = tmp2,
  metadata = list(
    hospital = "Smoke Hospital",
    department = "Intensiv",
    data_definition = "Antal daglige haendelser",
    analysis = "Signifikant fald efter intervention i mdr 13"
  ),
  font_path = font_path_override
)
check_pdf(tmp2, "Smoke 2 (i-chart med metadata)")

# ---- Smoke test 3: run-chart med target -------------------------------------
cat("\n--- Smoke 3: run-chart med target ---\n")
tmp3 <- tempfile(pattern = "bfhcharts_smoke_runchart_", fileext = ".pdf")
smoke_files <- c(smoke_files, tmp3)

result3 <- bfh_qic(
  data2,
  x = maaned,
  y = vaerdi,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Smoke: Run-chart med target",
  target_value = 16,
  target_text = "Maal: 16"
)
bfh_export_pdf(
  result3,
  output = tmp3,
  metadata = list(
    hospital = "Smoke Hospital",
    department = "Kirurgi"
  ),
  font_path = font_path_override
)
check_pdf(tmp3, "Smoke 3 (run-chart med target)")

# ---- Afslutning -------------------------------------------------------------
cat("\n=== PDF Smoke render OK: 3/3 tests bestod ===\n\n")
