# Tests for auto-mean substitution in run charts when >=50% of last-phase
# observations sit exactly on the median centerline.
#
# Background: qicharts2 hardcodes median as centerline for run charts.
# With discrete/coarse-reported data, Anhoej run/crossing analysis
# degenerates when many points sit exactly on the CL. bfh_qic() detects
# this condition in the last phase and auto-substitutes the centerline
# with the mean for that phase. Earlier phases keep the median.
#
# Detection scope: LAST phase only (mirrors filter_qic_to_last_phase()
# convention used by bfh_build_analysis_context and bfh_extract_spc_stats).

test_that("detect_majority_at_median_lastphase returns FALSE for non-run charts", {
  qic_data <- data.frame(
    x = 1:10,
    y = c(rep(1, 6), 2, 3, 4, 5),
    cl = rep(1, 10)
  )
  expect_false(BFHcharts:::detect_majority_at_median_lastphase(qic_data, "i"))
  expect_false(BFHcharts:::detect_majority_at_median_lastphase(qic_data, "p"))
})

test_that("detect_majority_at_median_lastphase fires when >=50% on median", {
  # 6 out of 10 on median (60%) -> trigger
  qic_data <- data.frame(
    x = 1:10,
    y = c(rep(1, 6), 2, 3, 4, 5),
    cl = rep(1, 10)
  )
  expect_true(BFHcharts:::detect_majority_at_median_lastphase(qic_data, "run"))
})

test_that("detect_majority_at_median_lastphase respects threshold boundary", {
  # Exactly 50%: 5 of 10 on median -> trigger (>=, not >)
  qic_data_50 <- data.frame(
    x = 1:10,
    y = c(rep(1, 5), 2, 3, 4, 5, 6),
    cl = rep(1, 10)
  )
  expect_true(BFHcharts:::detect_majority_at_median_lastphase(qic_data_50, "run"))

  # 4 of 10 (40%) -> no trigger
  qic_data_40 <- data.frame(
    x = 1:10,
    y = c(rep(1, 4), 2, 3, 4, 5, 6, 7),
    cl = rep(1, 10)
  )
  expect_false(BFHcharts:::detect_majority_at_median_lastphase(qic_data_40, "run"))
})

test_that("detect_majority_at_median_lastphase skips no_variation (constant y)", {
  qic_data <- data.frame(
    x = 1:10,
    y = rep(5, 10),
    cl = rep(5, 10)
  )
  expect_false(BFHcharts:::detect_majority_at_median_lastphase(qic_data, "run"))
})

test_that("detect_majority_at_median_lastphase filters to last phase only", {
  # Phase 1: 10 continuous points; Phase 2: 10 points with 6 on median.
  # Only phase 2 should trigger -> overall TRUE.
  qic_data <- data.frame(
    x = 1:20,
    y = c(rnorm(10, 5, 2), rep(1, 6), 2, 3, 4, 5),
    cl = c(rep(5, 10), rep(1, 10)),
    part = c(rep(1, 10), rep(2, 10))
  )
  expect_true(BFHcharts:::detect_majority_at_median_lastphase(qic_data, "run"))
})

test_that("detect_majority_at_median_lastphase ignores prior-phase majority", {
  # Phase 1 has 60% on median; Phase 2 continuous. Last-phase scope
  # means we evaluate only phase 2 -> no trigger.
  set.seed(42)
  qic_data <- data.frame(
    x = 1:20,
    y = c(rep(1, 6), 2, 3, 4, 5, rnorm(10, 10, 2)),
    cl = c(rep(1, 10), rep(10, 10)),
    part = c(rep(1, 10), rep(2, 10))
  )
  expect_false(BFHcharts:::detect_majority_at_median_lastphase(qic_data, "run"))
})

test_that("bfh_qic auto-substitutes median to mean for discrete run-chart data", {
  # median(y) = 1, mean(y) = 2; expect cl == mean after auto-sub.
  data <- data.frame(x = 1:20, y = c(rep(1, 12), 2, 2, 3, 3, 4, 4, 5, 5))
  expect_equal(median(data$y), 1)
  expect_equal(mean(data$y), 2)

  result <- bfh_qic(data, x = x, y = y, chart_type = "run")
  expect_true(isTRUE(attr(result$summary, "cl_auto_mean")))
  expect_false(isTRUE(attr(result$summary, "cl_user_supplied")))
  expect_equal(result$qic_data$cl[1], 2)
})

test_that("bfh_qic skips auto-sub for continuous run-chart data", {
  set.seed(42)
  data <- data.frame(x = 1:20, y = rnorm(20, 10, 2))
  result <- bfh_qic(data, x = x, y = y, chart_type = "run")
  expect_false(isTRUE(attr(result$summary, "cl_auto_mean")))
  # cl should still match the data-estimated median
  expect_equal(result$qic_data$cl[1], median(data$y))
})

test_that("bfh_qic skips auto-sub when user supplies cl=", {
  data <- data.frame(x = 1:20, y = c(rep(1, 12), 2, 2, 3, 3, 4, 4, 5, 5))
  result <- suppressWarnings(
    bfh_qic(data, x = x, y = y, chart_type = "run", cl = 99)
  )
  expect_true(isTRUE(attr(result$summary, "cl_user_supplied")))
  expect_false(isTRUE(attr(result$summary, "cl_auto_mean")))
  expect_equal(result$qic_data$cl[1], 99)
})

test_that("bfh_qic skips auto-sub for non-run chart types", {
  data <- data.frame(x = 1:20, y = c(rep(1, 12), 2, 2, 3, 3, 4, 4, 5, 5))
  result <- bfh_qic(data, x = x, y = y, chart_type = "i")
  expect_false(isTRUE(attr(result$summary, "cl_auto_mean")))
})

test_that("bfh_qic skips auto-sub when freeze is set", {
  # Freeze deliberately fixes CL to the freeze-window median; a high
  # tie-ratio after freeze is by design (signal of process shift), so
  # auto-sub must NOT fire and override the user's analytical intent.
  data <- data.frame(period = 1:24, value = c(rep(10, 12), rep(20, 12)))
  result <- bfh_qic(data, x = period, y = value, chart_type = "run", freeze = 12)
  expect_false(isTRUE(attr(result$summary, "cl_auto_mean")))
  # CL should equal qicharts2's freeze-window median (= 10)
  expect_equal(result$qic_data$cl[1], 10)
})

test_that("bfh_qic auto-subs only the last phase in multi-phase charts", {
  set.seed(42)
  # Phase 1: continuous (no auto-sub). Phase 2: 9/15 on median (60%).
  phase1 <- rnorm(15, 10, 2)
  phase2 <- c(rep(5, 9), 6, 6, 7, 7, 8, 8)
  data <- data.frame(x = 1:30, y = c(phase1, phase2))

  result <- bfh_qic(data, x = x, y = y, chart_type = "run", part = c(15))
  expect_true(isTRUE(attr(result$summary, "cl_auto_mean")))

  # Phase 1 should retain its median, phase 2 should use mean.
  cl_phase1 <- unique(result$qic_data$cl[result$qic_data$part == 1])
  cl_phase2 <- unique(result$qic_data$cl[result$qic_data$part == 2])
  expect_length(cl_phase1, 1L)
  expect_length(cl_phase2, 1L)
  expect_equal(cl_phase1, median(phase1), tolerance = 1e-6)
  expect_equal(cl_phase2, mean(phase2), tolerance = 1e-6)
})

test_that("cl_user_supplied and cl_auto_mean are mutually exclusive", {
  # User-cl wins regardless of trigger conditions.
  data <- data.frame(x = 1:20, y = c(rep(1, 12), 2, 2, 3, 3, 4, 4, 5, 5))
  result <- suppressWarnings(
    bfh_qic(data, x = x, y = y, chart_type = "run", cl = 99)
  )
  user <- isTRUE(attr(result$summary, "cl_user_supplied"))
  auto <- isTRUE(attr(result$summary, "cl_auto_mean"))
  expect_true(user)
  expect_false(auto)
  expect_false(user && auto) # invariant
})

test_that("empty_spc_stats() exposes cl_auto_mean as NULL", {
  empty <- BFHcharts:::empty_spc_stats()
  expect_true("cl_auto_mean" %in% names(empty))
  expect_null(empty$cl_auto_mean)
})

test_that("i18n caveat key cl_auto_mean resolves in da and en", {
  da <- BFHcharts:::i18n_lookup("labels.caveats.cl_auto_mean", "da")
  en <- BFHcharts:::i18n_lookup("labels.caveats.cl_auto_mean", "en")
  expect_type(da, "character")
  expect_type(en, "character")
  expect_match(da, "gennemsnit")
  expect_match(en, "mean")
})

test_that("bfh_extract_spc_stats surfaces cl_auto_mean flag", {
  data <- data.frame(x = 1:20, y = c(rep(1, 12), 2, 2, 3, 3, 4, 4, 5, 5))
  result <- bfh_qic(data, x = x, y = y, chart_type = "run")
  stats <- bfh_extract_spc_stats(result)
  expect_true(stats$cl_auto_mean)
  expect_false(isTRUE(stats$cl_user_supplied))
})

test_that("bfh_extract_spc_stats.data.frame surfaces cl_auto_mean from attribute", {
  data <- data.frame(x = 1:20, y = c(rep(1, 12), 2, 2, 3, 3, 4, 4, 5, 5))
  result <- bfh_qic(data, x = x, y = y, chart_type = "run")
  stats_from_summary <- bfh_extract_spc_stats(result$summary)
  expect_true(stats_from_summary$cl_auto_mean)
})

# Acceptance demo: pre-substitution Anhoej output collapses on discrete data
# (many ties with CL). Post-substitution moves CL off the ties so signals
# become meaningful again. This is the real-world fix being delivered.
test_that("auto-mean substitution makes Anhoej analysis meaningful", {
  # Discrete dataset with 12/20 = 60% on median(=1).
  data <- data.frame(x = 1:20, y = c(rep(1, 12), 2, 2, 3, 3, 4, 4, 5, 5))

  # Pre-substitution (force median CL via user-cl override).
  pre <- suppressWarnings(
    bfh_qic(data, x = x, y = y, chart_type = "run", cl = median(data$y))
  )
  # Post-substitution (auto-sub kicks in).
  post <- bfh_qic(data, x = x, y = y, chart_type = "run")

  # CL differs after auto-sub.
  expect_false(identical(pre$qic_data$cl[1], post$qic_data$cl[1]))

  # Post-substitution must have strictly fewer on-CL ties than pre.
  # (Mean can incidentally land on some integer y values, so we cannot
  # require zero -- the meaningful invariant is: substitution reduces
  # the tie count.)
  on_cl_pre <- sum(abs(pre$qic_data$y - pre$qic_data$cl) < 1e-9)
  on_cl_post <- sum(abs(post$qic_data$y - post$qic_data$cl) < 1e-9)
  expect_gt(on_cl_pre, on_cl_post)
})
