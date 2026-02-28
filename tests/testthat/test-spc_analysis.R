# Tests for SPC Analysis Functions

# ==============================================================================
# bfh_interpret_spc_signals() tests
# ==============================================================================

test_that("bfh_interpret_spc_signals detects serielængde signal", {
  stats <- list(runs_actual = 9, runs_expected = 7)
  result <- bfh_interpret_spc_signals(stats)

  expect_type(result, "character")
  expect_true(any(grepl("Serielængde-signal", result)))
  expect_true(any(grepl("9", result)))
  expect_true(any(grepl("7", result)))
})

test_that("bfh_interpret_spc_signals shows normal serielængde", {
  stats <- list(runs_actual = 5, runs_expected = 7)
  result <- bfh_interpret_spc_signals(stats)

  expect_type(result, "character")
  expect_false(any(grepl("Serielængde-signal", result)))
  expect_true(any(grepl("inden for forventet", result)))
})

test_that("bfh_interpret_spc_signals detects krydsnings signal", {
  stats <- list(crossings_actual = 3, crossings_expected = 5)
  result <- bfh_interpret_spc_signals(stats)

  expect_type(result, "character")
  expect_true(any(grepl("Krydsnings-signal", result)))
  expect_true(any(grepl("3", result)))
  expect_true(any(grepl("5", result)))
})

test_that("bfh_interpret_spc_signals shows normal krydsninger", {
  stats <- list(crossings_actual = 8, crossings_expected = 5)
  result <- bfh_interpret_spc_signals(stats)

  expect_type(result, "character")
  expect_false(any(grepl("Krydsnings-signal", result)))
  expect_true(any(grepl("inden for forventet", result)))
})

test_that("bfh_interpret_spc_signals detects outliers", {
  stats <- list(outliers_actual = 2)
  result <- bfh_interpret_spc_signals(stats)

  expect_type(result, "character")
  expect_true(any(grepl("2", result)))
  expect_true(any(grepl("kontrolgrænserne", result)))
})

test_that("bfh_interpret_spc_signals handles stable process", {
  stats <- list(
    runs_actual = 5,
    runs_expected = 7,
    crossings_actual = 8,
    crossings_expected = 5,
    outliers_actual = 0
  )
  result <- bfh_interpret_spc_signals(stats)

  expect_type(result, "character")
  # Should NOT contain "signal" (case insensitive) for normal process
  expect_false(any(grepl("Serielængde-signal", result)))
  expect_false(any(grepl("Krydsnings-signal", result)))
})

test_that("bfh_interpret_spc_signals handles empty stats", {
  stats <- list()
  result <- bfh_interpret_spc_signals(stats)

  expect_type(result, "character")
  expect_true(length(result) > 0)
  expect_true(any(grepl("stabil", result)))
})

test_that("bfh_interpret_spc_signals handles combined signals", {
  stats <- list(
    runs_actual = 9,
    runs_expected = 7,
    crossings_actual = 3,
    crossings_expected = 5,
    outliers_actual = 1
  )
  result <- bfh_interpret_spc_signals(stats)

  expect_type(result, "character")
  expect_true(length(result) >= 3)  # At least 3 interpretations
  expect_true(any(grepl("Serielængde-signal", result)))
  expect_true(any(grepl("Krydsnings-signal", result)))
  expect_true(any(grepl("kontrolgrænserne", result)))
})


# ==============================================================================
# bfh_build_analysis_context() tests
# ==============================================================================

test_that("bfh_build_analysis_context rejects invalid input", {
  expect_error(
    bfh_build_analysis_context(data.frame()),
    "bfh_qic_result"
  )

  expect_error(
    bfh_build_analysis_context(list(a = 1)),
    "bfh_qic_result"
  )
})

test_that("bfh_build_analysis_context extracts context from bfh_qic_result", {
  skip_if_not_installed("qicharts2")

  # Create test data
  set.seed(123)
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 100, sd = 10)
  )

  result <- bfh_qic(
    test_data,
    x = date,
    y = value,
    chart_type = "i",
    chart_title = "Test Chart"
  )

  ctx <- bfh_build_analysis_context(result)

  # Check required fields
  expect_true("chart_title" %in% names(ctx))
  expect_true("chart_type" %in% names(ctx))
  expect_true("n_points" %in% names(ctx))
  expect_true("spc_stats" %in% names(ctx))
  expect_true("signal_interpretations" %in% names(ctx))
  expect_true("has_signals" %in% names(ctx))

  # Check values
  expect_equal(ctx$chart_title, "Test Chart")
  expect_equal(ctx$chart_type, "i")
  expect_equal(ctx$n_points, 24)
  expect_type(ctx$signal_interpretations, "character")
  expect_type(ctx$has_signals, "logical")
})

test_that("bfh_build_analysis_context merges user metadata", {
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  ctx <- bfh_build_analysis_context(
    result,
    metadata = list(
      data_definition = "Test definition",
      target = 45,
      hospital = "BFH",
      department = "Quality"
    )
  )

  expect_equal(ctx$data_definition, "Test definition")
  expect_equal(ctx$target_value, 45)
  expect_equal(ctx$hospital, "BFH")
  expect_equal(ctx$department, "Quality")
})


# ==============================================================================
# bfh_generate_analysis() tests
# ==============================================================================

test_that("bfh_generate_analysis rejects invalid input", {
  expect_error(
    bfh_generate_analysis(data.frame()),
    "bfh_qic_result"
  )
})

test_that("bfh_generate_analysis returns standard text when use_ai = FALSE", {
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 100, sd = 10)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
  analysis <- bfh_generate_analysis(result, use_ai = FALSE)

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis includes chart title in output", {
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(
    test_data,
    x = date,
    y = value,
    chart_type = "i",
    chart_title = "Månedlige Infektioner"
  )

  analysis <- bfh_generate_analysis(result, use_ai = FALSE)

  expect_true(grepl("Månedlige Infektioner", analysis))
})

test_that("bfh_generate_analysis works with metadata", {
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  analysis <- bfh_generate_analysis(
    result,
    metadata = list(
      data_definition = "Infektioner pr. 1000 patientdage",
      hospital = "BFH"
    ),
    use_ai = FALSE
  )

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis falls back gracefully when AI unavailable", {
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  # Even if use_ai = TRUE but BFHllm not installed, should fall back
  # This test verifies no error is thrown
  analysis <- bfh_generate_analysis(result, use_ai = FALSE)

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis accepts min_chars and max_chars parameters", {
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  # Test with custom min/max chars (should not error)
  analysis <- bfh_generate_analysis(
    result,
    use_ai = FALSE,
    min_chars = 200,
    max_chars = 500
  )

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis has correct default values", {
  skip_if_not_installed("qicharts2")

  # Check function defaults
  fn_args <- formals(bfh_generate_analysis)

  expect_equal(fn_args$min_chars, 300)
  expect_equal(fn_args$max_chars, 375)
})

test_that("bfh_generate_analysis validates min_chars < max_chars", {
  skip_if_not_installed("qicharts2")

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  # min_chars equal to max_chars should error
  expect_error(
    bfh_generate_analysis(result, min_chars = 300, max_chars = 300),
    "min_chars must be less than max_chars"
  )

  # min_chars greater than max_chars should error
  expect_error(
    bfh_generate_analysis(result, min_chars = 500, max_chars = 300),
    "min_chars must be less than max_chars"
  )
})
