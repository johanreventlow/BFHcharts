# Integration Tests for BFHcharts
# End-to-end tests of full workflow from data to plot
# Skip on CI - requires BFHtheme fonts not available on CI
skip_on_ci()

test_that("bfh_qic() generates valid run chart", {
  library(ggplot2)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = c(15, 18, 12, 20, 16, 14, 19, 17, 13, 21, 18, 16)
  )

  plot <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Test Run Chart"
  )

  expect_valid_bfh_qic_result(plot)
  expect_equal(plot$plot$labels$title, "Test Run Chart")

  # Numerisk verifikation — fanger regressioner i beregning
  # Run-chart CL = median (ikke mean)
  expect_equal(plot$qic_data$cl[1], median(data$value), tolerance = 1e-6,
               label = "run-chart centerlinje = median(value)")
  expect_equal(nrow(plot$qic_data), 12,
               label = "qic_data har række pr. input-punkt")
})

test_that("bfh_qic() generates valid p-chart with denominator", {
  library(ggplot2)

  # Deterministisk data (ingen RNG) — infections/surgeries giver præcis p̄ = 0.05
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rep(5L, 12),
    surgeries = rep(100L, 12)
  )

  plot <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    n = surgeries,
    chart_type = "p",
    y_axis_unit = "percent",
    chart_title = "Infection Rate"
  )

  expect_valid_bfh_qic_result(plot)
  expect_equal(plot$plot$labels$title, "Infection Rate")

  # Numerisk: pooled proportion = 60/1200 = 0.05
  p_bar <- sum(data$infections) / sum(data$surgeries)
  expect_equal(plot$qic_data$cl[1], p_bar, tolerance = 1e-6,
               label = "p-chart centerlinje = pooled proportion")
})

test_that("bfh_qic() handles phase splits correctly", {
  library(ggplot2)

  # Deterministisk data med tydelig level-shift:
  # Baseline 20, post-intervention 15
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(
      rep(c(19, 20, 21), 4),       # Baseline: mean exakt 20
      rep(c(14, 15, 16), 4)        # Post: mean exakt 15
    )
  )

  plot <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Intervention Study",
    part = c(12)
  )

  expect_valid_bfh_qic_result(plot)

  # Numerisk: to faser, hver med specifik CL
  expect_equal(nrow(plot$summary), 2,
               label = "Summary har række pr. fase")
  cl_phase_1 <- unique(plot$qic_data$cl[1:12])
  cl_phase_2 <- unique(plot$qic_data$cl[13:24])
  expect_equal(cl_phase_1, 20, tolerance = 0.01,
               label = "Phase 1 CL = baseline mean (20)")
  expect_equal(cl_phase_2, 15, tolerance = 0.01,
               label = "Phase 2 CL = post-intervention mean (15)")
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

test_that("bfh_qic() handles target values correctly", {
  library(ggplot2)

  # Deterministisk data hvor median er præcis 100
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = c(95, 98, 100, 105, 97, 103, 100, 102, 96, 104, 99, 101)
  )

  plot <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Chart with Target",
    target_value = 95,
    target_text = "Target: 95"
  )

  expect_valid_bfh_qic_result(plot)
  # target_value skal bevares i config
  expect_equal(plot$config$target_value, 95,
               label = "target_value propageret til config")
  # Target-kolonne i qic_data skal have den angivne værdi
  if ("target" %in% names(plot$qic_data)) {
    expect_true(any(plot$qic_data$target == 95, na.rm = TRUE),
                info = "qic_data$target indeholder target_value=95")
  }
})

test_that("bfh_qic() validates input correctly", {
  # Test invalid chart type
  expect_error(
    bfh_qic(
      data = data.frame(x = 1:10, y = 1:10),
      x = x,
      y = y,
      chart_type = "invalid_type"
    ),
    "chart_type must be one of"
  )

  # Test invalid y_axis_unit
  expect_error(
    bfh_qic(
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

test_that("bfh_qic() handles exclude parameter correctly", {
  library(ggplot2)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = c(15, 18, 50, 20, 16, 14, 19, 17, 13, 21, 18, 16) # Point 3 is outlier
  )

  # Exclude outlier from calculations
  plot <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "I-Chart with Excluded Outlier",
    exclude = c(3)
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
  expect_equal(plot$plot$labels$title, "I-Chart with Excluded Outlier")
})

test_that("bfh_qic() handles multiply parameter correctly", {
  library(ggplot2)
  set.seed(42)

  # Data in proportions (0-1)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    proportion = runif(12, 0.01, 0.05) # Proportions 1-5%
  )

  # Convert to percentages (0-100)
  plot <- bfh_qic(
    data = data,
    x = month,
    y = proportion,
    chart_type = "i",
    y_axis_unit = "percent",
    chart_title = "Proportions as Percentages",
    multiply = 100
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
  expect_equal(plot$plot$labels$title, "Proportions as Percentages")
})

test_that("bfh_qic() handles agg.fun parameter correctly", {
  library(ggplot2)
  set.seed(42)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Use median aggregation
  plot_median <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "I-Chart with Median",
    agg.fun = "median"
  )

  expect_s3_class(plot_median, "bfh_qic_result")
  expect_s3_class(plot_median$plot, "ggplot")

  # Use sum aggregation
  plot_sum <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Run Chart with Sum",
    agg.fun = "sum"
  )

  expect_s3_class(plot_sum, "bfh_qic_result")
  expect_s3_class(plot_sum$plot, "ggplot")
})

test_that("bfh_qic() validates exclude parameter", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Invalid exclude position (out of bounds)
  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      exclude = c(15) # Only 12 rows
    ),
    "exclude positions must be positive integers within data bounds"
  )

  # Negative exclude position
  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      exclude = c(-1)
    ),
    "exclude positions must be positive integers"
  )
})

test_that("bfh_qic() validates multiply parameter", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Non-numeric multiply
  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      multiply = "hundred"
    ),
    "multiply must be a single positive number"
  )

  # Negative multiply
  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      multiply = -100
    ),
    "multiply must be a single positive number"
  )

  # Multiple values
  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      multiply = c(100, 200)
    ),
    "multiply must be a single positive number"
  )
})

test_that("bfh_qic() validates agg.fun parameter", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Invalid aggregation function
  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      agg.fun = "invalid_func"
    ),
    "'arg' should be one of"
  )
})

test_that("bfh_qic() combines new parameters correctly", {
  library(ggplot2)
  set.seed(42)

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
  plot <- bfh_qic(
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

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
  expect_equal(plot$plot$labels$title, "Combined Parameters Test")
})

test_that("bfh_qic() handles cl parameter correctly", {
  library(ggplot2)
  set.seed(42)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Use custom centerline value
  plot <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "I-Chart with Custom Centerline",
    cl = 25  # Set custom centerline to 25
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
  expect_equal(plot$plot$labels$title, "I-Chart with Custom Centerline")
})

test_that("bfh_qic() validates cl parameter", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 20, 5)
  )

  # Non-numeric cl
  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      cl = "not_a_number"
    ),
    "cl must be a single numeric value"
  )

  # Multiple values for cl
  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      cl = c(20, 25)
    ),
    "cl must be a single numeric value"
  )

  # NA value for cl
  expect_error(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      cl = NA
    ),
    "cl must be a single numeric value"
  )
})

test_that("bfh_qic() uses cl with phase splits", {
  library(ggplot2)
  set.seed(42)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(
      rnorm(12, mean = 20, sd = 3), # Before intervention
      rnorm(12, mean = 15, sd = 2) # After intervention
    )
  )

  # Generate plot with custom centerline and phase split
  plot <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Custom CL with Phase Split",
    cl = 18,
    part = c(12)
  )

  # Validate result structure (now returns bfh_qic_result)
  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
  expect_equal(plot$plot$labels$title, "Custom CL with Phase Split")
})
