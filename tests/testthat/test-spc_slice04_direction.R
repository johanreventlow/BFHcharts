# Tests: Slice 4 INCLUDE -- Direction modifier (uden target)
#
# Refs: openspec change restructure-spc-analysis-architecture, Slice 4


# Helper: byg multi-phase data hvor sidste fase har forskellig CL
# fra forrige. bfh_qic(part=N) splits efter punkt N (ej kolonne).
N_BASELINE <- 12L
N_CURRENT <- 12L

make_multiphase_data <- function(baseline_mean = 50, current_mean = 55) {
  set.seed(404L)
  values <- c(
    rnorm(N_BASELINE, mean = baseline_mean, sd = 1),
    rnorm(N_CURRENT, mean = current_mean, sd = 1)
  )
  data.frame(
    date = seq(as.Date("2023-01-01"),
      by = "month", length.out = N_BASELINE + N_CURRENT
    ),
    value = round(values, 1)
  )
}


# ==========================================================================
# .resolve_direction logic
# ==========================================================================

test_that("Slice 4: ingen metadata$direction -> features$direction = unknown", {
  data <- make_multiphase_data()
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = N_BASELINE)
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_equal(analysis$features$direction, "unknown")
})


test_that("Slice 4: metadata$direction = neutral -> features$direction = neutral", {
  data <- make_multiphase_data()
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = N_BASELINE)
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = as.Date("2026-05-18"),
      direction = "neutral"
    )
  )

  expect_equal(analysis$features$direction, "neutral")
})


test_that("Slice 4: higher_better + stigende CL -> favorable", {
  # Baseline=50, current=55: delta=+5
  data <- make_multiphase_data(baseline_mean = 50, current_mean = 55)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = N_BASELINE)
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = as.Date("2026-05-18"),
      direction = "higher_better"
    )
  )

  expect_equal(analysis$features$direction, "favorable")
})


test_that("Slice 4: higher_better + faldende CL -> unfavorable", {
  # Baseline=55, current=50: delta=-5
  data <- make_multiphase_data(baseline_mean = 55, current_mean = 50)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = N_BASELINE)
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = as.Date("2026-05-18"),
      direction = "higher_better"
    )
  )

  expect_equal(analysis$features$direction, "unfavorable")
})


test_that("Slice 4: lower_better + faldende CL -> favorable", {
  data <- make_multiphase_data(baseline_mean = 55, current_mean = 50)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = N_BASELINE)
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = as.Date("2026-05-18"),
      direction = "lower_better"
    )
  )

  expect_equal(analysis$features$direction, "favorable")
})


test_that("Slice 4: single-phase + metadata$direction -> neutral (kraever baseline)", {
  set.seed(405L)
  data_single <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_single, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = as.Date("2026-05-18"),
      direction = "higher_better"
    )
  )

  # Single-phase: ingen baseline -> direction=neutral selv med meta-direction
  expect_equal(analysis$features$direction, "neutral")
})


# ==========================================================================
# Render-integration: prose-clause appendes
# ==========================================================================

test_that("Slice 4: favorable direction appender 'i den ønskede retning' til stability", {
  data <- make_multiphase_data(baseline_mean = 50, current_mean = 55)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = N_BASELINE)
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = as.Date("2026-05-18"),
      direction = "higher_better"
    )
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)

  expect_match(text, "ønskede retning", ignore.case = TRUE)
})


test_that("Slice 4: unfavorable direction appender 'modsat' clause", {
  data <- make_multiphase_data(baseline_mean = 50, current_mean = 55)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = N_BASELINE)
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = as.Date("2026-05-18"),
      direction = "lower_better"
    )
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)

  expect_match(text, "uønsket retning|væk fra den ønskede", ignore.case = TRUE)
})


test_that("Slice 4: neutral/unknown emitter ingen direction-clause", {
  set.seed(406L)
  data_single <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_single, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )
  text <- bfh_render_analysis(analysis)

  expect_no_match(text, "ønskede retning")
  expect_no_match(text, "uønsket retning")
})


# ==========================================================================
# en.yaml mirror
# ==========================================================================

test_that("Slice 4: en.yaml mirror existerer", {
  data <- make_multiphase_data(baseline_mean = 50, current_mean = 55)
  res <- bfh_qic(data, x = date, y = value, chart_type = "i", part = N_BASELINE)
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = as.Date("2026-05-18"),
      direction = "higher_better"
    ),
    language = "en"
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)

  expect_match(text, "desired direction", ignore.case = TRUE)
})
