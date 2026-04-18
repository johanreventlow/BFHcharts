# ============================================================================
# BFHllm mock-tests for bfh_generate_analysis(use_ai = TRUE)
# ============================================================================
#
# Dækker AI-path der ellers kun rammes når BFHllm er installeret og nås
# faktisk. Mocker BFHllm::bfhllm_spc_suggestion for at teste success, failure
# og empty-response scenarier deterministisk.
#
# Reference: openspec/changes/strengthen-test-infrastructure (Fase 2 task 12)
# Spec: test-infrastructure, "External dependencies SHALL be testable in isolation"

# ----------------------------------------------------------------------------
# Helper: minimal bfh_qic_result til AI-analyse
# ----------------------------------------------------------------------------

make_test_result_for_analysis <- function() {
  data <- fixture_deterministic_chart_data()
  suppressWarnings(
    bfh_qic(data,
            x = month,
            y = infections,
            chart_type = "i",
            chart_title = "Test Analysis")
  )
}

# ============================================================================
# SUCCESS PATH: BFHllm returnerer tekst → bruges direkte
# ============================================================================

test_that("bfh_generate_analysis(use_ai=TRUE) bruger BFHllm-output ved success", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  mock_output <- "AI-genereret analysetekst med kliniske anbefalinger."

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) mock_output,
    .package = "BFHllm"
  )

  analysis <- bfh_generate_analysis(result, use_ai = TRUE)

  expect_equal(analysis, mock_output)
})

test_that("bfh_generate_analysis(use_ai=TRUE) accepterer lang AI-output", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  long_output <- paste(rep("AI analyse sætning. ", 20), collapse = "")

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) long_output,
    .package = "BFHllm"
  )

  analysis <- bfh_generate_analysis(result, use_ai = TRUE)

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 100)
})

# ============================================================================
# FAILURE PATH: BFHllm kaster fejl → fall-back til standardtekst
# ============================================================================

test_that("bfh_generate_analysis(use_ai=TRUE) falder tilbage ved BFHllm-fejl", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) {
      stop("API rate limit exceeded")
    },
    .package = "BFHllm"
  )

  # Warning forventes (tryCatch wrapper omdanner fejl til warning)
  analysis <- suppressWarnings(
    bfh_generate_analysis(result, use_ai = TRUE)
  )

  # Fallback-analyse returneres — ikke den fejlede AI-tekst
  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
  # Fallback-teksten indeholder typisk "stabil" eller "signal"-sprog
  expect_true(
    grepl("stabil|signal|serie|over|under|m\u00e5l|observation", analysis,
          ignore.case = TRUE)
  )
})

test_that("bfh_generate_analysis(use_ai=TRUE) warner ved BFHllm-fejl", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) {
      stop("Connection refused")
    },
    .package = "BFHllm"
  )

  expect_warning(
    bfh_generate_analysis(result, use_ai = TRUE),
    "AI analyse fejlede"
  )
})

# ============================================================================
# EMPTY RESPONSE: BFHllm returnerer tom streng → fall-back
# ============================================================================

test_that("bfh_generate_analysis(use_ai=TRUE) falder tilbage ved tom AI-response", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) "",
    .package = "BFHllm"
  )

  analysis <- bfh_generate_analysis(result, use_ai = TRUE)

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)  # Fallback-tekst (ikke tom)
})

test_that("bfh_generate_analysis(use_ai=TRUE) falder tilbage ved NULL AI-response", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) NULL,
    .package = "BFHllm"
  )

  analysis <- bfh_generate_analysis(result, use_ai = TRUE)

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

# ============================================================================
# ARG-passing: BFHllm kaldes med korrekte parametre
# ============================================================================

test_that("bfh_generate_analysis(use_ai=TRUE) sender min_chars/max_chars til BFHllm", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  captured_args <- NULL

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(spc_result, context, min_chars, max_chars,
                                     use_rag = TRUE, timeout = 30, ...) {
      captured_args <<- list(
        min_chars = min_chars,
        max_chars = max_chars,
        chart_title = context$chart_title,
        n_points = context$n_points,
        centerline = context$centerline,
        use_rag = use_rag,
        timeout = timeout
      )
      "mocked output"
    },
    .package = "BFHllm"
  )

  bfh_generate_analysis(result, use_ai = TRUE, min_chars = 250, max_chars = 400)

  expect_equal(captured_args$min_chars, 250)
  expect_equal(captured_args$max_chars, 400)
  expect_equal(captured_args$chart_title, "Test Analysis")
  expect_equal(captured_args$use_rag, TRUE)
  expect_equal(captured_args$timeout, 30)
  expect_type(captured_args$n_points, "integer")
})

test_that("bfh_generate_analysis(use_ai=TRUE) sender baseline_analysis til BFHllm", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  captured_baseline <- NULL

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(spc_result, context, ...) {
      captured_baseline <<- context$baseline_analysis
      "mocked"
    },
    .package = "BFHllm"
  )

  bfh_generate_analysis(result, use_ai = TRUE)

  expect_type(captured_baseline, "character")
  expect_gt(nchar(captured_baseline), 0)
  # Baseline indeholder fallback-analyse-sprog
  expect_true(
    grepl("stabil|signal|serie|over|under|m\u00e5l|observation",
          captured_baseline, ignore.case = TRUE)
  )
})

# ============================================================================
# AUTO-DETECTION: use_ai = NULL fallback
# ============================================================================

test_that("bfh_generate_analysis(use_ai=NULL) bruger BFHllm når tilgængelig", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) "AI via auto-detect",
    .package = "BFHllm"
  )

  analysis <- bfh_generate_analysis(result, use_ai = NULL)

  expect_equal(analysis, "AI via auto-detect")
})
