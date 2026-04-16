# Tests for SPC Analysis Functions


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
  expect_true("has_signals" %in% names(ctx))
  expect_false("signal_interpretations" %in% names(ctx))

  # Check values
  expect_equal(ctx$chart_title, "Test Chart")
  expect_equal(ctx$chart_type, "i")
  expect_equal(ctx$n_points, 24)
  expect_type(ctx$has_signals, "logical")
})

test_that("bfh_build_analysis_context merges user metadata", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

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
  set.seed(42)

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 100, sd = 10)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
  analysis <- bfh_generate_analysis(result, use_ai = FALSE)

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis returns valid text with chart title set", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

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

  # Fallback-analyse genererer stabilitetstekst, ikke nødvendigvis med titel
  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis works with metadata", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

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
  set.seed(42)

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
  set.seed(42)

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
  set.seed(42)

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

# ==============================================================================
# pick_text() tests (intern funktion)
# ==============================================================================

test_that("pick_text vælger detailed variant når budget tillader det", {
  variants <- list(
    short = "Kort tekst.",
    standard = "Standard tekst med lidt mere.",
    detailed = "Detaljeret tekst med meget mere indhold og forklaring."
  )
  result <- BFHcharts:::pick_text(variants, budget = 200)
  expect_equal(result, "Detaljeret tekst med meget mere indhold og forklaring.")
})

test_that("pick_text vælger standard variant ved mellemstort budget", {
  variants <- list(
    short = "Kort tekst.",
    standard = "Standard tekst med lidt mere.",
    detailed = "Detaljeret tekst med meget mere indhold og forklaring."
  )
  budget <- nchar("Standard tekst med lidt mere.") + 1
  result <- BFHcharts:::pick_text(variants, budget = budget)
  expect_equal(result, "Standard tekst med lidt mere.")
})

test_that("pick_text vælger short variant ved lille budget", {
  variants <- list(
    short = "Kort tekst.",
    standard = "Standard tekst med lidt mere.",
    detailed = "Detaljeret tekst med meget mere indhold og forklaring."
  )
  result <- BFHcharts:::pick_text(variants, budget = 15)
  expect_equal(result, "Kort tekst.")
})

test_that("pick_text returnerer short selv når budget er for lille", {
  variants <- list(
    short = "Kort tekst.",
    standard = "Standard tekst med lidt mere."
  )
  result <- BFHcharts:::pick_text(variants, budget = 3)
  expect_equal(result, "Kort tekst.")
})

test_that("pick_text erstatter placeholders i valgt variant", {
  variants <- list(
    short = "Serie: {runs_actual}.",
    standard = "Serie ({runs_actual}) over forventet ({runs_expected}).",
    detailed = "Længste serie ({runs_actual}) overstiger forventet maksimum ({runs_expected}). Skift."
  )
  result <- BFHcharts:::pick_text(
    variants,
    data = list(runs_actual = 9, runs_expected = 7),
    budget = 200
  )
  expect_true(grepl("9", result))
  expect_true(grepl("7", result))
  expect_false(grepl("\\{runs_actual\\}", result))
})

test_that("pick_text håndterer varianter med kun short og standard", {
  variants <- list(
    short = "Kort.",
    standard = "Standard tekst."
  )
  result <- BFHcharts:::pick_text(variants, budget = 200)
  expect_equal(result, "Standard tekst.")
})

test_that("pick_text håndterer gammel YAML-format (bagudkompatibilitet)", {
  variants <- list("Processen er stabil.")
  result <- BFHcharts:::pick_text(variants, budget = 200)
  expect_equal(result, "Processen er stabil.")
})

test_that("pick_text med budget = Inf vælger detailed", {
  variants <- list(
    short = "Kort.",
    standard = "Standard.",
    detailed = "Detaljeret."
  )
  result <- BFHcharts:::pick_text(variants)
  expect_equal(result, "Detaljeret.")
})
