# Integration Tests for BFHcharts
# End-to-end tests of full workflow from data to plot

test_that("create_spc_chart() generates valid run chart", {
  library(ggplot2)

  # Create test data
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = c(15, 18, 12, 20, 16, 14, 19, 17, 13, 21, 18, 16)
  )

  # Generate plot
  plot <- create_spc_chart(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Test Run Chart"
  )

  # Validate plot structure
  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$title, "Test Run Chart")
})

test_that("create_spc_chart() generates valid p-chart with denominator", {
  library(ggplot2)

  # Create test data
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 5),
    surgeries = rpois(12, lambda = 100)
  )

  # Generate plot
  plot <- create_spc_chart(
    data = data,
    x = month,
    y = infections,
    n = surgeries,
    chart_type = "p",
    y_axis_unit = "percent",
    chart_title = "Infection Rate"
  )

  # Validate plot structure
  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$title, "Infection Rate")
})

test_that("create_spc_chart() handles phase splits correctly", {
  library(ggplot2)

  # Create test data with intervention
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(
      rnorm(12, mean = 20, sd = 3), # Before intervention
      rnorm(12, mean = 15, sd = 2) # After intervention
    )
  )

  # Generate plot with phase split
  plot <- create_spc_chart(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Intervention Study",
    part = c(12)
  )

  # Validate plot structure
  expect_s3_class(plot, "ggplot")
})

test_that("create_spc_chart() applies custom colors", {
  library(ggplot2)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 100, 10)
  )

  # Create custom color palette compatible with BFHcharts
  custom_colors <- list(
    primary = "#003366",
    secondary = "#808080",
    darkgrey = "#333333",
    lightgrey = "#cce5f1",
    mediumgrey = "#646c6f",
    dark = "#333333"
  )

  plot <- create_spc_chart(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    colors = custom_colors
  )

  expect_s3_class(plot, "ggplot")
})

test_that("bfh_spc_plot() works with pre-calculated qic data", {
  library(ggplot2)
  library(qicharts2)

  # Calculate QIC data manually
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = c(15, 18, 12, 20, 16, 14, 19, 17, 13, 21, 18, 16)
  )

  qic_result <- qic(
    x = month,
    y = value,
    data = data,
    chart = "i",
    return.data = TRUE
  )

  # Add anhoej.signal if missing
  if (!"anhoej.signal" %in% names(qic_result)) {
    qic_result$anhoej.signal <- if ("runs.signal" %in% names(qic_result)) {
      qic_result$runs.signal
    } else {
      rep(FALSE, nrow(qic_result))
    }
  }

  # Create plot config
  config <- spc_plot_config(
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Manual QIC Chart"
  )

  viewport <- viewport_dims(base_size = 14)

  # Generate plot
  plot <- bfh_spc_plot(
    qic_data = qic_result,
    plot_config = config,
    viewport = viewport
  )

  expect_s3_class(plot, "ggplot")
})

test_that("create_spc_chart() handles target values correctly", {
  library(ggplot2)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 100, 10)
  )

  plot <- create_spc_chart(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Chart with Target",
    target_value = 95,
    target_text = "Target: 95"
  )

  expect_s3_class(plot, "ggplot")
})

test_that("create_spc_chart() validates input correctly", {
  # Test invalid chart type
  expect_error(
    create_spc_chart(
      data = data.frame(x = 1:10, y = 1:10),
      x = x,
      y = y,
      chart_type = "invalid_type"
    ),
    "chart_type must be one of"
  )

  # Test invalid y_axis_unit
  expect_error(
    create_spc_chart(
      data = data.frame(x = 1:10, y = 1:10),
      x = x,
      y = y,
      y_axis_unit = "invalid_unit"
    ),
    "y_axis_unit must be one of"
  )
})
