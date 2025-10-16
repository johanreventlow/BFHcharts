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

# ============================================================================
# NEW QIC PARAMETERS TESTS
# ============================================================================

test_that("create_spc_chart() handles exclude parameter correctly", {
  library(ggplot2)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = c(15, 18, 50, 20, 16, 14, 19, 17, 13, 21, 18, 16) # Point 3 is outlier
  )

  # Exclude outlier from calculations
  plot <- create_spc_chart(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "I-Chart with Excluded Outlier",
    exclude = c(3)
  )

  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$title, "I-Chart with Excluded Outlier")
})

test_that("create_spc_chart() handles multiply parameter correctly", {
  library(ggplot2)

  # Data in proportions (0-1)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    proportion = runif(12, 0.01, 0.05) # Proportions 1-5%
  )

  # Convert to percentages (0-100)
  plot <- create_spc_chart(
    data = data,
    x = month,
    y = proportion,
    chart_type = "i",
    y_axis_unit = "percent",
    chart_title = "Proportions as Percentages",
    multiply = 100
  )

  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$title, "Proportions as Percentages")
})

test_that("create_spc_chart() handles agg.fun parameter correctly", {
  library(ggplot2)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Use median aggregation
  plot_median <- create_spc_chart(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "I-Chart with Median",
    agg.fun = "median"
  )

  expect_s3_class(plot_median, "ggplot")

  # Use sum aggregation
  plot_sum <- create_spc_chart(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Run Chart with Sum",
    agg.fun = "sum"
  )

  expect_s3_class(plot_sum, "ggplot")
})

test_that("create_spc_chart() validates exclude parameter", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Invalid exclude position (out of bounds)
  expect_error(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      exclude = c(15) # Only 12 rows
    ),
    "exclude positions must be positive integers within data bounds"
  )

  # Negative exclude position
  expect_error(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      exclude = c(-1)
    ),
    "exclude positions must be positive integers"
  )
})

test_that("create_spc_chart() validates multiply parameter", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Non-numeric multiply
  expect_error(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      multiply = "hundred"
    ),
    "multiply must be a single positive number"
  )

  # Negative multiply
  expect_error(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      multiply = -100
    ),
    "multiply must be a single positive number"
  )

  # Multiple values
  expect_error(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      multiply = c(100, 200)
    ),
    "multiply must be a single positive number"
  )
})

test_that("create_spc_chart() validates agg.fun parameter", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Invalid aggregation function
  expect_error(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      agg.fun = "invalid_func"
    ),
    "'arg' should be one of"
  )
})

test_that("create_spc_chart() combines new parameters correctly", {
  library(ggplot2)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    proportion = c(
      runif(12, 0.02, 0.05), # Before intervention
      runif(12, 0.01, 0.03) # After intervention
    )
  )
  # Add outlier
  data$proportion[5] <- 0.15

  # Combine exclude, multiply, and agg.fun
  plot <- create_spc_chart(
    data = data,
    x = month,
    y = proportion,
    chart_type = "i",
    y_axis_unit = "percent",
    chart_title = "Combined Parameters Test",
    exclude = c(5), # Exclude outlier
    multiply = 100, # Convert to percent
    agg.fun = "median", # Use median
    part = c(12) # Phase split
  )

  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$title, "Combined Parameters Test")
})

test_that("create_spc_chart() handles cl parameter correctly", {
  library(ggplot2)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Use custom centerline value
  plot <- create_spc_chart(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "I-Chart with Custom Centerline",
    cl = 25  # Set custom centerline to 25
  )

  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$title, "I-Chart with Custom Centerline")
})

test_that("create_spc_chart() validates cl parameter", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Non-numeric cl
  expect_error(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      cl = "not_a_number"
    ),
    "cl must be a single numeric value"
  )

  # Multiple values for cl
  expect_error(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      cl = c(20, 25)
    ),
    "cl must be a single numeric value"
  )

  # NA value for cl
  expect_error(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      cl = NA
    ),
    "cl must be a single numeric value"
  )
})

test_that("create_spc_chart() uses cl with phase splits", {
  library(ggplot2)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(
      rnorm(12, mean = 20, sd = 3), # Before intervention
      rnorm(12, mean = 15, sd = 2) # After intervention
    )
  )

  # Generate plot with custom centerline and phase split
  plot <- create_spc_chart(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Custom CL with Phase Split",
    cl = 18,
    part = c(12)
  )

  # Validate plot structure
  expect_s3_class(plot, "ggplot")
  expect_equal(plot$labels$title, "Custom CL with Phase Split")
})
