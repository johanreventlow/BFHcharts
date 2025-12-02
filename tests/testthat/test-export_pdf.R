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
# PUBLIC API TESTS - bfh_extract_spc_stats() and bfh_merge_metadata()
# ============================================================================

test_that("bfh_extract_spc_stats extracts statistics from valid summary", {
  # Create valid summary data frame
  summary <- data.frame(
    længste_løb_max = 8,
    længste_løb = 6,
    antal_kryds_min = 10,
    antal_kryds = 12
  )

  stats <- bfh_extract_spc_stats(summary)

  # Verify structure
  expect_type(stats, "list")
  expect_named(stats, c("runs_expected", "runs_actual", "crossings_expected",
                        "crossings_actual", "outliers_expected", "outliers_actual"))

  # Verify values
  expect_equal(stats$runs_expected, 8)
  expect_equal(stats$runs_actual, 6)
  expect_equal(stats$crossings_expected, 10)
  expect_equal(stats$crossings_actual, 12)
  expect_null(stats$outliers_expected)
  expect_null(stats$outliers_actual)
})

test_that("bfh_extract_spc_stats handles NULL summary gracefully", {
  stats <- bfh_extract_spc_stats(NULL)

  # Should return list with all NULLs
  expect_type(stats, "list")
  expect_null(stats$runs_expected)
  expect_null(stats$runs_actual)
  expect_null(stats$crossings_expected)
  expect_null(stats$crossings_actual)
  expect_null(stats$outliers_expected)
  expect_null(stats$outliers_actual)
})

test_that("bfh_extract_spc_stats handles empty data frame gracefully", {
  stats <- bfh_extract_spc_stats(data.frame())

  # Should return list with all NULLs
  expect_type(stats, "list")
  expect_null(stats$runs_expected)
  expect_null(stats$runs_actual)
  expect_null(stats$crossings_expected)
  expect_null(stats$crossings_actual)
})

test_that("bfh_extract_spc_stats handles missing columns gracefully", {
  # Summary with only some columns
  summary <- data.frame(
    længste_løb = 6,
    antal_kryds = 12
  )

  stats <- bfh_extract_spc_stats(summary)

  # Should extract available columns
  expect_null(stats$runs_expected)  # Missing column
  expect_equal(stats$runs_actual, 6)  # Present
  expect_null(stats$crossings_expected)  # Missing column
  expect_equal(stats$crossings_actual, 12)  # Present
})

test_that("bfh_extract_spc_stats validates input type", {
  # Should error for non-data frame input
  expect_error(
    bfh_extract_spc_stats("not a data frame"),
    "summary must be a data frame or NULL"
  )

  expect_error(
    bfh_extract_spc_stats(123),
    "summary must be a data frame or NULL"
  )

  expect_error(
    bfh_extract_spc_stats(list(a = 1)),
    "summary must be a data frame or NULL"
  )
})

test_that("bfh_merge_metadata merges user metadata with defaults", {
  metadata <- list(
    department = "Kvalitetsafdeling",
    analysis = "Signifikant fald"
  )

  merged <- bfh_merge_metadata(metadata, chart_title = "Infektioner")

  # User values should override defaults
  expect_equal(merged$department, "Kvalitetsafdeling")
  expect_equal(merged$analysis, "Signifikant fald")

  # Defaults should be present
  expect_equal(merged$hospital, "Bispebjerg og Frederiksberg Hospital")
  expect_equal(merged$title, "Infektioner")
  expect_null(merged$details)
  expect_null(merged$author)
  expect_equal(merged$date, Sys.Date())
  expect_null(merged$data_definition)
})

test_that("bfh_merge_metadata handles empty metadata", {
  merged <- bfh_merge_metadata(list(), chart_title = "Test Chart")

  # Should return defaults only
  expect_equal(merged$hospital, "Bispebjerg og Frederiksberg Hospital")
  expect_equal(merged$title, "Test Chart")
  expect_null(merged$department)
  expect_null(merged$analysis)
  expect_null(merged$details)
  expect_null(merged$author)
  expect_equal(merged$date, Sys.Date())
  expect_null(merged$data_definition)
})

test_that("bfh_merge_metadata handles NULL metadata", {
  merged <- bfh_merge_metadata(NULL, chart_title = "Test Chart")

  # Should return defaults
  expect_equal(merged$hospital, "Bispebjerg og Frederiksberg Hospital")
  expect_equal(merged$title, "Test Chart")
})

test_that("bfh_merge_metadata handles NULL chart title", {
  # With metadata title
  metadata <- list(title = "Custom Title")
  merged <- bfh_merge_metadata(metadata, chart_title = NULL)
  expect_equal(merged$title, "Custom Title")

  # Without metadata title
  metadata <- list()
  merged <- bfh_merge_metadata(metadata, chart_title = NULL)
  expect_null(merged$title)
})

test_that("bfh_merge_metadata ignores unknown fields", {
  metadata <- list(
    department = "Valid Field",
    unknown_field = "Should be ignored",
    another_unknown = 123
  )

  merged <- bfh_merge_metadata(metadata, chart_title = "Test")

  # Valid field should be present
  expect_equal(merged$department, "Valid Field")

  # Unknown fields should be ignored
  expect_null(merged$unknown_field)
  expect_null(merged$another_unknown)
})

test_that("bfh_merge_metadata validates input type", {
  # Should error for non-list metadata
  expect_error(
    bfh_merge_metadata("not a list", "Title"),
    "metadata must be a list or NULL"
  )

  expect_error(
    bfh_merge_metadata(123, "Title"),
    "metadata must be a list or NULL"
  )

  expect_error(
    bfh_merge_metadata(data.frame(a = 1), "Title"),
    "metadata must be a list or NULL"
  )
})

test_that("bfh_merge_metadata all fields can be overridden", {
  metadata <- list(
    hospital = "Custom Hospital",
    department = "Custom Department",
    title = "Custom Title",
    analysis = "Custom Analysis",
    details = "Custom Details",
    author = "Custom Author",
    date = as.Date("2025-01-01"),
    data_definition = "Custom Definition"
  )

  merged <- bfh_merge_metadata(metadata, chart_title = "Ignored Title")

  # All fields should be overridden (including title from metadata)
  expect_equal(merged$hospital, "Custom Hospital")
  expect_equal(merged$department, "Custom Department")
  expect_equal(merged$title, "Custom Title")  # metadata title, not chart_title
  expect_equal(merged$analysis, "Custom Analysis")
  expect_equal(merged$details, "Custom Details")
  expect_equal(merged$author, "Custom Author")
  expect_equal(merged$date, as.Date("2025-01-01"))
  expect_equal(merged$data_definition, "Custom Definition")
})

test_that("internal functions delegate to public API", {
  # Verify that internal versions call public versions
  summary <- data.frame(
    længste_løb_max = 8,
    længste_løb = 6
  )

  # Internal function should give same result as public
  internal_result <- BFHcharts:::extract_spc_stats(summary)
  public_result <- bfh_extract_spc_stats(summary)

  expect_identical(internal_result, public_result)

  # Same for merge_metadata
  internal_merged <- BFHcharts:::merge_metadata(list(department = "Test"), "Title")
  public_merged <- bfh_merge_metadata(list(department = "Test"), "Title")

  expect_identical(internal_merged, public_merged)
})

# ============================================================================
# NEW TESTS FOR PDF EXPORT BUG FIXES (Issue #60)
# ============================================================================

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

  # Fail-safe for unparseable versions (returns FALSE with warning)
  expect_warning(
    result <- BFHcharts:::check_quarto_version("unknown-version", "1.4.0"),
    "Could not parse Quarto version"
  )
  expect_false(result)
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

# ============================================================================
# NEW TESTS FOR ISSUE #62 - Content Verification and Regressions
# ============================================================================

test_that("bfh_create_typst_document works with chart from different directory", {
  # Create chart in separate directory (simulating arbitrary path)
  chart_dir <- tempfile("chart_source_")
  dir.create(chart_dir)
  output_dir <- tempfile("typst_output_")
  dir.create(output_dir)

  chart_path <- file.path(chart_dir, "my_chart.png")
  png(chart_path, width = 400, height = 300)
  plot(1:10, main = "Test")
  dev.off()

  output_path <- file.path(output_dir, "document.typ")

  # This should work - chart is copied to output directory
  bfh_create_typst_document(
    chart_image = chart_path,
    output = output_path,
    metadata = list(title = "Test Chart", hospital = "Test Hospital"),
    spc_stats = list(),
    template = "bfh-diagram2"
  )

  # Verify document was created
  expect_true(file.exists(output_path))

  # Verify chart was copied to output directory
  expect_true(file.exists(file.path(output_dir, "my_chart.png")))

  # Verify Typst content uses relative path (not absolute)
  content <- paste(readLines(output_path), collapse = "\n")
  expect_match(content, 'image\\("my_chart.png"\\)')
  expect_false(grepl(chart_dir, content))  # No absolute path

  # Cleanup
  unlink(chart_dir, recursive = TRUE)
  unlink(output_dir, recursive = TRUE)
})

test_that("check_quarto_version handles prefixed version strings", {
  # "Quarto X.Y.Z" format (some installations output this)
  expect_true(BFHcharts:::check_quarto_version("Quarto 1.4.557", "1.4.0"))
  expect_true(BFHcharts:::check_quarto_version("Quarto 1.5.0", "1.4.0"))
  expect_false(BFHcharts:::check_quarto_version("Quarto 1.3.340", "1.4.0"))

  # Two-part versions
  expect_true(BFHcharts:::check_quarto_version("1.4", "1.4.0"))
  expect_false(BFHcharts:::check_quarto_version("1.3", "1.4.0"))
})

test_that("bfh_export_pdf rejects directory as template_path", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, value, chart_type = "i", chart_title = "Test")
  )

  temp_file <- tempfile(fileext = ".pdf")

  # Directory should be rejected
  expect_error(
    bfh_export_pdf(result, temp_file, template_path = tempdir()),
    "must be a file, not a directory"
  )
})

test_that("bfh_export_pdf rejects non-.typ template file", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rpois(12, lambda = 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, month, value, chart_type = "i", chart_title = "Test")
  )

  # Create a non-.typ file
  txt_file <- tempfile(fileext = ".txt")
  writeLines("not a template", txt_file)

  temp_file <- tempfile(fileext = ".pdf")

  # Should be rejected
  expect_error(
    bfh_export_pdf(result, temp_file, template_path = txt_file),
    "\\.typ"
  )

  # Cleanup
  unlink(txt_file)
})

test_that("generated Typst contains metadata and chart reference", {
  # Test without Quarto - just verify the Typst generation
  # Create chart in different directory to test copying
  chart_dir <- tempfile("chart_source_")
  dir.create(chart_dir)
  output_dir <- tempfile("typst_output_")
  dir.create(output_dir)

  chart_path <- file.path(chart_dir, "chart.png")
  png(chart_path, width = 400, height = 300)
  plot(1:10)
  dev.off()

  output_path <- file.path(output_dir, "document.typ")

  bfh_create_typst_document(
    chart_image = chart_path,
    output = output_path,
    metadata = list(
      title = "My Test Title",
      hospital = "Copenhagen Hospital",
      date = as.Date("2025-03-15")
    ),
    spc_stats = list(runs_expected = 7, runs_actual = 5),
    template = "bfh-diagram2"
  )

  content <- paste(readLines(output_path), collapse = "\n")

  # Verify metadata appears in content
  expect_match(content, "My Test Title")
  expect_match(content, "Copenhagen Hospital")
  expect_match(content, "2025-03-15")

  # Verify SPC stats appear
  expect_match(content, "runs_expected: 7")
  expect_match(content, "runs_actual: 5")

  # Verify chart reference
  expect_match(content, 'image\\("chart.png"\\)')

  # Verify template import
  expect_match(content, '#import "bfh-template/bfh-template.typ"')

  # Cleanup
  unlink(chart_dir, recursive = TRUE)
  unlink(output_dir, recursive = TRUE)
})

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

test_that("bfh_export_pdf handles ggsave failure gracefully", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  chart <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )

  # Try to save to invalid path (directory doesn't exist and can't be created)
  # On Unix: /dev/null/file.pdf will fail
  # On Windows: we'll use a path with invalid characters
  if (.Platform$OS.type == "unix") {
    expect_error(
      bfh_export_pdf(chart, "/dev/null/impossible.pdf"),
      "Failed to save chart image"
    )
  }
})

test_that("quarto_available handles unparseable version correctly", {
  # Mock function to test version parsing with invalid input
  check_result <- BFHcharts:::check_quarto_version("invalid-version-string", "1.4.0")

  # Should return FALSE (fail-safe) for unparseable version
  expect_false(check_result)
})

test_that("bfh_export_pdf validates input structure", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  # Create malformed bfh_qic_result (missing required components)
  bad_result <- list(
    plot = NULL,  # Missing plot
    summary = NULL,
    config = list(chart_title = "Test")
  )
  class(bad_result) <- "bfh_qic_result"

  temp_file <- tempfile(fileext = ".pdf")

  # Should fail validation or during ggsave
  expect_error(
    bfh_export_pdf(bad_result, temp_file)
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_compile_typst reports Quarto compilation failures", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  # Create invalid Typst file that will fail compilation
  temp_typst <- tempfile(fileext = ".typ")
  writeLines(c(
    "#let invalid_syntax = ",  # Incomplete statement
    "This will cause a Typst error"
  ), temp_typst)

  temp_pdf <- tempfile(fileext = ".pdf")

  # Should report compilation failure with exit code or missing PDF
  expect_error(
    BFHcharts:::bfh_compile_typst(temp_typst, temp_pdf),
    "compilation failed|PDF compilation failed"
  )

  # Cleanup
  unlink(temp_typst)
  if (file.exists(temp_pdf)) unlink(temp_pdf)
})

# ===========================================================================
# markdown_to_typst TESTS
# ===========================================================================

test_that("markdown_to_typst converts bold text", {
  # Single bold phrase
 expect_equal(
    BFHcharts:::markdown_to_typst("This is **bold** text"),
    "This is #strong[bold] text"
  )

  # Multiple bold phrases
  expect_equal(
    BFHcharts:::markdown_to_typst("**First** and **second**"),
    "#strong[First] and #strong[second]"
  )
})

test_that("markdown_to_typst converts italic text", {
  # Single italic phrase
  expect_equal(
    BFHcharts:::markdown_to_typst("This is *italic* text"),
    "This is #emph[italic] text"
  )
})

test_that("markdown_to_typst converts mixed bold and italic", {
  expect_equal(
    BFHcharts:::markdown_to_typst("Has **bold** and *italic* words"),
    "Has #strong[bold] and #emph[italic] words"
  )
})

test_that("markdown_to_typst converts newlines to Typst line breaks", {
  result <- BFHcharts:::markdown_to_typst("Line one\nLine two")
  expect_match(result, "Line one\\\\\nLine two")
})

test_that("markdown_to_typst handles SPCify default title format", {
  input <- "Skriv en kort og sigende titel eller\n**konkluder hvad grafen viser**"
  result <- BFHcharts:::markdown_to_typst(input)

  # Should contain bold conversion
  expect_match(result, "#strong\\[konkluder hvad grafen viser\\]")
  # Should contain line break
  expect_match(result, "\\\\")
})

test_that("markdown_to_typst handles empty and NULL input", {
  expect_equal(BFHcharts:::markdown_to_typst(""), "")
  expect_equal(BFHcharts:::markdown_to_typst(NULL), "")
  expect_equal(BFHcharts:::markdown_to_typst(character(0)), "")
})

test_that("markdown_to_typst preserves plain text without formatting", {
  plain_text <- "This is plain text without any formatting"
  expect_equal(BFHcharts:::markdown_to_typst(plain_text), plain_text)
})

test_that("build_typst_content uses content blocks for title and analysis", {
  # Create minimal test setup
  test_metadata <- list(
    hospital = "Test Hospital",
    title = "**Bold** Title",
    analysis = "*Italic* analysis"
  )

  test_spc_stats <- list()

  # Create temp files
  temp_template <- tempfile(fileext = ".typ")
  file.create(temp_template)

  content <- BFHcharts:::build_typst_content(
    chart_image = "chart.png",
    metadata = test_metadata,
    spc_stats = test_spc_stats,
    template_file = temp_template,
    template = "test-template"
  )

  content_str <- paste(content, collapse = "\n")

  # Title should be content block with #strong
  expect_match(content_str, "title: \\[#strong\\[Bold\\] Title\\]")

  # Analysis should be content block with #emph
  expect_match(content_str, "analysis: \\[#emph\\[Italic\\] analysis\\]")

  # Hospital should remain quoted string (not content block)
  expect_match(content_str, 'hospital: "Test Hospital"')

  # Cleanup
  unlink(temp_template)
})
