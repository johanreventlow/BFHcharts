# Tests: Slice 8 INCLUDE -- Few-obs / not-evaluable override
#
# Refs: openspec change restructure-spc-analysis-architecture, Slice 8

set.seed(808L)
TEST_DATA_SHORT <- data.frame(
  date = seq(as.Date("2024-01-01"), by = "month", length.out = 8L),
  value = round(rnorm(8L, 50, 5), 1)
)

TEST_DATA_MIN <- data.frame(
  date = seq(as.Date("2024-01-01"), by = "month", length.out = 11L),
  value = round(rnorm(11L, 50, 5), 1)
)


test_that("Slice 8: n < N_MIN udloeser confidence_tier=low + stability_pattern=not_evaluable", {
  res <- bfh_qic(TEST_DATA_SHORT, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  # Cycle 04 H4 + M1 fix: stability_pattern canonical "not_evaluable" naar
  # confidence=low. caveats$few_obs dropped -- low-confidence-override er
  # primaer mekanisme.
  expect_equal(analysis$confidence, "low")
  expect_equal(analysis$features$stability_pattern, "not_evaluable")
  expect_null(analysis$caveats$few_obs)
})


test_that("Slice 8: low-confidence render erstatter stability-base", {
  res <- bfh_qic(TEST_DATA_SHORT, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  text <- bfh_render_analysis(analysis, max_chars = 800L)

  # not_evaluable-tekst er aktiv
  expect_match(text, "for kort serie|kun.*observationer", ignore.case = TRUE)
  # standard-stability-formuleringer SKAL IKKE optraede
  expect_no_match(text, "stabil og forudsigelig", ignore.case = TRUE)
  expect_no_match(text, "skift i niveau", ignore.case = TRUE)
})


test_that("Slice 8: low-confidence skipper target+action arms", {
  res <- bfh_qic(TEST_DATA_SHORT,
    x = date, y = value, chart_type = "i",
    target_text = "<= 100"
  )
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  text <- bfh_render_analysis(analysis, max_chars = 800L)

  # Target-arm-clauses skal IKKE rendres ved low confidence
  expect_no_match(text, "Det nuværende niveau ligger")
  expect_no_match(text, "Det nuværende niveau opfylder")
  # Action-arm-clauses skal IKKE rendres
  expect_no_match(text, "Fortsæt med praksis")
  expect_no_match(text, "Identificér og fjern")
})


test_that("Slice 8: n = 11 (lige under N_MIN) udloeser low-tier", {
  res <- bfh_qic(TEST_DATA_MIN, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_equal(analysis$confidence, "low")
})


test_that("Slice 8: n >= N_MIN er IKKE low-tier", {
  set.seed(810L)
  data_12 <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 12L),
    value = round(rnorm(12L, 50, 5), 1)
  )
  res <- bfh_qic(data_12, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_true(analysis$confidence %in% c("medium", "high"))
})


test_that("Slice 8: run-chart n=24 with sigma_hat=NA SKAL IKKE udloese low-tier (N1 fix)", {
  set.seed(811L)
  data_24 <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_24, x = date, y = value, chart_type = "run")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_true(is.na(analysis$aux$sigma_hat))
  expect_true(is.finite(analysis$aux$sigma_data))
  expect_equal(analysis$confidence, "high")
})


test_that("Slice 8: en.yaml mirror existerer for not_evaluable", {
  res <- bfh_qic(TEST_DATA_SHORT, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18")),
    language = "en"
  )

  text <- bfh_render_analysis(analysis, max_chars = 800L)
  expect_match(text, "too short|observations|sparse|reliable assessment",
    ignore.case = TRUE
  )
})


# ==========================================================================
# Cycle 05 finding #5: low_confidence_reason dispatcher
# ==========================================================================

test_that("Cycle 05 finding #5: few_obs reason -> nr-obs-prose", {
  res <- bfh_qic(TEST_DATA_SHORT, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_equal(analysis$features$low_confidence_reason, "few_obs")
  text <- bfh_render_analysis(analysis, max_chars = 800L)
  expect_match(text, "kun.*observationer|for kort serie", ignore.case = TRUE)
})


test_that("Cycle 05 finding #5: NA reason naar confidence-tier ej low", {
  set.seed(805L)
  data_24 <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_24, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  expect_true(is.na(analysis$features$low_confidence_reason))
})
