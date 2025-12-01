# ============================================================================
# TESTS FOR PNG EXPORT FUNCTION
# ============================================================================

test_that("bfh_export_png creates PNG file", {
  skip_on_cran()

  # Create test data
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  # Create chart
  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      chart_title = "Test Chart"
    )
  )

  # Create temporary file path
  temp_file <- tempfile(fileext = ".png")

  # Export to PNG
  returned <- bfh_export_png(
    result,
    temp_file,
    width_mm = 200,
    height_mm = 120,
    dpi = 96
  )

  # Verify file was created
  expect_true(file.exists(temp_file))

  # Verify file size is reasonable (should be > 0 bytes)
  file_info <- file.info(temp_file)
  expect_gt(file_info$size, 0)

  # Verify return value for pipe chaining
  expect_identical(returned, result)
  expect_invisible(bfh_export_png(result, temp_file))

  # Cleanup
  unlink(temp_file)
})

test_that("bfh_export_png respects dimension parameters", {
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "run")
  )

  temp_file <- tempfile(fileext = ".png")

  # Export with specific dimensions
  bfh_export_png(
    result,
    temp_file,
    width_mm = 100,
    height_mm = 80,
    dpi = 150
  )

  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_file)
})

test_that("bfh_export_png works in pipe workflow", {
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2)
  )

  temp_file <- tempfile(fileext = ".png")

  # Pipe workflow
  result <- suppressWarnings(
    bfh_qic(data, month, value, chart_type = "i", y_axis_unit = "count") |>
      bfh_export_png(temp_file, width_mm = 150, height_mm = 100)
  )

  expect_true(file.exists(temp_file))
  expect_s3_class(result, "bfh_qic_result")

  # Cleanup
  unlink(temp_file)
})

test_that("bfh_export_png validates input class", {
  temp_file <- tempfile(fileext = ".png")

  # Invalid input: not a bfh_qic_result
  expect_error(
    bfh_export_png(
      "not a result",
      temp_file
    ),
    "x must be a bfh_qic_result object"
  )

  expect_error(
    bfh_export_png(
      data.frame(x = 1:10),
      temp_file
    ),
    "x must be a bfh_qic_result object"
  )

  # ggplot object (old return type) should also fail
  data <- data.frame(x = 1:10, y = 1:10)
  plot <- ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point()

  expect_error(
    bfh_export_png(plot, temp_file),
    "x must be a bfh_qic_result object"
  )

  # Cleanup (in case file was created)
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_png validates output path", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "run")
  )

  # Empty string
  expect_error(
    bfh_export_png(result, ""),
    "output must be a non-empty character string"
  )

  # NULL
  expect_error(
    bfh_export_png(result, NULL),
    "output must be a non-empty character string"
  )

  # Numeric
  expect_error(
    bfh_export_png(result, 123),
    "output must be a non-empty character string"
  )

  # Multiple paths
  expect_error(
    bfh_export_png(result, c("file1.png", "file2.png")),
    "output must be a non-empty character string"
  )
})

test_that("bfh_export_png validates dimensions", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "run")
  )

  temp_file <- tempfile(fileext = ".png")

  # Negative width
  expect_error(
    bfh_export_png(result, temp_file, width_mm = -100),
    "width_mm must be a positive number"
  )

  # Zero width
  expect_error(
    bfh_export_png(result, temp_file, width_mm = 0),
    "width_mm must be a positive number"
  )

  # Negative height
  expect_error(
    bfh_export_png(result, temp_file, height_mm = -50),
    "height_mm must be a positive number"
  )

  # Non-numeric width
  expect_error(
    bfh_export_png(result, temp_file, width_mm = "200"),
    "width_mm must be a positive number"
  )

  # Multiple values
  expect_error(
    bfh_export_png(result, temp_file, width_mm = c(100, 200)),
    "width_mm must be a positive number"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_png validates DPI", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "run")
  )

  temp_file <- tempfile(fileext = ".png")

  # Negative DPI
  expect_error(
    bfh_export_png(result, temp_file, dpi = -96),
    "dpi must be a positive number"
  )

  # Zero DPI
  expect_error(
    bfh_export_png(result, temp_file, dpi = 0),
    "dpi must be a positive number"
  )

  # Non-numeric DPI
  expect_error(
    bfh_export_png(result, temp_file, dpi = "96"),
    "dpi must be a positive number"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_png warns on unusual dimensions", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "run")
  )

  temp_file <- tempfile(fileext = ".png")

  # Very large dimensions should warn
  expect_warning(
    bfh_export_png(result, temp_file, width_mm = 3000, height_mm = 2500),
    "Very large dimensions detected"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_png warns on unusual DPI", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "run")
  )

  temp_file <- tempfile(fileext = ".png")

  # Very low DPI should warn
  expect_warning(
    bfh_export_png(result, temp_file, dpi = 30),
    "Unusual DPI value"
  )

  # Very high DPI should warn
  expect_warning(
    bfh_export_png(result, temp_file, dpi = 1200),
    "Unusual DPI value"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_png creates directory if needed", {
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "run")
  )

  # Create path with non-existent directory
  temp_dir <- tempfile()
  temp_file <- file.path(temp_dir, "subdir", "chart.png")

  # Export should create directory
  bfh_export_png(result, temp_file)

  expect_true(file.exists(temp_file))
  expect_true(dir.exists(dirname(temp_file)))

  # Cleanup
  unlink(temp_dir, recursive = TRUE)
})

test_that("bfh_export_png preserves chart title in PNG", {
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data, month, infections,
      chart_type = "i",
      chart_title = "Test Title with Æ Ø Å"
    )
  )

  temp_file <- tempfile(fileext = ".png")
  bfh_export_png(result, temp_file)

  # Verify file exists (title is rendered in the PNG)
  expect_true(file.exists(temp_file))

  # Verify plot object has title
  expect_true(!is.null(result$plot$labels$title))
  expect_equal(result$plot$labels$title, "Test Title with Æ Ø Å")

  # Cleanup
  unlink(temp_file)
})
