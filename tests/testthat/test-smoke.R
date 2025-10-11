# Smoke Tests for BFHcharts Package
# Basic sanity checks to ensure package loads and core functions work

test_that("Package loads without errors", {
  expect_true(require(BFHcharts, quietly = TRUE))
})

test_that("BFH_COLORS palette exists", {
  expect_type(BFH_COLORS, "list")
  expect_true("primary" %in% names(BFH_COLORS))
  expect_true("secondary" %in% names(BFH_COLORS))
  expect_true("darkgrey" %in% names(BFH_COLORS))
})

test_that("create_color_palette() creates valid palette", {
  custom <- create_color_palette(
    primary = "#003366",
    secondary = "#808080",
    accent = "#FF9900"
  )

  expect_type(custom, "list")
  expect_equal(custom$primary, "#003366")
  expect_equal(custom$secondary, "#808080")
  expect_equal(custom$accent, "#FF9900")
})

test_that("spc_plot_config() creates valid config", {
  config <- spc_plot_config(
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Test Chart"
  )

  expect_s3_class(config, "spc_plot_config")
  expect_equal(config$chart_type, "run")
  expect_equal(config$y_axis_unit, "count")
  expect_equal(config$chart_title, "Test Chart")
})

test_that("viewport_dims() creates valid viewport", {
  viewport <- viewport_dims(base_size = 14)

  expect_s3_class(viewport, "viewport_dims")
  expect_equal(viewport$base_size, 14)
})

test_that("CHART_TYPES_DA mapping exists", {
  expect_type(CHART_TYPES_DA, "character")
  expect_true("run" %in% CHART_TYPES_DA)
  expect_true("i" %in% CHART_TYPES_DA)
  expect_true("p" %in% CHART_TYPES_DA)
})

test_that("get_qic_chart_type() translates Danish to English", {
  expect_equal(
    get_qic_chart_type("Seriediagram med SPC (Run Chart)"),
    "run"
  )
})

test_that("chart_type_requires_denominator() works correctly", {
  expect_true(chart_type_requires_denominator("p"))
  expect_true(chart_type_requires_denominator("u"))
  expect_false(chart_type_requires_denominator("run"))
  expect_false(chart_type_requires_denominator("i"))
})

test_that("Y_AXIS_UNITS_DA constants exist", {
  expect_type(Y_AXIS_UNITS_DA, "character")
  expect_true("count" %in% names(Y_AXIS_UNITS_DA))
  expect_true("percent" %in% names(Y_AXIS_UNITS_DA))
  expect_equal(Y_AXIS_UNITS_DA["count"], "Antal")
})

test_that("bfh_theme() creates valid ggplot2 theme", {
  library(ggplot2)

  theme_obj <- bfh_theme()
  expect_s3_class(theme_obj, "theme")
  expect_s3_class(theme_obj, "gg")
})

test_that("detect_date_interval() detects monthly data", {
  dates <- seq(as.Date("2024-01-01"), by = "month", length.out = 12)
  result <- detect_date_interval(dates)

  expect_type(result, "list")
  expect_equal(result$type, "monthly")
  expect_true(result$median_days > 25 && result$median_days < 35)
})

test_that("detect_date_interval() detects weekly data", {
  dates <- seq(as.Date("2024-01-01"), by = "week", length.out = 12)
  result <- detect_date_interval(dates)

  expect_type(result, "list")
  expect_equal(result$type, "weekly")
  expect_equal(result$median_days, 7)
})

test_that("parse_danish_dates() parses Danish format", {
  dates <- c("01-01-2024", "15-03-2024", "31-12-2024")
  result <- parse_danish_dates(dates)

  expect_s3_class(result, "POSIXct")
  expect_length(result, 3)
  expect_false(any(is.na(result)))
})
