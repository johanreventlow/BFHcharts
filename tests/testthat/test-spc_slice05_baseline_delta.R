# Tests: Slice 5 INCLUDE -- Baseline-delta + phase-intervention modifier
#
# Refs: openspec change restructure-spc-analysis-architecture, Slice 5


make_phase_data_slice5 <- function(baseline_mean = 50, current_mean = 55,
                                   sigma_d = 1.0, n = 12L) {
  set.seed(505L)
  values <- c(
    rnorm(n, mean = baseline_mean, sd = sigma_d),
    rnorm(n, mean = current_mean, sd = sigma_d)
  )
  data.frame(
    date = seq(as.Date("2023-01-01"), by = "month", length.out = 2 * n),
    value = round(values, 1)
  )
}


# ==========================================================================
# phase_context detection
# ==========================================================================

test_that("Slice 5: single-phase data -> phase_context = single", {
  set.seed(506L)
  data_single <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_single, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_equal(analysis$features$phase_context, "single")
})


test_that("Slice 5: multi-phase data -> phase_context = post_intervention", {
  data <- make_phase_data_slice5()
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = 12L)
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_equal(analysis$features$phase_context, "post_intervention")
})


test_that("Slice 5: aux indeholder baseline_centerline + baseline_delta_pct", {
  data <- make_phase_data_slice5(50, 55)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = 12L)
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_true(is.finite(analysis$aux$baseline_centerline))
  expect_true(is.finite(analysis$aux$baseline_delta))
  expect_true(is.finite(analysis$aux$baseline_delta_pct))
})


# ==========================================================================
# Render-integration: baseline-delta modifier appender prose-clause
# ==========================================================================

test_that("Slice 5: post_intervention rendres med fra-til-clause", {
  data <- make_phase_data_slice5(50, 55)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = 12L)
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)

  # Forventer "flyttet fra X til Y" pattern
  expect_match(text, "flyttet fra.*til|fra.*til", ignore.case = TRUE)
})


test_that("Slice 5: single-phase emitter ingen baseline-delta-clause", {
  set.seed(507L)
  data_single <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_single, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )
  text <- bfh_render_analysis(analysis)

  expect_no_match(text, "flyttet fra")
})


# ==========================================================================
# Kombineret med magnitude + direction (full modifier-cascade)
# ==========================================================================

test_that("Slice 5: kombineret med magnitude + direction (rige prose)", {
  data <- make_phase_data_slice5(50, 55)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = 12L)
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = as.Date("2026-05-18"),
      direction = "higher_better"
    )
  )
  text <- bfh_render_analysis(analysis, max_chars = 1200L)

  # Forventer alle tre modifier-clauses
  expect_match(text, "forandring", ignore.case = TRUE) # magnitude
  expect_match(text, "ønskede retning", ignore.case = TRUE) # direction
  expect_match(text, "flyttet fra", ignore.case = TRUE) # baseline_delta
})


# ==========================================================================
# en.yaml mirror
# ==========================================================================

test_that("Slice 5: en.yaml mirror existerer", {
  data <- make_phase_data_slice5(50, 55)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = 12L)
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18")),
    language = "en"
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)

  expect_match(text, "from.*to", ignore.case = TRUE)
})
