# ============================================================================
# CHART TYPE CONSTANTS TESTS
# ============================================================================

test_that("CHART_TYPES_EN contains all valid English codes", {
  expect_true(is.character(CHART_TYPES_EN))
  expect_true(length(CHART_TYPES_EN) > 0)

  # Check for all expected types
  expected_types <- c("run", "i", "mr", "p", "pp", "u", "up", "c", "g", "xbar", "s", "t")
  expect_true(all(expected_types %in% CHART_TYPES_EN))
})

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_that("Chart type utilities work in bfh_qic", {
  skip_if_fonts_unavailable()

  # Integration test: verify chart type utilities work in real workflow
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, 15, 2),
    total = rpois(12, 100)
  )

  # Test with English code
  plot1 <- bfh_qic(
    data = data,
    x = month,
    y = value,
    chart_type = "run",
    y_axis_unit = "count"
  )
  expect_s3_class(plot1, "bfh_qic_result")
  expect_s3_class(plot1$plot, "ggplot")

  # Test with ratio chart requiring denominator
  plot2 <- bfh_qic(
    data = data,
    x = month,
    y = value,
    n = total,
    chart_type = "p",
    y_axis_unit = "percent"
  )
  expect_s3_class(plot2, "bfh_qic_result")
  expect_s3_class(plot2$plot, "ggplot")
})

test_that("bfh_qic accepts all CHART_TYPES_EN chart types", {
  skip_if_fonts_unavailable()

  set.seed(42)

  # Basis testdata
  base_data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, 50, 10),
    count = rpois(24, 15),
    total = rpois(24, 100)
  )

  # Typer der ikke kræver nævner
  simple_types <- c("run", "i", "mr", "c", "g", "t")
  for (ct in simple_types) {
    result <- bfh_qic(
      data = base_data, x = month, y = value,
      chart_type = ct, y_axis_unit = "count"
    )
    expect_s3_class(result, "bfh_qic_result")
  }

  # Typer der kræver nævner
  denom_types <- c("p", "pp", "u", "up")
  for (ct in denom_types) {
    result <- bfh_qic(
      data = base_data, x = month, y = count, n = total,
      chart_type = ct, y_axis_unit = "percent"
    )
    expect_s3_class(result, "bfh_qic_result")
  }

  # xbar og s kræver subgrupperet data
  subgroup_data <- data.frame(
    group = rep(1:12, each = 5),
    value = rnorm(60, 50, 10)
  )
  for (ct in c("xbar", "s")) {
    result <- bfh_qic(
      data = subgroup_data, x = group, y = value,
      chart_type = ct, y_axis_unit = "count"
    )
    expect_s3_class(result, "bfh_qic_result")
  }
})

test_that("bfh_qic rejects invalid chart types", {
  data <- data.frame(month = Sys.Date(), value = 1)
  expect_error(
    bfh_qic(data = data, x = month, y = value, chart_type = "invalid"),
    "chart_type must be one of"
  )
})
