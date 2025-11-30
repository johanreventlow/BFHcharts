# ============================================================================
# UNIT CONVERSION TESTS
# ============================================================================

test_that("convert_to_inches() converts centimeters correctly", {
  result <- convert_to_inches(25.4, 15.24, "cm")

  expect_equal(result$width_inches, 10, tolerance = 0.01)
  expect_equal(result$height_inches, 6, tolerance = 0.01)
  expect_equal(result$detected_unit, "cm")
})

test_that("convert_to_inches() converts millimeters correctly", {
  result <- convert_to_inches(254, 152.4, "mm")

  expect_equal(result$width_inches, 10, tolerance = 0.01)
  expect_equal(result$height_inches, 6, tolerance = 0.01)
  expect_equal(result$detected_unit, "mm")
})

test_that("convert_to_inches() passes through inches correctly", {
  result <- convert_to_inches(10, 6, "in")

  expect_equal(result$width_inches, 10)
  expect_equal(result$height_inches, 6)
  expect_equal(result$detected_unit, "in")
})

test_that("convert_to_inches() converts pixels correctly", {
  result <- convert_to_inches(960, 576, "px", dpi = 96)

  expect_equal(result$width_inches, 10, tolerance = 0.01)
  expect_equal(result$height_inches, 6, tolerance = 0.01)
  expect_equal(result$detected_unit, "px")
})

test_that("convert_to_inches() validates input types", {
  expect_error(
    convert_to_inches("25", 15, "cm"),
    "width and height must be numeric"
  )

  expect_error(
    convert_to_inches(25, "15", "cm"),
    "width and height must be numeric"
  )
})

test_that("convert_to_inches() validates input length", {
  expect_error(
    convert_to_inches(c(25, 30), 15, "cm"),
    "width and height must be single values"
  )
})

test_that("convert_to_inches() validates positive values", {
  expect_error(
    convert_to_inches(-25, 15, "cm"),
    "width and height must be positive"
  )

  expect_error(
    convert_to_inches(25, 0, "cm"),
    "width and height must be positive"
  )
})

test_that("convert_to_inches() validates units parameter", {
  expect_error(
    convert_to_inches(25, 15, "meters"),
    "units must be one of: cm, mm, in, px"
  )
})

# ============================================================================
# SMART AUTO-DETECTION TESTS
# ============================================================================

test_that("smart_convert_to_inches() detects pixels (> 100)", {
  result <- smart_convert_to_inches(800, 600, dpi = 96)

  expect_equal(result$detected_unit, "px")
  expect_equal(result$width_inches, 800/96, tolerance = 0.01)
  expect_equal(result$height_inches, 600/96, tolerance = 0.01)
})

test_that("smart_convert_to_inches() detects centimeters (10-100)", {
  result <- smart_convert_to_inches(25, 15)

  expect_equal(result$detected_unit, "cm")
  expect_equal(result$width_inches, 25/2.54, tolerance = 0.01)
  expect_equal(result$height_inches, 15/2.54, tolerance = 0.01)
})

test_that("smart_convert_to_inches() detects inches (< 10)", {
  result <- smart_convert_to_inches(10, 6)

  expect_equal(result$detected_unit, "in")
  expect_equal(result$width_inches, 10)
  expect_equal(result$height_inches, 6)
})

test_that("smart_convert_to_inches() uses max dimension for detection", {
  # Portrait: height > width, but both < 100 → cm
  result1 <- smart_convert_to_inches(15, 25)
  expect_equal(result1$detected_unit, "cm")

  # Landscape: width > height, but both < 100 → cm
  result2 <- smart_convert_to_inches(25, 15)
  expect_equal(result2$detected_unit, "cm")

  # Portrait pixels: height > 100 → px
  result3 <- smart_convert_to_inches(600, 800)
  expect_equal(result3$detected_unit, "px")
})

# ============================================================================
# REVERSE CONVERSION TESTS
# ============================================================================

test_that("convert_from_inches() converts to centimeters correctly", {
  result <- convert_from_inches(10, 6, "cm")

  expect_equal(result$width, 25.4, tolerance = 0.01)
  expect_equal(result$height, 15.24, tolerance = 0.01)
  expect_equal(result$unit, "cm")
})

test_that("convert_from_inches() converts to millimeters correctly", {
  result <- convert_from_inches(10, 6, "mm")

  expect_equal(result$width, 254, tolerance = 0.1)
  expect_equal(result$height, 152.4, tolerance = 0.1)
  expect_equal(result$unit, "mm")
})

test_that("convert_from_inches() converts to pixels correctly", {
  result <- convert_from_inches(10, 6, "px", dpi = 96)

  expect_equal(result$width, 960)
  expect_equal(result$height, 576)
  expect_equal(result$unit, "px")
})

# ============================================================================
# INTEGRATION WITH bfh_qic() TESTS
# ============================================================================

test_that("bfh_qic() accepts centimeters with auto-detection", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  expect_no_error({
    suppressWarnings(
      plot <- bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        y_axis_unit = "count",
        width = 25,   # Auto-detected as cm
        height = 15
      )
    )
  })
})

test_that("bfh_qic() accepts explicit centimeters", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  expect_no_error({
    suppressWarnings(
      plot <- bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        y_axis_unit = "count",
        width = 25,
        height = 15,
        units = "cm"
      )
    )
  })
})

test_that("bfh_qic() accepts pixels with auto-detection", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  expect_no_error({
    suppressWarnings(
      plot <- bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        y_axis_unit = "count",
        width = 800,  # Auto-detected as px
        height = 600,
        dpi = 96
      )
    )
  })
})

test_that("bfh_qic() backward compatibility - inches still work", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  # Old code with inches (< 10 → auto-detected as inches)
  expect_no_error({
    suppressWarnings(
      plot <- bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        y_axis_unit = "count",
        width = 10,
        height = 6
      )
    )
  })
})

test_that("bfh_qic() accepts all supported units explicitly", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  # Test each unit type
  for (unit in c("cm", "mm", "in", "px")) {
    expect_no_error(
      suppressWarnings(
        plot <- bfh_qic(
          data = data,
          x = month,
          y = infections,
          chart_type = "run",
          y_axis_unit = "count",
          width = if (unit == "px") 800 else if (unit == "mm") 250 else 25,
          height = if (unit == "px") 600 else if (unit == "mm") 150 else 15,
          units = unit,
          dpi = 96
        )
      )
    )
  }
})

test_that("bfh_qic() works without width/height (NULL)", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  # No dimensions → should work (NPC-based label placement)
  expect_no_error({
    suppressWarnings(
      plot <- bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = "run",
        y_axis_unit = "count"
      )
    )
  })
})
