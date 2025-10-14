test_that("has_arrow_symbol detects Unicode arrow symbols", {
  # Unicode arrows should be detected (up and down)
  expect_true(has_arrow_symbol("\u2191"))  # ↑
  expect_true(has_arrow_symbol("\u2193"))  # ↓

  # Arrows with surrounding text
  expect_true(has_arrow_symbol("Mål: \u2193"))
  expect_true(has_arrow_symbol("\u2191 Target"))
})

test_that("has_arrow_symbol detects < and > symbols without numbers", {
  # Bare < and > should be detected (will be converted to arrows)
  expect_true(has_arrow_symbol("<"))
  expect_true(has_arrow_symbol(">"))

  # With trailing whitespace only (leading whitespace would fail ^< pattern)
  expect_true(has_arrow_symbol("< "))
  expect_true(has_arrow_symbol("<  "))
  expect_true(has_arrow_symbol(">  "))
})

test_that("has_arrow_symbol does NOT detect < and > with numbers", {
  # These should NOT be detected as arrows (they're comparison operators)
  expect_false(has_arrow_symbol("<18"))
  expect_false(has_arrow_symbol(">90"))
  expect_false(has_arrow_symbol("< 18"))
  expect_false(has_arrow_symbol("> 90"))
  expect_false(has_arrow_symbol("<=25"))
  expect_false(has_arrow_symbol(">=80"))
})

test_that("has_arrow_symbol handles edge cases", {
  # NULL and empty strings
  expect_false(has_arrow_symbol(NULL))
  expect_false(has_arrow_symbol(""))
  expect_false(has_arrow_symbol("   "))

  # Regular text without arrows
  expect_false(has_arrow_symbol("Target value"))
  expect_false(has_arrow_symbol("90%"))
  expect_false(has_arrow_symbol("18"))
})

test_that("Arrow symbol detection suppresses target line in plots", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2)
  )

  # Test with bare < symbol (should suppress target line)
  # Must provide target_value for qicharts2 to create target column
  plot_less <- suppressWarnings(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      chart_type = "run",
      y_axis_unit = "count",
      target_text = "<",
      target_value = 15  # Provide target value
    )
  )

  # Test with bare > symbol (should suppress target line)
  plot_greater <- suppressWarnings(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      chart_type = "run",
      y_axis_unit = "count",
      target_text = ">",
      target_value = 15  # Provide target value
    )
  )

  # Test with Unicode arrow (should suppress target line)
  plot_arrow <- suppressWarnings(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      chart_type = "run",
      y_axis_unit = "count",
      target_text = "\u2193",
      target_value = 15  # Provide target value
    )
  )

  # All should be valid ggplot objects
  expect_s3_class(plot_less, "ggplot")
  expect_s3_class(plot_greater, "ggplot")
  expect_s3_class(plot_arrow, "ggplot")

  # Build plots to access layers
  built_less <- ggplot2::ggplot_build(plot_less)
  built_greater <- ggplot2::ggplot_build(plot_greater)
  built_arrow <- ggplot2::ggplot_build(plot_arrow)

  # Count geom_line layers
  # Run chart with target line: data line (1) + centerline (1) + target line (1) + cl extension (1) + target extension (1) = 5
  # Run chart WITHOUT target line (arrows): data line (1) + centerline (1) + cl extension (1) = 3
  count_line_layers <- function(built_plot) {
    sum(sapply(built_plot$plot$layers, function(layer) {
      inherits(layer$geom, "GeomLine")
    }))
  }

  # All should have 3 line layers (no target line or target extension)
  expect_equal(count_line_layers(built_less), 3)
  expect_equal(count_line_layers(built_greater), 3)
  expect_equal(count_line_layers(built_arrow), 3)
})

test_that("Comparison operators with numbers do NOT suppress target line", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2)
  )

  # Test with <18 (should NOT suppress target line)
  plot_with_number <- suppressWarnings(
    create_spc_chart(
      data = data,
      x = month,
      y = value,
      chart_type = "run",
      y_axis_unit = "count",
      target_text = "<18",
      target_value = 18
    )
  )

  expect_s3_class(plot_with_number, "ggplot")

  # Build plot
  built <- ggplot2::ggplot_build(plot_with_number)

  # Count line layers - should have 5 (data + centerline + target + cl extension + target extension)
  count_line_layers <- function(built_plot) {
    sum(sapply(built_plot$plot$layers, function(layer) {
      inherits(layer$geom, "GeomLine")
    }))
  }

  expect_equal(count_line_layers(built), 5)
})
