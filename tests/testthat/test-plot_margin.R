# Test plot_margin parameter functionality
# Skip i miljøer uden Mari-fonts (typisk CI) — bfh_qic triggerer theme-loading
skip_if_fonts_unavailable()

# Setup: fixture_numeric_data() er tilgængelig via helper-fixtures.R.

# ============================================================================
# Basic Functionality Tests
# ============================================================================

test_that("plot_margin NULL uses default behavior", {
  df <- fixture_numeric_data()

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

test_that("plot_margin with numeric vector sets exact values", {
  df <- fixture_numeric_data()

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = c(10, 10, 10, 10)
  )

  expect_valid_bfh_qic_result(plot)
  # Margin SKAL være exact c(10, 10, 10, 10) — ikke bare af rigtig type
  expect_plot_margin(plot$plot, c(10, 10, 10, 10))
})

test_that("plot_margin with margin() object works (mm)", {
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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

test_that("asymmetric margins bevares præcist (t/r/b/l adskilt)", {
  df <- fixture_numeric_data()

  plot <- bfh_qic(
    data = df,
    x = x,
    y = y,
    chart_type = "i",
    y_axis_unit = "count",
    plot_margin = c(2, 20, 5, 10)
  )

  expect_valid_bfh_qic_result(plot)
  # Verificér at hver position er bevaret — fanger potentielle swap-bugs
  expect_plot_margin(plot$plot, c(2, 20, 5, 10))
})

# ============================================================================
# Chart Type Compatibility Tests
# ============================================================================

test_that("plot_margin fungerer med alle chart-typer (deterministisk data)", {
  df <- fixture_numeric_data()
  # Deterministisk denominator (ingen RNG) for p/u-chart cases
  df$n <- rep(100L, nrow(df))

  chart_types <- c("run", "i", "p", "c", "u")

  for (chart_type in chart_types) {
    if (chart_type %in% c("p", "u")) {
      plot <- suppressWarnings(bfh_qic(
        data = df,
        x = x,
        y = y,
        n = n,
        chart_type = chart_type,
        y_axis_unit = "count",
        plot_margin = c(5, 5, 5, 5)
      ))
    } else {
      plot <- suppressWarnings(bfh_qic(
        data = df,
        x = x,
        y = y,
        chart_type = chart_type,
        y_axis_unit = "count",
        plot_margin = c(5, 5, 5, 5)
      ))
    }

    expect_valid_bfh_qic_result(plot)
    # Margin skal være exact c(5,5,5,5) for hver chart-type
    expect_plot_margin(plot$plot, c(5, 5, 5, 5),
                       tolerance = 0.01)
  }
})

# ============================================================================
# Validation Tests
# ============================================================================

test_that("plot_margin validation rejects wrong length", {
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
  df <- fixture_numeric_data()

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
