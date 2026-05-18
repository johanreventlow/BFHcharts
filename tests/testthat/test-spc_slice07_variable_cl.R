# Tests: Slice 7 INCLUDE -- Variable CL caveat
#
# Refs: openspec change restructure-spc-analysis-architecture, Slice 7


# ==========================================================================
# .detect_variable_cl() pure helper
# ==========================================================================

test_that("Slice 7: detect_variable_cl FALSE naar UCL/LCL mangler", {
  fake_run <- list(qic_data = data.frame(x = 1:10, y = rnorm(10)))
  expect_false(BFHcharts:::.detect_variable_cl(fake_run))
})

test_that("Slice 7: detect_variable_cl FALSE naar UCL/LCL er konstante", {
  fake_i <- list(qic_data = data.frame(
    x = 1:10, y = rnorm(10),
    ucl = rep(60, 10), lcl = rep(40, 10)
  ))
  expect_false(BFHcharts:::.detect_variable_cl(fake_i))
})

test_that("Slice 7: detect_variable_cl TRUE naar UCL/LCL varierer >10%", {
  # cv = sd / mean. Range har width 20, 24, 16, 22, 18 -> cv ~ 0.15
  fake_p <- list(qic_data = data.frame(
    x = 1:5, y = c(0.5, 0.6, 0.4, 0.55, 0.5),
    ucl = c(60, 72, 48, 66, 54),
    lcl = c(40, 48, 32, 44, 36)
  ))
  expect_true(BFHcharts:::.detect_variable_cl(fake_p))
})

test_that("Slice 7: detect_variable_cl FALSE naar variation <= 10%", {
  # Range 20, 21, 19, 20.5, 20 -> cv ~ 0.04
  fake_low <- list(qic_data = data.frame(
    x = 1:5, y = c(0.5, 0.6, 0.4, 0.55, 0.5),
    ucl = c(60, 60.5, 59.5, 60.25, 60),
    lcl = c(40, 39.5, 40.5, 39.75, 40)
  ))
  expect_false(BFHcharts:::.detect_variable_cl(fake_low))
})


# ==========================================================================
# Integration: p-chart med varierende sample-size
# ==========================================================================

test_that("Slice 7: p-chart med varierende n udloeser variable_cl-caveat", {
  set.seed(707L)
  # Stikproevestoerrelse varierer fra 50 til 500 -> kontrolgraense-bredde varierer
  ns <- c(50, 100, 75, 200, 150, 300, 500, 100, 250, 400, 80, 350, 120, 60, 450)
  data_p <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = length(ns)),
    numerator = rbinom(length(ns), ns, 0.10),
    denominator = ns
  )
  res <- bfh_qic(data_p,
    x = date, y = numerator, n = denominator,
    chart_type = "p"
  )

  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_true(isTRUE(analysis$features$data_quality$variable_cl))
  expect_equal(analysis$caveats$variable_cl, "variable_cl")
})


test_that("Slice 7: variable_cl-caveat appender til prose", {
  set.seed(708L)
  ns <- c(50, 100, 75, 200, 150, 300, 500, 100, 250, 400, 80, 350, 120, 60, 450)
  data_p <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = length(ns)),
    numerator = rbinom(length(ns), ns, 0.10),
    denominator = ns
  )
  res <- bfh_qic(data_p,
    x = date, y = numerator, n = denominator,
    chart_type = "p"
  )

  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)

  expect_match(text, "kontrolgrænserne varierer", ignore.case = TRUE)
})


test_that("Slice 7: i-chart med konstant n udloser IKKE variable_cl", {
  set.seed(709L)
  data_i <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_i, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_false(isTRUE(analysis$features$data_quality$variable_cl))
  expect_null(analysis$caveats$variable_cl)
})


test_that("Slice 7: run-chart har ingen UCL/LCL -> ingen caveat", {
  set.seed(710L)
  data_run <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_run, x = date, y = value, chart_type = "run")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_null(analysis$caveats$variable_cl)
})
