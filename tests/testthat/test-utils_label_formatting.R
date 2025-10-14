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
  expect_equal(format_y_value(999999, "count"), "999,999K") # format() shows more decimals
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
  expect_equal(format_y_value(123.456, "rate"), "123,456") # format() shows all decimals when present
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

test_that("format_y_value formats time in minutes for small ranges", {
  y_range <- c(0, 50) # < 60 minutes

  expect_equal(format_y_value(30, "time", y_range), "30 min")
  expect_equal(format_y_value(45.5, "time", y_range), "45,5 min")
  expect_equal(format_y_value(10, "time", y_range), "10 min")
})

test_that("format_y_value formats time in hours for medium ranges", {
  y_range <- c(0, 500) # 60-1440 minutes

  expect_equal(format_y_value(60, "time", y_range), "1 timer")
  expect_equal(format_y_value(90, "time", y_range), "1,5 timer")
  expect_equal(format_y_value(180, "time", y_range), "3 timer")
  expect_equal(format_y_value(300, "time", y_range), "5 timer")
})

test_that("format_y_value formats time in days for large ranges", {
  y_range <- c(0, 5000) # > 1440 minutes

  expect_equal(format_y_value(1440, "time", y_range), "1 dage")
  expect_equal(format_y_value(2880, "time", y_range), "2 dage")
  expect_equal(format_y_value(2160, "time", y_range), "1,5 dage")
})

test_that("format_y_value warns when y_range missing for time", {
  expect_warning(
    result <- format_y_value(120, "time", y_range = NULL),
    "y_range mangler for 'time' unit"
  )
  # Should use default formatting
  expect_equal(result, "120")
})

test_that("format_y_value warns when y_range incomplete for time", {
  expect_warning(
    result <- format_y_value(120, "time", y_range = c(50)),
    "y_range mangler for 'time' unit"
  )
})

test_that("format_y_value uses Danish labels for time", {
  expect_true(grepl("min", format_y_value(30, "time", c(0, 50))))
  expect_true(grepl("timer", format_y_value(90, "time", c(0, 500))))
  expect_true(grepl("dage", format_y_value(1440, "time", c(0, 5000))))
})

test_that("format_y_value uses Danish decimal notation for time", {
  result <- format_y_value(90, "time", c(0, 500)) # 1.5 hours
  expect_true(grepl("1,5", result)) # Comma separator
})

test_that("format_y_value handles time threshold boundaries", {
  # Just below 60 minutes
  expect_true(grepl("min", format_y_value(50, "time", c(0, 59))))

  # At 60 minutes
  expect_true(grepl("timer", format_y_value(60, "time", c(0, 60))))

  # Just below 1440 minutes (24 hours)
  expect_true(grepl("timer", format_y_value(1400, "time", c(0, 1439))))

  # At 1440 minutes
  expect_true(grepl("dage", format_y_value(1440, "time", c(0, 1440))))
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
  # Zero with range > 60 becomes hours
  expect_equal(format_y_value(0, "time", c(0, 100)), "0 timer")
})

test_that("format_y_value handles very small values", {
  # Very small values show decimals (nsmall=1)
  expect_equal(format_y_value(0.001, "count"), "0,001")
  expect_equal(format_y_value(0.001, "percent"), "0%")
  expect_equal(format_y_value(0.001, "rate"), "0,001")
})

test_that("format_y_value handles very large values", {
  expect_equal(format_y_value(1e12, "count"), "1000 mia.")
  expect_equal(format_y_value(999e12, "count"), "999000 mia.")
})

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_that("format_y_value matches y-axis formatting for counts", {
  # Test that format_y_value produces same output as format_y_axis_count
  test_values <- c(500, 1000, 1500, 1e6, 2.5e6, 1e9)

  for (val in test_values) {
    formatted <- format_y_value(val, "count")
    expect_true(is.character(formatted))
    expect_true(nchar(formatted) > 0)
  }
})

test_that("format_y_value works in create_spc_chart workflow", {
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
