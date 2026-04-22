# Unit Tests for bfh_spc_plot() - Core SPC Plot Rendering
# Tests the low-level plot generation function in R/plot_core.R
#
# Fixture: fixture_plot_qic_data() er tilgængelig via helper-fixtures.R.
# Skip på CI: BFHtheme bruger proprietære Mari-fonts som ikke findes i CI-miljøet.
skip_if_fonts_unavailable()

# ============================================================================
# 1. BASIC RENDERING
# ============================================================================

test_that("bfh_spc_plot() creates valid ggplot for i-chart", {
  qic_data <- fixture_plot_qic_data()
  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  # Skal have data

  expect_true(nrow(result$data) > 0)
})

test_that("bfh_spc_plot() creates valid ggplot for p-chart", {
  qic_data <- fixture_plot_qic_data()
  config <- spc_plot_config(chart_type = "p", y_axis_unit = "percent")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
})

test_that("bfh_spc_plot() creates valid ggplot for run chart", {
  # Run charts har typisk ingen UCL/LCL
  qic_data <- fixture_plot_qic_data(has_cl_limits = FALSE)
  config <- spc_plot_config(chart_type = "run", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
})

test_that("bfh_spc_plot() rejects non-data.frame input", {
  config <- spc_plot_config()
  viewport <- viewport_dims()

  expect_error(
    bfh_spc_plot("not a data frame", config, viewport),
    "qic_data must be a data frame"
  )
})

test_that("bfh_spc_plot() rejects data missing required columns", {
  bad_data <- data.frame(x = 1:5, y = 1:5)
  config <- spc_plot_config()
  viewport <- viewport_dims()

  expect_error(
    bfh_spc_plot(bad_data, config, viewport),
    "qic_data missing required columns"
  )
})

# ============================================================================
# 2. MISSING CONTROL LIMIT COLUMNS (run charts)
# ============================================================================

test_that("bfh_spc_plot() works without ucl/lcl columns", {
  qic_data <- fixture_plot_qic_data(has_cl_limits = FALSE)
  config <- spc_plot_config(chart_type = "run", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  # Ingen ribbon/UCL/LCL layers forventet
  layer_types <- vapply(result$layers, function(l) class(l$geom)[1], character(1))
  expect_false("GeomRibbon" %in% layer_types)
})

test_that("bfh_spc_plot() works with all-NA ucl/lcl", {
  qic_data <- fixture_plot_qic_data(has_cl_limits = TRUE)
  qic_data$ucl <- NA_real_
  qic_data$lcl <- NA_real_
  config <- spc_plot_config(chart_type = "run", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  # Ribbon skal springes over da alle UCL/LCL er NA
  layer_types <- vapply(result$layers, function(l) class(l$geom)[1], character(1))
  expect_false("GeomRibbon" %in% layer_types)
})

# ============================================================================
# 3. SIGMA.SIGNAL COLORING
# ============================================================================

test_that("sigma.signal points get different color", {
  signals <- rep(FALSE, 12)
  signals[c(4, 8)] <- TRUE # Punkt 4 og 8 er sigma signals
  qic_data <- fixture_plot_qic_data(sigma_signals = signals)
  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")

  # Tjek at point_colour er sat korrekt i data
  plot_data <- result$data
  blue <- BFHtheme::bfh_cols("hospital_blue")
  grey <- BFHtheme::bfh_cols("regionh_grey")

  expect_equal(unname(plot_data$point_colour[4]), unname(blue))
  expect_equal(unname(plot_data$point_colour[8]), unname(blue))
  expect_equal(unname(plot_data$point_colour[1]), unname(grey))
  expect_equal(unname(plot_data$point_colour[12]), unname(grey))
})

test_that("no sigma.signal column defaults to all grey", {
  qic_data <- fixture_plot_qic_data()
  qic_data$sigma.signal <- NULL # Fjern kolonnen
  config <- spc_plot_config(chart_type = "run", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  grey <- BFHtheme::bfh_cols("regionh_grey")
  expect_true(all(unname(result$data$point_colour) == unname(grey)))
})

# ============================================================================
# 4. ANHOEJ SIGNAL LINETYPE
# ============================================================================

test_that("anhoej.signal controls centerline linetype", {
  signals <- rep(FALSE, 12)
  signals[5:10] <- TRUE # Consecutive run
  qic_data <- fixture_plot_qic_data(anhoej_signals = signals)
  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")

  # Verify scale_linetype_manual layer er tilstede
  scales_list <- result$scales$scales
  has_linetype_scale <- any(vapply(scales_list, function(s) {
    "linetype" %in% s$aesthetics
  }, logical(1)))
  expect_true(has_linetype_scale)

  # Tjek at anhoej.signal kolonnen er bevaret
  expect_true("anhoej.signal" %in% names(result$data))
  expect_equal(sum(result$data$anhoej.signal), 6)
})

test_that("missing anhoej.signal column defaults to FALSE", {
  qic_data <- fixture_plot_qic_data()
  qic_data$anhoej.signal <- NULL
  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  expect_true(all(result$data$anhoej.signal == FALSE))
})

# ============================================================================
# 5. TARGET LINE
# ============================================================================

test_that("target line is drawn when target values present", {
  qic_data <- fixture_plot_qic_data(target_val = 55)
  config <- spc_plot_config(
    chart_type = "i",
    y_axis_unit = "count",
    target_value = 55
  )
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")

  # Tjek at target data er i plottet
  expect_true("target" %in% names(result$data))
  expect_true(all(result$data$target == 55))
})

test_that("target line not drawn when target is all NA", {
  qic_data <- fixture_plot_qic_data(target_val = NA_real_)
  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  # geom_line med target y aes er tilstede men tegner intet (na.rm = TRUE)
  expect_true(all(is.na(result$data$target)))
})

# ============================================================================
# 6. TARGET LINE SUPPRESSION (arrow symbols)
# ============================================================================

test_that("target line is suppressed when target_text has arrow symbol", {
  qic_data <- fixture_plot_qic_data(target_val = 55)
  config <- spc_plot_config(
    chart_type = "i",
    y_axis_unit = "count",
    target_value = 55,
    target_text = "\u2191 55" # Up arrow triggers suppression
  )
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")

  # Skal have faerre layers end uden arrow symbol
  # (target geom_line udeladt)
  config_no_arrow <- spc_plot_config(
    chart_type = "i",
    y_axis_unit = "count",
    target_value = 55,
    target_text = "Target: 55"
  )
  result_no_arrow <- bfh_spc_plot(qic_data, config_no_arrow, viewport)

  # Suppressed version har faerre layers (mangler target line)
  expect_true(length(result$layers) < length(result_no_arrow$layers))
})

test_that("target line not suppressed for normal target_text", {
  qic_data <- fixture_plot_qic_data(target_val = 55)
  config <- spc_plot_config(
    chart_type = "i",
    y_axis_unit = "count",
    target_value = 55,
    target_text = "Target: 55"
  )
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  # Target line layer skal vaere tilstede
  layer_count <- length(result$layers)
  expect_true(layer_count > 0)
})

# ============================================================================
# 7. NUMERIC X-AXIS
# ============================================================================

test_that("bfh_spc_plot() handles numeric x-axis correctly", {
  qic_data <- fixture_plot_qic_data(x_dates = FALSE)
  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  # x-vaerdierne er numeriske
  expect_true(is.numeric(result$data$x))
})

test_that("numeric x-axis generates valid plot without date formatting", {
  qic_data <- fixture_plot_qic_data(x_dates = FALSE, has_cl_limits = TRUE)
  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  # Plottet kan bygges (ggplot_build kaster ikke fejl)
  built <- ggplot2::ggplot_build(result)
  expect_true(!is.null(built))
})

# ============================================================================
# 8. PHASE HANDLING (multi-part)
# ============================================================================

test_that("bfh_spc_plot() renders multi-phase data correctly", {
  parts <- c(rep(1L, 6), rep(2L, 6))
  qic_data <- fixture_plot_qic_data(parts = parts)
  # Anden fase har andre kontrolgraenser
  qic_data$cl[7:12] <- 48
  qic_data$ucl[7:12] <- 56
  qic_data$lcl[7:12] <- 40

  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  # Data skal have 2 unikke parts
  expect_equal(length(unique(result$data$part)), 2)
})

test_that("bfh_spc_plot() renders 3 phases correctly", {
  parts <- c(rep(1L, 4), rep(2L, 4), rep(3L, 4))
  qic_data <- fixture_plot_qic_data(parts = parts)

  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  expect_equal(length(unique(result$data$part)), 3)
})

# ============================================================================
# 9. CHART TITLE AND LABELS
# ============================================================================

test_that("bfh_spc_plot() sets chart title correctly", {
  qic_data <- fixture_plot_qic_data()
  config <- spc_plot_config(
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Test Chart Title"
  )
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
  expect_equal(result$labels$title, "Test Chart Title")
})

test_that("bfh_spc_plot() handles NULL title", {
  qic_data <- fixture_plot_qic_data()
  config <- spc_plot_config(
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = NULL
  )
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(qic_data, config, viewport)

  expect_s3_class(result, "ggplot")
})

# ============================================================================
# 10. VIEWPORT SCALING
# ============================================================================

test_that("bfh_spc_plot() scales with different base_size", {
  qic_data <- fixture_plot_qic_data()
  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")

  result_small <- bfh_spc_plot(qic_data, config, viewport_dims(base_size = 10))
  result_large <- bfh_spc_plot(qic_data, config, viewport_dims(base_size = 20))

  expect_s3_class(result_small, "ggplot")
  expect_s3_class(result_large, "ggplot")
})

# ============================================================================
# 11. Y-AXIS UNIT TYPES
# ============================================================================

test_that("bfh_spc_plot() handles all y_axis_unit types", {
  qic_data <- fixture_plot_qic_data()
  viewport <- viewport_dims(base_size = 14)

  for (unit in c("count", "percent", "rate", "time")) {
    config <- spc_plot_config(chart_type = "i", y_axis_unit = unit)
    result <- bfh_spc_plot(qic_data, config, viewport)
    expect_s3_class(result, "ggplot")
  }
})

# ============================================================================
# 12. PLOT MARGIN
# ============================================================================

test_that("bfh_spc_plot() accepts custom plot_margin", {
  qic_data <- fixture_plot_qic_data()
  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(
    qic_data, config, viewport,
    plot_margin = c(5, 10, 5, 10)
  )

  expect_s3_class(result, "ggplot")
})

test_that("bfh_spc_plot() accepts ggplot2::margin() object", {
  qic_data <- fixture_plot_qic_data()
  config <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  viewport <- viewport_dims(base_size = 14)

  result <- bfh_spc_plot(
    qic_data, config, viewport,
    plot_margin = ggplot2::margin(5, 10, 5, 10, unit = "mm")
  )

  expect_s3_class(result, "ggplot")
})
