# ============================================================================
# TESTS FOR Observable JS Export Functions
# ============================================================================

# Hjælpefunktion til at oprette test bfh_qic_result objekter
make_test_result <- function(chart_type = "run", y_axis_unit = "count") {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = chart_type,
      y_axis_unit = y_axis_unit
    )
  )
}

# ============================================================================
# bfh_prepare_ojs_data() tests
# ============================================================================

test_that("bfh_prepare_ojs_data() returns correct structure", {
  skip_on_ci()

  result <- make_test_result()
  ojs <- bfh_prepare_ojs_data(result)

  expect_type(ojs, "list")
  expect_named(ojs, c("data", "config", "colors", "summary"))
})

test_that("bfh_prepare_ojs_data() data has correct columns", {
  skip_on_ci()

  result <- make_test_result()
  ojs <- bfh_prepare_ojs_data(result)

  expected_cols <- c(
    "x", "y", "cl", "ucl", "lcl", "target",
    "part", "sigma_signal", "anhoej_signal", "notes"
  )
  expect_true(is.data.frame(ojs$data))
  expect_named(ojs$data, expected_cols)
})

test_that("bfh_prepare_ojs_data() x column is ISO date strings", {
  skip_on_ci()

  result <- make_test_result()
  ojs <- bfh_prepare_ojs_data(result)

  # Alle x-værdier skal matche YYYY-MM-DD format
  expect_true(all(grepl("^\\d{4}-\\d{2}-\\d{2}$", ojs$data$x)))
})

test_that("bfh_prepare_ojs_data() config contains required fields", {
  skip_on_ci()

  result <- make_test_result()
  ojs <- bfh_prepare_ojs_data(result)

  expect_type(ojs$config, "list")
  expect_true("chart_type" %in% names(ojs$config))
  expect_true("y_axis_unit" %in% names(ojs$config))
  expect_equal(ojs$config$chart_type, "run")
  expect_equal(ojs$config$y_axis_unit, "count")
})

test_that("bfh_prepare_ojs_data() colors are hex strings", {
  skip_on_ci()

  result <- make_test_result()
  ojs <- bfh_prepare_ojs_data(result)

  expect_type(ojs$colors, "list")
  expect_true(all(c(
    "hospital_blue", "hospital_grey", "hospital_dark_grey",
    "light_blue", "very_light_blue"
  ) %in% names(ojs$colors)))

  # Alle farver skal være hex-strenge
  for (col_name in names(ojs$colors)) {
    expect_match(ojs$colors[[col_name]], "^#[0-9A-Fa-f]{6}$",
      info = paste("Color", col_name, "should be a hex string")
    )
  }
})

test_that("bfh_prepare_ojs_data() includes summary", {
  skip_on_ci()

  result <- make_test_result()
  ojs <- bfh_prepare_ojs_data(result)

  expect_true(is.data.frame(ojs$summary) || is.list(ojs$summary))
})

test_that("bfh_prepare_ojs_data() works with i-chart", {
  skip_on_ci()

  result <- make_test_result(chart_type = "i")
  ojs <- bfh_prepare_ojs_data(result)

  expect_type(ojs, "list")
  expect_equal(ojs$config$chart_type, "i")
  # I-chart skal have kontrolgrænser
  expect_true(any(!is.na(ojs$data$ucl)))
  expect_true(any(!is.na(ojs$data$lcl)))
})

test_that("bfh_prepare_ojs_data() works with p-chart", {
  skip_on_ci()

  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    events = rbinom(12, size = 200, prob = 0.08),
    n = rep(200, 12)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = events,
      n = n,
      chart_type = "p",
      y_axis_unit = "percent"
    )
  )

  ojs <- bfh_prepare_ojs_data(result)

  expect_type(ojs, "list")
  expect_equal(ojs$config$chart_type, "p")
  expect_equal(ojs$config$y_axis_unit, "percent")
})

test_that("bfh_prepare_ojs_data() rejects non-bfh_qic_result input", {
  expect_error(
    bfh_prepare_ojs_data(list(a = 1)),
    "must be a bfh_qic_result object"
  )

  expect_error(
    bfh_prepare_ojs_data("not a result"),
    "must be a bfh_qic_result object"
  )
})

test_that("bfh_prepare_ojs_data() part column is integer", {
  skip_on_ci()

  result <- make_test_result()
  ojs <- bfh_prepare_ojs_data(result)

  expect_type(ojs$data$part, "integer")
})

test_that("bfh_prepare_ojs_data() includes footer when provided", {
  skip_on_ci()

  result <- make_test_result()
  ojs <- bfh_prepare_ojs_data(result, footer = "BFH | Test footer")

  expect_equal(ojs$footer, "BFH | Test footer")
})

test_that("bfh_prepare_ojs_data() omits footer when NULL", {
  skip_on_ci()

  result <- make_test_result()
  ojs <- bfh_prepare_ojs_data(result, footer = NULL)

  expect_null(ojs$footer)
})

# ============================================================================
# bfh_ojs_path() tests
# ============================================================================

test_that("bfh_ojs_path() returns valid path for bfh-spc-utils.js", {
  path <- bfh_ojs_path("bfh-spc-utils.js")

  expect_type(path, "character")
  expect_true(file.exists(path))
  expect_true(grepl("bfh-spc-utils\\.js$", path))
})

test_that("bfh_ojs_path() returns valid path for bfh-spc-scales.js", {
  path <- bfh_ojs_path("bfh-spc-scales.js")

  expect_type(path, "character")
  expect_true(file.exists(path))
})

test_that("bfh_ojs_path() returns valid path for bfh-spc.js", {
  path <- bfh_ojs_path("bfh-spc.js")

  expect_type(path, "character")
  expect_true(file.exists(path))
})

test_that("bfh_ojs_path() returns valid path for bfh-spc-stats.js", {
  path <- bfh_ojs_path("bfh-spc-stats.js")

  expect_type(path, "character")
  expect_true(file.exists(path))
})

test_that("bfh_ojs_path() errors for non-existent file", {
  expect_error(
    bfh_ojs_path("does-not-exist.js"),
    "no file found"
  )
})

# ============================================================================
# bfh_ojs_define() tests
# ============================================================================

test_that("bfh_ojs_define() errors without Quarto context", {
  skip_on_ci()

  result <- make_test_result()

  # Uden Quarto rendering-kontekst skal funktionen fejle
  expect_error(
    bfh_ojs_define(result),
    "ojs_define.*not found"
  )
})
