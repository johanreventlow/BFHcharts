# test-config_font_scaling.R
# Unit tests for calculate_base_size() og FONT_SCALING_CONFIG

test_that("calculate_base_size returns expected values for typical viewports", {
  # Med default config (divisor=3.5, min=8, max=48):
  # sqrt(w*h)/3.5 for smaa viewports er under min_size (8), saa de clampes.
  # Stoerre viewports: sqrt(50*30)/3.5 = sqrt(1500)/3.5 = 38.73/3.5 = 11.1

  result_6x4 <- calculate_base_size(6, 4)
  expect_true(is.numeric(result_6x4))
  expect_true(result_6x4 > 0)
  # Smaa viewports rammer min_size
  expect_equal(result_6x4, FONT_SCALING_CONFIG$min_size)

  result_8x5 <- calculate_base_size(8, 5)
  expect_true(is.numeric(result_8x5))
  expect_true(result_8x5 > 0)

  result_10x6 <- calculate_base_size(10, 6)
  expect_true(is.numeric(result_10x6))
  expect_true(result_10x6 > 0)

  # Larger viewport should give larger or equal base_size
  expect_true(result_8x5 >= result_6x4)
  expect_true(result_10x6 >= result_8x5)
})

test_that("calculate_base_size increases for sufficiently large viewports", {
  # Use custom config with low min to see actual scaling
  config <- list(divisor = 3.5, min_size = 1, max_size = 100)
  r1 <- calculate_base_size(6, 4, config = config)
  r2 <- calculate_base_size(20, 15, config = config)
  r3 <- calculate_base_size(50, 30, config = config)
  expect_true(r2 > r1)
  expect_true(r3 > r2)
})

test_that("calculate_base_size respects min bound for very small viewport", {
  result <- calculate_base_size(0.5, 0.5)
  expect_equal(result, FONT_SCALING_CONFIG$min_size)
})

test_that("calculate_base_size respects max bound for very large viewport", {
  result <- calculate_base_size(10000, 10000)
  expect_equal(result, FONT_SCALING_CONFIG$max_size)
})

test_that("calculate_base_size returns 14 for NULL width", {
  expect_equal(calculate_base_size(NULL, 5), 14)
})

test_that("calculate_base_size returns 14 for NULL height", {
  expect_equal(calculate_base_size(8, NULL), 14)
})

test_that("calculate_base_size returns 14 for NA width", {
  expect_equal(calculate_base_size(NA, 5), 14)
})

test_that("calculate_base_size returns 14 for NA height", {
  expect_equal(calculate_base_size(8, NA), 14)
})

test_that("calculate_base_size returns 14 for both NULL", {
  expect_equal(calculate_base_size(NULL, NULL), 14)
})

test_that("calculate_base_size handles negative dimensions gracefully", {
  # Negative * positive = negative -> sqrt(negative) = NaN (med warning)
  # Funktionen crasher ikke, men returnerer NaN pga. NaN-propagering
  result_neg <- suppressWarnings(calculate_base_size(-1, 5))
  expect_true(is.numeric(result_neg))  # NaN er stadig numeric

  # Both negative -> positive product -> valid result
  result <- calculate_base_size(-2, -3)
  expect_true(is.numeric(result))
  expect_false(is.nan(result))
})

test_that("calculate_base_size output is always numeric", {
  expect_true(is.numeric(calculate_base_size(8, 5)))
  expect_length(calculate_base_size(8, 5), 1)
})

test_that("calculate_base_size scales with geometric mean formula", {
  # Verify the formula: sqrt(w * h) / divisor, clamped to [min, max]
  w <- 10
  h <- 6
  config <- FONT_SCALING_CONFIG
  expected <- max(config$min_size, min(config$max_size, sqrt(w * h) / config$divisor))
  expect_equal(calculate_base_size(w, h), expected)
})

test_that("calculate_base_size accepts custom config", {
  custom_config <- list(divisor = 1.0, min_size = 5, max_size = 100)
  result <- calculate_base_size(10, 10, config = custom_config)
  # sqrt(100) / 1.0 = 10, clamped to [5, 100] = 10
  expect_equal(result, 10)
})
