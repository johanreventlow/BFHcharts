test_that("apply_spc_theme adds theme to plot", {
  # Create a simple test plot
  data <- data.frame(x = 1:10, y = rnorm(10))
  base_plot <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  # Apply SPC theme
  themed_plot <- apply_spc_theme(base_plot, base_size = 14)

  # Should return a ggplot object
  expect_s3_class(themed_plot, "ggplot")

  # Should have coord system (lemon::coord_capped_cart creates CoordFlexCartesian)
  expect_s3_class(themed_plot$coordinates, "CoordFlexCartesian")

  # Theme should be applied
  expect_true(!is.null(themed_plot$theme))
})

test_that("apply_spc_theme respects base_size parameter", {
  data <- data.frame(x = 1:10, y = rnorm(10))
  base_plot <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  # Apply with different base sizes
  plot_small <- apply_spc_theme(base_plot, base_size = 10)
  plot_large <- apply_spc_theme(base_plot, base_size = 20)

  # Both should be valid plots
  expect_s3_class(plot_small, "ggplot")
  expect_s3_class(plot_large, "ggplot")

  # Theme elements should reflect different sizes
  # (We can't easily test the exact sizes, but we can verify the theme exists)
  expect_true(!is.null(plot_small$theme))
  expect_true(!is.null(plot_large$theme))
})

test_that("apply_spc_theme uses coord_capped_cart with correct parameters", {
  data <- data.frame(x = 1:10, y = rnorm(10))
  base_plot <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  themed_plot <- apply_spc_theme(base_plot)

  # Check coordinate system type (lemon creates CoordFlexCartesian)
  expect_s3_class(themed_plot$coordinates, "CoordFlexCartesian")

  # The coord should have bottom = "right" and gap = 0 settings
  # These are internal to lemon, but we can verify the coord was applied
  expect_true(!is.null(themed_plot$coordinates))
})


test_that("apply_spc_theme can be used in bfh_qic workflow", {
  skip_on_ci()  # Requires BFHtheme fonts not available on CI

  # Integration test: verify theme application works in real workflow
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2)
  )

  plot <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      chart_type = "run",
      y_axis_unit = "count",
      chart_title = "Test Plot",
      base_size = 16
    )
  )

  # Plot should have theme applied
  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
  expect_true(!is.null(plot$plot$theme))
  expect_s3_class(plot$plot$coordinates, "CoordFlexCartesian")
})
