# ============================================================================
# SECURITY TESTS FOR PDF EXPORT
# ============================================================================

# Helper: fixture_test_chart() er tilgængelig via helper-fixtures.R.

# ============================================================================
# PATH TRAVERSAL TESTS
# ============================================================================

test_that("bfh_export_pdf rejects path traversal in output", {
  chart <- fixture_test_chart()

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
  chart <- fixture_test_chart()
  temp_file <- withr::local_tempfile(fileext = ".pdf")

  # Path traversal in template_path. Use restrict_template = FALSE to bypass the
  # default-safe guard added in 0.16.0 -- this test exercises the path-traversal
  # validator specifically, not the restrict_template guard.
  expect_error(
    bfh_export_pdf(chart, temp_file,
      template_path = "../../etc/passwd",
      restrict_template = FALSE
    ),
    "path traversal"
  )

  expect_error(
    bfh_export_pdf(chart, temp_file,
      template_path = "../../../sensitive/template.typ",
      restrict_template = FALSE
    ),
    "path traversal"
  )
})

# ============================================================================
# SHELL METACHARACTER TESTS
# ============================================================================

test_that("bfh_export_pdf afviser shell-pipeline metachars + LF/CR i output", {
  chart <- fixture_test_chart()
  expect_error(
    bfh_export_pdf(chart, "output.pdf; rm -rf /"),
    "disallowed"
  )
  expect_error(
    bfh_export_pdf(chart, "output\nrm -rf /.pdf"),
    "disallowed"
  )
  expect_error(
    bfh_export_pdf(chart, "output\rm.pdf"),
    "disallowed"
  )
})

# Bemærk (Codex 2026-04-30 finding #10): parens/brackets/braces/&$'
# tillades nu i output-stier — hospital-filnavne. ;|<>backtick afvises
# stadig fordi R's system2(stdout=TRUE) shell-mode kan eksekvere dem.
# Se test-path-policy.R for fuld dækning.

# ============================================================================
# SAFE PATH TESTS (should pass)
# ============================================================================

test_that("bfh_export_pdf allows safe paths", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_on_cran()

  chart <- fixture_test_chart()

  # Safe paths should work
  temp_file <- tempfile(fileext = ".pdf")

  expect_no_error(suppressWarnings(
    bfh_export_pdf(chart, temp_file)
  ))

  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_file)
})

test_that("bfh_export_pdf allows paths with spaces", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_on_cran()

  chart <- fixture_test_chart()

  # Path with spaces (should be allowed - not a security risk)
  temp_dir <- tempfile("test directory ")
  dir.create(temp_dir)
  temp_file <- file.path(temp_dir, "my report.pdf")

  expect_no_error(suppressWarnings(
    bfh_export_pdf(chart, temp_file)
  ))

  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_dir, recursive = TRUE)
})

test_that("bfh_export_pdf allows paths with underscores and dashes", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_on_cran()

  chart <- fixture_test_chart()

  # Safe special characters
  temp_file <- tempfile("my-report_2024", fileext = ".pdf")

  expect_no_error(suppressWarnings(
    bfh_export_pdf(chart, temp_file)
  ))

  expect_true(file.exists(temp_file))

  # Cleanup
  unlink(temp_file)
})

# ============================================================================
# METADATA VALIDATION TESTS
# ============================================================================

test_that("bfh_export_pdf validates metadata field types", {
  chart <- fixture_test_chart()
  temp_file <- withr::local_tempfile(fileext = ".pdf")

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
})

test_that("bfh_export_pdf allows Date objects for date field", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_on_cran()

  chart <- fixture_test_chart()
  temp_file <- withr::local_tempfile(fileext = ".pdf")

  # Date object is allowed for 'date' field
  expect_no_error(suppressWarnings(
    bfh_export_pdf(chart, temp_file, metadata = list(date = Sys.Date()))
  ))
})

test_that("bfh_export_pdf enforces metadata string length limits", {
  chart <- fixture_test_chart()
  temp_file <- withr::local_tempfile(fileext = ".pdf")

  # String exceeding 10,000 characters
  long_string <- paste(rep("A", 10001), collapse = "")

  expect_error(
    bfh_export_pdf(chart, temp_file, metadata = list(analysis = long_string)),
    "exceeds maximum length of 10,000 characters"
  )
})

test_that("bfh_export_pdf warns about unknown metadata fields", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_on_cran()

  chart <- fixture_test_chart()
  temp_file <- withr::local_tempfile(fileext = ".pdf")

  # Unknown field should trigger warning
  expect_warning(
    bfh_export_pdf(chart, temp_file, metadata = list(unknown_field = "value")),
    "Unknown metadata fields will be ignored: unknown_field"
  )
})
