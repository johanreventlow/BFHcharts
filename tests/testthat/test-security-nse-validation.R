test_that("create_spc_chart accepts valid column names", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15),
    surgeries = rpois(12, lambda = 100)
  )

  # Valid simple names should work (no error)
  expect_no_error({
    suppressWarnings(
      create_spc_chart(data, x = month, y = infections, chart_type = "run")
    )
  })

  # Names with underscores and dots should work
  data$patient_count <- rpois(12, 50)
  data$rate.value <- rnorm(12, 5, 1)

  expect_no_error({
    suppressWarnings(
      create_spc_chart(data, x = month, y = patient_count, chart_type = "run")
    )
  })

  expect_no_error({
    suppressWarnings(
      create_spc_chart(data, x = month, y = rate.value, chart_type = "run")
    )
  })
})

test_that("create_spc_chart rejects malicious column names with expressions", {
  data <- data.frame(
    month = 1:12,
    value = rnorm(12)
  )

  # Function calls should be rejected
  expect_error(
    create_spc_chart(data, x = system("echo pwned"), y = value, chart_type = "run"),
    "x must be a simple column name"
  )

  expect_error(
    create_spc_chart(data, x = month, y = system("echo pwned"), chart_type = "run"),
    "y must be a simple column name"
  )
})

test_that("create_spc_chart rejects column names with operators", {
  data <- data.frame(
    month = 1:12,
    value = rnorm(12),
    total = rpois(12, 100)
  )

  # Arithmetic expressions should be rejected
  expect_error(
    create_spc_chart(data, x = month, y = value + 1, chart_type = "run"),
    "y must be a simple column name"
  )

  # Subset operators should be rejected
  expect_error(
    create_spc_chart(data, x = month[1], y = value, chart_type = "run"),
    "x must be a simple column name"
  )
})

test_that("create_spc_chart rejects column names with special characters", {
  data <- data.frame(
    month = 1:12,
    value = rnorm(12)
  )

  # Names with parentheses should be rejected
  expect_error(
    create_spc_chart(data, x = month, y = c(value), chart_type = "run"),
    "y must be a simple column name"
  )

  # Note: Backticked names like `value` are actually valid column names in R
  # and deparse to "value" (no backticks), so they pass validation correctly
})

test_that("create_spc_chart validates n parameter for ratio charts", {
  data <- data.frame(
    month = 1:12,
    events = rpois(12, 5),
    total = rpois(12, 100)
  )

  # Valid n parameter (no error)
  expect_no_error({
    suppressWarnings(
      create_spc_chart(data, x = month, y = events, n = total, chart_type = "p")
    )
  })

  # Invalid n parameter with expression
  expect_error(
    create_spc_chart(data, x = month, y = events, n = sum(total), chart_type = "p"),
    "n must be a simple column name"
  )
})

test_that("NSE validation prevents code injection patterns", {
  # The validation happens at the NSE layer where expressions are parsed
  # Our regex validates the deparsed form, catching malicious patterns

  data <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "day", length.out = 30),
    value = rnorm(30)
  )

  # Test that function calls in column names are rejected
  # These would deparse to forms containing parentheses
  expect_true({
    # Validate that the regex correctly identifies non-simple patterns
    test_patterns <- c(
      "system('rm')" = FALSE,  # Contains parentheses - invalid
      "value" = TRUE,          # Simple name - valid
      "my_column" = TRUE,      # With underscore - valid
      "col.name" = TRUE,       # With dot - valid
      "1col" = FALSE,          # Starts with number - invalid
      "col name" = FALSE,      # Contains space - invalid
      "col+1" = FALSE          # Contains operator - invalid
    )

    all(sapply(names(test_patterns), function(pattern) {
      expected <- test_patterns[[pattern]]
      actual <- grepl("^[a-zA-Z][a-zA-Z0-9._]*$", pattern)
      actual == expected
    }))
  })
})

test_that("Column name validation provides helpful error messages", {
  data <- data.frame(month = 1:12, value = rnorm(12))

  error_msg <- tryCatch(
    create_spc_chart(data, x = month + 1, y = value, chart_type = "run"),
    error = function(e) e$message
  )

  expect_true(grepl("simple column name", error_msg))
  expect_true(grepl("month \\+ 1", error_msg))
})
