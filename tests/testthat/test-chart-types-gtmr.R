# Smoke + boundary tests for g-chart, t-chart, og mr-chart.
# Formel-niveau tests ligge i test-statistical-accuracy-extended.R.
# Disse tests fokuserer på: S3-klasse, dataintegritet, og grænsetilfælde.

# ============================================================================
# MR-CHART
# ============================================================================

test_that("mr-chart returnerer bfh_qic_result S3-objekt", {
  data <- data.frame(
    periode = 1:12,
    value = c(10, 11, 9, 12, 10, 11, 13, 10, 12, 11, 9, 10)
  )
  result <- bfh_qic(data, x = periode, y = value, chart_type = "mr")
  expect_s3_class(result, "bfh_qic_result")
})

test_that("mr-chart qic_data har UCL > CL og LCL == 0", {
  data <- data.frame(
    periode = 1:12,
    value = c(10, 11, 9, 12, 10, 11, 13, 10, 12, 11, 9, 10)
  )
  result <- bfh_qic(data, x = periode, y = value, chart_type = "mr")
  qd <- result$qic_data
  # UCL skal være over centerlinje
  expect_gt(qd$ucl[2], qd$cl[2])
  # LCL = 0 for n=2 (D3 = 0)
  expect_equal(qd$lcl[2], 0, tolerance = 1e-9)
})

test_that("mr-chart første observation har NA y-værdi", {
  data <- data.frame(periode = 1:8, value = c(10, 12, 9, 11, 10, 13, 11, 9))
  result <- bfh_qic(data, x = periode, y = value, chart_type = "mr")
  expect_true(is.na(result$qic_data$y[1]))
})

test_that("mr-chart håndterer minimum data (3 observationer)", {
  data <- data.frame(periode = 1:3, value = c(10, 12, 11))
  result <- bfh_qic(data, x = periode, y = value, chart_type = "mr")
  expect_s3_class(result, "bfh_qic_result")
  # 3 inputrækker → 3 rækker i qic_data
  expect_equal(nrow(result$qic_data), 3)
})

# ============================================================================
# G-CHART
# ============================================================================

test_that("g-chart returnerer bfh_qic_result S3-objekt", {
  data <- data.frame(
    skift = 1:12,
    antal = c(5, 8, 6, 7, 4, 9, 5, 7, 6, 8, 5, 6)
  )
  result <- bfh_qic(data, x = skift, y = antal, chart_type = "g")
  expect_s3_class(result, "bfh_qic_result")
})

test_that("g-chart UCL > CL, LCL >= 0", {
  data <- data.frame(
    skift = 1:12,
    antal = c(5, 8, 6, 7, 4, 9, 5, 7, 6, 8, 5, 6)
  )
  result <- bfh_qic(data, x = skift, y = antal, chart_type = "g")
  qd <- result$qic_data
  expect_gt(qd$ucl[1], qd$cl[1])
  expect_gte(qd$lcl[1], 0)
})

test_that("g-chart med nul-tæller rækker krasher ikke", {
  # Grænsetilfælde: nul-tæller er teknisk gyldigt for g-chart
  # (ingen events i perioden)
  data <- data.frame(
    skift = 1:10,
    antal = c(0, 5, 0, 7, 4, 0, 5, 7, 6, 8)
  )
  result <- bfh_qic(data, x = skift, y = antal, chart_type = "g")
  expect_s3_class(result, "bfh_qic_result")
})

test_that("g-chart qic_data antal rækker matcher input", {
  n_obs <- 15
  data <- data.frame(
    skift = seq_len(n_obs),
    antal = sample(3:20, n_obs, replace = TRUE)
  )
  result <- bfh_qic(data, x = skift, y = antal, chart_type = "g")
  expect_equal(nrow(result$qic_data), n_obs)
})

# ============================================================================
# T-CHART
# ============================================================================

test_that("t-chart returnerer bfh_qic_result S3-objekt", {
  data <- data.frame(
    haendelse = 1:10,
    dage = c(5, 3, 7, 4, 6, 5, 8, 6, 7, 4)
  )
  result <- bfh_qic(data, x = haendelse, y = dage, chart_type = "t")
  expect_s3_class(result, "bfh_qic_result")
})

test_that("t-chart UCL > CL og LCL >= 0", {
  data <- data.frame(
    haendelse = 1:10,
    dage = c(5, 3, 7, 4, 6, 5, 8, 6, 7, 4)
  )
  result <- bfh_qic(data, x = haendelse, y = dage, chart_type = "t")
  qd <- result$qic_data
  expect_gt(qd$ucl[1], qd$cl[1])
  expect_gte(qd$lcl[1], 0)
})

test_that("t-chart med identiske tider (tied) krasher ikke", {
  # Grænsetilfælde: alle tider er identiske → nul varians i z-rum
  data <- data.frame(
    haendelse = 1:8,
    dage = rep(5, 8)
  )
  result <- bfh_qic(data, x = haendelse, y = dage, chart_type = "t")
  expect_s3_class(result, "bfh_qic_result")
})

test_that("t-chart respekterer Nelson back-transformation: CL er ikke rå mean", {
  # Nelson-transformation: cl = mean(y^(1/3.6))^3.6 ≠ mean(y)
  values <- c(5, 3, 7, 4, 6, 5, 8, 6)
  data <- data.frame(haendelse = seq_along(values), dage = values)
  result <- bfh_qic(data, x = haendelse, y = dage, chart_type = "t")
  # CL fra Nelson-transformation ≠ rå middelværdi
  raw_mean <- mean(values)
  nelson_cl <- result$qic_data$cl[1]
  expect_false(isTRUE(all.equal(nelson_cl, raw_mean, tolerance = 0.01)))
})
