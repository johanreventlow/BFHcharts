# ============================================================================
# SMOKE TESTS: ip (I-prime) chart via bfh_qic()
# ============================================================================
# TDD: tests written before Group 3 implementation.
# Verifies that bfh_qic() correctly routes chart_type = "ip" through the
# pbcharts adapter and produces a valid bfh_qic_result object.
#
# Heavy CL-identity / varying-limits / notes-alignment acceptance tests
# are deferred to Group 4.
# ============================================================================

skip_if_not_installed("pbcharts")

# Small but realistic dataset: monthly Dates, integer numerator, varying den
make_iprime_data <- function(n = 20L) {
  set.seed(42L)
  dates <- seq.Date(from = as.Date("2023-01-01"), by = "month", length.out = n)
  data.frame(
    date = dates,
    num = as.integer(round(runif(n, 10, 50))),
    den = as.integer(round(runif(n, 100, 300))),
    stringsAsFactors = FALSE
  )
}

df <- make_iprime_data()

# ============================================================================
# Test 1: returns bfh_qic_result
# ============================================================================

test_that("bfh_qic with chart_type ip returns a bfh_qic_result object", {
  result <- bfh_qic(df, x = date, y = num, n = den, chart_type = "ip")
  expect_true(is_bfh_qic_result(result))
})

# ============================================================================
# Test 2: return.data = TRUE produces qic contract data.frame
# ============================================================================

test_that("bfh_qic with chart_type ip and return.data=TRUE returns a data.frame with contract columns", {
  result <- bfh_qic(df,
    x = date, y = num, n = den,
    chart_type = "ip", return.data = TRUE
  )
  expect_s3_class(result, "data.frame")
  contract_cols <- c("x", "y", "cl", "ucl", "lcl", "n", "notes")
  for (col in contract_cols) {
    expect_true(col %in% names(result),
      info = paste("qic_data should contain contract column:", col)
    )
  }
})

# ============================================================================
# Test 3: missing n emits degeneration message
# ============================================================================

test_that("bfh_qic with chart_type ip and no n emits degeneration message", {
  expect_message(
    bfh_qic(df, x = date, y = num, chart_type = "ip"),
    regexp = "denominator"
  )
})
