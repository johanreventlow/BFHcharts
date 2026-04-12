# Edge case tests for bfh_qic()
# Verificerer at pipelinen håndterer grænsetilfælde korrekt

test_that("bfh_qic håndterer minimum data (3 punkter)", {
  skip_if_not_installed("qicharts2")

  data <- data.frame(
    date = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")),
    value = c(10, 15, 12)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = date, y = value, chart_type = "run")
  )

  expect_s3_class(result, "bfh_qic_result")
  expect_equal(nrow(result$qic_data), 3)
})

test_that("bfh_qic håndterer alle identiske værdier (zero variance)", {
  skip_if_not_installed("qicharts2")

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rep(50, 12)
  )

  # Skal ikke crashe — qicharts2 håndterer zero variance
  result <- suppressWarnings(
    bfh_qic(data, x = date, y = value, chart_type = "i")
  )

  expect_s3_class(result, "bfh_qic_result")
  # Centerlinje skal være 50
  expect_true(all(result$qic_data$cl == 50))
})

test_that("bfh_qic håndterer data med alle nul-værdier", {
  skip_if_not_installed("qicharts2")

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rep(0, 12)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = date, y = value, chart_type = "run")
  )

  expect_s3_class(result, "bfh_qic_result")
})

test_that("bfh_qic håndterer negative værdier", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = -10, sd = 5)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = date, y = value, chart_type = "i")
  )

  expect_s3_class(result, "bfh_qic_result")
  # Y-værdier skal afspejle de negative inputdata
  expect_true(any(result$qic_data$y < 0))
})

test_that("bfh_qic håndterer stor dataset (200 punkter)", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2010-01-01"), by = "month", length.out = 200),
    value = rpois(200, lambda = 50)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = date, y = value, chart_type = "i")
  )

  expect_s3_class(result, "bfh_qic_result")
  expect_equal(nrow(result$qic_data), 200)
})

test_that("bfh_qic returnerer summary med korrekte danske kolonner", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rpois(24, lambda = 50)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i")

  # Summary skal have danske kolonner fra format_qic_summary
  expect_true("fase" %in% names(result$summary))
  expect_true("centerlinje" %in% names(result$summary))
  expect_true("antal_observationer" %in% names(result$summary))
})

test_that("bfh_qic med multiply parameter skalerer korrekt", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 0.5, sd = 0.1)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i",
                     multiply = 100)

  # Multiplicerede y-værdier skal være ~50 (0.5 * 100)
  expect_true(mean(result$qic_data$y) > 30)
})

test_that("bfh_qic med cl parameter sætter custom centerlinje", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rpois(12, lambda = 50)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "run",
                     cl = 42)

  # Centerlinje skal være 42 (custom)
  expect_true(all(result$qic_data$cl == 42))
})

test_that("bfh_qic med part parameter opretter faser", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rpois(24, lambda = 50)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i",
                     part = 12)

  expect_equal(length(unique(result$qic_data$part)), 2)
  expect_equal(nrow(result$summary), 2)
})

test_that("bfh_qic med freeze parameter fryser baseline", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rpois(24, lambda = 50)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = date, y = value, chart_type = "i",
             freeze = 12)
  )

  expect_s3_class(result, "bfh_qic_result")
  # Centerlinje skal være konstant (frozen fra de første 12 obs)
  cl_values <- unique(round(result$qic_data$cl, 2))
  expect_equal(length(cl_values), 1)
})
