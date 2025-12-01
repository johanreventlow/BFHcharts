# ============================================================================
# TESTS FOR bfh_qic_result S3 CLASS
# ============================================================================

test_that("new_bfh_qic_result creates valid S3 object", {
  # Create mock components
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  # Get bfh_qic_result object, then extract the plot
  result_obj <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      y_axis_unit = "count"
    )
  )

  plot <- result_obj$plot

  summary <- data.frame(
    fase = 1,
    centerlinje = 15.2,
    ucl = 20.5,
    lcl = 10.0
  )

  qic_data <- data.frame(
    x = data$month,
    y = data$infections,
    cl = 15.2,
    ucl = 20.5,
    lcl = 10.0
  )

  config <- list(
    chart_type = "run",
    chart_title = "Test Chart",
    y_axis_unit = "count"
  )

  # Create result object
  result <- new_bfh_qic_result(
    plot = plot,
    summary = summary,
    qic_data = qic_data,
    config = config
  )

  # Verify S3 class
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

test_that("new_bfh_qic_result validates inputs", {
  # Create valid components
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result_obj <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      y_axis_unit = "count"
    )
  )

  plot <- result_obj$plot

  summary <- data.frame(centerlinje = 15.2)
  qic_data <- data.frame(x = 1:10, y = 1:10)
  config <- list(chart_type = "run")

  # Test invalid plot
  expect_error(
    new_bfh_qic_result(
      plot = "not a plot",
      summary = summary,
      qic_data = qic_data,
      config = config
    ),
    "plot must be a ggplot object"
  )

  # Test invalid summary
  expect_error(
    new_bfh_qic_result(
      plot = plot,
      summary = "not a dataframe",
      qic_data = qic_data,
      config = config
    ),
    "summary must be a data.frame or tibble"
  )

  # Test invalid qic_data
  expect_error(
    new_bfh_qic_result(
      plot = plot,
      summary = summary,
      qic_data = "not a dataframe",
      config = config
    ),
    "qic_data must be a data.frame"
  )

  # Test invalid config
  expect_error(
    new_bfh_qic_result(
      plot = plot,
      summary = summary,
      qic_data = qic_data,
      config = "not a list"
    ),
    "config must be a list"
  )
})

test_that("print.bfh_qic_result displays plot", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result_obj <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      y_axis_unit = "count"
    )
  )

  plot <- result_obj$plot

  result <- new_bfh_qic_result(
    plot = plot,
    summary = data.frame(centerlinje = 15.2),
    qic_data = data.frame(x = 1:10, y = 1:10),
    config = list(chart_type = "run")
  )

  # Print should return invisibly for pipe chaining
  printed <- print(result)
  expect_identical(printed, result)
  expect_invisible(print(result))
})

test_that("plot.bfh_qic_result displays plot", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result_obj <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      y_axis_unit = "count"
    )
  )

  plot <- result_obj$plot

  result <- new_bfh_qic_result(
    plot = plot,
    summary = data.frame(centerlinje = 15.2),
    qic_data = data.frame(x = 1:10, y = 1:10),
    config = list(chart_type = "run")
  )

  # Plot should return the ggplot object invisibly
  plotted <- plot(result)
  expect_s3_class(plotted, "ggplot")
  expect_invisible(plot(result))
})

test_that("accessor functions work", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result_obj <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      y_axis_unit = "count"
    )
  )

  plot <- result_obj$plot

  result <- new_bfh_qic_result(
    plot = plot,
    summary = data.frame(centerlinje = 15.2),
    qic_data = data.frame(x = 1:10, y = 1:10),
    config = list(chart_type = "run")
  )

  # Direct accessors
  expect_s3_class(result$plot, "ggplot")
  expect_s3_class(result$summary, "data.frame")
  expect_s3_class(result$qic_data, "data.frame")
  expect_type(result$config, "list")

  # get_plot() function
  extracted_plot <- get_plot(result)
  expect_s3_class(extracted_plot, "ggplot")
  expect_identical(extracted_plot, result$plot)
})

test_that("is_bfh_qic_result identifies objects correctly", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result_obj <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "run",
      y_axis_unit = "count"
    )
  )

  plot <- result_obj$plot

  result <- new_bfh_qic_result(
    plot = plot,
    summary = data.frame(centerlinje = 15.2),
    qic_data = data.frame(x = 1:10, y = 1:10),
    config = list(chart_type = "run")
  )

  # Valid bfh_qic_result
  expect_true(is_bfh_qic_result(result))

  # Invalid objects
  expect_false(is_bfh_qic_result(plot))
  expect_false(is_bfh_qic_result(data.frame()))
  expect_false(is_bfh_qic_result(list()))
  expect_false(is_bfh_qic_result("string"))
})

test_that("get_plot validates input class", {
  expect_error(
    get_plot("not a result"),
    "x must be a bfh_qic_result object"
  )

  expect_error(
    get_plot(data.frame()),
    "x must be a bfh_qic_result object"
  )
})
