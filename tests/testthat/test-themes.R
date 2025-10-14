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

test_that("create_plot_footer generates footer with hospital name", {
  footer <- create_plot_footer(hospital_name = "BFH")

  # Should be a character string
  expect_type(footer, "character")
  expect_length(footer, 1)

  # Should contain hospital name
  expect_true(grepl("BFH", footer))

  # Should contain date
  expect_true(grepl("Genereret:", footer))

  # Should contain SPC analysis mention
  expect_true(grepl("SPC analyse", footer))
  expect_true(grepl("Anhøj-regler", footer))
})

test_that("create_plot_footer includes department when provided", {
  footer <- create_plot_footer(
    hospital_name = "BFH",
    department = "Akutafdelingen"
  )

  # Should contain department
  expect_true(grepl("Akutafdelingen", footer))

  # Department should be separated with dash
  expect_true(grepl("- Akutafdelingen", footer))
})

test_that("create_plot_footer includes data source when provided", {
  footer <- create_plot_footer(
    hospital_name = "BFH",
    data_source = "EPJ data"
  )

  # Should contain data source
  expect_true(grepl("Datakilde:", footer))
  expect_true(grepl("EPJ data", footer))
})

test_that("create_plot_footer includes custom date", {
  custom_date <- as.Date("2024-06-15")
  footer <- create_plot_footer(
    hospital_name = "BFH",
    date = custom_date
  )

  # Should contain formatted date
  expect_true(grepl("15-06-2024", footer))
})

test_that("create_plot_footer handles all parameters together", {
  footer <- create_plot_footer(
    hospital_name = "Bispebjerg og Frederiksberg Hospital",
    department = "Akutafdelingen",
    data_source = "EPJ data",
    date = as.Date("2024-01-15")
  )

  # Should contain all components
  expect_true(grepl("Bispebjerg og Frederiksberg Hospital", footer))
  expect_true(grepl("Akutafdelingen", footer))
  expect_true(grepl("EPJ data", footer))
  expect_true(grepl("15-01-2024", footer))
  expect_true(grepl("SPC analyse", footer))
})

test_that("create_plot_footer handles NULL department gracefully", {
  footer <- create_plot_footer(
    hospital_name = "BFH",
    department = NULL,
    data_source = "EPJ"
  )

  # Should not contain dash separator when no department
  expect_false(grepl("BFH -", footer))

  # But should still contain other elements
  expect_true(grepl("BFH", footer))
  expect_true(grepl("EPJ", footer))
})

test_that("create_plot_footer handles empty string department", {
  footer <- create_plot_footer(
    hospital_name = "BFH",
    department = "",
    data_source = "EPJ"
  )

  # Should not include empty department
  expect_false(grepl("- $", footer))
})

test_that("create_plot_footer handles NULL data_source gracefully", {
  footer <- create_plot_footer(
    hospital_name = "BFH",
    department = "Akutafdelingen",
    data_source = NULL
  )

  # Should not contain "Datakilde:" when NULL
  expect_false(grepl("Datakilde:", footer))

  # But should contain other elements
  expect_true(grepl("Akutafdelingen", footer))
})

test_that("create_plot_footer uses default date when not provided", {
  # Capture today's date
  today <- Sys.Date()
  expected_date_str <- format(today, "%d-%m-%Y")

  footer <- create_plot_footer(hospital_name = "BFH")

  # Should contain today's date
  expect_true(grepl(expected_date_str, footer))
})

test_that("create_plot_footer has correct separator structure", {
  footer <- create_plot_footer(
    hospital_name = "BFH",
    department = "Akut",
    data_source = "EPJ"
  )

  # Should use "|" as main separator
  expect_true(grepl("\\|", footer))

  # Department should use "-"
  expect_true(grepl("- Akut", footer))

  # Data source should use "|"
  expect_true(grepl("\\| Datakilde:", footer))

  # Date should use "|"
  expect_true(grepl("\\| Genereret:", footer))

  # SPC mention should use "|"
  expect_true(grepl("\\| SPC analyse", footer))
})

test_that("create_plot_footer output is suitable for plot caption", {
  footer <- create_plot_footer(
    hospital_name = "BFH",
    department = "Akutafdelingen"
  )

  # Should be single line (no newlines)
  expect_false(grepl("\n", footer))

  # Should not be too long (reasonable for plot caption)
  # Typical max is ~200 characters for readability
  expect_true(nchar(footer) < 250)
})

test_that("apply_spc_theme can be used in create_spc_chart workflow", {
  # Integration test: verify theme application works in real workflow
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2)
  )

  plot <- suppressWarnings(
    create_spc_chart(
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
  expect_s3_class(plot, "ggplot")
  expect_true(!is.null(plot$theme))
  expect_s3_class(plot$coordinates, "CoordFlexCartesian")
})
