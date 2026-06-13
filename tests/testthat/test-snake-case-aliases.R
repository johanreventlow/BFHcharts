# ============================================================================
# Tests for snake_case param aliases: agg_fun / return_data
# Closes #429
# ============================================================================

# Shared minimal fixture
make_alias_data <- function() {
  data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = c(10, 12, 11, 13, 10, 14, 11, 12, 13, 10, 11, 12)
  )
}

# ----------------------------------------------------------------------------
# return_data alias
# ----------------------------------------------------------------------------

test_that("return_data = TRUE returns a data.frame", {
  d <- make_alias_data()
  result <- bfh_qic(d,
    x = month, y = value, chart_type = "i",
    return_data = TRUE
  )
  expect_s3_class(result, "data.frame")
})

test_that("return_data = FALSE returns bfh_qic_result", {
  d <- make_alias_data()
  result <- bfh_qic(d,
    x = month, y = value, chart_type = "i",
    return_data = FALSE
  )
  expect_s3_class(result, "bfh_qic_result")
})

test_that("return.data = TRUE still works with deprecation warning", {
  d <- make_alias_data()
  expect_warning(
    {
      result <- bfh_qic(d,
        x = month, y = value, chart_type = "i",
        return.data = TRUE
      )
    },
    regexp = "return\\.data.*deprecated",
    fixed = FALSE
  )
  expect_s3_class(result, "data.frame")
})

test_that("supplying both return_data and return.data errors", {
  d <- make_alias_data()
  expect_error(
    bfh_qic(d,
      x = month, y = value, chart_type = "i",
      return.data = TRUE, return_data = TRUE
    ),
    regexp = "Supply only one of",
    fixed = FALSE
  )
})

# ----------------------------------------------------------------------------
# agg_fun alias
# ----------------------------------------------------------------------------

test_that("agg_fun = 'median' is accepted and returns bfh_qic_result", {
  d <- make_alias_data()
  result <- bfh_qic(d,
    x = month, y = value, chart_type = "i",
    agg_fun = "median"
  )
  expect_s3_class(result, "bfh_qic_result")
})

test_that("agg.fun = 'median' still works with deprecation warning", {
  d <- make_alias_data()
  expect_warning(
    {
      result <- bfh_qic(d,
        x = month, y = value, chart_type = "i",
        agg.fun = "median"
      )
    },
    regexp = "agg\\.fun.*deprecated",
    fixed = FALSE
  )
  expect_s3_class(result, "bfh_qic_result")
})

test_that("supplying both agg_fun and agg.fun errors", {
  d <- make_alias_data()
  expect_error(
    bfh_qic(d,
      x = month, y = value, chart_type = "i",
      agg.fun = "median", agg_fun = "mean"
    ),
    regexp = "Supply only one of",
    fixed = FALSE
  )
})

test_that("agg_fun and agg.fun produce the same result", {
  d <- make_alias_data()

  result_dot <- suppressWarnings(
    bfh_qic(d,
      x = month, y = value, chart_type = "i",
      agg.fun = "median", return_data = TRUE
    )
  )
  result_snake <- bfh_qic(d,
    x = month, y = value, chart_type = "i",
    agg_fun = "median", return_data = TRUE
  )

  expect_equal(result_snake$cl, result_dot$cl)
})
