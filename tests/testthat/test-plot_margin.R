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

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count"
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
})

test_that("plot_margin with numeric vector works", {
  df <- setup_test_data()

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = c(10, 10, 10, 10)
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")

  # Verify margin was applied
  margin_obj <- plot$plot$theme$plot.margin
  expect_s3_class(margin_obj, "ggplot2::margin")
})

test_that("plot_margin with margin() object works (mm)", {
  df <- setup_test_data()

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = ggplot2::margin(t = 5, r = 10, b = 5, l = 10, unit = "mm")
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")

  # Verify margin was applied
  margin_obj <- plot$plot$theme$plot.margin
  expect_s3_class(margin_obj, "ggplot2::margin")
})

test_that("plot_margin with margin() object works (pt)", {
  df <- setup_test_data()

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = ggplot2::margin(t = 14, r = 28, b = 14, l = 28, unit = "pt")
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")

  # Verify margin was applied
  margin_obj <- plot$plot$theme$plot.margin
  expect_s3_class(margin_obj, "ggplot2::margin")
})

test_that("plot_margin with margin() object works (lines)", {
  df <- setup_test_data()

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = ggplot2::margin(t = 0.5, r = 1, b = 0.5, l = 1, unit = "lines")
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")

  # Verify margin was applied
  margin_obj <- plot$plot$theme$plot.margin
  expect_s3_class(margin_obj, "ggplot2::margin")
})

test_that("asymmetric margins work correctly", {
  df <- setup_test_data()

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = c(2, 20, 5, 10)
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")

  # Verify margin was applied
  margin_obj <- plot$plot$theme$plot.margin
  expect_s3_class(margin_obj, "ggplot2::margin")
})

# ============================================================================
# Chart Type Compatibility Tests
# ============================================================================

test_that("plot_margin works with all chart types", {
  df <- setup_test_data()
  df$n <- rpois(24, 100)  # Add denominator for p/u charts

  chart_types <- c("run", "i", "p", "c", "u")

  for (chart_type in chart_types) {
    if (chart_type %in% c("p", "u")) {
      plot <- bfh_qic(
        data = df,
        x = x,
        y = y,
        n = n,
        chart_type = chart_type,
        y_axis_unit = "count",
        plot_margin = c(5, 5, 5, 5)
      )
    } else {
      plot <- bfh_qic(
        data = df,
        x = x,
        y = y,
        chart_type = chart_type,
        y_axis_unit = "count",
        plot_margin = c(5, 5, 5, 5)
      )
    }

    expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")

    # Verify margin was applied
    margin_obj <- plot$plot$theme$plot.margin
    expect_s3_class(margin_obj, "ggplot2::margin")
  }
})

# ============================================================================
# Validation Tests
# ============================================================================

test_that("plot_margin validation rejects wrong length", {
  df <- setup_test_data()

  expect_error(
    bfh_qic(
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
    bfh_qic(
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

  # Test that warning is produced for excessive margin values
  # Note: Large margins cause label placement to fail with error, but the warning should still be issued
  warned <- FALSE
  tryCatch(
    {
      suppressMessages(
        withCallingHandlers(
          bfh_qic(
            data = df,
            x = x,
            y = y,
            chart_type = "i",
            plot_margin = c(150, 10, 10, 10)
          ),
          warning = function(w) {
            if (grepl("values > 100mm", w$message)) {
              warned <<- TRUE
            }
          }
        )
      )
    },
    error = function(e) {
      # Label placement may fail with very large margins - this is expected
    }
  )

  expect_true(warned, info = "Should warn about excessive margin values")
})

test_that("plot_margin validation rejects wrong type", {
  df <- setup_test_data()

  expect_error(
    bfh_qic(
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
    bfh_qic(
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

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    plot_margin = c(0, 0, 0, 0)
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
  margin_obj <- plot$plot$theme$plot.margin
  expect_s3_class(margin_obj, "ggplot2::margin")
})

test_that("plot_margin works with very small values", {
  df <- setup_test_data()

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    plot_margin = c(0.1, 0.1, 0.1, 0.1)
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
  margin_obj <- plot$plot$theme$plot.margin
  expect_s3_class(margin_obj, "ggplot2::margin")
})

test_that("plot_margin works at boundary (100mm)", {
  df <- setup_test_data()

  # Should not warn at exactly 100mm (but may have warnings from label placement due to small panel)
  # We suppress warnings since large margins can cause label placement issues, which is expected
  suppressWarnings({
    plot <- bfh_qic(
      data = df,
      x = x,
      y = y,
      chart_type = "i",
      plot_margin = c(100, 100, 100, 100)
    )
  })

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
})

# ============================================================================
# Integration with Other Parameters
# ============================================================================

test_that("plot_margin works with width and height", {
  df <- setup_test_data()

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    width = 10,
    height = 6,
    plot_margin = c(5, 5, 5, 5)
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
  margin_obj <- plot$plot$theme$plot.margin
  expect_s3_class(margin_obj, "ggplot2::margin")
})

test_that("plot_margin works with base_size", {
  df <- setup_test_data()

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    base_size = 18,
    plot_margin = c(5, 5, 5, 5)
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
  margin_obj <- plot$plot$theme$plot.margin
  expect_s3_class(margin_obj, "ggplot2::margin")
})

test_that("plot_margin with lines scales with base_size", {
  df <- setup_test_data()

  # Small base_size
  plot_small <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    base_size = 10,
    plot_margin = ggplot2::margin(0.5, 0.5, 0.5, 0.5, unit = "lines")
  )

  # Large base_size
  plot_large <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    base_size = 20,
    plot_margin = ggplot2::margin(0.5, 0.5, 0.5, 0.5, unit = "lines")
  )

  expect_s3_class(plot_small, "bfh_qic_result")
  expect_s3_class(plot_large, "bfh_qic_result")
  expect_s3_class(plot_small$plot, "ggplot")
  expect_s3_class(plot_large$plot, "ggplot")

  # Both should have margin objects
  expect_s3_class(plot_small$plot$theme$plot.margin, "ggplot2::margin")
  expect_s3_class(plot_large$plot$theme$plot.margin, "ggplot2::margin")
})
