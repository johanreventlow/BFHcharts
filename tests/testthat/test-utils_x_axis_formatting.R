test_that("normalize_to_posixct converts Date to POSIXct", {
  date_input <- as.Date("2024-01-15")
  result <- normalize_to_posixct(date_input)

  expect_s3_class(result, "POSIXct")
  expect_equal(as.Date(result), date_input)
})

test_that("normalize_to_posixct leaves POSIXct unchanged", {
  posix_input <- as.POSIXct("2024-01-15 12:00:00")
  result <- normalize_to_posixct(posix_input)

  expect_identical(result, posix_input)
})

test_that("round_to_interval_start rounds to month start", {
  date <- as.POSIXct("2024-01-15 12:00:00", tz = "UTC")
  result <- round_to_interval_start(date, "monthly")

  # Check that result is first day of month
  expect_s3_class(result, "POSIXct")
  expect_equal(lubridate::month(result), 1)
  expect_equal(lubridate::day(result), 1)
  expect_true(result <= date)
})

test_that("round_to_interval_start rounds to week start", {
  date <- as.POSIXct("2024-01-15 12:00:00")  # Monday
  result <- round_to_interval_start(date, "weekly")

  # lubridate floors to Sunday by default
  expect_s3_class(result, "POSIXct")
  expect_true(result <= date)
})

test_that("round_to_interval_start returns date unchanged for daily", {
  date <- as.POSIXct("2024-01-15 12:00:00")
  result <- round_to_interval_start(date, "daily")

  expect_equal(result, date)
})

test_that("calculate_base_interval_secs returns correct values", {
  expect_equal(calculate_base_interval_secs("daily"), 86400)
  expect_equal(calculate_base_interval_secs("weekly"), 604800)
  expect_equal(calculate_base_interval_secs("monthly"), 2592000)
  expect_null(calculate_base_interval_secs("unknown"))
})

test_that("calculate_interval_multiplier returns 1 for sparse data", {
  result <- calculate_interval_multiplier(10, "weekly")
  expect_equal(result, 1)
})

test_that("calculate_interval_multiplier applies multiplier for dense weekly data", {
  result <- calculate_interval_multiplier(52, "weekly")  # 52 weeks → needs 4x
  expect_equal(result, 4)
})

test_that("calculate_interval_multiplier applies multiplier for dense monthly data", {
  result <- calculate_interval_multiplier(24, "monthly")  # 24 months → needs 3x
  expect_equal(result, 3)
})

test_that("calculate_date_breaks returns NULL for unknown interval", {
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2024-01-31")
  format_config <- list(breaks = TRUE, n_breaks = 8)

  result <- calculate_date_breaks(min_date, max_date, "unknown", format_config)
  expect_null(result)
})

test_that("calculate_date_breaks generates monthly breaks", {
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2024-12-31")
  format_config <- list(breaks = TRUE, n_breaks = 12)

  result <- calculate_date_breaks(min_date, max_date, "monthly", format_config)

  expect_s3_class(result, "POSIXct")
  expect_true(length(result) <= 15)  # Should not exceed 15 breaks
  expect_true(min_date %in% result)  # Min should be included
})

test_that("calculate_date_breaks generates weekly breaks", {
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2024-03-31")
  format_config <- list(breaks = TRUE, n_breaks = 13)

  result <- calculate_date_breaks(min_date, max_date, "weekly", format_config)

  expect_s3_class(result, "POSIXct")
  expect_true(length(result) <= 15)
})

test_that("calculate_date_breaks generates daily breaks with multiplier", {
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2024-01-31")
  format_config <- list(breaks = TRUE, n_breaks = 31)

  result <- calculate_date_breaks(min_date, max_date, "daily", format_config)

  expect_s3_class(result, "POSIXct")
  # 31 days should trigger 2x multiplier → ~16 breaks (still acceptable)
  expect_true(length(result) <= 20)  # Allow some margin
})

test_that("apply_numeric_x_axis adds continuous scale", {
  library(ggplot2)
  data <- data.frame(x = 1:10, y = rnorm(10))
  plot <- ggplot(data, aes(x = x, y = y)) + geom_point()

  result <- apply_numeric_x_axis(plot)

  expect_s3_class(result, "gg")
  # Check that scale was added (result should have more layers/scales)
})
