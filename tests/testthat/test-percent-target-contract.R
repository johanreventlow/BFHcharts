# Test suite: percent target contract (issue #203)
#
# Verificerer at bfh_qic() håndhæver scale-kontrakt for target_value
# når y_axis_unit = "percent". Kontrakt: target_value i [0, multiply * 1.5].

# Deterministisk p-chart data (events/total → proportion ~0.05)
make_p_data <- function(n = 12) {
  data.frame(
    period = seq(as.Date("2024-01-01"), by = "month", length.out = n),
    events = rep(5L, n),
    total  = rep(100L, n)
  )
}

# Deterministisk data til run-chart og i-chart (ingen denominator)
make_i_data <- function(n = 12) {
  data.frame(
    period = seq(as.Date("2024-01-01"), by = "month", length.out = n),
    value  = rep(50L, n)
  )
}

# ── Fejlsituationer ──────────────────────────────────────────────────────────

test_that("2.2: target_value=2.0 + percent + multiply=1 → error med 'uden for forventet skala'", {
  data <- make_p_data()
  expect_error(
    bfh_qic(data,
      x = period, y = events, n = total,
      chart_type = "p", y_axis_unit = "percent",
      target_value = 2.0
    ),
    "uden for forventet skala"
  )
})

test_that("2.5: negative target_value + percent → error mentions non-negative", {
  data <- make_p_data()
  expect_error(
    bfh_qic(data,
      x = period, y = events, n = total,
      chart_type = "p", y_axis_unit = "percent",
      target_value = -0.1
    ),
    "non-negative"
  )
})

test_that("2.8: target_value=1.51 + percent + multiply=1 → error", {
  data <- make_p_data()
  expect_error(
    bfh_qic(data,
      x = period, y = events, n = total,
      chart_type = "p", y_axis_unit = "percent",
      target_value = 1.51
    ),
    "uden for forventet skala"
  )
})

test_that("2.10: run-chart + percent + target_value=2.0 → error (kontrakt gælder)", {
  data <- make_i_data()
  expect_error(
    bfh_qic(data,
      x = period, y = value,
      chart_type = "run", y_axis_unit = "percent",
      target_value = 2.0
    ),
    "uden for forventet skala"
  )
})

test_that("2.11: fejlbesked inkluderer actionable hint (did you mean 0.02?)", {
  data <- make_p_data()
  expect_error(
    bfh_qic(data,
      x = period, y = events, n = total,
      chart_type = "p", y_axis_unit = "percent",
      target_value = 2.0
    ),
    "0\\.02"
  )
})

# ── Successituationer ────────────────────────────────────────────────────────

test_that("2.3: target_value=0.02 + percent + multiply=1 → success, qic_data$target==0.02", {
  data <- make_p_data()
  result <- bfh_qic(data,
    x = period, y = events, n = total,
    chart_type = "p", y_axis_unit = "percent",
    target_value = 0.02
  )
  expect_s3_class(result, "bfh_qic_result")
  expect_equal(
    unique(result$qic_data$target[!is.na(result$qic_data$target)]),
    0.02
  )
})

test_that("2.4: target_value=2.0 + percent + multiply=100 → success, qic_data$target==2.0", {
  data <- make_p_data()
  result <- bfh_qic(data,
    x = period, y = events, n = total,
    chart_type = "p", y_axis_unit = "percent",
    target_value = 2.0, multiply = 100
  )
  expect_s3_class(result, "bfh_qic_result")
  expect_equal(
    unique(result$qic_data$target[!is.na(result$qic_data$target)]),
    2.0
  )
})

test_that("2.6: target_value=1.0 (100%) + percent + multiply=1 → success", {
  data <- make_p_data()
  result <- bfh_qic(data,
    x = period, y = events, n = total,
    chart_type = "p", y_axis_unit = "percent",
    target_value = 1.0
  )
  expect_s3_class(result, "bfh_qic_result")
  expect_equal(
    unique(result$qic_data$target[!is.na(result$qic_data$target)]),
    1.0
  )
})

test_that("2.7: target_value=1.5 (øvre grænse) + percent + multiply=1 → success", {
  data <- make_p_data()
  result <- bfh_qic(data,
    x = period, y = events, n = total,
    chart_type = "p", y_axis_unit = "percent",
    target_value = 1.5
  )
  expect_s3_class(result, "bfh_qic_result")
  expect_equal(
    unique(result$qic_data$target[!is.na(result$qic_data$target)]),
    1.5
  )
})

test_that("2.9: count unit + target_value=9999 → success (ingen skala-check)", {
  data <- make_i_data()
  result <- bfh_qic(data,
    x = period, y = value,
    chart_type = "i", y_axis_unit = "count",
    target_value = 9999
  )
  expect_s3_class(result, "bfh_qic_result")
})
