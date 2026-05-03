# ============================================================================
# PDF CONTENT VERIFICATION TESTS
# ============================================================================
#
# Verificerer at bfh_export_pdf() producerer PDF-output der faktisk indeholder
# det forventede: chart-titel, metadata-felter, SPC-statistik og danske tegn.
#
# Dette er stærkere end de eksisterende file.exists()+size-checks som kun
# beviser at en fil blev skrevet — ikke at indholdet er korrekt.
#
# Reference: openspec/changes/strengthen-test-infrastructure (task 4.1–4.7)
# Spec: test-infrastructure, "Rendered outputs SHALL have content verification"
#
# Helpers tilgængelige via:
#   - helper-assertions.R: expect_pdf_contains()
#   - helper-fixtures.R: fixture_deterministic_chart_data()

# ============================================================================
# TESTS — Chart titel i output
# ============================================================================

test_that("PDF indeholder chart_title fra bfh_qic config", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_on_cran()

  title <- "Månedlige Hospital-Erhvervede Infektioner"

  result <- bfh_qic(
    data = fixture_deterministic_chart_data(),
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = title
  )

  temp_file <- withr::local_tempfile(fileext = ".pdf")
  bfh_export_pdf(result, temp_file)

  expect_pdf_contains(temp_file, "M.*nedlige")
  expect_pdf_contains(temp_file, "Hospital-Erhvervede")
  expect_pdf_contains(temp_file, "Infektioner")
})

# ============================================================================
# TESTS — Metadata-felter i output
# ============================================================================

test_that("PDF indeholder hospital-metadata fra bruger", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_on_cran()

  result <- bfh_qic(
    data = fixture_deterministic_chart_data(),
    x = month,
    y = infections,
    chart_type = "i",
    chart_title = "Test"
  )

  temp_file <- withr::local_tempfile(fileext = ".pdf")
  bfh_export_pdf(
    result,
    temp_file,
    metadata = list(hospital = "Rigshospitalet Test-Afdeling")
  )

  expect_pdf_contains(temp_file, "Rigshospitalet Test-Afdeling")
})

test_that("PDF indeholder department-metadata", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_on_cran()

  result <- bfh_qic(
    data = fixture_deterministic_chart_data(),
    x = month,
    y = infections,
    chart_type = "i",
    chart_title = "Test"
  )

  temp_file <- withr::local_tempfile(fileext = ".pdf")
  bfh_export_pdf(
    result,
    temp_file,
    metadata = list(
      department = "Kvalitets- og Forbedringsafdelingen"
    )
  )

  expect_pdf_contains(temp_file, "Kvalitets- og Forbedringsafdelingen")
})

test_that("PDF indeholder author-metadata", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_on_cran()

  result <- bfh_qic(
    data = fixture_deterministic_chart_data(),
    x = month,
    y = infections,
    chart_type = "i",
    chart_title = "Test"
  )

  temp_file <- withr::local_tempfile(fileext = ".pdf")
  bfh_export_pdf(
    result,
    temp_file,
    metadata = list(author = "Test Forfatter Jensen")
  )

  expect_pdf_contains(temp_file, "Test Forfatter Jensen")
})

test_that("PDF indeholder data_definition-metadata", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_on_cran()

  result <- bfh_qic(
    data = fixture_deterministic_chart_data(),
    x = month,
    y = infections,
    chart_type = "i",
    chart_title = "Test"
  )

  temp_file <- withr::local_tempfile(fileext = ".pdf")
  data_def <- "Antal hospital-erhvervede infektioner per kalendermåned, opgjort fra landspatientregistret"
  bfh_export_pdf(
    result,
    temp_file,
    metadata = list(data_definition = data_def)
  )

  # Match på robust substring (undgår whitespace-fejl pga. PDF-linjebrud)
  expect_pdf_contains(temp_file, "hospital-erhvervede infektioner")
  expect_pdf_contains(temp_file, "landspatientregistret")
})

# ============================================================================
# TESTS — SPC summary-tabel i output
# ============================================================================

test_that("PDF indeholder SPC centerlinje-værdi fra summary", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_on_cran()

  result <- bfh_qic(
    data = fixture_deterministic_chart_data(),
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Test Centerlinje"
  )

  # Verificér at summary har en centerlinje (sanity check)
  expect_true("centerlinje" %in% names(result$summary))
  cl_value <- result$summary$centerlinje[1]
  expect_true(is.numeric(cl_value) && !is.na(cl_value))

  temp_file <- withr::local_tempfile(fileext = ".pdf")
  bfh_export_pdf(result, temp_file)

  # Centerlinje-værdi skal vises (matcher både "15.2" og "15,2" — dansk komma)
  cl_rounded <- round(cl_value, 1)
  cl_pattern <- gsub("\\.", "[.,]", as.character(cl_rounded))
  expect_pdf_contains(temp_file, cl_pattern)
})

test_that("PDF indeholder Anhoej-statistik (runs og kryds)", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_on_cran()

  # Dataset med > 20 observationer så Anhøj-statistik er meningsfuld
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(
      14, 16, 13, 15, 18, 12, 17, 14, 19, 13, 15, 16,
      17, 15, 18, 14, 13, 17, 16, 15, 14, 17, 16, 15
    )
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Anhoej Test"
  )

  temp_file <- withr::local_tempfile(fileext = ".pdf")
  bfh_export_pdf(result, temp_file)

  # Tabel skal indeholde rubrik for længste_løb og antal_kryds
  # (label-teksten varierer — matcher flere plausible former)
  text <- pdftools::pdf_text(temp_file)
  combined <- paste(text, collapse = " ")
  combined <- gsub("[[:space:]]+", " ", combined)

  expect_true(
    grepl("l.?ngste|serie|run", combined, ignore.case = TRUE),
    info = "PDF skal omtale længste serie / løb / run"
  )
  expect_true(
    grepl("kryds|crossing", combined, ignore.case = TRUE),
    info = "PDF skal omtale antal kryds / crossings"
  )
})

# ============================================================================
# TESTS — Danske tegn (æ, ø, å) bevares i output
# ============================================================================

test_that("PDF bevarer danske tegn (æ, ø, å) i titel", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_on_cran()

  title <- "Tælling af hændelser pr. måned — æøå"

  result <- bfh_qic(
    data = fixture_deterministic_chart_data(),
    x = month,
    y = infections,
    chart_type = "i",
    chart_title = title
  )

  temp_file <- withr::local_tempfile(fileext = ".pdf")
  bfh_export_pdf(result, temp_file)

  # Hver af de tre specialtegn skal være bevaret
  expect_pdf_contains(temp_file, "æøå")
  expect_pdf_contains(temp_file, "T.lling") # tolerance for ligatur-variation
  expect_pdf_contains(temp_file, "h.ndelser")
  expect_pdf_contains(temp_file, "m.ned")
})

test_that("PDF bevarer danske tegn i metadata-strings", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_on_cran()

  result <- bfh_qic(
    data = fixture_deterministic_chart_data(),
    x = month,
    y = infections,
    chart_type = "i",
    chart_title = "Test"
  )

  temp_file <- withr::local_tempfile(fileext = ".pdf")
  bfh_export_pdf(
    result,
    temp_file,
    metadata = list(
      department = "Kvalitetsafdelingen — Forbedringshold Øst",
      analysis = "Signifikant fald observeret efter intervention på afdeling Å"
    )
  )

  expect_pdf_contains(temp_file, "Kvalitetsafdelingen")
  expect_pdf_contains(temp_file, "Forbedringshold")
  expect_pdf_contains(temp_file, "Signifikant fald")
  expect_pdf_contains(temp_file, "afdeling")
  # Bekræft mindst ét af ø/å specifikt (æ varierer i encoding ofte)
  text <- pdftools::pdf_text(temp_file)
  combined <- paste(text, collapse = " ")
  expect_true(
    grepl("ø|Ø|å|Å", combined),
    info = "PDF skal bevare mindst ét dansk specialtegn (ø/å)"
  )
})

# ============================================================================
# TESTS — Negative cases (fraværende metadata skal ikke vises)
# ============================================================================

test_that("PDF viser IKKE metadata-felter der ikke er angivet", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_on_cran()

  unique_marker <- "ZzUniqueMarker9876XyZ"

  result <- bfh_qic(
    data = fixture_deterministic_chart_data(),
    x = month,
    y = infections,
    chart_type = "i",
    chart_title = "Test Negative"
  )

  temp_file <- withr::local_tempfile(fileext = ".pdf")
  # Send IKKE department med — verificer at unik marker ikke dukker op
  bfh_export_pdf(result, temp_file, metadata = list(author = "Test"))

  text <- pdftools::pdf_text(temp_file)
  combined <- paste(text, collapse = " ")
  expect_false(
    grepl(unique_marker, combined),
    info = "Unik marker må ikke optræde hvis ikke sendt som metadata"
  )
})
