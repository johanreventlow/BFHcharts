# Tests for bfh_generate_details() og bfh_extract_spc_stats.bfh_qic_result()

test_that("bfh_generate_details genererer korrekt formateret tekst", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rpois(24, lambda = 50)
  )

  result <- bfh_qic(data,
    x = date, y = value, chart_type = "i",
    y_axis_unit = "count"
  )

  details <- bfh_generate_details(result)

  expect_type(details, "character")
  expect_gt(nchar(details), 0)
  # Skal indeholde periodeinfo
  expect_true(grepl("Periode:", details))
  # Skal indeholde gennemsnit
  expect_true(grepl("Gns\\.", details))
  # Skal indeholde seneste
  expect_true(grepl("Seneste", details))
  # Skal indeholde niveau
  expect_true(grepl("Nuv\u00e6rende niveau:", details))
  # Separator er bullet
  expect_true(grepl("\u2022", details))
})

test_that("bfh_generate_details viser numerator/denominator for p-chart", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    events = rpois(24, lambda = 10),
    total = rpois(24, lambda = 100)
  )

  result <- bfh_qic(data,
    x = date, y = events, n = total,
    chart_type = "p", y_axis_unit = "percent"
  )

  details <- bfh_generate_details(result)

  # P-chart skal vise numerator/denominator (fx "10/100")
  expect_true(grepl("/", details))
})

test_that("bfh_generate_details afviser ikke-bfh_qic_result input", {
  expect_error(
    bfh_generate_details("not a result"),
    "must be a bfh_qic_result"
  )
})

test_that("bfh_generate_details bruger dansk datoformatering", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rpois(12, lambda = 50)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i")

  details <- bfh_generate_details(result)

  # Skal indeholde en-dash mellem datoer
  expect_true(grepl("\u2013", details))
})

# =============================================================================
# bfh_generate_details: x-range validering (edge cases)
# =============================================================================

# Hjælpefunktion: byg et minimalt bfh_qic_result med styret x-kolonne
make_result_with_x <- function(x_col) {
  n <- length(x_col)
  # Tomme vektorer kræver separat håndtering — data.frame() tillader 0-rækker
  qic_data <- if (n == 0L) {
    data.frame(
      x            = x_col,
      y            = numeric(0),
      cl           = numeric(0),
      sigma.signal = logical(0)
    )
  } else {
    data.frame(
      x            = x_col,
      y            = seq_len(n),
      cl           = rep(0, n),
      sigma.signal = rep(FALSE, n)
    )
  }
  structure(
    list(
      plot = ggplot2::ggplot(),
      summary = data.frame(
        længste_løb = 3L,
        længste_løb_max = 7L,
        antal_kryds = 6L,
        antal_kryds_min = 4L,
        centerlinje = 0
      ),
      qic_data = qic_data,
      config = list(chart_type = "i", y_axis_unit = "count")
    ),
    class = c("bfh_qic_result", "list")
  )
}

test_that("bfh_generate_details fejler ved tom numerisk x (numeric(0))", {
  result <- make_result_with_x(numeric(0))
  # Forventer bfhcharts_config_error med beskrivende besked
  expect_error(
    bfh_generate_details(result),
    "no finite/non-NA values",
    class = "bfhcharts_config_error"
  )
})

test_that("bfh_generate_details fejler ved tom dato-x (as.Date(character(0)))", {
  result <- make_result_with_x(as.Date(character(0)))
  expect_error(
    bfh_generate_details(result),
    "no finite/non-NA values",
    class = "bfhcharts_config_error"
  )
})

test_that("bfh_generate_details fejler ved alle-NA numerisk x", {
  result <- make_result_with_x(c(NA_real_, NA_real_, NA_real_))
  expect_error(
    bfh_generate_details(result),
    "no finite/non-NA values",
    class = "bfhcharts_config_error"
  )
})

test_that("bfh_generate_details fejler ved mix af NA og Inf i numerisk x", {
  # Inf er ikke finit — fortolkes som ugyldig x-vaerdi
  result <- make_result_with_x(c(NA_real_, NA_real_, Inf))
  expect_error(
    bfh_generate_details(result),
    "no finite/non-NA values",
    class = "bfhcharts_config_error"
  )
})

test_that("bfh_generate_details succeeds med enkelt ikke-NA Date i overvejende NA vektor", {
  x_col <- as.Date(c(NA, NA, "2025-01-01", NA))
  result <- make_result_with_x(x_col)
  details <- bfh_generate_details(result)
  # Periode-range skal vaere den ene gyldige dato (start = slut)
  expect_type(details, "character")
  expect_true(grepl("Periode:", details))
  expect_true(grepl("jan\\. 2025", details))
})

test_that("bfh_generate_details gyldig datoaraekke: uaendret baseline (regression)", {
  set.seed(42)
  data <- data.frame(
    date  = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rpois(12, lambda = 50)
  )
  result <- bfh_qic(data, x = date, y = value, chart_type = "i", y_axis_unit = "count")
  details <- bfh_generate_details(result)
  expect_type(details, "character")
  expect_true(grepl("Periode:", details))
  expect_true(grepl("Gns\\.", details))
  expect_true(grepl("Seneste", details))
  expect_true(grepl("Nuværende niveau:", details))
})

test_that("bfh_export_pdf med tom data propagerer bfhcharts_config_error fra generate_details", {
  skip_if_no_quarto()

  # Opret et result-objekt med alle-NA x (simulerer tomt/ugyldig batch-frame)
  result_invalid <- make_result_with_x(as.Date(c(NA_character_, NA_character_)))
  tmp <- withr::local_tempfile(fileext = ".pdf")

  expect_error(
    bfh_export_pdf(result_invalid, tmp),
    "no finite/non-NA values",
    class = "bfhcharts_config_error"
  )
  # Ingen lækket temp-fil (tmp maa ikke vaere oprettet af export-funktionen)
  expect_false(file.exists(tmp))
})

# =============================================================================
# bfh_extract_spc_stats.bfh_qic_result (tidligere extract_spc_stats_extended)
# =============================================================================

test_that("bfh_extract_spc_stats(bfh_qic_result) returnerer korrekt struktur for i-chart", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 50, sd = 5)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i")
  stats <- bfh_extract_spc_stats(result)

  expect_type(stats, "list")
  expect_true("runs_expected" %in% names(stats))
  expect_true("runs_actual" %in% names(stats))
  expect_true("crossings_expected" %in% names(stats))
  expect_true("crossings_actual" %in% names(stats))
  expect_true("outliers_expected" %in% names(stats))
  expect_true("outliers_actual" %in% names(stats))
  expect_true("outliers_recent_count" %in% names(stats))
  expect_true("is_run_chart" %in% names(stats))
  expect_false(stats$is_run_chart)
})

test_that("bfh_extract_spc_stats(bfh_qic_result) markerer run chart korrekt", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 50, sd = 5)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "run")
  stats <- bfh_extract_spc_stats(result)

  expect_true(stats$is_run_chart)
  # Run charts har ikke outlier-data
  expect_null(stats$outliers_expected)
  expect_null(stats$outliers_actual)
  expect_null(stats$outliers_recent_count)
})

test_that("bfh_extract_spc_stats(bfh_qic_result) håndterer NULL summary", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 50, sd = 5)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i")
  # Simuler manglende summary
  result$summary <- NULL

  stats <- bfh_extract_spc_stats(result)

  # Skal stadig returnere en liste (outliers kan dog stadig udtrækkes fra qic_data)
  expect_type(stats, "list")
  expect_null(stats$runs_expected)
  expect_false(is.null(stats$outliers_actual))
})
