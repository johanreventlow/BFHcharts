test_that("README Quick Start example 1: run chart returns bfh_qic_result", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 15),
    surgeries = rpois(24, lambda = 100)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Monthly Hospital-Acquired Infections"
  )

  expect_s3_class(result, "bfh_qic_result")
})

test_that("README Quick Start example 2: p-chart with target returns bfh_qic_result", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 15),
    surgeries = rpois(24, lambda = 100)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    n = surgeries,
    chart_type = "p",
    y_axis_unit = "percent",
    chart_title = "Infection Rate per 100 Surgeries",
    target_value = 0.02,
    target_text = "↓ Target: 2%"
  )

  expect_s3_class(result, "bfh_qic_result")
})

test_that("README Quick Start example 3: i-chart with phase split returns bfh_qic_result", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 15)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Infections Before/After Intervention",
    part = c(12),
    freeze = 12
  )

  expect_s3_class(result, "bfh_qic_result")
})
