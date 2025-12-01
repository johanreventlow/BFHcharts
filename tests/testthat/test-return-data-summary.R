# ============================================================================
# TESTS FOR return.data AND print.summary PARAMETERS
# ============================================================================

test_that("default behavior returns bfh_qic_result object", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      y_axis_unit = "count"
    )
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
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      return.data = TRUE
    )
  )

  expect_s3_class(result, "data.frame")
  expect_true("cl" %in% names(result))
  expect_true("ucl" %in% names(result))
  expect_true("lcl" %in% names(result))
})

test_that("print.summary = TRUE returns list with plot and summary", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      print.summary = TRUE
    )
  )

  expect_type(result, "list")
  expect_named(result, c("plot", "summary"))
  expect_s3_class(result$plot, "ggplot")
  expect_s3_class(result$summary, "data.frame")
})

test_that("return.data = TRUE and print.summary = TRUE returns list with data and summary", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      return.data = TRUE,
      print.summary = TRUE
    )
  )

  expect_type(result, "list")
  expect_named(result, c("data", "summary"))
  expect_s3_class(result$data, "data.frame")
  expect_s3_class(result$summary, "data.frame")
})

test_that("summary has correct Danish column names", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      print.summary = TRUE
    )
  )

  expected_cols <- c("fase", "antal_observationer", "anvendelige_observationer",
                     "længste_løb", "længste_løb_max", "antal_kryds", "antal_kryds_min",
                     "løbelængde_signal", "sigma_signal", "centerlinje",
                     "nedre_kontrolgrænse", "øvre_kontrolgrænse")

  expect_true(all(expected_cols %in% names(result$summary)))
})

test_that("summary works with run charts (no control limits)", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      y_axis_unit = "count",
      print.summary = TRUE
    )
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
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 5),
    surgeries = rpois(12, lambda = 100)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      n = surgeries,
      chart_type = "p",
      y_axis_unit = "percent",
      print.summary = TRUE
    )
  )

  expect_s3_class(result$summary, "data.frame")
  expect_true("centerlinje" %in% names(result$summary))
  # P-charts have variable control limits, so they should NOT be in summary
  expect_false("nedre_kontrolgrænse" %in% names(result$summary))
  expect_false("øvre_kontrolgrænse" %in% names(result$summary))
})

test_that("summary works with c-charts", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    defects = rpois(12, lambda = 10)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = defects,
      chart_type = "c",
      y_axis_unit = "count",
      print.summary = TRUE
    )
  )

  expect_s3_class(result$summary, "data.frame")
  expect_true("centerlinje" %in% names(result$summary))
})

test_that("summary works with u-charts", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    defects = rpois(12, lambda = 10),
    units = rpois(12, lambda = 100)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = defects,
      n = units,
      chart_type = "u",
      y_axis_unit = "rate",
      print.summary = TRUE
    )
  )

  expect_s3_class(result$summary, "data.frame")
  expect_true("centerlinje" %in% names(result$summary))
  # U-charts have variable control limits, so they should NOT be in summary
  expect_false("nedre_kontrolgrænse" %in% names(result$summary))
  expect_false("øvre_kontrolgrænse" %in% names(result$summary))
})

test_that("summary handles multiple phases correctly", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      part = c(12),  # Split into 2 phases
      print.summary = TRUE
    )
  )

  expect_equal(nrow(result$summary), 2)
  expect_equal(result$summary$fase, c(1, 2))
})

test_that("summary decimal places are appropriate for y_axis_unit", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 5),
    surgeries = rpois(12, lambda = 100)
  )

  # Test percent (should have 2 decimal places)
  result_percent <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      n = surgeries,
      chart_type = "p",
      y_axis_unit = "percent",
      print.summary = TRUE
    )
  )

  # Check that centerlinje is rounded to 2 decimals
  cl_decimal_places <- nchar(sub(".*\\.", "", as.character(result_percent$summary$centerlinje[1])))
  expect_lte(cl_decimal_places, 2)

  # Test count (should have 1 decimal place)
  result_count <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      print.summary = TRUE
    )
  )

  cl_decimal_places <- nchar(sub(".*\\.", "", as.character(result_count$summary$centerlinje[1])))
  expect_lte(cl_decimal_places, 1)
})

test_that("return.data parameter validation works", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  expect_error(
    suppressWarnings(
      bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        return.data = "yes"
      )
    ),
    "return.data must be TRUE or FALSE"
  )

  expect_error(
    suppressWarnings(
      bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        return.data = c(TRUE, FALSE)
      )
    ),
    "return.data must be TRUE or FALSE"
  )

  expect_error(
    suppressWarnings(
      bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        return.data = NA
      )
    ),
    "return.data must be TRUE or FALSE"
  )
})

test_that("print.summary parameter validation works", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  expect_error(
    suppressWarnings(
      bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        print.summary = "yes"
      )
    ),
    "print.summary must be TRUE or FALSE"
  )

  expect_error(
    suppressWarnings(
      bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        print.summary = c(TRUE, FALSE)
      )
    ),
    "print.summary must be TRUE or FALSE"
  )

  expect_error(
    suppressWarnings(
      bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        print.summary = NA
      )
    ),
    "print.summary must be TRUE or FALSE"
  )
})

test_that("Anhøj statistics are included in summary", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      print.summary = TRUE
    )
  )

  # Check Anhøj rule statistics
  expect_true("længste_løb" %in% names(result$summary))
  expect_true("længste_løb_max" %in% names(result$summary))
  expect_true("antal_kryds" %in% names(result$summary))
  expect_true("antal_kryds_min" %in% names(result$summary))
  expect_true("løbelængde_signal" %in% names(result$summary))
  expect_true("sigma_signal" %in% names(result$summary))

  # Check that signals are logical
  expect_type(result$summary$løbelængde_signal, "logical")
  expect_type(result$summary$sigma_signal, "logical")
})

test_that("summary returns single row for charts without phases", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 5),
    surgeries = rpois(24, lambda = 100)
  )

  # Test p-chart (has variable control limits per observation)
  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      n = surgeries,
      chart_type = "p",
      y_axis_unit = "percent",
      print.summary = TRUE
    )
  )

  # Should have exactly 1 row (not one per observation)
  expect_equal(nrow(result$summary), 1)
  expect_equal(result$summary$fase[1], 1)
})

test_that("summary returns correct rows for multi-phase charts", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 36),
    infections = rpois(36, lambda = 15)
  )

  # Chart with 3 phases
  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      part = c(12, 24),
      print.summary = TRUE
    )
  )

  # Should have exactly 3 rows (one per phase)
  expect_equal(nrow(result$summary), 3)
  expect_equal(result$summary$fase, c(1, 2, 3))
})

test_that("i-charts and c-charts have constant control limits in summary", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  # I-chart should have control limits
  result_i <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      print.summary = TRUE
    )
  )

  expect_true("nedre_kontrolgrænse" %in% names(result_i$summary))
  expect_true("øvre_kontrolgrænse" %in% names(result_i$summary))
  expect_type(result_i$summary$nedre_kontrolgrænse, "double")
  expect_type(result_i$summary$øvre_kontrolgrænse, "double")

  # C-chart should also have control limits
  result_c <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "c",
      y_axis_unit = "count",
      print.summary = TRUE
    )
  )

  expect_true("nedre_kontrolgrænse" %in% names(result_c$summary))
  expect_true("øvre_kontrolgrænse" %in% names(result_c$summary))
})
