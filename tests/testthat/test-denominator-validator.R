# Tests for denominator content validation in bfh_qic()
# Spec: openspec/changes/add-denominator-validator
# Issue: #205

test_that("p-chart without n is rejected", {
  data <- data.frame(
    period = 1:8,
    events = rep(5L, 8)
  )
  expect_error(
    bfh_qic(data, x = period, y = events, chart_type = "p"),
    "requires denominator"
  )
})

test_that("i-chart without n succeeds (n not required)", {
  data <- data.frame(
    period = 1:10,
    value = c(10, 12, 11, 13, 9, 11, 14, 12, 10, 11)
  )
  result <- bfh_qic(data, x = period, y = value, chart_type = "i")
  expect_s3_class(result, "bfh_qic_result")
})

test_that("p-chart with n = 0 succeeds (qicharts2 NaN passthrough)", {
  data <- data.frame(
    period = 1:3,
    events = c(5L, 0L, 5L),
    total  = c(100L, 0L, 100L)
  )
  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
  )
  expect_s3_class(result, "bfh_qic_result")
})

test_that("p-chart with negative n is rejected (cl-pollution)", {
  data <- data.frame(
    period = 1:3,
    events = c(5L, 1L, 5L),
    total  = c(100L, -5L, 100L)
  )
  expect_error(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "p"),
    ">= 0"
  )
})

test_that("p-chart with Inf in n is rejected", {
  data <- data.frame(
    period = 1:3,
    events = c(5, 5, 5),
    total  = c(100, Inf, 100)
  )
  expect_error(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "p"),
    "Inf"
  )
})

test_that("p-chart with NA in single n row succeeds (qicharts2 drops it)", {
  data <- data.frame(
    period = 1:4,
    events = c(5L, 5L, 5L, 5L),
    total  = c(100L, NA_integer_, 100L, 100L)
  )
  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
  )
  expect_s3_class(result, "bfh_qic_result")
})

test_that("p-chart with y > n succeeds (proportion > 1 as outlier signal)", {
  data <- data.frame(
    period = 1:4,
    events = c(5L, 6L, 200L, 8L),
    total  = rep(100L, 4)
  )
  result <- bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
  expect_s3_class(result, "bfh_qic_result")
})

test_that("p-chart with all rows y <= n succeeds", {
  data <- data.frame(
    period = 1:5,
    events = c(5L, 6L, 4L, 8L, 7L),
    total  = rep(100L, 5)
  )
  result <- bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
  expect_s3_class(result, "bfh_qic_result")
})

test_that("u-chart with n = 0 succeeds (qicharts2 NaN passthrough)", {
  data <- data.frame(
    period = 1:3,
    events = c(5L, 5L, 5L),
    exposure = c(100L, 0L, 100L)
  )
  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = exposure, chart_type = "u")
  )
  expect_s3_class(result, "bfh_qic_result")
})

test_that("u-chart allows y > n (rate, not proportion)", {
  data <- data.frame(
    period = 1:3,
    events = c(50L, 60L, 200L),
    exposure = rep(100L, 3)
  )
  result <- bfh_qic(data, x = period, y = events, n = exposure, chart_type = "u")
  expect_s3_class(result, "bfh_qic_result")
})

test_that("pp-chart with y > n succeeds (proportion percent variant)", {
  data <- data.frame(
    period = 1:4,
    events = c(5L, 6L, 200L, 8L),
    total  = rep(100L, 4)
  )
  result <- bfh_qic(
    data,
    x = period, y = events, n = total,
    chart_type = "pp", y_axis_unit = "percent"
  )
  expect_s3_class(result, "bfh_qic_result")
})

test_that("xbar-chart skips denominator validation (subgroup via duplicated x)", {
  set.seed(42)
  # xbar requires duplicated x values per subgroup; no n column needed
  data <- data.frame(
    period = rep(1:5, each = 4),
    value  = rnorm(20, mean = 50, sd = 5)
  )
  result <- bfh_qic(data, x = period, y = value, chart_type = "xbar")
  expect_s3_class(result, "bfh_qic_result")
})

# ----------------------------------------------------------------------------
# Edge cases for n=0/NA passthrough (BFHcharts 0.18.0)
# ----------------------------------------------------------------------------

test_that("p-chart with ALL n = 0 succeeds (returns qic object, plot may be empty)", {
  data <- data.frame(
    period = 1:3,
    events = c(0L, 0L, 0L),
    total  = c(0L, 0L, 0L)
  )
  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
  )
  expect_s3_class(result, "bfh_qic_result")
})

test_that("p-chart with ALL n = NA succeeds", {
  data <- data.frame(
    period = 1:3,
    events = c(5L, 2L, 3L),
    total  = c(NA_integer_, NA_integer_, NA_integer_)
  )
  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
  )
  expect_s3_class(result, "bfh_qic_result")
})

test_that("p-chart with mixed valid + n=0: valid rows plotted, n=0 rows produce NaN", {
  data <- data.frame(
    period = 1:4,
    events = c(5L, 0L, 0L, 3L),
    total  = c(10L, 0L, 0L, 10L)
  )
  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
  )
  expect_s3_class(result, "bfh_qic_result")
  # Centerline beregnes fra valide raekker (5+3)/(10+10) = 0.4
  qic_data <- result$qic_data
  expect_true(any(is.nan(qic_data$y)))
  expect_true(any(!is.nan(qic_data$y)))
})

test_that("p-chart with all y > n (cl > 1) produces NaNs warning but does not error", {
  data <- data.frame(
    period = 1:3,
    events = c(15L, 20L, 18L),
    total  = c(10L, 10L, 10L)
  )
  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
  )
  expect_s3_class(result, "bfh_qic_result")
})
