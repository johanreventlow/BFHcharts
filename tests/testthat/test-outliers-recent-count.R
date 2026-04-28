# Tests for RECENT_OBS_WINDOW konstant og effective_window i outlier-tæller
#
# Verificerer at:
# - RECENT_OBS_WINDOW konstant eksisterer og er 6L
# - effective_window = min(RECENT_OBS_WINDOW, n_obs) for korte serier
# - outliers_recent_count kun tæller inden for effective_window
# - Edge cases: n_obs 0–7 håndteres korrekt
#
# Relateret: OpenSpec harden-outliers-recent-count

# RECENT_OBS_WINDOW KONSTANT ==================================================

test_that("RECENT_OBS_WINDOW konstant eksisterer og er 6L", {
  expect_true(exists("RECENT_OBS_WINDOW", envir = asNamespace("BFHcharts")))
  expect_equal(BFHcharts:::RECENT_OBS_WINDOW, 6L)
})

# EFFECTIVE_WINDOW I STATS-OUTPUT =============================================

test_that("effective_window er til stede i stats for bfh_qic_result", {
  sigma_signal <- rep(FALSE, 10)
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_true("effective_window" %in% names(stats))
})

test_that("n_obs = 1 giver effective_window = 1", {
  sigma_signal <- c(FALSE)
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$effective_window, 1L)
})

test_that("n_obs = 5 giver effective_window = 5", {
  sigma_signal <- rep(FALSE, 5)
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$effective_window, 5L)
})

test_that("n_obs = 6 giver effective_window = 6", {
  sigma_signal <- rep(FALSE, 6)
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$effective_window, 6L)
})

test_that("n_obs = 7 giver effective_window = 6 (capped til RECENT_OBS_WINDOW)", {
  sigma_signal <- rep(FALSE, 7)
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$effective_window, 6L)
})

test_that("n_obs = 20 giver effective_window = 6 (capped til RECENT_OBS_WINDOW)", {
  sigma_signal <- rep(FALSE, 20)
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$effective_window, 6L)
})

# OUTLIERS KUN I DE FØRSTE OBS ================================================

test_that("outliers kun i første observationer giver outliers_recent_count = 0", {
  # 10 obs: outlier på position 1-3, ingen i de seneste 6 (positioner 5-10)
  sigma_signal <- c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  # total outliers = 3, men ingen i seneste 6
  expect_equal(stats$outliers_actual, 3)
  expect_equal(stats$outliers_recent_count, 0)
  expect_equal(stats$effective_window, 6L)
})

# EDGE CASES: TOM / INGEN SIGMA.SIGNAL ========================================

test_that("ingen sigma.signal kolonne giver NULL effective_window og NULL outliers_recent_count", {
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

  # Ingen sigma.signal → outliers_recent_count og effective_window forbliver NULL
  # (tabel skjuler rækken frem for at vise "-")
  expect_null(stats$outliers_recent_count)
  expect_null(stats$effective_window)
})

test_that("run chart giver NULL effective_window (ingen kontrolgrænser)", {
  sigma_signal <- rep(FALSE, 10)
  result <- fixture_bfh_qic_result(sigma_signal, chart_type = "run")

  stats <- bfh_extract_spc_stats(result)

  expect_null(stats$effective_window)
  expect_null(stats$outliers_recent_count)
  expect_true(stats$is_run_chart)
})

# KONSISTENS MED EKSISTERENDE OUTLIER-LOGIK ===================================

test_that("effective_window ændrer ikke eksisterende semantik for outliers_actual (total)", {
  # Outlier på position 5 (udenfor vinduet) og 20, 21 (i vinduet)
  # 21 obs total: seneste 6 = positioner 16-21
  sigma_signal <- c(
    rep(FALSE, 4),
    TRUE, # position 5 — udenfor vinduet
    rep(FALSE, 14),
    TRUE, TRUE # positioner 20, 21 — i vinduet
  )
  result <- fixture_bfh_qic_result(sigma_signal)

  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$outliers_actual, 3) # total i seneste part
  expect_equal(stats$outliers_recent_count, 2) # kun i vinduet
  expect_equal(stats$effective_window, 6L)
})
