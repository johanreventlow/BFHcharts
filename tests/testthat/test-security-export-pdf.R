# ============================================================================
# SECURITY TESTS FOR PDF EXPORT
# ============================================================================

# Helper function to create test chart
create_test_chart <- function() {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )
}

# ============================================================================
# PATH TRAVERSAL TESTS
# ============================================================================

test_that("bfh_export_pdf rejects path traversal in output", {
  chart <- create_test_chart()

  # Path traversal with ..
  expect_error(
    bfh_export_pdf(chart, "../../etc/passwd"),
    "path traversal"
  )

  expect_error(
    bfh_export_pdf(chart, "../../../sensitive/data.pdf"),
    "path traversal"
  )

  # Relative path with ..
  expect_error(
    bfh_export_pdf(chart, "output/../../../etc/cron.d/malicious.pdf"),
    "path traversal"
  )
})

test_that("bfh_export_pdf rejects path traversal in template_path", {
  chart <- create_test_chart()
  temp_file <- tempfile(fileext = ".pdf")

  # Path traversal in template_path
  expect_error(
    bfh_export_pdf(chart, temp_file, template_path = "../../etc/passwd"),
    "path traversal"
  )

  expect_error(
    bfh_export_pdf(chart, temp_file, template_path = "../../../sensitive/template.typ"),
    "path traversal"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

# ============================================================================
# SHELL METACHARACTER TESTS
# ============================================================================

test_that("bfh_export_pdf rejects shell metacharacters in output", {
  chart <- create_test_chart()

  # Semicolon (command separator)
  expect_error(
    bfh_export_pdf(chart, "output.pdf; rm -rf /"),
    "unsafe characters"
  )

  # Pipe
  expect_error(
    bfh_export_pdf(chart, "output.pdf | cat"),
    "unsafe characters"
  )

  # Ampersand (background process)
  expect_error(
    bfh_export_pdf(chart, "output.pdf & malicious_command"),
    "unsafe characters"
  )

  # Dollar sign (variable expansion)
  expect_error(
    bfh_export_pdf(chart, "output_$USER.pdf"),
    "unsafe characters"
  )

  # Backtick (command substitution)
  expect_error(
    bfh_export_pdf(chart, "output_`date`.pdf"),
    "unsafe characters"
  )

  # Parentheses (subshell)
  expect_error(
    bfh_export_pdf(chart, "output_(malicious).pdf"),
    "unsafe characters"
  )

  # Curly braces (brace expansion)
  expect_error(
    bfh_export_pdf(chart, "output_{a,b}.pdf"),
    "unsafe characters"
  )

  # Redirection
  expect_error(
    bfh_export_pdf(chart, "output.pdf > /dev/null"),
    "unsafe characters"
  )

  expect_error(
    bfh_export_pdf(chart, "output.pdf < /etc/passwd"),
    "unsafe characters"
  )

  # Newline injection
  expect_error(
    bfh_export_pdf(chart, "output.pdf\nmalicious_command"),
    "unsafe characters"
  )
})

test_that("bfh_compile_typst rejects shell metacharacters", {
  # Create minimal valid Typst file
  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[test]", typst_file)

  # Test with malicious output path
  expect_error(
    bfh_compile_typst(typst_file, "output.pdf; rm -rf /"),
    "unsafe characters"
  )

  expect_error(
    bfh_compile_typst(typst_file, "output.pdf | cat"),
    "unsafe characters"
  )

  # Cleanup
  unlink(typst_file)
})

# ============================================================================
# SAFE PATH TESTS (should pass)
# ============================================================================

test_that("bfh_export_pdf allows safe paths", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  chart <- create_test_chart()

  # Safe paths should work
  temp_file <- tempfile(fileext = ".pdf")

  expect_silent(
    bfh_export_pdf(chart, temp_file)
  )

  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_file)
})

test_that("bfh_export_pdf allows paths with spaces", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  chart <- create_test_chart()

  # Path with spaces (should be allowed - not a security risk)
  temp_dir <- tempfile("test directory ")
  dir.create(temp_dir)
  temp_file <- file.path(temp_dir, "my report.pdf")

  expect_silent(
    bfh_export_pdf(chart, temp_file)
  )

  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_dir, recursive = TRUE)
})

test_that("bfh_export_pdf allows paths with underscores and dashes", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  chart <- create_test_chart()

  # Safe special characters
  temp_file <- tempfile("my-report_2024", fileext = ".pdf")

  expect_silent(
    bfh_export_pdf(chart, temp_file)
  )

  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_file)
})

# ============================================================================
# METADATA VALIDATION TESTS
# ============================================================================

test_that("bfh_export_pdf validates metadata field types", {
  chart <- create_test_chart()
  temp_file <- tempfile(fileext = ".pdf")

  # Numeric value (invalid)
  expect_error(
    bfh_export_pdf(chart, temp_file, metadata = list(hospital = 123)),
    "must be a character string"
  )

  # Logical value (invalid)
  expect_error(
    bfh_export_pdf(chart, temp_file, metadata = list(department = TRUE)),
    "must be a character string"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_pdf allows Date objects for date field", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  chart <- create_test_chart()
  temp_file <- tempfile(fileext = ".pdf")

  # Date object is allowed for 'date' field
  expect_silent(
    bfh_export_pdf(chart, temp_file, metadata = list(date = Sys.Date()))
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_pdf enforces metadata string length limits", {
  chart <- create_test_chart()
  temp_file <- tempfile(fileext = ".pdf")

  # String exceeding 10,000 characters
  long_string <- paste(rep("A", 10001), collapse = "")

  expect_error(
    bfh_export_pdf(chart, temp_file, metadata = list(analysis = long_string)),
    "exceeds maximum length of 10,000 characters"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})

test_that("bfh_export_pdf warns about unknown metadata fields", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  chart <- create_test_chart()
  temp_file <- tempfile(fileext = ".pdf")

  # Unknown field should trigger warning
  expect_warning(
    bfh_export_pdf(chart, temp_file, metadata = list(unknown_field = "value")),
    "Unknown metadata fields will be ignored: unknown_field"
  )

  # Cleanup
  if (file.exists(temp_file)) unlink(temp_file)
})
