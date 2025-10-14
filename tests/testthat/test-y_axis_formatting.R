# ============================================================================
# APPLY_Y_AXIS_FORMATTING TESTS
# ============================================================================

test_that("apply_y_axis_formatting validates plot object", {
  # Non-ggplot object should produce warning
  expect_warning(
    result <- apply_y_axis_formatting("not a plot", "count"),
    "plot is not a ggplot object"
  )
  # Should return object unchanged
  expect_equal(result, "not a plot")
})

test_that("apply_y_axis_formatting validates y_axis_unit", {
  data <- data.frame(x = 1:10, y = rnorm(10))
  plot <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) + ggplot2::geom_point()

  # NULL y_axis_unit should warn and default to 'count'
  expect_warning(
    result <- apply_y_axis_formatting(plot, NULL),
    "invalid y_axis_unit, defaulting to 'count'"
  )
  expect_s3_class(result, "ggplot")

  # Non-character y_axis_unit should warn
  expect_warning(
    result <- apply_y_axis_formatting(plot, 123),
    "invalid y_axis_unit"
  )
})

test_that("apply_y_axis_formatting applies percent formatting", {
  data <- data.frame(x = 1:10, y = runif(10))
  plot <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) + ggplot2::geom_point()

  result <- apply_y_axis_formatting(plot, "percent")

  expect_s3_class(result, "ggplot")
  # Should have a scale layer
  expect_true(length(result$scales$scales) > 0)
})

test_that("apply_y_axis_formatting applies count formatting", {
  data <- data.frame(x = 1:10, y = rpois(10, 1000))
  plot <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) + ggplot2::geom_point()

  result <- apply_y_axis_formatting(plot, "count")

  expect_s3_class(result, "ggplot")
  expect_true(length(result$scales$scales) > 0)
})

test_that("apply_y_axis_formatting applies rate formatting", {
  data <- data.frame(x = 1:10, y = rnorm(10, 5, 1))
  plot <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) + ggplot2::geom_point()

  result <- apply_y_axis_formatting(plot, "rate")

  expect_s3_class(result, "ggplot")
  expect_true(length(result$scales$scales) > 0)
})

test_that("apply_y_axis_formatting applies time formatting", {
  qic_data <- data.frame(x = 1:10, y = runif(10, 10, 50))
  plot <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) + ggplot2::geom_point()

  result <- apply_y_axis_formatting(plot, "time", qic_data)

  expect_s3_class(result, "ggplot")
  expect_true(length(result$scales$scales) > 0)
})

test_that("apply_y_axis_formatting handles unknown unit gracefully", {
  data <- data.frame(x = 1:10, y = rnorm(10))
  plot <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) + ggplot2::geom_point()

  # Unknown unit should return plot unchanged (default case in switch)
  result <- apply_y_axis_formatting(plot, "unknown_unit")

  expect_s3_class(result, "ggplot")
})

# ============================================================================
# FORMAT_Y_AXIS_PERCENT TESTS
# ============================================================================

test_that("format_y_axis_percent creates valid scale", {
  scale <- format_y_axis_percent()

  expect_s3_class(scale, "ScaleContinuousPosition")
  expect_true(!is.null(scale$labels))
})

# ============================================================================
# FORMAT_Y_AXIS_COUNT TESTS (K/M/mia notation)
# ============================================================================

test_that("format_y_axis_count creates valid scale", {
  scale <- format_y_axis_count()

  expect_s3_class(scale, "ScaleContinuousPosition")
  expect_true(is.function(scale$labels))
})

test_that("format_scaled_number formats billions correctly", {
  expect_equal(format_scaled_number(1e9, 1e9, " mia."), "1 mia.")
  expect_equal(format_scaled_number(1.5e9, 1e9, " mia."), "1,5 mia.")
  expect_equal(format_scaled_number(2.3e9, 1e9, " mia."), "2,3 mia.")
})

test_that("format_scaled_number formats millions correctly", {
  expect_equal(format_scaled_number(1e6, 1e6, "M"), "1M")
  expect_equal(format_scaled_number(2.5e6, 1e6, "M"), "2,5M")
  expect_equal(format_scaled_number(10.7e6, 1e6, "M"), "10,7M")
})

test_that("format_scaled_number formats thousands correctly", {
  expect_equal(format_scaled_number(1000, 1e3, "K"), "1K")
  expect_equal(format_scaled_number(1500, 1e3, "K"), "1,5K")
  expect_equal(format_scaled_number(25300, 1e3, "K"), "25,3K")
})

test_that("format_scaled_number handles NA values", {
  expect_true(is.na(format_scaled_number(NA, 1e3, "K")))
})

test_that("format_scaled_number uses Danish decimal mark", {
  # Should use comma as decimal separator
  result <- format_scaled_number(1.5e6, 1e6, "M")
  expect_true(grepl(",", result))
  expect_false(grepl("\\.", result))
})

test_that("format_unscaled_number formats integers without decimals", {
  expect_equal(format_unscaled_number(100), "100")
  expect_equal(format_unscaled_number(1000), "1.000")  # Danish thousand separator
  expect_equal(format_unscaled_number(1234567), "1.234.567")
})

test_that("format_unscaled_number formats decimals with Danish notation", {
  result <- format_unscaled_number(123.5)
  expect_true(grepl(",", result))  # Comma as decimal mark
  expect_true(grepl("123,5", result))
})

test_that("format_unscaled_number handles NA values", {
  expect_true(is.na(format_unscaled_number(NA)))
})

# ============================================================================
# FORMAT_Y_AXIS_RATE TESTS
# ============================================================================

test_that("format_y_axis_rate creates valid scale", {
  scale <- format_y_axis_rate()

  expect_s3_class(scale, "ScaleContinuousPosition")
  expect_true(is.function(scale$labels))
})

test_that("format_y_axis_rate formats integers without decimals", {
  scale <- format_y_axis_rate()
  labels <- scale$labels(c(1, 10, 100))

  # Integers should have no decimal mark
  expect_true(all(!grepl(",", labels)))
})

test_that("format_y_axis_rate formats decimals with Danish notation", {
  scale <- format_y_axis_rate()
  labels <- scale$labels(c(1.5, 10.7, 123.456))

  # Should use comma as decimal mark
  expect_true(all(grepl(",", labels)))
})

# ============================================================================
# FORMAT_Y_AXIS_TIME TESTS
# ============================================================================

test_that("format_y_axis_time handles missing qic_data", {
  expect_warning(
    scale <- format_y_axis_time(NULL),
    "missing qic_data"
  )
  expect_s3_class(scale, "ScaleContinuousPosition")
})

test_that("format_y_axis_time handles missing y column", {
  qic_data <- data.frame(x = 1:10)  # No y column

  expect_warning(
    scale <- format_y_axis_time(qic_data),
    "missing qic_data or y column"
  )
  expect_s3_class(scale, "ScaleContinuousPosition")
})

test_that("format_y_axis_time selects minutes for small values", {
  qic_data <- data.frame(x = 1:10, y = runif(10, 5, 50))  # < 60 minutes

  scale <- format_y_axis_time(qic_data)

  expect_s3_class(scale, "ScaleContinuousPosition")
  expect_true(is.function(scale$labels))

  # Test label generation
  labels <- scale$labels(c(10, 30, 50))
  expect_true(all(grepl("min", labels)))
})

test_that("format_y_axis_time selects hours for medium values", {
  qic_data <- data.frame(x = 1:10, y = runif(10, 100, 500))  # 60-1440 minutes

  scale <- format_y_axis_time(qic_data)

  labels <- scale$labels(c(120, 300, 600))  # 2h, 5h, 10h
  expect_true(all(grepl("timer", labels)))
})

test_that("format_y_axis_time selects days for large values", {
  qic_data <- data.frame(x = 1:10, y = runif(10, 2000, 5000))  # > 1440 minutes

  scale <- format_y_axis_time(qic_data)

  labels <- scale$labels(c(2880, 4320))  # 2 days, 3 days
  expect_true(all(grepl("dage", labels)))
})

test_that("format_time_with_unit formats minutes correctly", {
  expect_equal(format_time_with_unit(30, "minutes"), "30 min")
  expect_equal(format_time_with_unit(45.5, "minutes"), "45,5 min")
})

test_that("format_time_with_unit formats hours correctly", {
  expect_equal(format_time_with_unit(60, "hours"), "1 timer")
  expect_equal(format_time_with_unit(90, "hours"), "1,5 timer")
  expect_equal(format_time_with_unit(180, "hours"), "3 timer")
})

test_that("format_time_with_unit formats days correctly", {
  expect_equal(format_time_with_unit(1440, "days"), "1 dage")
  expect_equal(format_time_with_unit(2880, "days"), "2 dage")
  expect_equal(format_time_with_unit(2160, "days"), "1,5 dage")
})

test_that("format_time_with_unit handles NA values", {
  expect_true(is.na(format_time_with_unit(NA, "minutes")))
  expect_true(is.na(format_time_with_unit(NA, "hours")))
  expect_true(is.na(format_time_with_unit(NA, "days")))
})

test_that("format_time_with_unit uses Danish labels", {
  # Minutes
  expect_true(grepl("min", format_time_with_unit(30, "minutes")))

  # Hours - should be "timer" not "hours"
  expect_true(grepl("timer", format_time_with_unit(60, "hours")))

  # Days - should be "dage" not "days"
  expect_true(grepl("dage", format_time_with_unit(1440, "days")))
})

test_that("format_time_with_unit uses Danish decimal notation", {
  result <- format_time_with_unit(90, "hours")  # 1.5 hours
  expect_true(grepl("1,5", result))  # Comma as decimal separator
})

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_that("Y-axis formatting works in complete plots", {
  # Create test data
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    count = rpois(12, 5000),
    pct = runif(12, 0.1, 0.9),
    rate = rnorm(12, 5, 1),
    time = runif(12, 20, 100)
  )

  # Test count formatting
  base_plot_count <- ggplot2::ggplot(data, ggplot2::aes(x = month, y = count)) +
    ggplot2::geom_line()
  plot_count <- apply_y_axis_formatting(base_plot_count, y_axis_unit = "count")
  expect_s3_class(plot_count, "ggplot")

  # Test percent formatting
  base_plot_pct <- ggplot2::ggplot(data, ggplot2::aes(x = month, y = pct)) +
    ggplot2::geom_line()
  plot_pct <- apply_y_axis_formatting(base_plot_pct, y_axis_unit = "percent")
  expect_s3_class(plot_pct, "ggplot")

  # Test rate formatting
  base_plot_rate <- ggplot2::ggplot(data, ggplot2::aes(x = month, y = rate)) +
    ggplot2::geom_line()
  plot_rate <- apply_y_axis_formatting(base_plot_rate, y_axis_unit = "rate")
  expect_s3_class(plot_rate, "ggplot")

  # Test time formatting
  qic_data <- data.frame(x = data$month, y = data$time)
  base_plot_time <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()
  plot_time <- apply_y_axis_formatting(base_plot_time, y_axis_unit = "time", qic_data = qic_data)
  expect_s3_class(plot_time, "ggplot")
})

test_that("Y-axis formatting works in create_spc_chart", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2)
  )

  # Test with count unit
  plot_count <- suppressWarnings(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      chart_type = "run",
      y_axis_unit = "count"
    )
  )
  expect_s3_class(plot_count, "ggplot")

  # Test with percent unit
  plot_pct <- suppressWarnings(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      chart_type = "run",
      y_axis_unit = "percent"
    )
  )
  expect_s3_class(plot_pct, "ggplot")
})

test_that("Count formatting handles edge cases", {
  # Test boundary values for K/M/mia thresholds
  test_values <- c(
    999,      # Should be unscaled
    1000,     # Should be 1K
    999999,   # Should be 999,9K (or 999K if integer)
    1000000,  # Should be 1M
    999999999, # Should be 999,9M
    1000000000 # Should be 1 mia.
  )

  scale <- format_y_axis_count()
  labels <- scale$labels(test_values)

  # All should be non-NA strings
  expect_true(all(!is.na(labels)))
  expect_true(all(nchar(labels) > 0))

  # Check for expected suffixes at boundaries
  expect_true(grepl("K", labels[2]))  # 1000
  expect_true(grepl("M", labels[4]))  # 1000000
  expect_true(grepl("mia", labels[6]))  # 1000000000
})

test_that("All formatters handle NA values consistently", {
  # Scaled numbers
  expect_true(is.na(format_scaled_number(NA, 1e3, "K")))

  # Unscaled numbers
  expect_true(is.na(format_unscaled_number(NA)))

  # Time values
  expect_true(is.na(format_time_with_unit(NA, "minutes")))
})

test_that("Danish number notation is consistent across formatters", {
  # All should use comma as decimal separator
  expect_true(grepl(",", format_scaled_number(1.5e6, 1e6, "M")))
  expect_true(grepl(",", format_unscaled_number(123.5)))
  expect_true(grepl(",", format_time_with_unit(90, "hours")))

  # Unscaled numbers should use dot as thousand separator
  expect_true(grepl("\\.", format_unscaled_number(1234)))
})
