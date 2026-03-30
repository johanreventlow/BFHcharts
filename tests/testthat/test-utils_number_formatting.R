# Tests for utils_number_formatting.R
# Canonical number formatting functions for SPC plots with Danish notation

# ============================================================================
# determine_magnitude() tests
# ============================================================================

test_that("determine_magnitude returns NULL for small numbers", {
  expect_null(determine_magnitude(0))
  expect_null(determine_magnitude(1))
  expect_null(determine_magnitude(999))
  expect_null(determine_magnitude(500))
})

test_that("determine_magnitude returns K for thousands", {
  result <- determine_magnitude(1000)
  expect_equal(result$scale, 1e3)
  expect_equal(result$suffix, "K")

  result <- determine_magnitude(5000)
  expect_equal(result$scale, 1e3)
  expect_equal(result$suffix, "K")

  result <- determine_magnitude(999999)
  expect_equal(result$scale, 1e3)
  expect_equal(result$suffix, "K")
})

test_that("determine_magnitude returns M for millions", {
  result <- determine_magnitude(1e6)
  expect_equal(result$scale, 1e6)
  expect_equal(result$suffix, "M")

  result <- determine_magnitude(5e6)
  expect_equal(result$scale, 1e6)
  expect_equal(result$suffix, "M")

  result <- determine_magnitude(999999999)
  expect_equal(result$scale, 1e6)
  expect_equal(result$suffix, "M")
})

test_that("determine_magnitude returns mia for billions", {
  result <- determine_magnitude(1e9)
  expect_equal(result$scale, 1e9)
  expect_equal(result$suffix, " mia.")

  result <- determine_magnitude(5e9)
  expect_equal(result$scale, 1e9)
  expect_equal(result$suffix, " mia.")
})

test_that("determine_magnitude handles NA", {
  expect_null(determine_magnitude(NA))
  expect_null(determine_magnitude(NA_real_))
})

test_that("determine_magnitude handles negative numbers", {
  # Negative thousands

  result <- determine_magnitude(-1500)
  expect_equal(result$scale, 1e3)
  expect_equal(result$suffix, "K")

  # Negative millions
  result <- determine_magnitude(-2e6)
  expect_equal(result$scale, 1e6)
  expect_equal(result$suffix, "M")

  # Negative small numbers
  expect_null(determine_magnitude(-500))
})

test_that("determine_magnitude handles very small positive numbers", {
  expect_null(determine_magnitude(0.001))
  expect_null(determine_magnitude(0.5))
})

# ============================================================================
# format_count_danish() tests
# ============================================================================

test_that("format_count_danish formats basic numbers correctly", {
  expect_equal(format_count_danish(0), "0")
  expect_equal(format_count_danish(500), "500")
  expect_equal(format_count_danish(1), "1")
  expect_equal(format_count_danish(999), "999")
})

test_that("format_count_danish uses K notation for thousands", {
  # Exact thousands: no decimals

  expect_equal(format_count_danish(1000), "1K")
  expect_equal(format_count_danish(2000), "2K")

  # Non-exact thousands: Danish comma decimal
  result <- format_count_danish(1500)
  expect_true(grepl("K", result))
  expect_true(grepl(",", result))  # Dansk decimal separator
  expect_equal(result, "1,5K")
})

test_that("format_count_danish uses M notation for millions", {
  expect_equal(format_count_danish(1e6), "1M")
  expect_equal(format_count_danish(2e6), "2M")

  result <- format_count_danish(2500000)
  expect_true(grepl("M", result))
  expect_equal(result, "2,5M")
})

test_that("format_count_danish uses mia notation for billions", {
  expect_equal(format_count_danish(1e9), "1 mia.")
  expect_equal(format_count_danish(2e9), "2 mia.")

  result <- format_count_danish(1.5e9)
  expect_true(grepl("mia\\.", result))
  expect_equal(result, "1,5 mia.")
})

test_that("format_count_danish handles NA", {
  expect_true(is.na(format_count_danish(NA)))
  expect_true(is.na(format_count_danish(NA_real_)))
})

test_that("format_count_danish handles negative numbers", {
  result <- format_count_danish(-1500)
  expect_true(grepl("K", result))
  expect_equal(result, "-1,5K")

  result <- format_count_danish(-2e6)
  expect_equal(result, "-2M")
})

test_that("format_count_danish uses Danish decimal separator (comma)", {
  # Fraction values use comma
  result <- format_count_danish(0.5)
  expect_true(grepl(",", result))
  expect_false(grepl("\\.", result))  # Ingen punktum som decimal
})

# ============================================================================
# format_rate_danish() tests
# ============================================================================

test_that("format_rate_danish formats integer rates correctly", {
  expect_equal(format_rate_danish(0), "0")
  expect_equal(format_rate_danish(5), "5")
  expect_equal(format_rate_danish(100), "100")
})

test_that("format_rate_danish uses Danish decimal separator", {
  result <- format_rate_danish(3.5)
  expect_true(grepl(",", result))
  expect_false(grepl("\\.", result))
  expect_equal(result, "3,5")
})

test_that("format_rate_danish formats fractions with 2 decimals", {
  result <- format_rate_danish(0.75)
  expect_equal(result, "0,75")

  result <- format_rate_danish(0.1)
  expect_equal(result, "0,10")
})

test_that("format_rate_danish formats larger values with 1 decimal", {
  result <- format_rate_danish(12.34)
  expect_equal(result, "12,3")

  result <- format_rate_danish(5.67)
  expect_equal(result, "5,7")
})

test_that("format_rate_danish handles NA", {
  expect_true(is.na(format_rate_danish(NA)))
  expect_true(is.na(format_rate_danish(NA_real_)))
})

test_that("format_rate_danish handles negative values", {
  result <- format_rate_danish(-3.5)
  expect_true(grepl(",", result))
  expect_equal(result, "-3,5")
})

# ============================================================================
# format_scaled_number() tests
# ============================================================================

test_that("format_scaled_number formats exact divisions without decimals", {
  expect_equal(format_scaled_number(2000, 1e3, "K"), "2K")
  expect_equal(format_scaled_number(3e6, 1e6, "M"), "3M")
  expect_equal(format_scaled_number(1e9, 1e9, " mia."), "1 mia.")
})

test_that("format_scaled_number formats non-exact divisions with Danish comma", {
  expect_equal(format_scaled_number(1500, 1e3, "K"), "1,5K")
  expect_equal(format_scaled_number(2500000, 1e6, "M"), "2,5M")
})

test_that("format_scaled_number handles NA", {
  expect_true(is.na(format_scaled_number(NA, 1e3, "K")))
})

# ============================================================================
# format_unscaled_number() tests
# ============================================================================

test_that("format_unscaled_number formats integers without decimals", {
  expect_equal(format_unscaled_number(42), "42")
  expect_equal(format_unscaled_number(0), "0")
})

test_that("format_unscaled_number formats fractions with 2 decimals", {
  expect_equal(format_unscaled_number(0.75), "0,75")
  expect_equal(format_unscaled_number(0.1), "0,10")
})

test_that("format_unscaled_number formats other values with 1 decimal", {
  expect_equal(format_unscaled_number(12.34), "12,3")
})

test_that("format_unscaled_number handles NA", {
  expect_true(is.na(format_unscaled_number(NA)))
})
