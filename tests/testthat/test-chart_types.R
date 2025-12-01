# ============================================================================
# CHART TYPE CONSTANTS TESTS
# ============================================================================

test_that("CHART_TYPES_DA contains expected Danish labels", {
  expect_true(is.character(CHART_TYPES_DA))
  expect_true(length(CHART_TYPES_DA) > 0)

  # Check for key chart types
  expect_true("Seriediagram med SPC (Run Chart)" %in% names(CHART_TYPES_DA))
  expect_true("I-kort (Individuelle værdier)" %in% names(CHART_TYPES_DA))
  expect_true("P-kort (Andele)" %in% names(CHART_TYPES_DA))
  expect_true("U-kort (Rater)" %in% names(CHART_TYPES_DA))
  expect_true("C-kort (Tællinger)" %in% names(CHART_TYPES_DA))
})

test_that("CHART_TYPES_DA maps Danish to English codes correctly", {
  expect_equal(CHART_TYPES_DA["Seriediagram med SPC (Run Chart)"], c("Seriediagram med SPC (Run Chart)" = "run"))
  expect_equal(unname(CHART_TYPES_DA["I-kort (Individuelle værdier)"]), "i")
  expect_equal(unname(CHART_TYPES_DA["P-kort (Andele)"]), "p")
  expect_equal(unname(CHART_TYPES_DA["U-kort (Rater)"]), "u")
  expect_equal(unname(CHART_TYPES_DA["C-kort (Tællinger)"]), "c")
  expect_equal(unname(CHART_TYPES_DA["G-kort (Tid mellem hændelser)"]), "g")
})

test_that("CHART_TYPES_EN contains all valid English codes", {
  expect_true(is.character(CHART_TYPES_EN))
  expect_true(length(CHART_TYPES_EN) > 0)

  # Check for all expected types
  expected_types <- c("run", "i", "mr", "p", "pp", "u", "up", "c", "g", "xbar", "s", "t")
  expect_true(all(expected_types %in% CHART_TYPES_EN))
})

test_that("CHART_TYPE_DESCRIPTIONS contains Danish descriptions", {
  expect_true(is.character(CHART_TYPE_DESCRIPTIONS))
  expect_true(length(CHART_TYPE_DESCRIPTIONS) > 0)

  # All descriptions should be in Danish (contain Danish-specific words)
  expect_true("run" %in% names(CHART_TYPE_DESCRIPTIONS))
  expect_true("i" %in% names(CHART_TYPE_DESCRIPTIONS))
  expect_true("p" %in% names(CHART_TYPE_DESCRIPTIONS))
})

test_that("CHART_TYPE_DESCRIPTIONS values are non-empty strings", {
  for (desc in CHART_TYPE_DESCRIPTIONS) {
    expect_true(is.character(desc))
    expect_true(nchar(desc) > 0)
  }
})

test_that("Chart type constants are consistent across mappings", {
  # All values in CHART_TYPES_DA should be valid English codes
  for (code in CHART_TYPES_DA) {
    expect_true(
      unname(code) %in% CHART_TYPES_EN,
      info = sprintf("Code '%s' from CHART_TYPES_DA not in CHART_TYPES_EN", code)
    )
  }

  # Most codes in CHART_TYPES_EN should have descriptions
  # (some may not if they're less commonly used)
  common_types <- c("run", "i", "p", "u", "c", "g")
  for (type in common_types) {
    expect_true(
      type %in% names(CHART_TYPE_DESCRIPTIONS),
      info = sprintf("Common type '%s' missing from CHART_TYPE_DESCRIPTIONS", type)
    )
  }
})

# ============================================================================
# GET_QIC_CHART_TYPE TESTS
# ============================================================================

test_that("get_qic_chart_type converts Danish labels to English codes", {
  expect_equal(get_qic_chart_type("Seriediagram med SPC (Run Chart)"), "run")
  expect_equal(get_qic_chart_type("I-kort (Individuelle værdier)"), "i")
  expect_equal(get_qic_chart_type("P-kort (Andele)"), "p")
  expect_equal(get_qic_chart_type("P'-kort (Andele, standardiseret)"), "pp")
  expect_equal(get_qic_chart_type("U-kort (Rater)"), "u")
  expect_equal(get_qic_chart_type("U'-kort (Rater, standardiseret)"), "up")
  expect_equal(get_qic_chart_type("C-kort (Tællinger)"), "c")
  expect_equal(get_qic_chart_type("G-kort (Tid mellem hændelser)"), "g")
})

test_that("get_qic_chart_type returns English codes unchanged", {
  # If already English, should return as-is
  expect_equal(get_qic_chart_type("run"), "run")
  expect_equal(get_qic_chart_type("i"), "i")
  expect_equal(get_qic_chart_type("mr"), "mr")
  expect_equal(get_qic_chart_type("p"), "p")
  expect_equal(get_qic_chart_type("pp"), "pp")
  expect_equal(get_qic_chart_type("u"), "u")
  expect_equal(get_qic_chart_type("up"), "up")
  expect_equal(get_qic_chart_type("c"), "c")
  expect_equal(get_qic_chart_type("g"), "g")
  expect_equal(get_qic_chart_type("xbar"), "xbar")
  expect_equal(get_qic_chart_type("s"), "s")
  expect_equal(get_qic_chart_type("t"), "t")
})

test_that("get_qic_chart_type handles NULL input", {
  expect_equal(get_qic_chart_type(NULL), "run")
})

test_that("get_qic_chart_type handles empty string", {
  expect_equal(get_qic_chart_type(""), "run")
})

test_that("get_qic_chart_type warns and defaults for unknown types", {
  expect_warning(
    result <- get_qic_chart_type("invalid_type"),
    "Unknown chart type 'invalid_type'"
  )
  expect_equal(result, "run")

  expect_warning(
    result <- get_qic_chart_type("xyz"),
    "defaulting to 'run'"
  )
  expect_equal(result, "run")
})

test_that("get_qic_chart_type is case-sensitive for English codes", {
  # Should work for lowercase
  expect_equal(get_qic_chart_type("run"), "run")

  # Uppercase should not match and fall back to default with warning
  expect_warning(
    result <- get_qic_chart_type("RUN"),
    "Unknown chart type"
  )
  expect_equal(result, "run")
})

# ============================================================================
# CHART_TYPE_REQUIRES_DENOMINATOR TESTS
# ============================================================================

test_that("chart_type_requires_denominator returns TRUE for ratio charts", {
  # P-charts (proportions)
  expect_true(chart_type_requires_denominator("p"))
  expect_true(chart_type_requires_denominator("pp"))
  expect_true(chart_type_requires_denominator("P-kort (Andele)"))
  expect_true(chart_type_requires_denominator("P'-kort (Andele, standardiseret)"))

  # U-charts (rates)
  expect_true(chart_type_requires_denominator("u"))
  expect_true(chart_type_requires_denominator("up"))
  expect_true(chart_type_requires_denominator("U-kort (Rater)"))
  expect_true(chart_type_requires_denominator("U'-kort (Rater, standardiseret)"))
})

test_that("chart_type_requires_denominator returns FALSE for non-ratio charts", {
  # Run chart
  expect_false(chart_type_requires_denominator("run"))
  expect_false(chart_type_requires_denominator("Seriediagram med SPC (Run Chart)"))

  # I-chart
  expect_false(chart_type_requires_denominator("i"))
  expect_false(chart_type_requires_denominator("I-kort (Individuelle værdier)"))

  # MR-chart
  expect_false(chart_type_requires_denominator("mr"))
  expect_false(chart_type_requires_denominator("MR-kort (Moving Range)"))

  # C-chart
  expect_false(chart_type_requires_denominator("c"))
  expect_false(chart_type_requires_denominator("C-kort (Tællinger)"))

  # G-chart
  expect_false(chart_type_requires_denominator("g"))
  expect_false(chart_type_requires_denominator("G-kort (Tid mellem hændelser)"))

  # Other types
  expect_false(chart_type_requires_denominator("xbar"))
  expect_false(chart_type_requires_denominator("s"))
  expect_false(chart_type_requires_denominator("t"))
})

test_that("chart_type_requires_denominator handles NULL and empty", {
  # Should convert to "run" first (via get_qic_chart_type), then return FALSE
  expect_false(chart_type_requires_denominator(NULL))
  expect_false(chart_type_requires_denominator(""))
})

test_that("chart_type_requires_denominator handles unknown types", {
  # Should warn and default to "run" (which doesn't require denominator)
  expect_warning(
    result <- chart_type_requires_denominator("invalid"),
    "Unknown chart type"
  )
  expect_false(result)
})

# ============================================================================
# GET_CHART_DESCRIPTION TESTS
# ============================================================================

test_that("get_chart_description returns Danish descriptions for English codes", {
  # Check that we get non-empty Danish strings
  desc_run <- get_chart_description("run")
  expect_true(is.character(desc_run))
  expect_true(nchar(desc_run) > 0)
  expect_true(grepl("Seriediagram", desc_run))

  desc_i <- get_chart_description("i")
  expect_true(is.character(desc_i))
  expect_true(nchar(desc_i) > 0)
  expect_true(grepl("I-kort", desc_i))

  desc_p <- get_chart_description("p")
  expect_true(is.character(desc_p))
  expect_true(nchar(desc_p) > 0)
  expect_true(grepl("P-kort", desc_p) || grepl("andele", desc_p))
})

test_that("get_chart_description works with Danish labels", {
  # Should convert to English first, then get description
  desc <- get_chart_description("I-kort (Individuelle værdier)")
  expect_true(is.character(desc))
  expect_true(nchar(desc) > 0)

  desc <- get_chart_description("P-kort (Andele)")
  expect_true(is.character(desc))
  expect_true(nchar(desc) > 0)
})

test_that("get_chart_description returns fallback for unknown types", {
  # For types without descriptions, should return "SPC chart"
  expect_warning(
    desc <- get_chart_description("unknown_type"),
    "Unknown chart type"
  )
  # After warning from get_qic_chart_type, will use "run" and get its description
  expect_true(is.character(desc))
})

test_that("get_chart_description handles NULL and empty", {
  # Should default to "run" and return its description
  desc <- get_chart_description(NULL)
  expect_true(is.character(desc))
  expect_true(nchar(desc) > 0)

  desc <- get_chart_description("")
  expect_true(is.character(desc))
  expect_true(nchar(desc) > 0)
})

test_that("get_chart_description returns unname'd strings", {
  # Should not have names attribute
  desc <- get_chart_description("run")
  expect_null(names(desc))

  desc <- get_chart_description("i")
  expect_null(names(desc))
})

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_that("Chart type utilities work together correctly", {
  # Test workflow: Danish label → English code → check denominator → get description

  # P-chart workflow
  danish_label <- "P-kort (Andele)"
  english_code <- get_qic_chart_type(danish_label)
  expect_equal(english_code, "p")

  requires_denom <- chart_type_requires_denominator(english_code)
  expect_true(requires_denom)

  description <- get_chart_description(english_code)
  expect_true(is.character(description))
  expect_true(nchar(description) > 0)

  # Run chart workflow
  danish_label <- "Seriediagram med SPC (Run Chart)"
  english_code <- get_qic_chart_type(danish_label)
  expect_equal(english_code, "run")

  requires_denom <- chart_type_requires_denominator(english_code)
  expect_false(requires_denom)

  description <- get_chart_description(english_code)
  expect_true(grepl("Seriediagram", description))
})

test_that("All Danish labels map to valid English codes with descriptions", {
  for (danish_label in names(CHART_TYPES_DA)) {
    # Get English code
    english_code <- get_qic_chart_type(danish_label)

    # Should be a valid English code
    expect_true(
      english_code %in% CHART_TYPES_EN,
      info = sprintf("Danish label '%s' mapped to invalid code '%s'", danish_label, english_code)
    )

    # Should have a description (or return "SPC chart")
    description <- get_chart_description(english_code)
    expect_true(
      is.character(description) && nchar(description) > 0,
      info = sprintf("No description for code '%s' (from '%s')", english_code, danish_label)
    )
  }
})

test_that("Chart type utilities handle edge cases consistently", {
  # All three functions should handle NULL consistently
  expect_equal(get_qic_chart_type(NULL), "run")
  expect_false(chart_type_requires_denominator(NULL))
  expect_true(is.character(get_chart_description(NULL)))

  # All three functions should handle empty string consistently
  expect_equal(get_qic_chart_type(""), "run")
  expect_false(chart_type_requires_denominator(""))
  expect_true(is.character(get_chart_description("")))

  # All three functions should handle unknown types with warnings
  expect_warning(get_qic_chart_type("invalid"))
  expect_warning(chart_type_requires_denominator("invalid"))
  expect_warning(get_chart_description("invalid"))
})

test_that("Chart type utilities work in bfh_qic", {
  # Integration test: verify chart type utilities work in real workflow
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2),
    total = rpois(12, 100)
  )

  # Test with English code
  plot1 <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      chart_type = "run",
      y_axis_unit = "count"
    )
  )
  expect_s3_class(plot1, "bfh_qic_result")
  expect_s3_class(plot1$plot, "ggplot")

  # Test with ratio chart requiring denominator
  plot2 <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = value,
      n = total,
      chart_type = "p",
      y_axis_unit = "percent"
    )
  )
  expect_s3_class(plot2, "bfh_qic_result")
  expect_s3_class(plot2$plot, "ggplot")
})
