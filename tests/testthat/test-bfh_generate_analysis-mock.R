# ============================================================================
# BFHllm mock-tests for bfh_generate_analysis(use_ai = TRUE)
# ============================================================================
#
# Covers AI-path that is only reached when BFHllm is installed.
# Mocks BFHllm::bfhllm_spc_suggestion for deterministic testing of
# success, failure and empty-response scenarios.
# Also covers data_consent, use_rag, and audit-event contracts.
#
# Reference: openspec/changes/strengthen-test-infrastructure (Phase 2 task 12)
# Updated: openspec/changes/2026-05-01-harden-inject-assets-trust-contract

# ----------------------------------------------------------------------------
# Helper: minimal bfh_qic_result for AI analysis
# ----------------------------------------------------------------------------

make_test_result_for_analysis <- function() {
  data <- fixture_deterministic_chart_data()
  suppressWarnings(
    bfh_qic(data,
      x = month,
      y = infections,
      chart_type = "i",
      chart_title = "Test Analysis"
    )
  )
}

# ============================================================================
# data_consent CONTRACT
# ============================================================================

test_that("bfh_generate_analysis(use_ai=TRUE) errors without data_consent", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  expect_error(
    bfh_generate_analysis(result, use_ai = TRUE),
    regexp = "data_consent"
  )
})

test_that("bfh_generate_analysis(use_ai=TRUE) errors when data_consent != 'explicit'", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  expect_error(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "deny"),
    regexp = "data_consent"
  )
  expect_error(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "yes"),
    regexp = "data_consent"
  )
})

test_that("bfh_generate_analysis(use_ai=FALSE) ignores data_consent (no error)", {
  result <- make_test_result_for_analysis()

  # All data_consent values should be accepted when use_ai = FALSE
  expect_type(bfh_generate_analysis(result, use_ai = FALSE), "character")
  expect_type(
    bfh_generate_analysis(result, use_ai = FALSE, data_consent = NULL),
    "character"
  )
  expect_type(
    bfh_generate_analysis(result, use_ai = FALSE, data_consent = "deny"),
    "character"
  )
})

# ============================================================================
# use_rag PARAMETER
# ============================================================================

test_that("bfh_generate_analysis: default use_rag = FALSE sent to BFHllm", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  captured_use_rag <- NULL

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(spc_result, context, min_chars, max_chars,
                                     use_rag = TRUE, timeout = 30, ...) {
      captured_use_rag <<- use_rag
      "mocked output"
    },
    .package = "BFHllm"
  )

  suppressMessages(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit")
  )

  expect_false(captured_use_rag, label = "default use_rag must be FALSE")
})

test_that("bfh_generate_analysis: use_rag = TRUE passed to BFHllm when set", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  captured_use_rag <- NULL

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(spc_result, context, min_chars, max_chars,
                                     use_rag = FALSE, timeout = 30, ...) {
      captured_use_rag <<- use_rag
      "mocked output"
    },
    .package = "BFHllm"
  )

  suppressMessages(
    bfh_generate_analysis(
      result,
      use_ai = TRUE, data_consent = "explicit", use_rag = TRUE
    )
  )

  expect_true(captured_use_rag, label = "explicit use_rag = TRUE must be forwarded")
})

# ============================================================================
# SUCCESS PATH: BFHllm returns text -> used directly
# ============================================================================

test_that("bfh_generate_analysis(use_ai=TRUE) uses BFHllm output on success", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  mock_output <- "AI-genereret analysetekst med kliniske anbefalinger."

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) mock_output,
    .package = "BFHllm"
  )

  analysis <- suppressMessages(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit")
  )

  expect_equal(analysis, mock_output)
})

test_that("bfh_generate_analysis(use_ai=TRUE) accepts long AI output", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  long_output <- paste(rep("AI analyse saetning. ", 20), collapse = "")

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) long_output,
    .package = "BFHllm"
  )

  analysis <- suppressMessages(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit")
  )

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 100)
})

# ============================================================================
# FAILURE PATH: BFHllm throws error -> fall back to standard text
# ============================================================================

test_that("bfh_generate_analysis(use_ai=TRUE) falls back on BFHllm error", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) {
      stop("API rate limit exceeded")
    },
    .package = "BFHllm"
  )

  # Warning expected (tryCatch wrapper converts error to warning)
  analysis <- suppressWarnings(suppressMessages(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit")
  ))

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
  expect_true(
    grepl(
      "stabil|signal|serie|over|under|mål|observation",
      analysis,
      ignore.case = TRUE
    )
  )
})

test_that("bfh_generate_analysis(use_ai=TRUE) warns on BFHllm error", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) {
      stop("Connection refused")
    },
    .package = "BFHllm"
  )

  expect_warning(
    suppressMessages(
      bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit")
    ),
    "AI analysis failed"
  )
})

# ============================================================================
# EMPTY RESPONSE: BFHllm returns empty string -> fall back
# ============================================================================

test_that("bfh_generate_analysis(use_ai=TRUE) falls back on empty AI response", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) "",
    .package = "BFHllm"
  )

  analysis <- suppressMessages(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit")
  )

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis(use_ai=TRUE) falls back on NULL AI response", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) NULL,
    .package = "BFHllm"
  )

  analysis <- suppressMessages(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit")
  )

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

# ============================================================================
# ARG-passing: BFHllm called with correct parameters
# ============================================================================

test_that("bfh_generate_analysis(use_ai=TRUE) sends min_chars/max_chars to BFHllm", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  captured_args <- NULL

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(spc_result, context, min_chars, max_chars,
                                     use_rag = FALSE, timeout = 30, ...) {
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

  suppressMessages(
    bfh_generate_analysis(
      result,
      use_ai = TRUE, data_consent = "explicit", min_chars = 250, max_chars = 400
    )
  )

  expect_equal(captured_args$min_chars, 250)
  expect_equal(captured_args$max_chars, 400)
  expect_equal(captured_args$chart_title, "Test Analysis")
  expect_false(captured_args$use_rag) # default FALSE
  expect_equal(captured_args$timeout, 30)
  expect_type(captured_args$n_points, "integer")
})

test_that("bfh_generate_analysis(use_ai=TRUE) sends baseline_analysis to BFHllm", {
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

  suppressMessages(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit")
  )

  expect_type(captured_baseline, "character")
  expect_gt(nchar(captured_baseline), 0)
  expect_true(
    grepl(
      "stabil|signal|serie|over|under|mål|observation",
      captured_baseline,
      ignore.case = TRUE
    )
  )
})

# ============================================================================
# DEFAULT: use_ai = FALSE -- never calls BFHllm without explicit opt-in
# ============================================================================

test_that("bfh_generate_analysis(use_ai=FALSE) never calls BFHllm", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  ai_called <- FALSE

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) {
      ai_called <<- TRUE
      "AI output"
    },
    .package = "BFHllm"
  )

  bfh_generate_analysis(result)
  expect_false(ai_called, label = "default use_ai = FALSE must not call BFHllm")

  bfh_generate_analysis(result, use_ai = FALSE)
  expect_false(ai_called, label = "explicit use_ai = FALSE must not call BFHllm")
})

# ============================================================================
# AUDIT EVENT: structured [BFHcharts/audit] emitted on AI branch
# ============================================================================

test_that("bfh_generate_analysis(use_ai=TRUE) emits [BFHcharts/audit] message", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) "AI output",
    .package = "BFHllm"
  )

  expect_message(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit"),
    regexp = "\\[BFHcharts/audit\\]"
  )
})

test_that("bfh_generate_analysis(use_ai=TRUE) audit event contains required fields", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  captured_msg <- NULL

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) "AI output",
    .package = "BFHllm"
  )

  withCallingHandlers(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit"),
    message = function(m) {
      if (grepl("\\[BFHcharts/audit\\]", conditionMessage(m))) {
        captured_msg <<- conditionMessage(m)
        invokeRestart("muffleMessage")
      }
    }
  )

  expect_false(is.null(captured_msg), label = "[BFHcharts/audit] message must be emitted")
  # Required JSON fields
  expect_match(captured_msg, "ai_egress")
  expect_match(captured_msg, "BFHcharts")
  expect_match(captured_msg, "bfhllm_spc_suggestion")
  expect_match(captured_msg, "metadata")
  expect_match(captured_msg, "qic_data")
  expect_match(captured_msg, "use_rag")
})

test_that("bfh_generate_analysis(use_ai=TRUE) audit event records use_rag = false by default", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()
  captured_msg <- NULL

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) "AI output",
    .package = "BFHllm"
  )

  withCallingHandlers(
    bfh_generate_analysis(result, use_ai = TRUE, data_consent = "explicit"),
    message = function(m) {
      if (grepl("\\[BFHcharts/audit\\]", conditionMessage(m))) {
        captured_msg <<- conditionMessage(m)
        invokeRestart("muffleMessage")
      }
    }
  )

  # Default use_rag = FALSE should be in the JSON line
  expect_match(captured_msg, '"use_rag": false')
})

test_that("bfh_generate_analysis(use_ai=FALSE) emits no [BFHcharts/audit] message", {
  skip_if_not_installed("BFHllm")

  result <- make_test_result_for_analysis()

  testthat::local_mocked_bindings(
    bfhllm_spc_suggestion = function(...) "AI output",
    .package = "BFHllm"
  )

  msgs <- character(0)
  withCallingHandlers(
    bfh_generate_analysis(result, use_ai = FALSE),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  audit_msgs <- grep("\\[BFHcharts/audit\\]", msgs, value = TRUE)
  expect_length(audit_msgs, 0)
})
