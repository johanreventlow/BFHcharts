test_that("bfh_qic validates part positions are within bounds", {
  data <- data.frame(
    month = 1:24,
    value = rnorm(24)
  )

  # Valid part positions
  expect_no_error({
    suppressWarnings(
      bfh_qic(data, x = month, y = value, part = c(12), chart_type = "i")
    )
  })

  # Out of bounds part position
  expect_error(
    bfh_qic(data, x = month, y = value, part = c(999), chart_type = "i"),
    "part positions must be positive integers within data bounds"
  )

  # Negative part position
  expect_error(
    bfh_qic(data, x = month, y = value, part = c(-5), chart_type = "i"),
    "part positions must be positive integers within data bounds"
  )

  # Zero part position
  expect_error(
    bfh_qic(data, x = month, y = value, part = c(0), chart_type = "i"),
    "part positions must be positive integers within data bounds"
  )
})

test_that("bfh_qic validates freeze position is within bounds", {
  data <- data.frame(
    month = 1:24,
    value = rnorm(24)
  )

  # Valid freeze position
  expect_no_error({
    suppressWarnings(
      bfh_qic(data, x = month, y = value, freeze = 12, chart_type = "i")
    )
  })

  # Out of bounds freeze position
  expect_error(
    bfh_qic(data, x = month, y = value, freeze = 999, chart_type = "i"),
    "freeze position must be a positive integer within data bounds"
  )

  # Negative freeze position
  expect_error(
    bfh_qic(data, x = month, y = value, freeze = -1, chart_type = "i"),
    "freeze position must be a positive integer within data bounds"
  )
})

test_that("bfh_qic validates base_size is reasonable", {
  data <- data.frame(month = 1:12, value = rnorm(12))

  # Valid base_size
  expect_no_error({
    suppressWarnings(
      bfh_qic(data, x = month, y = value, base_size = 14, chart_type = "run")
    )
  })

  # Excessive base_size (potential DoS)
  expect_error(
    bfh_qic(data, x = month, y = value, base_size = 999, chart_type = "run"),
    "base_size must be between 1 and 100"
  )

  # Zero base_size
  expect_error(
    bfh_qic(data, x = month, y = value, base_size = 0, chart_type = "run"),
    "base_size must be between 1 and 100"
  )

  # Negative base_size
  expect_error(
    bfh_qic(data, x = month, y = value, base_size = -5, chart_type = "run"),
    "base_size must be between 1 and 100"
  )
})

test_that("bfh_qic validates width and height are reasonable", {
  data <- data.frame(month = 1:12, value = rnorm(12))

  # Valid dimensions
  expect_no_error({
    suppressWarnings(
      bfh_qic(data, x = month, y = value, width = 10, height = 6, chart_type = "run")
    )
  })

  # Excessive width (potential memory exhaustion)
  expect_error(
    bfh_qic(data, x = month, y = value, width = 99999, height = 6, chart_type = "run"),
    "width must be between 0 and 1000 inches"
  )

  # Excessive height
  expect_error(
    bfh_qic(data, x = month, y = value, width = 10, height = 99999, chart_type = "run"),
    "height must be between 0 and 1000 inches"
  )

  # Negative width
  expect_error(
    bfh_qic(data, x = month, y = value, width = -10, height = 6, chart_type = "run"),
    "width must be between 0 and 1000 inches"
  )

  # Zero height
  expect_error(
    bfh_qic(data, x = month, y = value, width = 10, height = 0, chart_type = "run"),
    "height must be between 0 and 1000 inches"
  )
})

test_that("Bounds validation prevents DoS attacks", {
  data <- data.frame(month = 1:100, value = rnorm(100))

  # Simulate DoS attack scenarios
  dos_scenarios <- list(
    list(param = "base_size", value = 999999, pattern = "base_size"),
    list(param = "width", value = 999999, pattern = "width"),
    list(param = "height", value = 999999, pattern = "height"),
    list(param = "part", value = c(999999), pattern = "part"),
    list(param = "freeze", value = 999999, pattern = "freeze")
  )

  for (scenario in dos_scenarios) {
    args <- list(
      data = data,
      x = quote(month),
      y = quote(value),
      chart_type = "run"
    )
    args[[scenario$param]] <- scenario$value

    expect_error(
      do.call(bfh_qic, args),
      scenario$pattern,
      info = sprintf("DoS scenario for %s should be rejected", scenario$param)
    )
  }
})

test_that("Validation provides helpful error messages", {
  data <- data.frame(month = 1:24, value = rnorm(24))

  # Test part error message
  error_msg <- tryCatch(
    bfh_qic(data, x = month, y = value, part = c(999), chart_type = "i"),
    error = function(e) e$message
  )
  expect_true(grepl("within data bounds \\(1-24\\)", error_msg))
  expect_true(grepl("999", error_msg))
})
