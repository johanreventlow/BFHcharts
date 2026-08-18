test_that("has_arrow_symbol detects Unicode arrow symbols", {
  # Unicode arrows should be detected (up and down)
  expect_true(has_arrow_symbol("\u2191")) # ↑
  expect_true(has_arrow_symbol("\u2193")) # ↓

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
  skip_if_fonts_unavailable()
  set.seed(42)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2)
  )

  # Test with bare < symbol (should suppress target line)
  # Must provide target_value for qicharts2 to create target column
  plot_less <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    target_text = "<",
    target_value = 15 # Provide target value
  )

  # Test with bare > symbol (should suppress target line)
  plot_greater <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    target_text = ">",
    target_value = 15 # Provide target value
  )

  # Test with Unicode arrow (should suppress target line)
  plot_arrow <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    target_text = "\u2193",
    target_value = 15 # Provide target value
  )

  # All should be valid bfh_qic_result objects
  expect_s3_class(plot_less, "bfh_qic_result")
  expect_s3_class(plot_greater, "bfh_qic_result")
  expect_s3_class(plot_arrow, "bfh_qic_result")

  # Extract ggplot objects from results
  plot_less_gg <- plot_less$plot
  plot_greater_gg <- plot_greater$plot
  plot_arrow_gg <- plot_arrow$plot

  # Verify plots are ggplot objects
  expect_s3_class(plot_less_gg, "ggplot")
  expect_s3_class(plot_greater_gg, "ggplot")
  expect_s3_class(plot_arrow_gg, "ggplot")

  # Build plots to access layers
  built_less <- ggplot2::ggplot_build(plot_less_gg)
  built_greater <- ggplot2::ggplot_build(plot_greater_gg)
  built_arrow <- ggplot2::ggplot_build(plot_arrow_gg)

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
  skip_if_fonts_unavailable()
  set.seed(42)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2)
  )

  # Test with <18 (should NOT suppress target line)
  plot_with_number <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    target_text = "<18",
    target_value = 18
  )

  expect_s3_class(plot_with_number, "bfh_qic_result")

  # Extract ggplot object
  plot_with_number_gg <- plot_with_number$plot
  expect_s3_class(plot_with_number_gg, "ggplot")

  # Build plot
  built <- ggplot2::ggplot_build(plot_with_number_gg)

  # Count line layers - should have 5 (data + centerline + target + cl extension + target extension)
  count_line_layers <- function(built_plot) {
    sum(sapply(built_plot$plot$layers, function(layer) {
      inherits(layer$geom, "GeomLine")
    }))
  }

  expect_equal(count_line_layers(built), 5)
})

test_that("Arrow renders when target_text is a bare arrow WITHOUT target_value", {
  # Regression test: indicators with only oensket_tendens set (retning uden
  # maal-vaerdi, fx BFHddl's abx_forbrug_j01g) send target_text = ">" or "<"
  # with NO target_value. Before the fix, add_spc_labels() gated its entire
  # arrow-parsing block on !is.na(target_value), so qic_data$target being
  # all-NA (qicharts2 never populates it without a numeric target) silently
  # suppressed the arrow -- even though target_text was parsed correctly in
  # isolation. The arrow's y-position is computed from NPC panel bounds, not
  # from target_value, so no numeric target should be required to render it.
  skip_if_fonts_unavailable()
  set.seed(42)

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2)
  )

  plot_up <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    target_text = ">" # No target_value supplied
  )
  plot_down <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count",
    target_text = "<" # No target_value supplied
  )

  expect_s3_class(plot_up, "bfh_qic_result")
  expect_s3_class(plot_down, "bfh_qic_result")

  # qic_data$target must indeed be all-NA in this scenario (confirms the
  # test actually exercises the target_value-absent path, not a false pass).
  expect_true(all(is.na(plot_up$qic_data$target %||% NA)))
  expect_true(all(is.na(plot_down$qic_data$target %||% NA)))

  expect_true(isTRUE(attr(plot_up$plot, "suppress_targetline")))
  expect_true(isTRUE(attr(plot_down$plot, "suppress_targetline")))
  expect_equal(attr(plot_up$plot, "arrow_type"), "up")
  expect_equal(attr(plot_down$plot, "arrow_type"), "down")
})
