# ============================================================================
# TESTS FOR return.data AND print.summary PARAMETERS
# ============================================================================

test_that("default behavior returns bfh_qic_result object", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "run",
    y_axis_unit = "count"
  )

  # NEW BEHAVIOR: Returns bfh_qic_result S3 object
  expect_s3_class(result, "bfh_qic_result")
  expect_s3_class(result, "list")

  # Verify structure
  expect_true("plot" %in% names(result))
  expect_true("summary" %in% names(result))
  expect_true("qic_data" %in% names(result))
  expect_true("config" %in% names(result))

  # Verify components
  expect_s3_class(result$plot, "ggplot")
  expect_s3_class(result$summary, "data.frame")
  expect_s3_class(result$qic_data, "data.frame")
  expect_type(result$config, "list")
})

test_that("return.data = TRUE returns data.frame with qic calculations", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count",
    return.data = TRUE
  )

  expect_s3_class(result, "data.frame")
  expect_true("cl" %in% names(result))
  expect_true("ucl" %in% names(result))
  expect_true("lcl" %in% names(result))
})

test_that("print.summary parameter is no longer accepted (fully removed in v0.14.3)", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  # Parameter removed entirely from formals in v0.14.3 (deprecated v0.11.0).
  # Calling with print.summary triggers R's "unused argument" error.
  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      print.summary = TRUE
    ),
    "unused argument"
  )
})

test_that("summary tilgaengeligt som result$summary i default bfh_qic_result-objekt", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count"
  )

  expect_s3_class(result, "bfh_qic_result")
  expect_s3_class(result$summary, "data.frame")
  expect_s3_class(result$plot, "ggplot")
})

test_that("summary has correct Danish column names", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count"
  )

  expected_cols <- c(
    "fase", "antal_observationer", "anvendelige_observationer",
    "længste_løb", "længste_løb_max", "antal_kryds", "antal_kryds_min",
    "anhoej_signal", "runs_signal", "crossings_signal", "sigma_signal", "centerlinje",
    "nedre_kontrolgrænse", "øvre_kontrolgrænse"
  )

  expect_true(all(expected_cols %in% names(result$summary)))
})

test_that("summary works with run charts (no control limits)", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "run",
    y_axis_unit = "count"
  )

  # Run charts have control limit columns but they contain NA values
  expect_true("centerlinje" %in% names(result$summary))
  expect_true("nedre_kontrolgrænse" %in% names(result$summary))
  expect_true("øvre_kontrolgrænse" %in% names(result$summary))

  # Values should be NA for run charts
  expect_true(is.na(result$summary$nedre_kontrolgrænse[1]))
  expect_true(is.na(result$summary$øvre_kontrolgrænse[1]))
})

test_that("summary works with p-charts", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 5),
    surgeries = rpois(12, lambda = 100)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    n = surgeries,
    chart_type = "p",
    y_axis_unit = "percent"
  )

  expect_s3_class(result$summary, "data.frame")
  expect_true("centerlinje" %in% names(result$summary))
  # P-charts have variable control limits, so they should NOT be in summary
  expect_false("nedre_kontrolgrænse" %in% names(result$summary))
  expect_false("øvre_kontrolgrænse" %in% names(result$summary))
})

test_that("summary works with c-charts", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    defects = rpois(12, lambda = 10)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = defects,
    chart_type = "c",
    y_axis_unit = "count"
  )

  expect_s3_class(result$summary, "data.frame")
  expect_true("centerlinje" %in% names(result$summary))
})

test_that("summary works with u-charts", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    defects = rpois(12, lambda = 10),
    units = rpois(12, lambda = 100)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = defects,
    n = units,
    chart_type = "u",
    y_axis_unit = "rate"
  )

  expect_s3_class(result$summary, "data.frame")
  expect_true("centerlinje" %in% names(result$summary))
  # U-charts have variable control limits, so they should NOT be in summary
  expect_false("nedre_kontrolgrænse" %in% names(result$summary))
  expect_false("øvre_kontrolgrænse" %in% names(result$summary))
})

test_that("summary handles multiple phases correctly", {
  set.seed(42)
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
    part = c(12) # Split into 2 phases
  )

  expect_equal(nrow(result$summary), 2)
  expect_equal(result$summary$fase, c(1, 2))
})

test_that("summary returnerer raa qicharts2-precision uafhaengigt af y_axis_unit", {
  # Slice C kontrakt (v0.15.0): summary lagrer raa cl-vaerdi.
  # Display-formattere afrunder selv ved string-emission.
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 5),
    surgeries = rpois(12, lambda = 100)
  )

  result_percent <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    n = surgeries,
    chart_type = "p",
    y_axis_unit = "percent"
  )

  # summary$centerlinje skal vaere identisk med qic_data$cl raat
  expect_identical(
    result_percent$summary$centerlinje[1],
    result_percent$qic_data$cl[1]
  )

  result_count <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count"
  )

  expect_identical(
    result_count$summary$centerlinje[1],
    result_count$qic_data$cl[1]
  )
})

test_that("return.data parameter validation works", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      return.data = "yes"
    ),
    "return.data must be TRUE or FALSE"
  )

  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      return.data = c(TRUE, FALSE)
    ),
    "return.data must be TRUE or FALSE"
  )

  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      return.data = NA
    ),
    "return.data must be TRUE or FALSE"
  )
})

# print.summary parameter validation tests removed: parameter no longer
# exists on bfh_qic() formals (removed v0.14.3, deprecated v0.11.0). The
# regression that asserts the parameter is gone lives in
# tests/testthat/test-public-api-contract.R.

test_that("Anhøj statistics are included in summary", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count"
  )

  # Check Anhøj rule statistics
  expect_true("længste_løb" %in% names(result$summary))
  expect_true("længste_løb_max" %in% names(result$summary))
  expect_true("antal_kryds" %in% names(result$summary))
  expect_true("antal_kryds_min" %in% names(result$summary))
  expect_true("anhoej_signal" %in% names(result$summary))
  expect_true("runs_signal" %in% names(result$summary))
  expect_true("crossings_signal" %in% names(result$summary))
  expect_true("sigma_signal" %in% names(result$summary))

  # Check that signals are logical
  expect_type(result$summary$anhoej_signal, "logical")
  expect_type(result$summary$runs_signal, "logical")
  expect_type(result$summary$crossings_signal, "logical")
  expect_type(result$summary$sigma_signal, "logical")
})

test_that("summary returns single row for charts without phases", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 5),
    surgeries = rpois(24, lambda = 100)
  )

  # Test p-chart (has variable control limits per observation)
  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    n = surgeries,
    chart_type = "p",
    y_axis_unit = "percent"
  )

  # Should have exactly 1 row (not one per observation)
  expect_equal(nrow(result$summary), 1)
  expect_equal(result$summary$fase[1], 1)
})

test_that("summary returns correct rows for multi-phase charts", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 36),
    infections = rpois(36, lambda = 15)
  )

  # Chart with 3 phases
  result <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count",
    part = c(12, 24)
  )

  # Should have exactly 3 rows (one per phase)
  expect_equal(nrow(result$summary), 3)
  expect_equal(result$summary$fase, c(1, 2, 3))
})

test_that("i-charts and c-charts have constant control limits in summary", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  # I-chart should have control limits
  result_i <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count"
  )

  expect_true("nedre_kontrolgrænse" %in% names(result_i$summary))
  expect_true("øvre_kontrolgrænse" %in% names(result_i$summary))
  expect_type(result_i$summary$nedre_kontrolgrænse, "double")
  expect_type(result_i$summary$øvre_kontrolgrænse, "double")

  # C-chart should also have control limits
  result_c <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "c",
    y_axis_unit = "count"
  )

  expect_true("nedre_kontrolgrænse" %in% names(result_c$summary))
  expect_true("øvre_kontrolgrænse" %in% names(result_c$summary))
})
