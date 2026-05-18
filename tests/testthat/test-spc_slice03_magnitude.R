# Tests: Slice 3 INCLUDE -- Magnitude modifier (sigma-shift bucket)
#
# Refs: openspec change restructure-spc-analysis-architecture, Slice 3


# ==========================================================================
# .compute_magnitude() pure helper
# ==========================================================================

test_that("Slice 3: magnitude=NA naar baseline_delta=NA", {
  expect_true(is.na(BFHcharts:::.compute_magnitude(NA_real_, 1, 1)))
  expect_true(is.na(BFHcharts:::.compute_magnitude(NULL, 1, 1)))
})

test_that("Slice 3: magnitude=NA naar |delta| < 1e-9 (no shift)", {
  expect_true(is.na(BFHcharts:::.compute_magnitude(0, 1, 1)))
  expect_true(is.na(BFHcharts:::.compute_magnitude(1e-10, 1, 1)))
})

test_that("Slice 3: magnitude buckets via sigma_hat", {
  # ratio = delta / sigma
  expect_equal(BFHcharts:::.compute_magnitude(0.5, 1.0, 0.8), "small") # 0.5
  expect_equal(BFHcharts:::.compute_magnitude(1.5, 1.0, 0.8), "medium") # 1.5
  expect_equal(BFHcharts:::.compute_magnitude(3.0, 1.0, 0.8), "large") # 3.0
})

test_that("Slice 3: sigma_data fallback naar sigma_hat NA", {
  expect_equal(BFHcharts:::.compute_magnitude(0.5, NA_real_, 1.0), "small")
  expect_equal(BFHcharts:::.compute_magnitude(2.5, NA, 1.0), "large")
})

test_that("Slice 3: magnitude=NA naar baade sigma_hat og sigma_data er NA", {
  expect_true(is.na(BFHcharts:::.compute_magnitude(1.0, NA, NA)))
})


# ==========================================================================
# Integration: multi-phase data udloeser magnitude-bucket
# ==========================================================================

make_phase_data <- function(baseline_mean = 50, current_mean = 55,
                            sigma_d = 1.0) {
  set.seed(303L)
  n <- 12L
  values <- c(
    rnorm(n, mean = baseline_mean, sd = sigma_d),
    rnorm(n, mean = current_mean, sd = sigma_d)
  )
  data.frame(
    date = seq(as.Date("2023-01-01"), by = "month", length.out = 2 * n),
    value = round(values, 1)
  )
}


test_that("Slice 3: large shift (5 sigma) -> features$magnitude=large", {
  # baseline=50, current=55, sigma_d=1 -> delta=5, ratio=~5 (large)
  data <- make_phase_data(50, 55, sigma_d = 1)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = 12L)
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_equal(analysis$features$magnitude, "large")
  expect_true(is.finite(analysis$aux$baseline_delta_pct))
})


test_that("Slice 3: small shift -> features$magnitude=small", {
  # baseline=50, current=50.3, sigma_d=2 -> delta=0.3, ratio<<1 (small)
  data <- make_phase_data(50, 50.3, sigma_d = 2.0)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = 12L)
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_true(analysis$features$magnitude %in% c("small", NA_character_))
})


test_that("Slice 3: single-phase -> magnitude=NA (no baseline_delta)", {
  set.seed(304L)
  data_single <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_single, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_true(is.na(analysis$features$magnitude))
})


# ==========================================================================
# Render-integration: magnitude appender prose-clause
# ==========================================================================

test_that("Slice 3: large magnitude appender procent-clause", {
  data <- make_phase_data(50, 55, sigma_d = 1)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = 12L)
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)

  # Procent-tegn + "forandring" forventes
  expect_match(text, "%.*forandring|forandring.*%", ignore.case = TRUE)
})


test_that("Slice 3: magnitude + direction kombineret (small/medium prose-floder)", {
  data <- make_phase_data(50, 55, sigma_d = 1)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = 12L)
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = as.Date("2026-05-18"),
      direction = "higher_better"
    )
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)

  expect_match(text, "forandring", ignore.case = TRUE)
  expect_match(text, "ønskede retning", ignore.case = TRUE)
})


test_that("Slice 3: NA magnitude -> ingen prose-clause", {
  set.seed(305L)
  data_single <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_single, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )
  text <- bfh_render_analysis(analysis)

  expect_no_match(text, "forandring")
})


# ==========================================================================
# en.yaml mirror
# ==========================================================================

test_that("Slice 3: en.yaml mirror existerer", {
  data <- make_phase_data(50, 55, sigma_d = 1)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = 12L)
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18")),
    language = "en"
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)

  expect_match(text, "change", ignore.case = TRUE)
})
