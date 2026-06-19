# Direct unit tests for R/utils_panel_measurement.R
#
# utils_panel_measurement.R contains measure_panel_height_from_gtable() and
# with_temporary_device(). These functions were previously only covered
# transitively (via add_right_labels_marquee integration tests).
#
# Device-dependent tests use skip_on_cran() because they open graphics
# devices, which is not available in CRAN check environments.

# Helper: build a minimal valid gtable via ggplotGrob
make_minimal_gtable <- function() {
  p <- ggplot2::ggplot(
    data.frame(x = 1:5, y = 1:5),
    ggplot2::aes(x = x, y = y)
  ) +
    ggplot2::geom_point()
  ggplot2::ggplotGrob(p)
}

# Helper: build a gtable with the panel grob renamed so no row is named "panel"
make_no_panel_gtable <- function() {
  g <- make_minimal_gtable()
  g$layout$name[g$layout$name == "panel"] <- "not_a_panel"
  g
}

# -----------------------------------------------------------------------
# Happy path: returns a positive numeric height
# -----------------------------------------------------------------------

test_that("measure_panel_height_from_gtable returns positive numeric on valid gtable", {
  skip_on_cran()

  g <- make_minimal_gtable()
  result <- BFHcharts:::measure_panel_height_from_gtable(g, device_width = 7, device_height = 7)

  expect_type(result, "double")
  expect_true(is.finite(result))
  expect_gt(result, 0)
  expect_lte(result, 7) # cannot exceed device height
})

# -----------------------------------------------------------------------
# Fallback floor: when fixed rows consume all height, result is >= 0.1
# -----------------------------------------------------------------------

test_that("measure_panel_height_from_gtable floor is 0.1 when device_height is near zero", {
  skip_on_cran()

  g <- make_minimal_gtable()

  # Open a real device so device_ready = TRUE path works without trying to
  # open a 0.001-inch device (cairo_pdf would error on that).
  tmp <- tempfile(fileext = ".pdf")
  grDevices::cairo_pdf(tmp, width = 7, height = 7)
  on.exit({
    tryCatch(grDevices::dev.off(), error = function(e) NULL)
    unlink(tmp, force = TRUE)
  })

  # device_height = 0.001 means device_height - fixed_total is very negative,
  # so max(0.1, ...) kicks in and returns the floor value.
  result <- BFHcharts:::measure_panel_height_from_gtable(
    g,
    device_width = 7,
    device_height = 0.001,
    device_ready = TRUE
  )

  expect_type(result, "double")
  expect_equal(result, 0.1)
})

# -----------------------------------------------------------------------
# Error on no-panel gtable: stop() is the documented behaviour
# -----------------------------------------------------------------------

test_that("measure_panel_height_from_gtable errors when gtable has no panel row", {
  skip_on_cran()

  g <- make_no_panel_gtable()
  expect_error(
    BFHcharts:::measure_panel_height_from_gtable(g),
    regexp = "panel"
  )
})

# -----------------------------------------------------------------------
# Error on out-of-range panel index
# -----------------------------------------------------------------------

test_that("measure_panel_height_from_gtable errors when panel index exceeds panel count", {
  skip_on_cran()

  g <- make_minimal_gtable()
  expect_error(
    BFHcharts:::measure_panel_height_from_gtable(g, panel = 99),
    regexp = "panel"
  )
})

# -----------------------------------------------------------------------
# NULL input errors immediately (no partial gtable parsing)
# -----------------------------------------------------------------------

test_that("measure_panel_height_from_gtable errors on NULL input", {
  expect_error(
    BFHcharts:::measure_panel_height_from_gtable(NULL)
  )
})

# -----------------------------------------------------------------------
# with_temporary_device: opens a device, runs code, restores device
# -----------------------------------------------------------------------

test_that("with_temporary_device restores the active device after use", {
  skip_on_cran()

  dev_before <- grDevices::dev.cur()

  result <- BFHcharts:::with_temporary_device(
    width_in = 7,
    height_in = 7,
    code = grDevices::dev.cur()
  )

  dev_after <- grDevices::dev.cur()

  # Device should be restored to pre-call state
  expect_equal(dev_after, dev_before)

  # The code block ran inside a different device
  expect_false(identical(result, dev_before))
})

test_that("with_temporary_device cleans up even when code errors", {
  skip_on_cran()

  dev_before <- grDevices::dev.cur()
  n_devices_before <- length(grDevices::dev.list())

  expect_error(
    BFHcharts:::with_temporary_device(
      width_in = 7,
      height_in = 7,
      code = stop("intentional error")
    )
  )

  dev_after <- grDevices::dev.cur()
  n_devices_after <- length(grDevices::dev.list())

  # No leaked device
  expect_equal(n_devices_after, n_devices_before)
  expect_equal(dev_after, dev_before)
})
