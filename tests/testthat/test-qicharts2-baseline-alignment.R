# Regression-tests: BFHcharts facade skal matche qicharts2 baseline

baseline_anhoej_signal <- function(qic_df) {
  if ("anhoej.signal" %in% names(qic_df)) {
    sig <- as.logical(qic_df$anhoej.signal)
  } else if ("anhoej.signals" %in% names(qic_df)) {
    sig <- as.logical(qic_df$anhoej.signals)
  } else if ("runs.signal" %in% names(qic_df) && "crossings.signal" %in% names(qic_df)) {
    sig <- as.logical(qic_df$runs.signal | qic_df$crossings.signal)
  } else if ("runs.signal" %in% names(qic_df)) {
    sig <- as.logical(qic_df$runs.signal)
  } else {
    sig <- rep(FALSE, nrow(qic_df))
  }

  ifelse(is.na(sig), FALSE, sig)
}

test_that("bfh_qic run-chart with freeze matches qicharts2 CL baseline", {
  data <- data.frame(
    period = 1:24,
    value = c(rep(10, 12), rep(20, 12))
  )

  baseline <- qicharts2::qic(
    data = data,
    x = period,
    y = value,
    chart = "run",
    freeze = 12,
    return.data = TRUE
  )

  result <- bfh_qic(
    data = data,
    x = period,
    y = value,
    chart_type = "run",
    freeze = 12
  )

  expect_equal(result$qic_data$cl, baseline$cl, tolerance = 1e-12)
})

test_that("bfh_qic p-chart control limits match qicharts2 baseline", {
  data <- data.frame(
    period = 1:24,
    events = c(12, 10, 11, 13, 9, 10, 8, 7, 11, 10, 9, 12,
               11, 8, 9, 10, 12, 11, 10, 9, 8, 10, 11, 12),
    n = c(100, 95, 110, 105, 98, 102, 96, 101, 107, 99, 104, 103,
          97, 108, 100, 102, 106, 98, 101, 99, 103, 105, 100, 96)
  )

  baseline <- qicharts2::qic(
    data = data,
    x = period,
    y = events,
    n = n,
    chart = "p",
    return.data = TRUE
  )

  result <- bfh_qic(
    data = data,
    x = period,
    y = events,
    n = n,
    chart_type = "p"
  )

  expect_equal(result$qic_data$cl, baseline$cl, tolerance = 1e-12)
  expect_equal(result$qic_data$ucl, baseline$ucl, tolerance = 1e-12)
  expect_equal(result$qic_data$lcl, baseline$lcl, tolerance = 1e-12)
  expect_equal(result$qic_data$anhoej.signal, baseline_anhoej_signal(baseline))
})

test_that("bfh_qic xbar/s with duplicated subgroup x matches qicharts2 baseline", {
  set.seed(42)

  # 12 subgrupper, 4 observationer i hver subgroup
  subgroup <- rep(1:12, each = 4)
  measurement <- c(
    rnorm(24, mean = 10, sd = 1),
    rnorm(24, mean = 11, sd = 1.2)
  )
  data <- data.frame(subgroup = subgroup, value = measurement)

  baseline_xbar <- qicharts2::qic(
    data = data,
    x = subgroup,
    y = value,
    chart = "xbar",
    return.data = TRUE
  )
  baseline_s <- qicharts2::qic(
    data = data,
    x = subgroup,
    y = value,
    chart = "s",
    return.data = TRUE
  )

  result_xbar <- bfh_qic(
    data = data,
    x = subgroup,
    y = value,
    chart_type = "xbar"
  )
  result_s <- bfh_qic(
    data = data,
    x = subgroup,
    y = value,
    chart_type = "s"
  )

  expect_equal(result_xbar$qic_data$cl, baseline_xbar$cl, tolerance = 1e-12)
  expect_equal(result_xbar$qic_data$ucl, baseline_xbar$ucl, tolerance = 1e-12)
  expect_equal(result_xbar$qic_data$lcl, baseline_xbar$lcl, tolerance = 1e-12)

  expect_equal(result_s$qic_data$cl, baseline_s$cl, tolerance = 1e-12)
  expect_equal(result_s$qic_data$ucl, baseline_s$ucl, tolerance = 1e-12)
  expect_equal(result_s$qic_data$lcl, baseline_s$lcl, tolerance = 1e-12)
})

test_that("bfh_qic only forwards agg.fun when explicitly supplied", {
  data <- data.frame(
    subgroup = rep(1:8, each = 3),
    value = c(8, 10, 15, 11, 12, 14, 9, 8, 13, 12, 11, 10,
              15, 13, 14, 10, 12, 11, 9, 10, 12, 14, 15, 13)
  )

  # Omitted agg.fun: should match qicharts2 default behavior
  baseline_default <- qicharts2::qic(
    data = data,
    x = subgroup,
    y = value,
    chart = "run",
    return.data = TRUE
  )
  result_default <- bfh_qic(
    data = data,
    x = subgroup,
    y = value,
    chart_type = "run"
  )

  # Explicit agg.fun: should match explicit qicharts2 call
  baseline_median <- qicharts2::qic(
    data = data,
    x = subgroup,
    y = value,
    chart = "run",
    agg.fun = "median",
    return.data = TRUE
  )
  result_median <- bfh_qic(
    data = data,
    x = subgroup,
    y = value,
    chart_type = "run",
    agg.fun = "median"
  )

  expect_equal(result_default$qic_data$cl, baseline_default$cl, tolerance = 1e-12)
  expect_equal(result_median$qic_data$cl, baseline_median$cl, tolerance = 1e-12)
})
