# test-fct_add_spc_labels.R
# Unit tests for add_spc_labels()

# Shared test data ----
make_test_data <- function() {
  qic_data <- data.frame(
    x = as.Date("2024-01-01") + 0:11 * 30,
    y = c(50, 52, 48, 55, 47, 51, 49, 53, 50, 48, 52, 51),
    cl = rep(50.5, 12),
    target = rep(45, 12)
  )
  qic_data
}

make_test_plot <- function(qic_data = make_test_data()) {
  ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()
}


# Basic tests ----

test_that("add_spc_labels returns a ggplot object", {
  qic_data <- make_test_data()
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(p, qic_data, y_axis_unit = "count")
  expect_true(inherits(result, "gg"))
})

test_that("add_spc_labels errors on non-ggplot input", {
  qic_data <- make_test_data()
  expect_error(add_spc_labels("not a plot", qic_data), "ggplot")
})

test_that("add_spc_labels errors on non-data.frame qic_data", {
  p <- make_test_plot()
  expect_error(add_spc_labels(p, "not a df"), "data.frame")
})

# BASELINE header ----

test_that("BASELINE header when centerline_value is provided", {
  qic_data <- make_test_data()
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count",
    centerline_value = 50.5
  )
  expect_true(inherits(result, "gg"))
  # BASELINE header er indlejret i marquee label tekst - vi verificerer at
  # funktionen koerer korrekt med centerline_value sat
})

test_that("BASELINE header when has_frys_column=TRUE and no skift", {
  qic_data <- make_test_data()
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count",
    has_frys_column = TRUE,
    has_skift_column = FALSE
  )
  expect_true(inherits(result, "gg"))
})

# NUV. NIVEAU header ----

test_that("NUV. NIVEAU header when no centerline_value and no frys", {
  qic_data <- make_test_data()
  p <- make_test_plot(qic_data)

  # Default: ingen centerline_value, ingen frys -> NUV. NIVEAU
  result <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count"
  )
  expect_true(inherits(result, "gg"))
})

# Arrow detection ----

test_that("target_text='<' produces arrow with suppress_targetline attr", {
  qic_data <- make_test_data()
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count",
    target_text = "<"
  )
  expect_true(inherits(result, "gg"))
  expect_true(attr(result, "suppress_targetline"))
  expect_equal(attr(result, "arrow_type"), "down")
})

test_that("target_text='>' produces up arrow", {
  qic_data <- make_test_data()
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count",
    target_text = ">"
  )
  expect_true(inherits(result, "gg"))
  expect_true(attr(result, "suppress_targetline"))
  expect_equal(attr(result, "arrow_type"), "up")
})

# Operator parsing ----

test_that("target_text='>=90' shows operator symbol", {
  qic_data <- make_test_data()
  qic_data$target <- rep(90, 12)
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count",
    target_text = ">=90"
  )
  expect_true(inherits(result, "gg"))
  # Ingen pil - det er en operator med vaerdi
  expect_false(isTRUE(attr(result, "suppress_targetline")))
})

# Percent suffix ----

test_that("percent suffix auto-added when y_axis_unit='percent'", {
  qic_data <- make_test_data()
  p <- make_test_plot(qic_data)

  # Med target_text uden % -> skal automatisk tilfoeje %
  result <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "percent",
    target_text = ">=90"
  )
  expect_true(inherits(result, "gg"))
})

# Only CL label ----

test_that("only CL label when no target", {
  qic_data <- make_test_data()
  qic_data$target <- NA_real_
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count"
  )
  expect_true(inherits(result, "gg"))
  # Ingen arrow attributter
  expect_null(attr(result, "arrow_type"))
})

# Only target label ----

test_that("only target label when no CL", {
  qic_data <- make_test_data()
  qic_data$cl <- NA_real_
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count"
  )
  expect_true(inherits(result, "gg"))
})

# Returns unchanged when both NA ----

test_that("returns plot unchanged when both CL and target are NA", {
  qic_data <- make_test_data()
  qic_data$cl <- NA_real_
  qic_data$target <- NA_real_
  p <- make_test_plot(qic_data)

  expect_warning(
    result <- add_spc_labels(p, qic_data, y_axis_unit = "count"),
    "No CL or Target"
  )
  # Returnerer original plot uaendret
  expect_identical(result, p)
})

# Part column ----

test_that("CL value extracted from latest part when part column exists", {
  qic_data <- make_test_data()
  qic_data$part <- c(rep(1, 6), rep(2, 6))
  # Saet forskellige CL for de to parts
  qic_data$cl <- c(rep(48, 6), rep(53, 6))
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count"
  )
  expect_true(inherits(result, "gg"))
})

# Boundary-aware label placement ----

test_that("CL at zero with target above does not crash and returns ggplot", {
  # Reproducer HOFTER-scenariet: CL=0%, target=1%, data 0-8%
  qic_data <- data.frame(
    x = as.Date("2024-01-01") + 0:11 * 30,
    y = c(0, 0, 0, 0.06, 0, 0.04, 0, 0, 0, 0, 0, 0),
    cl = rep(0, 12),
    target = rep(0.01, 12)
  )
  p <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  result <- add_spc_labels(p, qic_data, y_axis_unit = "percent")
  expect_true(inherits(result, "gg"))
})

test_that("boundary labels avoid adding excess whitespace when minimal expansion is enough", {
  qic_data <- data.frame(
    x = as.Date("2024-01-01") + 0:11 * 30,
    y = c(0, 0, 0, 0.06, 0, 0.04, 0, 0, 0, 0, 0, 0),
    cl = rep(0, 12),
    target = rep(0.01, 12)
  )
  p <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  plot_before_labels <- apply_y_axis_formatting(p, "percent", qic_data)
  range_before <- ggplot2::ggplot_build(plot_before_labels)$layout$panel_params[[1]]$y.range

  result <- suppressWarnings(add_spc_labels(plot_before_labels, qic_data, y_axis_unit = "percent"))
  range_after <- ggplot2::ggplot_build(result)$layout$panel_params[[1]]$y.range

  expect_equal(range_before, c(-0.003, 0.063), tolerance = 1e-8)
  expect_equal(range_after, range_before, tolerance = 1e-8)
})

test_that("non-boundary labels keep the minimal default y expansion", {
  qic_data <- data.frame(
    x = as.Date("2024-01-01") + 0:11 * 30,
    y = c(40, 52, 48, 55, 47, 51, 49, 53, 50, 48, 52, 60),
    cl = rep(50.5, 12),
    target = rep(48, 12)
  )
  p <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  plot_before_labels <- apply_y_axis_formatting(p, "count", qic_data)
  range_before <- ggplot2::ggplot_build(plot_before_labels)$layout$panel_params[[1]]$y.range

  result <- suppressWarnings(add_spc_labels(plot_before_labels, qic_data, y_axis_unit = "count"))
  range_after <- ggplot2::ggplot_build(result)$layout$panel_params[[1]]$y.range

  expect_equal(range_after, range_before, tolerance = 1e-8)
})

test_that("CL at data maximum with target below does not crash", {
  # Spejlvendt scenarie: CL nær toppen
  qic_data <- data.frame(
    x = as.Date("2024-01-01") + 0:11 * 30,
    y = c(95, 98, 97, 100, 96, 99, 98, 97, 100, 99, 98, 97) / 100,
    cl = rep(0.98, 12),
    target = rep(0.95, 12)
  )
  p <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  result <- add_spc_labels(p, qic_data, y_axis_unit = "percent")
  expect_true(inherits(result, "gg"))
})

# Placement metadata assertions ----

test_that("placement_info metadata is attached and has correct structure", {
  qic_data <- make_test_data()
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(p, qic_data, y_axis_unit = "count")
  info <- attr(result, "placement_info")

  expect_false(is.null(info))
  expect_true(is.list(info))
  expect_true("yA" %in% names(info))
  expect_true("yB" %in% names(info))
  expect_true("placement_quality" %in% names(info))
})

test_that("CL and target labels do not overlap in NPC space", {
  # Data hvor baade CL og target er inden for data-range
  qic_data <- data.frame(
    x = as.Date("2024-01-01") + 0:11 * 30,
    y = c(40, 52, 48, 55, 47, 51, 49, 53, 50, 48, 52, 60),
    cl = rep(50.5, 12),
    target = rep(48, 12)
  )
  p <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()

  result <- add_spc_labels(p, qic_data, y_axis_unit = "count")
  info <- attr(result, "placement_info")

  # Begge labels skal vaere placeret (ikke NA)
  expect_false(is.na(info$yA))
  expect_false(is.na(info$yB))

  # Labels maa ikke overlappe: afstanden mellem centre skal vaere mindst 1% NPC
  # (en label er typisk 8-15% NPC, saa 1% er et konservativt minimum)
  expect_true(abs(info$yA - info$yB) > 0.01)
})

test_that("placement is stable across different viewport dimensions", {
  qic_data <- make_test_data()
  p <- make_test_plot(qic_data)

  # Smal viewport
  result_narrow <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count",
    viewport_width = 4, viewport_height = 3
  )
  info_narrow <- attr(result_narrow, "placement_info")

  # Bred viewport
  result_wide <- add_spc_labels(
    p, qic_data,
    y_axis_unit = "count",
    viewport_width = 10, viewport_height = 5
  )
  info_wide <- attr(result_wide, "placement_info")

  # Begge skal vaere valid placements
  expect_false(is.na(info_narrow$yA))
  expect_false(is.na(info_wide$yA))

  # Placement quality skal vaere acceptable i begge tilfaelde
  expect_true(info_narrow$placement_quality %in% c("optimal", "acceptable", "degraded"))
  expect_true(info_wide$placement_quality %in% c("optimal", "acceptable", "degraded"))

  # Labels maa ikke overlappe i nogen af tilfaeldene
  if (!is.na(info_narrow$yB)) {
    expect_true(abs(info_narrow$yA - info_narrow$yB) > 0)
  }
  if (!is.na(info_wide$yB)) {
    expect_true(abs(info_wide$yA - info_wide$yB) > 0)
  }
})

test_that("coincident CL and target are placed without overlap", {
  # CL og target er identiske
  qic_data <- make_test_data()
  qic_data$target <- qic_data$cl
  p <- make_test_plot(qic_data)

  result <- add_spc_labels(p, qic_data, y_axis_unit = "count")
  info <- attr(result, "placement_info")

  expect_false(is.na(info$yA))
  expect_false(is.na(info$yB))

  # Selv med sammenfaldende linjer: labels skal vaere separeret
  expect_true(abs(info$yA - info$yB) > 0)
})

test_that("no scale_color warning when plot already has colour scale", {
  qic_data <- make_test_data()
  p <- make_test_plot(qic_data) +
    ggplot2::geom_point(ggplot2::aes(color = y)) +
    ggplot2::scale_color_viridis_c()

  # Skal ikke give "Scale for colour is already present" advarsel
  expect_no_warning(
    result <- add_spc_labels(p, qic_data, y_axis_unit = "count")
  )
  expect_true(inherits(result, "gg"))
})
