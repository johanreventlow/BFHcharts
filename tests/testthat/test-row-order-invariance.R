# Tests for row-order invariance i outliers_recent_count
#
# Verificerer at bfh_extract_spc_stats.bfh_qic_result() sorterer qic_data
# efter x inden recency-vinduet beregnes, så input-rækkefølgen ikke påvirker
# resultatet.
#
# Relateret: OpenSpec harden-outliers-recent-count (row-order fix)

# Hjælper: byg fixture med eksplicit x + sigma.signal — ikke via fixture_bfh_qic_result
# fordi den hardcoder x = seq_len(n); her skal x og sigma.signal permuteres samlet.
make_result_with_x <- function(x_vals, sigma_vals, chart_type = "i") {
  n <- length(x_vals)
  stopifnot(n == length(sigma_vals))

  qic_data <- data.frame(
    x = x_vals,
    y = seq_len(n),
    cl = rep(0, n),
    sigma.signal = sigma_vals
  )

  summary_df <- data.frame(
    `længste_løb` = 3L,
    `længste_løb_max` = 7L,
    antal_kryds = 6L,
    antal_kryds_min = 4L,
    centerlinje = 0,
    check.names = FALSE
  )

  structure(
    list(
      plot = ggplot2::ggplot(),
      summary = summary_df,
      qic_data = qic_data,
      config = list(chart_type = chart_type)
    ),
    class = c("bfh_qic_result", "list")
  )
}

# ROW-ORDER INVARIANCE =========================================================

test_that("sorteret stigende input giver baseline (regression)", {
  # 10 obs: outlier ved x=8, x=9 — inden for seneste 6 (x=5..10)
  x_vals <- 1:10
  sigma_vals <- c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE)

  result <- make_result_with_x(x_vals, sigma_vals)
  stats <- bfh_extract_spc_stats(result)

  # Baseline: 2 outliers i seneste 6 observationer
  expect_equal(stats$outliers_recent_count, 2L)
  expect_equal(stats$effective_window, 6L)
})

test_that("omvendt rækkefølge giver samme resultat som stigende", {
  x_vals <- 1:10
  sigma_vals <- c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE)

  result_asc <- make_result_with_x(x_vals, sigma_vals)
  result_desc <- make_result_with_x(rev(x_vals), rev(sigma_vals))

  stats_asc <- bfh_extract_spc_stats(result_asc)
  stats_desc <- bfh_extract_spc_stats(result_desc)

  expect_equal(stats_desc$outliers_recent_count, stats_asc$outliers_recent_count)
  expect_equal(stats_desc$effective_window, stats_asc$effective_window)
  expect_equal(stats_desc$outliers_actual, stats_asc$outliers_actual)
})

test_that("tilfældig permutation giver samme resultat som stigende (seed 42)", {
  set.seed(42)
  n <- 12
  x_vals <- 1:n
  sigma_vals <- c(rep(FALSE, 6), TRUE, FALSE, FALSE, TRUE, FALSE, FALSE)

  perm <- sample(n)

  result_sorted <- make_result_with_x(x_vals, sigma_vals)
  result_perm <- make_result_with_x(x_vals[perm], sigma_vals[perm])

  stats_sorted <- bfh_extract_spc_stats(result_sorted)
  stats_perm <- bfh_extract_spc_stats(result_perm)

  expect_equal(stats_perm$outliers_recent_count, stats_sorted$outliers_recent_count)
  expect_equal(stats_perm$effective_window, stats_sorted$effective_window)
  expect_equal(stats_perm$outliers_actual, stats_sorted$outliers_actual)
})

test_that("signal kun ved x-start → recent_count = 0 uanset input-rækkefølge", {
  # 10 obs: outliers kun ved x=1 og x=2 (udenfor seneste 6: x=5..10)
  x_vals <- 1:10
  sigma_vals <- c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)

  # Stigende
  result_asc <- make_result_with_x(x_vals, sigma_vals)
  # Omvendt
  result_desc <- make_result_with_x(rev(x_vals), rev(sigma_vals))

  stats_asc <- bfh_extract_spc_stats(result_asc)
  stats_desc <- bfh_extract_spc_stats(result_desc)

  expect_equal(stats_asc$outliers_recent_count, 0L)
  expect_equal(stats_desc$outliers_recent_count, 0L)
})

test_that("signal kun ved x-end → recent_count > 0 uanset input-rækkefølge", {
  # 10 obs: outliers kun ved x=9 og x=10 (i seneste 6: x=5..10)
  x_vals <- 1:10
  sigma_vals <- c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE)

  # Stigende
  result_asc <- make_result_with_x(x_vals, sigma_vals)
  # Omvendt
  result_desc <- make_result_with_x(rev(x_vals), rev(sigma_vals))

  stats_asc <- bfh_extract_spc_stats(result_asc)
  stats_desc <- bfh_extract_spc_stats(result_desc)

  expect_equal(stats_asc$outliers_recent_count, 2L)
  expect_equal(stats_desc$outliers_recent_count, 2L)
})
