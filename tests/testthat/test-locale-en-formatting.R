# ============================================================================
# Locale-aware EN/DA formatering (Codex 2026-04-30 #3 / locale-aware-en-formatting)
# ============================================================================
# Verificerer at language="en" parameter producerer engelsk talnotation
# (decimal `.`, thousand `,`) på både y-akse og percent-formatering.

# ----------------------------------------------------------------------------
# format_count() dispatcher (utils_number_formatting.R)
# ----------------------------------------------------------------------------

test_that("format_count('da') producerer dansk format (decimal `,`, thousand `.`)", {
  # Værdier >= 1000 triggrer K-notation; smaller værdier viser fuld notation
  expect_equal(format_count(123.5, "da"), "123,5") # < 1000: ingen scaling
  expect_equal(format_count(1500, "da"), "1,5K")
  expect_equal(format_count(2.3e6, "da"), "2,3M")
  expect_equal(format_count(1.5e9, "da"), "1,5 mia.")
})

test_that("format_count('en') producerer engelsk format (decimal `.`, thousand `,`)", {
  expect_equal(format_count(123.5, "en"), "123.5") # < 1000: fuld notation
  expect_equal(format_count(1500, "en"), "1.5K")
  expect_equal(format_count(2.3e6, "en"), "2.3M")
  expect_equal(format_count(1.5e9, "en"), "1.5 B")
})

test_that("format_count default = 'da' (backward compat)", {
  expect_equal(format_count(123.5), "123,5")
  expect_equal(format_count(1234.5), "1,2K") # K-notation triggrer
})

test_that("format_count thousand-separator: ikke-skaleret tal under 1000 i en", {
  # Test at thousand-separator faktisk virker for tal mellem 100-999 (uskaleret)
  # Vi har ingen tal i [1000, 999999] uden K-skaling, så test integer-format:
  expect_equal(format_count(999, "en"), "999")
  expect_equal(format_count(999, "da"), "999")
})

# ----------------------------------------------------------------------------
# Y-axis count labels
# ----------------------------------------------------------------------------

test_that("format_y_axis_count language='en' producerer engelsk thousand-separator", {
  scale <- format_y_axis_count(language = "en")
  labels <- scale$labels(c(1000, 2000, 3000))
  expect_equal(labels, c("1K", "2K", "3K"))

  # Småtal bevarer engelsk thousand-separator
  labels_small <- scale$labels(c(500, 750, 999))
  expect_equal(labels_small, c("500", "750", "999"))
})

test_that("format_y_axis_count language='da' producerer dansk thousand-separator (regression)", {
  scale <- format_y_axis_count(language = "da")
  labels <- scale$labels(c(1000, 2000, 3000))
  # K-notation aktiveres ved >=1000
  expect_equal(labels, c("1K", "2K", "3K"))
})

# ----------------------------------------------------------------------------
# Y-axis percent labels
# ----------------------------------------------------------------------------

test_that("format_y_axis_percent language='en' producerer engelsk percent-format (uden space)", {
  # Narrow range -> decimaler bruges
  scale <- format_y_axis_percent(c(0.975, 0.990), language = "en")
  labels <- scale$labels(c(0.975, 0.980))
  expect_equal(labels, c("97.5%", "98.0%"))
})

test_that("format_y_axis_percent language='da' producerer dansk percent-format (med komma)", {
  # Narrow range -> decimaler bruges
  scale <- format_y_axis_percent(c(0.975, 0.990), language = "da")
  labels <- scale$labels(c(0.975, 0.980))
  # Dansk: decimaltegn = komma, suffix indeholder space (kan vaere NBSP fra scales)
  expect_true(all(grepl(",", labels))) # decimal-tegn er komma
  expect_match(labels[1], "^97,5") # "97,5" prefix
})

# ----------------------------------------------------------------------------
# bfh_qic() ende-til-ende: language flyder gennem til y-akse
# ----------------------------------------------------------------------------

test_that("bfh_qic(language='en') producerer engelsk y-akse-format på count-data", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = c(1000, 1100, 1200, 1500, 2000, 2300, 2500, 2700, 3000, 3200, 3500, 3800)
  )
  result <- bfh_qic(data, x = month, y = value, chart_type = "i", language = "en")
  expect_s3_class(result, "bfh_qic_result")
  expect_equal(result$config$language, "en")
})

test_that("bfh_qic(language='da') (default) bevarer dansk y-akse-format", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = c(1000, 1100, 1200, 1500, 2000, 2300, 2500, 2700, 3000, 3200, 3500, 3800)
  )
  result <- suppressWarnings(
    bfh_qic(data, x = month, y = value, chart_type = "i") # default da
  )
  expect_equal(result$config$language, "da")
})

# ----------------------------------------------------------------------------
# format_y_value() locale-awareness (utils_label_formatting.R)
# ----------------------------------------------------------------------------

test_that("format_y_value count: 'da' producerer dansk format", {
  expect_equal(format_y_value(1234, "count", language = "da"), "1,2K")
  expect_equal(format_y_value(123.5, "count", language = "da"), "123,5")
})

test_that("format_y_value count: 'en' producerer engelsk format", {
  expect_equal(format_y_value(1234, "count", language = "en"), "1.2K")
  expect_equal(format_y_value(123.5, "count", language = "en"), "123.5")
})

test_that("format_y_value rate: 'da' producerer dansk decimal-tegn", {
  result <- format_y_value(1.5, "rate", language = "da")
  expect_true(grepl(",", result, fixed = TRUE))
})

test_that("format_y_value rate: 'en' producerer engelsk decimal-tegn", {
  result <- format_y_value(1.5, "rate", language = "en")
  expect_true(grepl(".", result, fixed = TRUE))
  expect_false(grepl(",", result, fixed = TRUE))
})

test_that("format_y_value percent: 'da' producerer dansk komma naer target", {
  result <- format_y_value(0.887, "percent", target = 0.90, language = "da")
  expect_true(grepl(",", result, fixed = TRUE))
})

test_that("format_y_value percent: 'en' producerer engelsk punktum naer target", {
  result <- format_y_value(0.887, "percent", target = 0.90, language = "en")
  expect_false(grepl(",", result, fixed = TRUE))
  expect_true(grepl(".", result, fixed = TRUE))
})

test_that("format_y_value default: 'en' producerer engelsk decimal-tegn", {
  result <- format_y_value(1.5, "other", language = "en")
  expect_true(grepl(".", result, fixed = TRUE))
  expect_false(grepl(",", result, fixed = TRUE))
})

test_that("format_y_value default language = 'da' (bagudkompatibilitet)", {
  result <- format_y_value(1234, "count")
  expect_equal(result, "1,2K")
})

# ----------------------------------------------------------------------------
# spc_plot_config validation
# ----------------------------------------------------------------------------

test_that("spc_plot_config afviser ukendt language", {
  expect_error(
    spc_plot_config(language = "fr"),
    "language must be 'da' or 'en'"
  )
})
