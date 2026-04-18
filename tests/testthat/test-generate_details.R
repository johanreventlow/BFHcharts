# Tests for bfh_generate_details() og bfh_extract_spc_stats.bfh_qic_result()

test_that("bfh_generate_details genererer korrekt formateret tekst", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rpois(24, lambda = 50)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i",
                     y_axis_unit = "count")

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

  result <- bfh_qic(data, x = date, y = events, n = total,
                     chart_type = "p", y_axis_unit = "percent")

  details <- bfh_generate_details(result)

  # P-chart skal vise numerator/denominator (fx "10/100")
  expect_true(grepl("/", details))
})

test_that("bfh_generate_details afviser ikke-bfh_qic_result input", {
  expect_error(bfh_generate_details("not a result"),
               "must be a bfh_qic_result")
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
