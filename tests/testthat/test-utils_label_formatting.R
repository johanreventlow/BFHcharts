# ============================================================================
# FORMAT_Y_VALUE TESTS
# ============================================================================

test_that("format_y_value handles NA values correctly", {
  expect_true(is.na(format_y_value(NA, "count")))
  expect_true(is.na(format_y_value(NA, "percent")))
  expect_true(is.na(format_y_value(NA, "rate")))
  expect_true(is.na(format_y_value(NA, "time", y_range = c(0, 100))))
})

test_that("format_y_value validates input types", {
  # Non-numeric input should warn
  expect_warning(
    result <- format_y_value("text", "count"),
    "val skal være numerisk"
  )
  expect_equal(result, "text")
})

# ============================================================================
# PERCENT FORMATTING TESTS
# ============================================================================

test_that("format_y_value formats percentages correctly", {
  expect_equal(format_y_value(0.5, "percent"), "50%")
  expect_equal(format_y_value(0.456, "percent"), "46%")
  expect_equal(format_y_value(0.999, "percent"), "100%")
  expect_equal(format_y_value(0.001, "percent"), "0%")
})

test_that("format_y_value handles percent edge cases", {
  expect_equal(format_y_value(0, "percent"), "0%")
  expect_equal(format_y_value(1, "percent"), "100%")
})

# ============================================================================
# CONTEXTUAL PERCENT PRECISION TESTS
# ============================================================================

test_that("format_percent_contextual shows decimal when close to target", {
  # Within 2 percentage points of target - show decimal
  expect_equal(format_percent_contextual(0.887, target = 0.90), "88,7%")
  expect_equal(format_percent_contextual(0.915, target = 0.90), "91,5%")
  expect_equal(format_percent_contextual(0.885, target = 0.90), "88,5%")
})

test_that("format_percent_contextual shows whole percent when far from target", {
  # More than 2 percentage points from target - show whole percent
  expect_equal(format_percent_contextual(0.634, target = 0.90), "63%")
  expect_equal(format_percent_contextual(0.50, target = 0.90), "50%")
  expect_equal(format_percent_contextual(0.70, target = 0.90), "70%")
})

test_that("format_percent_contextual shows whole percent when no target", {
  # No target set - show whole percent
  expect_equal(format_percent_contextual(0.887, target = NULL), "89%")
  expect_equal(format_percent_contextual(0.50, target = NULL), "50%")
  expect_equal(format_percent_contextual(0.999, target = NULL), "100%")
})

test_that("format_percent_contextual handles boundary at 2 percentage points", {
  # Just within 2 percentage points - shows decimal
  expect_equal(format_percent_contextual(0.881, target = 0.90), "88,1%")
  expect_equal(format_percent_contextual(0.919, target = 0.90), "91,9%")

  # At or beyond 2 percentage points - whole percent (threshold is exclusive due to >)
  expect_equal(format_percent_contextual(0.88, target = 0.90), "88%")
  expect_equal(format_percent_contextual(0.879, target = 0.90), "88%")
  expect_equal(format_percent_contextual(0.921, target = 0.90), "92%")
})

test_that("format_percent_contextual uses Danish comma notation", {
  result <- format_percent_contextual(0.887, target = 0.90)
  expect_true(grepl(",", result))  # Danish comma
  expect_false(grepl("\\.", result))  # No English dot
})

test_that("format_percent_contextual handles NA values", {
  expect_true(is.na(format_percent_contextual(NA, target = 0.90)))
  expect_true(is.na(format_percent_contextual(NA, target = NULL)))
})

test_that("format_percent_contextual handles NA target", {
  # NA target should behave like NULL target - whole percent
  expect_equal(format_percent_contextual(0.887, target = NA), "89%")
})

test_that("format_y_value with target parameter shows contextual precision", {
  # With target - shows decimal when close
  expect_equal(format_y_value(0.887, "percent", target = 0.90), "88,7%")
  expect_equal(format_y_value(0.634, "percent", target = 0.90), "63%")

  # Without target - whole percent (backward compatible)
  expect_equal(format_y_value(0.887, "percent"), "89%")
  expect_equal(format_y_value(0.50, "percent"), "50%")
})

# ============================================================================
# COUNT FORMATTING TESTS (K/M/mia notation)
# ============================================================================

test_that("format_y_value formats billions correctly", {
  expect_equal(format_y_value(1e9, "count"), "1 mia.")
  expect_equal(format_y_value(1.5e9, "count"), "1,5 mia.")
  expect_equal(format_y_value(2.3e9, "count"), "2,3 mia.")
  expect_equal(format_y_value(10e9, "count"), "10 mia.")
})

test_that("format_y_value formats millions correctly", {
  expect_equal(format_y_value(1e6, "count"), "1M")
  expect_equal(format_y_value(2.5e6, "count"), "2,5M")
  expect_equal(format_y_value(10.7e6, "count"), "10,7M")
  expect_equal(format_y_value(999e6, "count"), "999M")
})

test_that("format_y_value formats thousands correctly", {
  expect_equal(format_y_value(1000, "count"), "1K")
  expect_equal(format_y_value(1500, "count"), "1,5K")
  expect_equal(format_y_value(25.3e3, "count"), "25,3K")
  expect_equal(format_y_value(999e3, "count"), "999K")
})

test_that("format_y_value formats small counts correctly", {
  # Integers without decimals
  expect_equal(format_y_value(100, "count"), "100")
  expect_equal(format_y_value(500, "count"), "500")

  # With decimals
  expect_equal(format_y_value(123.5, "count"), "123,5")
  expect_equal(format_y_value(45.7, "count"), "45,7")
})

test_that("format_y_value uses Danish notation for counts", {
  # Comma as decimal separator
  result <- format_y_value(1.5e6, "count")
  expect_true(grepl(",", result))
  expect_false(grepl("\\.", result))

  # Dot as thousand separator for small values (not applicable to K/M/mia)
  result <- format_y_value(123.5, "count")
  expect_true(grepl(",", result)) # Decimal mark
})

test_that("format_y_value handles negative counts", {
  expect_equal(format_y_value(-1000, "count"), "-1K")
  expect_equal(format_y_value(-1e6, "count"), "-1M")
  expect_equal(format_y_value(-1e9, "count"), "-1 mia.")
  expect_equal(format_y_value(-123, "count"), "-123")
})

test_that("format_y_value handles count boundaries", {
  # Just below threshold
  expect_equal(format_y_value(999, "count"), "999")
  expect_equal(format_y_value(999999, "count"), "1000,0K") # Afrundet til nærmeste K
  expect_equal(format_y_value(999999999, "count"), "1000,0M") # Rounds to 1000M

  # At threshold
  expect_equal(format_y_value(1000, "count"), "1K")
  expect_equal(format_y_value(1000000, "count"), "1M")
  expect_equal(format_y_value(1000000000, "count"), "1 mia.")
})

# ============================================================================
# RATE FORMATTING TESTS
# ============================================================================

test_that("format_y_value formats rates as integers when appropriate", {
  expect_equal(format_y_value(1, "rate"), "1")
  expect_equal(format_y_value(10, "rate"), "10")
  expect_equal(format_y_value(100, "rate"), "100")
})

test_that("format_y_value formats rates with decimals", {
  expect_equal(format_y_value(1.5, "rate"), "1,5")
  expect_equal(format_y_value(10.7, "rate"), "10,7")
  expect_equal(format_y_value(123.456, "rate"), "123,5") # Afrundet til 1 decimal
})

test_that("format_y_value uses Danish notation for rates", {
  result <- format_y_value(12.5, "rate")
  expect_true(grepl(",", result)) # Comma as decimal
  expect_false(grepl("\\.", result))
})

test_that("format_y_value handles negative rates", {
  expect_equal(format_y_value(-5, "rate"), "-5")
  expect_equal(format_y_value(-5.5, "rate"), "-5,5")
})

# ============================================================================
# TIME FORMATTING TESTS
# ============================================================================

test_that("format_y_value bruger komposit-format for time-enhed (minutter)", {
  # Komposit-format: "30m" i stedet for "30 minutter"
  expect_equal(format_y_value(1, "time"), "1m")
  expect_equal(format_y_value(30, "time"), "30m")
  expect_equal(format_y_value(10, "time"), "10m")
  # Decimaler rundes til hele minutter (45,5 -> 46m)
  expect_equal(format_y_value(45.5, "time"), "46m")
})

test_that("format_y_value bruger komposit-format for time-enhed (timer)", {
  expect_equal(format_y_value(60, "time"), "1t")
  expect_equal(format_y_value(90, "time"), "1t 30m")
  expect_equal(format_y_value(180, "time"), "3t")
  expect_equal(format_y_value(300, "time"), "5t")
})

test_that("format_y_value bruger komposit-format for time-enhed (dage)", {
  expect_equal(format_y_value(1440, "time"), "1d")
  expect_equal(format_y_value(2880, "time"), "2d")
  # Max 2 komponenter — dage+timer udelader minutter
  expect_equal(format_y_value(3660, "time"), "2d 13t")
})

test_that("format_y_value ignorerer y_range for time (irrelevant i komposit)", {
  # y_range-parameteren er legacy — komposit-format håndterer
  # minutter/timer/dage automatisk uden behov for range-kontekst.
  expect_equal(format_y_value(60, "time", y_range = c(0, 120)), "1t")
  expect_equal(format_y_value(60, "time", y_range = c(0, 10000)), "1t")
  expect_equal(format_y_value(60, "time", y_range = NULL), "1t")
})

test_that("format_y_value håndterer overflow-rounding i komposit-format", {
  # Regression: 59,7 min skal rundes til "1t", ikke "60m"
  expect_equal(format_y_value(59.7, "time"), "1t")
  expect_equal(format_y_value(1439.7, "time"), "1d")
})

test_that("format_y_value håndterer NA for time", {
  expect_true(is.na(format_y_value(NA_real_, "time")))
})

# ============================================================================
# DEFAULT FORMATTING TESTS
# ============================================================================

test_that("format_y_value uses default formatting for unknown units", {
  expect_equal(format_y_value(10, "unknown_unit"), "10")
  expect_equal(format_y_value(10.5, "unknown_unit"), "10,5")
})

test_that("format_y_value default uses Danish notation", {
  result <- format_y_value(123.5, "other")
  expect_true(grepl(",", result))
})

test_that("format_y_value default handles integers", {
  expect_equal(format_y_value(42, "other"), "42")
  expect_equal(format_y_value(100, "other"), "100")
})

# ============================================================================
# EDGE CASES AND SPECIAL VALUES
# ============================================================================

test_that("format_y_value handles zero correctly", {
  expect_equal(format_y_value(0, "count"), "0")
  expect_equal(format_y_value(0, "percent"), "0%")
  expect_equal(format_y_value(0, "rate"), "0")
  # Zero i komposit-format: "0m" uanset range
  expect_equal(format_y_value(0, "time", c(0, 100)), "0m")
})

test_that("format_y_value handles very small values", {
  # Very small values show decimals (nsmall=1)
  expect_equal(format_y_value(0.001, "count"), "0,00")
  expect_equal(format_y_value(0.001, "percent"), "0%")
  expect_equal(format_y_value(0.001, "rate"), "0,00")
})

test_that("format_y_value handles very large values", {
  expect_equal(format_y_value(1e12, "count"), "1000 mia.")
  expect_equal(format_y_value(999e12, "count"), "999000 mia.")
})

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_that("format_y_value produces valid count format", {
  # Test that format_y_value produces valid formatted strings for counts
  # Verify specific formatting rules (K/M/mia notation, Danish decimal notation)

  # Small numbers: should be formatted with K notation
  result_1234 <- format_y_value(1234, "count")
  expect_match(result_1234, "K")  # Should become 1.2K

  # K notation (thousands)
  expect_match(format_y_value(1500, "count"), "K")

  # M notation (millions)
  expect_match(format_y_value(1e6, "count"), "M")

  # mia notation (billions)
  expect_match(format_y_value(1e9, "count"), "mia")

  # All results should be non-empty strings
  expect_true(is.character(format_y_value(500, "count")))
  expect_true(nchar(format_y_value(500, "count")) > 0)
})

test_that("format_y_value works in bfh_qic workflow", {
  # This is tested indirectly through label creation
  # Verify that function is exported and callable
  expect_true(exists("format_y_value"))
  expect_true(is.function(format_y_value))
})

test_that("format_y_value is consistent across multiple calls", {
  # Same input should produce same output
  val <- 1234.5
  result1 <- format_y_value(val, "count")
  result2 <- format_y_value(val, "count")
  expect_equal(result1, result2)
})
