# Tests for add_plot_enhancements()

make_base_plot <- function(qic_data) {
  ggplot2::ggplot(qic_data, ggplot2::aes(x, y)) +
    ggplot2::geom_line() +
    ggplot2::geom_point()
}

make_qic_data <- function(x) {
  data.frame(
    x = x,
    y = c(10, 12, 11, 13, 14),
    cl = rep(12, 5),
    target = rep(15, 5),
    part = rep(1, 5),
    ucl = rep(16, 5),
    lcl = rep(8, 5),
    stringsAsFactors = FALSE
  )
}

layer_geoms <- function(plot) {
  vapply(plot$layers, function(layer) class(layer$geom)[1], character(1))
}

test_that("add_plot_enhancements extends numeric CL and target lines by 20 percent", {
  qic_data <- make_qic_data(1:5)
  plot <- add_plot_enhancements(
    make_base_plot(qic_data),
    qic_data,
    comment_data = NULL
  )

  expect_equal(unname(layer_geoms(plot)), c("GeomLine", "GeomPoint", "GeomLine", "GeomLine"))

  cl_layer <- plot$layers[[3]]$data
  target_layer <- plot$layers[[4]]$data
  expected_x <- c(5, 5 + (5 - 1) * LINE_EXTENSION_FACTOR)

  expect_equal(cl_layer$type, c("cl", "cl"))
  expect_equal(target_layer$type, c("target", "target"))
  expect_equal(cl_layer$x, expected_x)
  expect_equal(target_layer$x, expected_x)
  expect_equal(cl_layer$y, c(12, 12))
  expect_equal(target_layer$y, c(15, 15))
})

test_that("add_plot_enhancements handles Date and POSIXct x values", {
  date_x <- seq(as.Date("2024-01-01"), by = "month", length.out = 5)
  date_data <- make_qic_data(date_x)
  date_plot <- add_plot_enhancements(
    make_base_plot(date_data),
    date_data,
    comment_data = NULL
  )

  date_cl <- date_plot$layers[[3]]$data
  date_target <- date_plot$layers[[4]]$data
  expect_s3_class(date_cl$x, "POSIXct")
  expect_equal(
    as.numeric(date_cl$x[2] - date_cl$x[1], units = "secs"),
    as.numeric(difftime(max(date_x), min(date_x), units = "secs")) * LINE_EXTENSION_FACTOR
  )
  expect_equal(date_cl$x, date_target$x)

  posix_x <- as.POSIXct("2024-01-01 00:00:00", tz = "UTC") + c(0, 86400, 172800, 259200, 345600)
  posix_data <- make_qic_data(posix_x)
  posix_plot <- add_plot_enhancements(
    make_base_plot(posix_data),
    posix_data,
    comment_data = NULL
  )

  posix_cl <- posix_plot$layers[[3]]$data
  expect_s3_class(posix_cl$x, "POSIXct")
  expect_equal(
    as.numeric(posix_cl$x[2] - posix_cl$x[1], units = "secs"),
    as.numeric(difftime(max(posix_x), min(posix_x), units = "secs")) * LINE_EXTENSION_FACTOR
  )
})

test_that("add_plot_enhancements does not add comment layers for empty comment data", {
  qic_data <- make_qic_data(1:5)
  empty_comments <- data.frame(x = numeric(0), y = numeric(0), comment = character(0))

  plot <- add_plot_enhancements(
    make_base_plot(qic_data),
    qic_data,
    comment_data = empty_comments
  )

  expect_equal(unname(layer_geoms(plot)), c("GeomLine", "GeomPoint", "GeomLine", "GeomLine"))
})

test_that("add_plot_enhancements adds curved arrows for diagonal comment labels", {
  qic_data <- data.frame(
    x = 1:6,
    y = c(10, 12, 11, 13, 14, 12),
    cl = rep(12, 6),
    target = rep(15, 6),
    part = rep(1, 6),
    ucl = rep(16, 6),
    lcl = rep(8, 6),
    stringsAsFactors = FALSE
  )
  comment_data <- data.frame(x = 3, y = 11, comment = "Intervention")

  plot <- suppressWarnings(add_plot_enhancements(
    make_base_plot(qic_data),
    qic_data,
    comment_data = comment_data,
    line_positions = c(cl = 12, ucl = 16, lcl = 8, target = 15)
  ))

  expect_equal(unname(layer_geoms(plot)), c("GeomLine", "GeomPoint", "GeomLine", "GeomLine", "GeomCurve", "GeomText"))

  curve_layer <- plot$layers[[5]]$data
  text_layer <- plot$layers[[6]]$data

  expect_equal(nrow(curve_layer), 1)
  expect_equal(curve_layer$label_text, "Intervention")
  expect_true(curve_layer$draw_arrow)
  expect_true(curve_layer$curvature != 0)
  expect_true(curve_layer$end_x != curve_layer$point_x || curve_layer$end_y != curve_layer$point_y)
  expect_equal(text_layer$label_text, "Intervention")
})

test_that("add_plot_enhancements shortens straight arrows before the data point", {
  qic_data <- data.frame(
    x = 1:6,
    y = c(10, 12, 11, 13, 14, 12),
    cl = rep(12, 6),
    target = rep(15, 6),
    part = rep(1, 6),
    ucl = rep(16, 6),
    lcl = rep(8, 6),
    stringsAsFactors = FALSE
  )
  comment_data <- data.frame(x = 2, y = 10, comment = "OK")

  plot <- suppressWarnings(add_plot_enhancements(
    make_base_plot(qic_data),
    qic_data,
    comment_data = comment_data,
    line_positions = c(cl = 12, ucl = 16, lcl = 8, target = 15)
  ))

  expect_equal(unname(layer_geoms(plot)), c("GeomLine", "GeomPoint", "GeomLine", "GeomLine", "GeomSegment", "GeomText"))

  segment_layer <- plot$layers[[5]]$data

  expect_equal(nrow(segment_layer), 1)
  expect_equal(segment_layer$curvature, 0)
  expect_true(segment_layer$draw_arrow)
  expect_equal(segment_layer$end_x, segment_layer$point_x)
  expect_gt(abs(segment_layer$end_y - segment_layer$point_y), 0)
  expect_lt(
    sqrt((segment_layer$end_x - segment_layer$point_x)^2 + (segment_layer$end_y - segment_layer$point_y)^2),
    sqrt((segment_layer$arrow_x - segment_layer$point_x)^2 + (segment_layer$arrow_y - segment_layer$point_y)^2)
  )
})
