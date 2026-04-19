# Tests for format_qic_summary()
# Verificerer at BFHcharts korrekt formaterer qicharts2-output til dansk
#
# Fixture: fixture_qicharts_summary_data() er tilgængelig via helper-fixtures.R.

# =============================================================================
# BASIC FUNCTIONALITY
# =============================================================================

test_that("format_qic_summary returnerer data frame med danske kolonnenavne", {
  qic_data <- fixture_qicharts_summary_data()
  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  expect_s3_class(result, "data.frame")
  expect_true("fase" %in% names(result))
  expect_true("antal_observationer" %in% names(result))
  expect_true("anvendelige_observationer" %in% names(result))
  expect_true("længste_løb" %in% names(result))
  expect_true("længste_løb_max" %in% names(result))
  expect_true("antal_kryds" %in% names(result))
  expect_true("antal_kryds_min" %in% names(result))
  expect_true("løbelængde_signal" %in% names(result))
  expect_true("centerlinje" %in% names(result))
})

test_that("format_qic_summary returnerer korrekte typer", {
  qic_data <- fixture_qicharts_summary_data()
  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  expect_type(result$fase, "integer")
  expect_type(result$antal_observationer, "integer")
  expect_type(result$længste_løb, "integer")
  expect_type(result$løbelængde_signal, "logical")
  expect_type(result$centerlinje, "double")
})

test_that("format_qic_summary afviser ikke-data.frame input", {
  expect_error(format_qic_summary("not a df"), "must be a data frame")
  expect_error(format_qic_summary(42), "must be a data frame")
})

# =============================================================================
# MULTI-FASE HÅNDTERING
# =============================================================================

test_that("format_qic_summary håndterer multi-fase data korrekt", {
  qic_data <- fixture_qicharts_summary_data(n = 24, parts = 2)
  # Giv del 2 andre værdier
  qic_data$cl[13:24] <- 55
  qic_data$longest.run[13:24] <- 6L
  qic_data$n.crossings[13:24] <- 10L

  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  expect_equal(nrow(result), 2)
  expect_equal(result$fase, c(1L, 2L))
  # Centerlinje skal afspejle per-fase værdier
  expect_equal(result$centerlinje[1], 50, tolerance = 0.1)
  expect_equal(result$centerlinje[2], 55, tolerance = 0.1)
})

test_that("format_qic_summary aggregerer Anhøj-stats per part", {
  qic_data <- fixture_qicharts_summary_data(n = 24, parts = 2)
  # Sæt forskellige longest.run i de to faser
  qic_data$longest.run[1:12] <- 3L
  qic_data$longest.run[13:24] <- 7L

  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  # safe_max per part — skal give max per fase
  expect_equal(result$længste_løb[1], 3L)
  expect_equal(result$længste_løb[2], 7L)
})

test_that("format_qic_summary kombinerer signals korrekt med any()", {
  qic_data <- fixture_qicharts_summary_data(n = 24, parts = 2, add_signals = TRUE)

  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  # Fase 1 har signals, fase 2 har ikke
  expect_true(result$løbelængde_signal[1])
  expect_false(result$løbelængde_signal[2])
})

test_that("format_qic_summary inkluderer aggregerede outlier-kolonner per fase", {
  qic_data <- fixture_qicharts_summary_data(n = 24, parts = 2)
  qic_data$sigma.signal[c(2, 14, 15)] <- TRUE

  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  expect_true("forventede_outliers" %in% names(result))
  expect_true("antal_outliers" %in% names(result))
  expect_equal(result$forventede_outliers, c(0L, 0L))
  expect_equal(result$antal_outliers, c(1L, 2L))
})

# =============================================================================
# AFRUNDING OG UNIT-SPECIFIK FORMATERING
# =============================================================================

test_that("format_qic_summary runder korrekt for percent", {
  qic_data <- fixture_qicharts_summary_data()
  qic_data$cl <- rep(0.6789, 24)
  result <- format_qic_summary(qic_data, y_axis_unit = "percent")

  # percent = 2 decimaler
  expect_equal(result$centerlinje, 0.68)
})

test_that("format_qic_summary runder korrekt for count", {
  qic_data <- fixture_qicharts_summary_data()
  qic_data$cl <- rep(50.456, 24)
  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  # count = 1 decimal
  expect_equal(result$centerlinje, 50.5)
})

test_that("format_qic_summary runder korrekt for rate", {
  qic_data <- fixture_qicharts_summary_data()
  qic_data$cl <- rep(12.345, 24)
  result <- format_qic_summary(qic_data, y_axis_unit = "rate")

  # rate = 2 decimaler
  expect_equal(result$centerlinje, 12.35)
})

# =============================================================================
# VARIABLE KONTROLGRÆNSER (P/U-CHARTS)
# =============================================================================

test_that("format_qic_summary inkluderer kontrolgrænser ved konstante grænser", {
  qic_data <- fixture_qicharts_summary_data()
  # Konstante grænser (I-chart)
  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  expect_true("nedre_kontrolgrænse" %in% names(result))
  expect_true("øvre_kontrolgrænse" %in% names(result))
})

test_that("format_qic_summary ekskluderer kontrolgrænser ved variable grænser", {
  qic_data <- fixture_qicharts_summary_data()
  # Simuler variable grænser (som p/u-charts har)
  qic_data$lcl <- seq(30, 40, length.out = 24)
  qic_data$ucl <- seq(60, 70, length.out = 24)

  result <- format_qic_summary(qic_data, y_axis_unit = "percent")

  # Variable grænser skal udelades (misvisende at vise én værdi)
  expect_false("nedre_kontrolgrænse" %in% names(result))
  expect_false("øvre_kontrolgrænse" %in% names(result))
})

# =============================================================================
# RUN CHARTS (INGEN LCL/UCL)
# =============================================================================

test_that("format_qic_summary håndterer run chart uden lcl/ucl", {
  qic_data <- fixture_qicharts_summary_data()
  qic_data$lcl <- NULL
  qic_data$ucl <- NULL

  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  expect_false("nedre_kontrolgrænse" %in% names(result))
  expect_false("øvre_kontrolgrænse" %in% names(result))
  # Men centerlinje skal stadig være der
  expect_true("centerlinje" %in% names(result))
})

# =============================================================================
# EDGE CASES
# =============================================================================

test_that("format_qic_summary håndterer NA i Anhøj-stats", {
  qic_data <- fixture_qicharts_summary_data()
  qic_data$longest.run <- NA_integer_
  qic_data$n.crossings <- NA_integer_

  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  # safe_max af alle NAs → NA_real_, som as.integer → NA_integer_
  expect_true(is.na(result$længste_løb))
  expect_true(is.na(result$antal_kryds))
})

test_that("format_qic_summary håndterer single-row data", {
  qic_data <- fixture_qicharts_summary_data(n = 24)
  # Kun én unik part
  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  expect_equal(nrow(result), 1)
})
