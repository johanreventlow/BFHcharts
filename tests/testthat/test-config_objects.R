# ============================================================================
# SPC_PLOT_CONFIG TESTS
# ============================================================================

test_that("spc_plot_config creates valid configuration object", {
  cfg <- spc_plot_config(
    chart_type = "run",
    y_axis_unit = "count"
  )

  expect_s3_class(cfg, "spc_plot_config")
  expect_true(is.list(cfg))
  expect_equal(cfg$chart_type, "run")
  expect_equal(cfg$y_axis_unit, "count")
})

test_that("spc_plot_config includes all parameters", {
  cfg <- spc_plot_config(
    chart_type = "p",
    y_axis_unit = "percent",
    target_value = 95,
    target_text = "Target: 95%",
    centerline_value = 90,
    chart_title = "Test Chart"
  )

  expect_equal(cfg$chart_type, "p")
  expect_equal(cfg$y_axis_unit, "percent")
  expect_equal(cfg$target_value, 95)
  expect_equal(cfg$target_text, "Target: 95%")
  expect_equal(cfg$centerline_value, 90)
  expect_equal(cfg$chart_title, "Test Chart")
})

test_that("spc_plot_config uses default values", {
  cfg <- spc_plot_config()

  expect_equal(cfg$chart_type, "run")
  expect_equal(cfg$y_axis_unit, "count")
  expect_null(cfg$target_value)
  expect_null(cfg$target_text)
  expect_null(cfg$centerline_value)
  expect_null(cfg$chart_title)
})

test_that("spc_plot_config errors on invalid chart_type", {
  expect_error(
    spc_plot_config(chart_type = "invalid_type"),
    "Invalid chart_type",
    class = "bfhcharts_config_error"
  )

  expect_error(
    spc_plot_config(chart_type = "xyz"),
    "Valid types are",
    class = "bfhcharts_config_error"
  )
})

test_that("spc_plot_config accepts all valid chart types", {
  valid_types <- CHART_TYPES_EN

  for (type in valid_types) {
    expect_no_warning(
      cfg <- spc_plot_config(chart_type = type)
    )
    expect_equal(cfg$chart_type, type)
  }
})

test_that("spc_plot_config errors on invalid y_axis_unit", {
  expect_error(
    spc_plot_config(y_axis_unit = "invalid_unit"),
    "Invalid y_axis_unit",
    class = "bfhcharts_config_error"
  )

  expect_error(
    spc_plot_config(y_axis_unit = "meters"),
    "Valid units are",
    class = "bfhcharts_config_error"
  )
})

test_that("spc_plot_config accepts all valid y_axis units", {
  valid_units <- c("count", "percent", "rate", "time")

  for (unit in valid_units) {
    expect_no_warning(
      cfg <- spc_plot_config(y_axis_unit = unit)
    )
    expect_equal(cfg$y_axis_unit, unit)
  }
})

test_that("spc_plot_config validates target_value is numeric", {
  cfg <- spc_plot_config(target_value = 50)
  expect_equal(cfg$target_value, 50)

  expect_error(
    spc_plot_config(target_value = "fifty"),
    "target_value",
    class = "bfhcharts_config_error"
  )

  expect_error(
    spc_plot_config(target_value = NA_real_),
    "target_value",
    class = "bfhcharts_config_error"
  )

  expect_error(
    spc_plot_config(target_value = Inf),
    "target_value",
    class = "bfhcharts_config_error"
  )
})

test_that("print.spc_plot_config displays configuration", {
  cfg <- spc_plot_config(
    chart_type = "p",
    y_axis_unit = "percent",
    target_value = 95
  )

  output <- capture.output(print(cfg))

  expect_true(any(grepl("SPC Plot Configuration", output)))
  expect_true(any(grepl("Chart Type.*p", output)))
  expect_true(any(grepl("Y-Axis Unit.*percent", output)))
  expect_true(any(grepl("Target Value.*95", output)))
})

test_that("print.spc_plot_config returns object invisibly", {
  cfg <- spc_plot_config()

  result <- withVisible(print(cfg))

  expect_false(result$visible)
  expect_identical(result$value, cfg)
})

# ============================================================================
# VIEWPORT_DIMS TESTS
# ============================================================================

test_that("viewport_dims creates valid configuration object", {
  vp <- viewport_dims()

  expect_s3_class(vp, "viewport_dims")
  expect_true(is.list(vp))
  expect_equal(vp$base_size, 14)
})

test_that("viewport_dims includes all parameters", {
  vp <- viewport_dims(width = 1200, height = 800, base_size = 18)

  expect_equal(vp$width, 1200)
  expect_equal(vp$height, 800)
  expect_equal(vp$base_size, 18)
})

test_that("viewport_dims uses default values", {
  vp <- viewport_dims()

  expect_null(vp$width)
  expect_null(vp$height)
  expect_equal(vp$base_size, 14)
})

test_that("viewport_dims validates width is positive", {
  vp <- viewport_dims(width = 1000)
  expect_equal(vp$width, 1000)

  expect_error(
    viewport_dims(width = 0),
    "positive",
    class = "bfhcharts_config_error"
  )

  expect_error(
    viewport_dims(width = -100),
    "positive",
    class = "bfhcharts_config_error"
  )

  expect_error(
    viewport_dims(width = "large"),
    "positive",
    class = "bfhcharts_config_error"
  )

  expect_error(
    viewport_dims(width = NA_real_),
    "positive",
    class = "bfhcharts_config_error"
  )
})

test_that("viewport_dims validates height is positive", {
  vp <- viewport_dims(height = 600)
  expect_equal(vp$height, 600)

  expect_error(
    viewport_dims(height = 0),
    "positive",
    class = "bfhcharts_config_error"
  )

  expect_error(
    viewport_dims(height = -50),
    "positive",
    class = "bfhcharts_config_error"
  )

  expect_error(
    viewport_dims(height = NA_real_),
    "positive",
    class = "bfhcharts_config_error"
  )
})

test_that("viewport_dims validates base_size is positive", {
  vp <- viewport_dims(base_size = 16)
  expect_equal(vp$base_size, 16)

  expect_error(
    viewport_dims(base_size = 0),
    "base_size",
    class = "bfhcharts_config_error"
  )

  expect_error(
    viewport_dims(base_size = -10),
    "base_size",
    class = "bfhcharts_config_error"
  )

  expect_error(
    viewport_dims(base_size = "large"),
    "base_size",
    class = "bfhcharts_config_error"
  )

  expect_error(
    viewport_dims(base_size = NA_real_),
    "base_size",
    class = "bfhcharts_config_error"
  )
})

test_that("print.viewport_dims displays configuration", {
  vp <- viewport_dims(width = 1000, height = 600, base_size = 16)

  output <- capture.output(print(vp))

  expect_true(any(grepl("Viewport Dimensions", output)))
  expect_true(any(grepl("Width.*1000", output)))
  expect_true(any(grepl("Height.*600", output)))
  expect_true(any(grepl("Base Size.*16", output)))
})

test_that("print.viewport_dims shows 'Auto' for NULL dimensions", {
  vp <- viewport_dims()

  output <- capture.output(print(vp))

  expect_true(any(grepl("Width.*Auto", output)))
  expect_true(any(grepl("Height.*Auto", output)))
})

test_that("print.viewport_dims returns object invisibly", {
  vp <- viewport_dims()

  result <- withVisible(print(vp))

  expect_false(result$visible)
  expect_identical(result$value, vp)
})

# ============================================================================
# PHASE_CONFIG TESTS
# ============================================================================

test_that("phase_config creates valid configuration object", {
  pc <- phase_config()

  expect_s3_class(pc, "phase_config")
  expect_true(is.list(pc))
})

test_that("phase_config includes all parameters", {
  pc <- phase_config(
    part_positions = c(15, 30, 45),
    freeze_position = 15
  )

  expect_equal(pc$part_positions, c(15, 30, 45))
  expect_equal(pc$freeze_position, 15)
})

test_that("phase_config uses default NULL values", {
  pc <- phase_config()

  expect_null(pc$part_positions)
  expect_null(pc$freeze_position)
})

test_that("phase_config validates part_positions are positive", {
  pc <- phase_config(part_positions = c(10, 20, 30))
  expect_equal(pc$part_positions, c(10, 20, 30))

  pc <- phase_config(part_positions = 15)
  expect_equal(pc$part_positions, 15)

  expect_error(
    phase_config(part_positions = c(10, 0, 20)),
    "part_positions",
    class = "bfhcharts_config_error"
  )

  expect_error(
    phase_config(part_positions = c(10, -5)),
    "part_positions",
    class = "bfhcharts_config_error"
  )

  expect_error(
    phase_config(part_positions = "ten"),
    "part_positions",
    class = "bfhcharts_config_error"
  )

  expect_error(
    phase_config(part_positions = NA_integer_),
    "part_positions",
    class = "bfhcharts_config_error"
  )
})

test_that("phase_config validates freeze_position is positive", {
  pc <- phase_config(freeze_position = 20)
  expect_equal(pc$freeze_position, 20)

  expect_error(
    phase_config(freeze_position = 0),
    "freeze_position",
    class = "bfhcharts_config_error"
  )

  expect_error(
    phase_config(freeze_position = -10),
    "freeze_position",
    class = "bfhcharts_config_error"
  )

  expect_error(
    phase_config(freeze_position = NA_real_),
    "freeze_position",
    class = "bfhcharts_config_error"
  )
})

test_that("print.phase_config displays configuration", {
  pc <- phase_config(
    part_positions = c(15, 30),
    freeze_position = 15
  )

  output <- capture.output(print(pc))

  expect_true(any(grepl("Phase Configuration", output)))
  expect_true(any(grepl("Part Positions.*15.*30", output)))
  expect_true(any(grepl("Freeze Position.*15", output)))
})

test_that("print.phase_config shows NULL for empty values", {
  pc <- phase_config()

  output <- capture.output(print(pc))

  expect_true(any(grepl("Part Positions.*NULL", output)))
  expect_true(any(grepl("Freeze Position.*NULL", output)))
})

test_that("print.phase_config returns object invisibly", {
  pc <- phase_config()

  result <- withVisible(print(pc))

  expect_false(result$visible)
  expect_identical(result$value, pc)
})

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_that("Configuration objects can be used together", {
  # Create all three config objects
  plot_cfg <- spc_plot_config(chart_type = "p", y_axis_unit = "percent")
  viewport <- viewport_dims(width = 1000, height = 600, base_size = 16)
  phases <- phase_config(part_positions = 20)

  # All should be valid
  expect_s3_class(plot_cfg, "spc_plot_config")
  expect_s3_class(viewport, "viewport_dims")
  expect_s3_class(phases, "phase_config")

  # Should have correct values
  expect_equal(plot_cfg$chart_type, "p")
  expect_equal(viewport$width, 1000)
  expect_equal(phases$part_positions, 20)
})

test_that("Configuration objects work in bfh_qic", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2),
    total = rpois(12, 100)
  )

  # Create plot with configured objects
  plot <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      n = total,
      chart_type = "p",
      y_axis_unit = "percent",
      base_size = 16
    )
  )

  # Plot should be created successfully
  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
})
