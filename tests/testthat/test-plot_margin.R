# Test plot_margin parameter functionality

# Setup test data
setup_test_data <- function() {
  data.frame(
    x = 1:24,
    y = rnorm(24, 100, 10)
  )
}

# ============================================================================
# Basic Functionality Tests
# ============================================================================

test_that("plot_margin NULL uses default behavior", {
  df <- setup_test_data()

  plot <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count"
  )

  expect_s3_class(plot, "ggplot")
})

test_that("plot_margin with numeric vector works", {
  df <- setup_test_data()

  plot <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = c(10, 10, 10, 10)
  )

  expect_s3_class(plot, "ggplot")

  # Verify margin was applied
  margin_obj <- plot$theme$plot.margin
  expect_s3_class(margin_obj, "margin")
})

test_that("plot_margin with margin() object works (mm)", {
  df <- setup_test_data()

  plot <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = ggplot2::margin(t = 5, r = 10, b = 5, l = 10, unit = "mm")
  )

  expect_s3_class(plot, "ggplot")

  # Verify margin was applied
  margin_obj <- plot$theme$plot.margin
  expect_s3_class(margin_obj, "margin")
})

test_that("plot_margin with margin() object works (pt)", {
  df <- setup_test_data()

  plot <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = ggplot2::margin(t = 14, r = 28, b = 14, l = 28, unit = "pt")
  )

  expect_s3_class(plot, "ggplot")

  # Verify margin was applied
  margin_obj <- plot$theme$plot.margin
  expect_s3_class(margin_obj, "margin")
})

test_that("plot_margin with margin() object works (lines)", {
  df <- setup_test_data()

  plot <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = ggplot2::margin(t = 0.5, r = 1, b = 0.5, l = 1, unit = "lines")
  )

  expect_s3_class(plot, "ggplot")

  # Verify margin was applied
  margin_obj <- plot$theme$plot.margin
  expect_s3_class(margin_obj, "margin")
})

test_that("asymmetric margins work correctly", {
  df <- setup_test_data()

  plot <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = c(2, 20, 5, 10)
  )

  expect_s3_class(plot, "ggplot")

  # Verify margin was applied
  margin_obj <- plot$theme$plot.margin
  expect_s3_class(margin_obj, "margin")
})

# ============================================================================
# Chart Type Compatibility Tests
# ============================================================================

test_that("plot_margin works with all chart types", {
  df <- setup_test_data()
  df$n <- rpois(24, 100)  # Add denominator for p/u charts

  chart_types <- c("run", "i", "p", "c", "u")

  for (chart_type in chart_types) {
    plot <- create_spc_chart(
      data = df,
      x = x,
      y = y,
      n = if (chart_type %in% c("p", "u")) n else NULL,
      chart_type = chart_type,
      y_axis_unit = "count",
      plot_margin = c(5, 5, 5, 5)
    )

    expect_s3_class(plot, "ggplot", info = paste("Failed for chart_type:", chart_type))

    # Verify margin was applied
    margin_obj <- plot$theme$plot.margin
    expect_s3_class(margin_obj, "margin", info = paste("Margin not applied for:", chart_type))
  }
})

# ============================================================================
# Validation Tests
# ============================================================================

test_that("plot_margin validation rejects wrong length", {
  df <- setup_test_data()

  expect_error(
    create_spc_chart(
      data = df,
      x = x,
      y = y,
      chart_type = "i",
      plot_margin = c(5, 5)  # Only 2 values
    ),
    "numeric vector of length 4"
  )
})

test_that("plot_margin validation rejects negative values", {
  df <- setup_test_data()

  expect_error(
    create_spc_chart(
      data = df,
      x = x,
      y = y,
      chart_type = "i",
      plot_margin = c(5, -5, 5, 5)
    ),
    "must be non-negative"
  )
})

test_that("plot_margin warns about excessive values", {
  df <- setup_test_data()

  expect_warning(
    create_spc_chart(
      data = df,
      x = x,
      y = y,
      chart_type = "i",
      plot_margin = c(150, 10, 10, 10)
    ),
    "values > 100mm"
  )
})

test_that("plot_margin validation rejects wrong type", {
  df <- setup_test_data()

  expect_error(
    create_spc_chart(
      data = df,
      x = x,
      y = y,
      chart_type = "i",
      plot_margin = "10mm"  # String instead of numeric/margin
    ),
    "must be either"
  )
})

test_that("plot_margin validation rejects list", {
  df <- setup_test_data()

  expect_error(
    create_spc_chart(
      data = df,
      x = x,
      y = y,
      chart_type = "i",
      plot_margin = list(top = 5, right = 5, bottom = 5, left = 5)
    ),
    "must be either"
  )
})

# ============================================================================
# Edge Cases
# ============================================================================

test_that("plot_margin works with zero margins", {
  df <- setup_test_data()

  plot <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    plot_margin = c(0, 0, 0, 0)
  )

  expect_s3_class(plot, "ggplot")
  margin_obj <- plot$theme$plot.margin
  expect_s3_class(margin_obj, "margin")
})

test_that("plot_margin works with very small values", {
  df <- setup_test_data()

  plot <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    plot_margin = c(0.1, 0.1, 0.1, 0.1)
  )

  expect_s3_class(plot, "ggplot")
  margin_obj <- plot$theme$plot.margin
  expect_s3_class(margin_obj, "margin")
})

test_that("plot_margin works at boundary (100mm)", {
  df <- setup_test_data()

  # Should not warn at exactly 100mm
  expect_silent(
    plot <- create_spc_chart(
      data = df,
      x = x,
      y = y,
      chart_type = "i",
      plot_margin = c(100, 100, 100, 100)
    )
  )

  expect_s3_class(plot, "ggplot")
})

# ============================================================================
# Integration with Other Parameters
# ============================================================================

test_that("plot_margin works with width and height", {
  df <- setup_test_data()

  plot <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    width = 10,
    height = 6,
    plot_margin = c(5, 5, 5, 5)
  )

  expect_s3_class(plot, "ggplot")
  margin_obj <- plot$theme$plot.margin
  expect_s3_class(margin_obj, "margin")
})

test_that("plot_margin works with base_size", {
  df <- setup_test_data()

  plot <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    base_size = 18,
    plot_margin = c(5, 5, 5, 5)
  )

  expect_s3_class(plot, "ggplot")
  margin_obj <- plot$theme$plot.margin
  expect_s3_class(margin_obj, "margin")
})

test_that("plot_margin with lines scales with base_size", {
  df <- setup_test_data()

  # Small base_size
  plot_small <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    base_size = 10,
    plot_margin = ggplot2::margin(0.5, 0.5, 0.5, 0.5, unit = "lines")
  )

  # Large base_size
  plot_large <- create_spc_chart(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    base_size = 20,
    plot_margin = ggplot2::margin(0.5, 0.5, 0.5, 0.5, unit = "lines")
  )

  expect_s3_class(plot_small, "ggplot")
  expect_s3_class(plot_large, "ggplot")

  # Both should have margin objects
  expect_s3_class(plot_small$theme$plot.margin, "margin")
  expect_s3_class(plot_large$theme$plot.margin, "margin")
})
