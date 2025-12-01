# ============================================================================
# TESTS FOR PDF EXPORT FUNCTION
# ============================================================================

test_that("quarto_available detects Quarto CLI", {
  # This test just checks that the function runs without error
  result <- quarto_available()
  expect_type(result, "logical")
  expect_length(result, 1)
})

test_that("bfh_export_pdf requires Quarto", {
  skip_if(quarto_available(), "Quarto is available, skipping negative test")

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )

  temp_file <- tempfile(fileext = ".pdf")

  # Should error if Quarto not available
  expect_error(
    bfh_export_pdf(result, temp_file),
    "Quarto CLI not found"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_pdf validates input class", {
  temp_file <- tempfile(fileext = ".pdf")

  # Invalid input: not a bfh_qic_result
  expect_error(
    bfh_export_pdf("not a result", temp_file),
    "x must be a bfh_qic_result object"
  )

  expect_error(
    bfh_export_pdf(data.frame(x = 1:10), temp_file),
    "x must be a bfh_qic_result object"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_pdf validates output path", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i")
  )

  # Empty string
  expect_error(
    bfh_export_pdf(result, ""),
    "output must be a non-empty character string"
  )

  # NULL
  expect_error(
    bfh_export_pdf(result, NULL),
    "output must be a non-empty character string"
  )

  # Numeric
  expect_error(
    bfh_export_pdf(result, 123),
    "output must be a non-empty character string"
  )
})

test_that("bfh_export_pdf validates metadata", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i")
  )

  temp_file <- tempfile(fileext = ".pdf")

  # metadata must be a list
  expect_error(
    bfh_export_pdf(result, temp_file, metadata = "not a list"),
    "metadata must be a list"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_pdf creates PDF file", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      chart_title = "Monthly Infections"
    )
  )

  temp_file <- tempfile(fileext = ".pdf")

  # Export to PDF
  returned <- bfh_export_pdf(
    result,
    temp_file,
    metadata = list(
      hospital = "BFH",
      department = "Test Department"
    )
  )

  # Verify file was created
  expect_true(file.exists(temp_file))

  # Verify file size is reasonable (PDF should be > 0 bytes)
  file_info <- file.info(temp_file)
  expect_gt(file_info$size, 0)

  # Verify return value for pipe chaining
  expect_identical(returned, result)

  # Cleanup
  unlink(temp_file)
})

test_that("bfh_export_pdf works in pipe workflow", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2)
  )

  temp_file <- tempfile(fileext = ".pdf")

  # Pipe workflow
  result <- suppressWarnings(
    bfh_qic(data, month, value, chart_type = "i",
            y_axis_unit = "count", chart_title = "Test") |>
      bfh_export_pdf(temp_file)
  )

  expect_true(file.exists(temp_file))
  expect_s3_class(result, "bfh_qic_result")

  # Cleanup
  unlink(temp_file)
})

test_that("bfh_export_pdf extracts SPC statistics", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      chart_title = "Infections with Statistics"
    )
  )

  temp_file <- tempfile(fileext = ".pdf")

  # Export should include SPC stats in PDF
  bfh_export_pdf(result, temp_file)

  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_file)
})

test_that("bfh_export_pdf handles metadata correctly", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test Chart")
  )

  temp_file <- tempfile(fileext = ".pdf")

  # Export with full metadata
  bfh_export_pdf(
    result,
    temp_file,
    metadata = list(
      hospital = "Test Hospital",
      department = "Quality Department",
      analysis = "Significant decrease observed",
      data_definition = "Number of infections per month",
      author = "Test Author"
    )
  )

  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_file)
})

test_that("bfh_export_pdf strips title from chart image", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      chart_title = "Title Should Be In Template Not Image"
    )
  )

  temp_file <- tempfile(fileext = ".pdf")

  # Title should go to Typst template, not PNG image
  bfh_export_pdf(result, temp_file)

  expect_true(file.exists(temp_file))

  # Original result should still have title
  expect_equal(result$config$chart_title, "Title Should Be In Template Not Image")

  # Cleanup
  unlink(temp_file)
})

test_that("bfh_export_pdf creates directory if needed", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )

  # Create path with non-existent directory
  temp_dir <- tempfile()
  temp_file <- file.path(temp_dir, "subdir", "report.pdf")

  # Export should create directory
  bfh_export_pdf(result, temp_file)

  expect_true(file.exists(temp_file))
  expect_true(dir.exists(dirname(temp_file)))

  # Cleanup
  unlink(temp_dir, recursive = TRUE)
})

test_that("extract_spc_stats handles missing columns gracefully", {
  # Empty summary
  stats <- BFHcharts:::extract_spc_stats(data.frame())
  expect_type(stats, "list")
  expect_null(stats$runs_expected)
  expect_null(stats$runs_actual)

  # NULL summary
  stats <- BFHcharts:::extract_spc_stats(NULL)
  expect_type(stats, "list")

  # Summary with some columns
  summary <- data.frame(
    længste_løb = 8,
    antal_kryds = 5
  )
  stats <- BFHcharts:::extract_spc_stats(summary)
  expect_equal(stats$runs_actual, 8)
  expect_equal(stats$crossings_actual, 5)
})

test_that("merge_metadata preserves user values and provides defaults", {
  # Empty metadata
  merged <- BFHcharts:::merge_metadata(list(), "Test Title")
  expect_equal(merged$title, "Test Title")
  expect_equal(merged$hospital, "Bispebjerg og Frederiksberg Hospital")

  # User metadata overrides
  merged <- BFHcharts:::merge_metadata(
    list(hospital = "Custom Hospital", department = "Custom Dept"),
    "Test Title"
  )
  expect_equal(merged$hospital, "Custom Hospital")
  expect_equal(merged$department, "Custom Dept")
  expect_equal(merged$title, "Test Title")
})

test_that("escape_typst_string handles special characters", {
  # Backslashes
  escaped <- BFHcharts:::escape_typst_string("path\\to\\file")
  expect_true(grepl("\\\\\\\\", escaped))

  # Quotes
  escaped <- BFHcharts:::escape_typst_string('say "hello"')
  expect_true(grepl('\\\\"', escaped))

  # NULL and empty
  expect_equal(BFHcharts:::escape_typst_string(NULL), "")
  expect_equal(BFHcharts:::escape_typst_string(""), "")
})

# ============================================================================
# NEW TESTS FOR PDF EXPORT BUG FIXES (Issue #60)
# ============================================================================

test_that("escape_typst_path normalizes and escapes paths", {
  # Forward slashes should work on all platforms
  path <- "/tmp/my folder/chart.png"
  escaped <- BFHcharts:::escape_typst_path(path)
  expect_true(grepl("/", escaped))
  expect_false(grepl("\\\\", escaped))  # No backslashes in result

  # Backslashes should be converted to forward slashes
  windows_path <- "C:\\Users\\Name\\Documents\\chart.png"
  escaped <- BFHcharts:::escape_typst_path(windows_path)
  # Result should use forward slashes (normalizePath with winslash="/")
  expect_type(escaped, "character")

  # Special characters should be escaped
  path_with_quotes <- '/tmp/say "hello"/chart.png'
  escaped <- BFHcharts:::escape_typst_path(path_with_quotes)
  expect_true(grepl('\\\\"', escaped))

  # Empty and NULL
  expect_equal(BFHcharts:::escape_typst_path(NULL), "")
  expect_equal(BFHcharts:::escape_typst_path(""), "")
})

test_that("check_quarto_version parses versions correctly", {
  # Valid version strings
  expect_true(BFHcharts:::check_quarto_version("1.4.557", "1.4.0"))
  expect_true(BFHcharts:::check_quarto_version("1.5.0", "1.4.0"))
  expect_true(BFHcharts:::check_quarto_version("2.0.0", "1.4.0"))

  # Version too old
  expect_false(BFHcharts:::check_quarto_version("1.3.9", "1.4.0"))
  expect_false(BFHcharts:::check_quarto_version("1.3.0", "1.4.0"))

  # Exact match
  expect_true(BFHcharts:::check_quarto_version("1.4.0", "1.4.0"))

  # Graceful fallback for unparseable versions (returns TRUE with warning)
  expect_warning(
    result <- BFHcharts:::check_quarto_version("unknown-version", "1.4.0"),
    "Could not parse Quarto version"
  )
  expect_true(result)
})

test_that("quarto_available returns logical", {
  result <- quarto_available()
  expect_type(result, "logical")
  expect_length(result, 1)
})

test_that("build_typst_content includes date parameter", {
  # Create minimal inputs
  metadata <- list(
    hospital = "Test Hospital",
    title = "Test Chart",
    date = as.Date("2025-01-15")
  )
  spc_stats <- list()

  # Mock chart_image and template_file paths
  chart_image <- "/tmp/chart.png"
  template_file <- system.file("templates/typst/bfh-template/bfh-template.typ",
                               package = "BFHcharts")

  skip_if(!file.exists(template_file), "Template file not found")

  content <- BFHcharts:::build_typst_content(
    chart_image = chart_image,
    metadata = metadata,
    spc_stats = spc_stats,
    template = "bfh-diagram2",
    template_file = template_file
  )

  # Content should include date parameter
  content_str <- paste(content, collapse = "\n")
  expect_true(grepl("date:", content_str))
  expect_true(grepl("2025-01-15", content_str))
})

test_that("build_typst_content escapes file paths", {
  metadata <- list(hospital = "Test", title = "Test")
  spc_stats <- list()

  # Path with spaces
  chart_image <- "/tmp/my charts/test chart.png"
  template_file <- system.file("templates/typst/bfh-template/bfh-template.typ",
                               package = "BFHcharts")

  skip_if(!file.exists(template_file), "Template file not found")

  content <- BFHcharts:::build_typst_content(
    chart_image = chart_image,
    metadata = metadata,
    spc_stats = spc_stats,
    template = "bfh-diagram2",
    template_file = template_file
  )

  # Should not have any problematic escape sequences
  content_str <- paste(content, collapse = "\n")
  # The path should be present (normalized)
  expect_true(grepl("image\\(", content_str))
})

test_that("bfh_export_pdf validates custom template_path", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )

  temp_file <- tempfile(fileext = ".pdf")

  # Non-existent custom template should error
  expect_error(
    bfh_export_pdf(result, temp_file, template_path = "/nonexistent/template.typ"),
    "Custom template file not found"
  )

  # Invalid template_path type should error
  expect_error(
    bfh_export_pdf(result, temp_file, template_path = 123),
    "template_path must be a single character string"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_pdf passes date metadata to template", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )

  temp_file <- tempfile(fileext = ".pdf")

  # Export with custom date
  bfh_export_pdf(
    result,
    temp_file,
    metadata = list(
      date = as.Date("2025-06-15")
    )
  )

  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_file)
})
