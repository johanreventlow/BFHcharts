# =============================================================================
# Tests for .emit_audit_event() helper (utils_audit.R)
# =============================================================================
#
# Covers: tasks 4.6, 4.7, 6.3
# Scenarios:
#   - Option set -> JSON-line written to file
#   - Option unset -> structured message() emitted with [BFHcharts/audit] prefix
#   - JSON output contains expected fields


# Helper: build minimal event list for testing
make_test_event <- function(use_rag = FALSE) {
  list(
    timestamp = "2026-05-01T10:00:00.000Z",
    event = "ai_egress",
    package = "BFHcharts",
    target = "BFHllm::bfhllm_spc_suggestion",
    fields_sent = c("metadata", "qic_data"),
    context_keys = c("data_definition", "chart_title"),
    use_rag = use_rag,
    hostname = "test-host",
    user = "test-user"
  )
}


# ============================================================================
# OPTION-BASED JSON OUTPUT
# ============================================================================

test_that(".emit_audit_event writes JSON-line to file when option is set", {
  skip_if_not_installed("withr")

  event <- make_test_event()

  withr::with_tempfile("log_file", {
    withr::with_options(
      list(BFHcharts.audit_log = log_file),
      BFHcharts:::.emit_audit_event(event)
    )

    lines <- readLines(log_file)
    expect_length(lines, 1L)
    expect_match(lines[1], "^\\{")
    expect_match(lines[1], "\\}$")
  })
})

test_that(".emit_audit_event JSON-line contains all required fields", {
  skip_if_not_installed("withr")

  event <- make_test_event()

  withr::with_tempfile("log_file", {
    withr::with_options(
      list(BFHcharts.audit_log = log_file),
      BFHcharts:::.emit_audit_event(event)
    )

    line <- readLines(log_file)[[1]]
    expect_match(line, '"event"')
    expect_match(line, '"ai_egress"')
    expect_match(line, '"package"')
    expect_match(line, '"BFHcharts"')
    expect_match(line, '"target"')
    expect_match(line, '"bfhllm_spc_suggestion"')
    expect_match(line, '"use_rag"')
    expect_match(line, '"hostname"')
    expect_match(line, '"user"')
  })
})

test_that(".emit_audit_event appends multiple events as separate JSON lines", {
  skip_if_not_installed("withr")

  event <- make_test_event()

  withr::with_tempfile("log_file", {
    withr::with_options(
      list(BFHcharts.audit_log = log_file),
      {
        BFHcharts:::.emit_audit_event(event)
        BFHcharts:::.emit_audit_event(event)
      }
    )

    lines <- readLines(log_file)
    expect_length(lines, 2L)
  })
})

test_that(".emit_audit_event records use_rag = FALSE as JSON false", {
  skip_if_not_installed("withr")

  event <- make_test_event(use_rag = FALSE)

  withr::with_tempfile("log_file", {
    withr::with_options(
      list(BFHcharts.audit_log = log_file),
      BFHcharts:::.emit_audit_event(event)
    )

    line <- readLines(log_file)[[1]]
    expect_match(line, '"use_rag": false')
  })
})

test_that(".emit_audit_event records use_rag = TRUE as JSON true", {
  skip_if_not_installed("withr")

  event <- make_test_event(use_rag = TRUE)

  withr::with_tempfile("log_file", {
    withr::with_options(
      list(BFHcharts.audit_log = log_file),
      BFHcharts:::.emit_audit_event(event)
    )

    line <- readLines(log_file)[[1]]
    expect_match(line, '"use_rag": true')
  })
})

# ============================================================================
# FALLBACK MESSAGE OUTPUT (option unset or empty)
# ============================================================================

test_that(".emit_audit_event emits message with [BFHcharts/audit] prefix when option unset", {
  event <- make_test_event()

  # Ensure option is NOT set
  withr::with_options(
    list(BFHcharts.audit_log = NULL),
    expect_message(
      BFHcharts:::.emit_audit_event(event),
      regexp = "\\[BFHcharts/audit\\]"
    )
  )
})

test_that(".emit_audit_event emits message when audit_log is empty string", {
  event <- make_test_event()

  withr::with_options(
    list(BFHcharts.audit_log = ""),
    expect_message(
      BFHcharts:::.emit_audit_event(event),
      regexp = "\\[BFHcharts/audit\\]"
    )
  )
})

test_that(".emit_audit_event fallback message contains event fields", {
  event <- make_test_event()
  captured_msg <- NULL

  withr::with_options(
    list(BFHcharts.audit_log = NULL),
    withCallingHandlers(
      BFHcharts:::.emit_audit_event(event),
      message = function(m) {
        captured_msg <<- conditionMessage(m)
        invokeRestart("muffleMessage")
      }
    )
  )

  expect_match(captured_msg, "ai_egress")
  expect_match(captured_msg, "BFHcharts")
})
