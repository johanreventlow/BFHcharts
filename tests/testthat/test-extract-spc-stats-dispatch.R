# Tests for bfh_extract_spc_stats() S3 dispatch and outlier counting
#
# Context:
# - bfh_extract_spc_stats() blev udvidet fra en enkelt funktion til S3-generic
#   med methods for data.frame (summary) og bfh_qic_result.
# - Den gamle semantik for data.frame-input bevares (backward compat).
# - For bfh_qic_result-input tælles outliers med to felter:
#     * outliers_actual: TOTAL antal outliers i seneste part (til tabellen i PDF)
#     * outliers_recent_count: Antal outliers i seneste 6 obs (til analyseteksten)
#
# Issue: #XX (biSPCharts preview viser forkert outlier-antal)

# HELPER: fixture_bfh_qic_result() er tilgængelig via helper-fixtures.R.

# S3 DISPATCH =================================================================

test_that("bfh_extract_spc_stats.data.frame preserves backward-compatible behavior", {
  summary <- data.frame(
    længste_løb = 5L,
    længste_løb_max = 7L,
    antal_kryds = 6L,
    antal_kryds_min = 4L
  )

  stats <- bfh_extract_spc_stats(summary)

  expect_equal(stats$runs_actual, 5L)
  expect_equal(stats$runs_expected, 7L)
  expect_equal(stats$crossings_actual, 6L)
  expect_equal(stats$crossings_expected, 4L)
  # Backward compat: data.frame-method kender ikke qic_data, så outliers er NULL
  expect_null(stats$outliers_actual)
  expect_null(stats$outliers_expected)
})

test_that("bfh_extract_spc_stats(NULL) returns empty stats (backward compat)", {
  stats <- bfh_extract_spc_stats(NULL)

  expect_null(stats$runs_actual)
  expect_null(stats$crossings_actual)
  expect_null(stats$outliers_actual)
})

test_that("bfh_extract_spc_stats errors on invalid input class", {
  expect_error(bfh_extract_spc_stats("string"))
  expect_error(bfh_extract_spc_stats(123))
  expect_error(bfh_extract_spc_stats(list(a = 1)))
})

# TABEL-TAL: outliers_actual = TOTAL i seneste part ==========================

test_that("bfh_extract_spc_stats(bfh_qic_result) returns TOTAL outliers in latest part", {
  # Regression for konkret bug: 3 outliers total, 2 i seneste 6 obs.
  # Før fix: outliers_actual == 2 (begrænset til seneste 6).
  # Efter fix: outliers_actual == 3 (total i seneste part).
  sigma_signal <- c(
    rep(FALSE, 5),
    TRUE,                 # outlier på position 6 (udenfor seneste 6 obs)
    rep(FALSE, 13),
    TRUE, TRUE            # 2 outliers på position 20 og 21 (inden for seneste 6)
  )
  # 21 obs total: seneste 6 = positioner 16-21 => kun 2 outliers i vinduet
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$outliers_actual, 3)
  expect_equal(stats$outliers_expected, 0)
})

test_that("bfh_extract_spc_stats only counts outliers in latest part when phases present", {
  # Outliers i begge parts; kun seneste part skal tælles i tabellen.
  sigma_signal <- c(TRUE, TRUE, FALSE, FALSE, FALSE, TRUE)
  parts <- c(1, 1, 1, 2, 2, 2)
  result <- fixture_bfh_qic_result(sigma_signal, part = parts)

  stats <- bfh_extract_spc_stats(result)

  # Seneste part = 2, har 1 outlier på position 6
  expect_equal(stats$outliers_actual, 1)
})

# ANALYSE-TEKST: outliers_recent_count = seneste 6 obs =======================

test_that("bfh_extract_spc_stats(bfh_qic_result) exposes outliers_recent_count for last 6 obs", {
  sigma_signal <- c(
    rep(FALSE, 5),
    TRUE,                 # udenfor vinduet
    rep(FALSE, 13),
    TRUE, TRUE            # i vinduet (seneste 6 obs)
  )
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$outliers_recent_count, 2)
})

test_that("outliers_recent_count equals outliers_actual when all outliers fall in last 6 obs", {
  sigma_signal <- c(rep(FALSE, 15), TRUE, FALSE, TRUE, FALSE, FALSE)
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$outliers_actual, 2)
  expect_equal(stats$outliers_recent_count, 2)
})

test_that("outliers_recent_count filters to latest part AND last 6 obs within it", {
  # Seneste part starter ved part == 2
  sigma_signal <- c(TRUE, TRUE, rep(FALSE, 20), TRUE)
  parts <- c(rep(1, 10), rep(2, 13))
  result <- fixture_bfh_qic_result(sigma_signal, part = parts)

  stats <- bfh_extract_spc_stats(result)

  # outliers_actual: total i seneste part (part 2) = 1
  expect_equal(stats$outliers_actual, 1)
  # outliers_recent_count: seneste 6 obs i part 2 (obs 8-13) = 1
  expect_equal(stats$outliers_recent_count, 1)
})

# RUN CHARTS ==================================================================

test_that("bfh_extract_spc_stats(bfh_qic_result) returns NULL outliers for run charts", {
  sigma_signal <- c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE)
  result <- fixture_bfh_qic_result(sigma_signal, chart_type = "run")

  stats <- bfh_extract_spc_stats(result)

  expect_null(stats$outliers_actual)
  expect_null(stats$outliers_expected)
  expect_null(stats$outliers_recent_count)
  expect_true(stats$is_run_chart)
})

# EDGE CASES ==================================================================

test_that("bfh_extract_spc_stats returns 0 outliers when no sigma.signal triggers", {
  sigma_signal <- rep(FALSE, 20)
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$outliers_actual, 0)
  expect_equal(stats$outliers_recent_count, 0)
  expect_equal(stats$outliers_expected, 0)
})

test_that("bfh_extract_spc_stats handles missing sigma.signal column gracefully", {
  qic_data <- data.frame(x = 1:5, y = 1:5, cl = rep(0, 5))
  result <- structure(
    list(
      plot = ggplot2::ggplot(),
      summary = data.frame(),
      qic_data = qic_data,
      config = list(chart_type = "i")
    ),
    class = c("bfh_qic_result", "list")
  )

  stats <- bfh_extract_spc_stats(result)

  # Ingen sigma.signal → outliers skal forblive NULL (tabel skjuler rækken)
  expect_null(stats$outliers_actual)
  expect_null(stats$outliers_recent_count)
})

test_that("bfh_extract_spc_stats preserves runs and crossings from summary", {
  sigma_signal <- c(rep(FALSE, 14), TRUE)
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  # Skal også indeholde runs/crossings fra summary via data.frame-method
  expect_equal(stats$runs_actual, 3L)
  expect_equal(stats$runs_expected, 7L)
  expect_equal(stats$crossings_actual, 6L)
  expect_equal(stats$crossings_expected, 4L)
})
