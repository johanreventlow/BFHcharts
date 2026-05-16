# Tests for auto-mean substitution in run charts when >=50% of a phase's
# included observations sit exactly on the median centerline.
#
# Background: qicharts2 hardcodes median as centerline for run charts.
# With discrete/coarse-reported data, Anhoej run/crossing analysis
# degenerates when many points sit exactly on the CL. bfh_qic() detects
# this condition per-phase and auto-substitutes the centerline with the
# mean for any phase that triggers. Non-trigger phases keep the median.
#
# Detection scope: per-phase (cycle 02 H1 fix). Earlier work scoped only
# the last phase, which left earlier phases of multi-phase run charts on
# degenerate median CLs.

test_that("detect_majority_at_median_per_phase returns integer(0) for non-run charts", {
  qic_data <- data.frame(
    x = 1:10,
    y = c(rep(1, 6), 2, 3, 4, 5),
    cl = rep(1, 10)
  )
  expect_length(BFHcharts:::detect_majority_at_median_per_phase(qic_data, "i"), 0L)
  expect_length(BFHcharts:::detect_majority_at_median_per_phase(qic_data, "p"), 0L)
})

test_that("detect_majority_at_median_per_phase returns synthetic part 1 when >=50% on median (no part column)", {
  # 6 of 10 on median (60%) -> trigger; no part column -> single synthetic phase 1
  qic_data <- data.frame(
    x = 1:10,
    y = c(rep(1, 6), 2, 3, 4, 5),
    cl = rep(1, 10)
  )
  expect_equal(BFHcharts:::detect_majority_at_median_per_phase(qic_data, "run"), 1L)
})

test_that("detect_majority_at_median_per_phase respects threshold boundary", {
  # Exactly 50%: 5 of 10 on median -> trigger (>=, not >)
  qic_data_50 <- data.frame(
    x = 1:10,
    y = c(rep(1, 5), 2, 3, 4, 5, 6),
    cl = rep(1, 10)
  )
  expect_equal(BFHcharts:::detect_majority_at_median_per_phase(qic_data_50, "run"), 1L)

  # 4 of 10 (40%) -> no trigger
  qic_data_40 <- data.frame(
    x = 1:10,
    y = c(rep(1, 4), 2, 3, 4, 5, 6, 7),
    cl = rep(1, 10)
  )
  expect_length(
    BFHcharts:::detect_majority_at_median_per_phase(qic_data_40, "run"), 0L
  )
})

test_that("detect_majority_at_median_per_phase skips no_variation (constant y)", {
  qic_data <- data.frame(
    x = 1:10,
    y = rep(5, 10),
    cl = rep(5, 10)
  )
  expect_length(BFHcharts:::detect_majority_at_median_per_phase(qic_data, "run"), 0L)
})

test_that("detect_majority_at_median_per_phase returns only the last phase when only it triggers", {
  # Phase 1: continuous; Phase 2: 6/10 on median. Only phase 2 should trigger.
  set.seed(123)
  qic_data <- data.frame(
    x = 1:20,
    y = c(rnorm(10, 5, 2), rep(1, 6), 2, 3, 4, 5),
    cl = c(rep(5, 10), rep(1, 10)),
    part = c(rep(1, 10), rep(2, 10))
  )
  expect_equal(BFHcharts:::detect_majority_at_median_per_phase(qic_data, "run"), 2L)
})

test_that("detect_majority_at_median_per_phase fires for earlier phase (cycle 02 H1)", {
  # Phase 1 has 60% on median; Phase 2 continuous. Per-phase scope picks
  # phase 1 -- earlier behaviour (last-phase-only) wrongly returned FALSE.
  set.seed(42)
  qic_data <- data.frame(
    x = 1:20,
    y = c(rep(1, 6), 2, 3, 4, 5, rnorm(10, 10, 2)),
    cl = c(rep(1, 10), rep(10, 10)),
    part = c(rep(1, 10), rep(2, 10))
  )
  expect_equal(BFHcharts:::detect_majority_at_median_per_phase(qic_data, "run"), 1L)
})

test_that("detect_majority_at_median_per_phase returns both phases when both trigger", {
  qic_data <- data.frame(
    x = 1:20,
    y = c(rep(1, 6), 2, 3, 4, 5, rep(7, 6), 8, 9, 10, 11),
    cl = c(rep(1, 10), rep(7, 10)),
    part = c(rep(1, 10), rep(2, 10))
  )
  expect_equal(
    BFHcharts:::detect_majority_at_median_per_phase(qic_data, "run"), c(1L, 2L)
  )
})

test_that("detect_majority_at_median_per_phase ignores excluded rows (cycle 02 H3)", {
  # 4 included tied + 6 included non-tied (4/10 = 40%, no trigger)
  # + 4 EXCLUDED rows tied to median. With include-respect, ratio stays
  # 4/10 = 40%. Without include-respect, ratio would be 8/14 = 57%.
  qic_data <- data.frame(
    x = 1:14,
    y = c(rep(1, 4), 2, 3, 4, 5, 6, 7, rep(1, 4)),
    cl = rep(1, 14),
    include = c(rep(TRUE, 10), rep(FALSE, 4))
  )
  expect_length(
    BFHcharts:::detect_majority_at_median_per_phase(qic_data, "run"), 0L
  )
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

test_that("bfh_qic auto-subs only the triggering phase (last) in multi-phase charts", {
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

test_that("bfh_qic auto-subs an EARLIER phase when it triggers (cycle 02 H1)", {
  set.seed(42)
  # Phase 1: 12/18 tied at 1 (66% on median); Phase 2: continuous.
  # Pre-fix: phase 1 retained median, cl_auto_mean=FALSE overall.
  # Post-fix: phase 1 switches to mean, cl_auto_mean=TRUE.
  phase1 <- c(rep(1, 12), 2, 2, 3, 3, 4, 4)
  phase2 <- rnorm(15, 8, 2)
  data <- data.frame(x = 1:33, y = c(phase1, phase2))

  result <- bfh_qic(data, x = x, y = y, chart_type = "run", part = 18)
  expect_true(isTRUE(attr(result$summary, "cl_auto_mean")))

  cl_phase1 <- unique(result$qic_data$cl[result$qic_data$part == 1])
  cl_phase2 <- unique(result$qic_data$cl[result$qic_data$part == 2])
  expect_length(cl_phase1, 1L)
  expect_length(cl_phase2, 1L)
  expect_equal(cl_phase1, mean(phase1), tolerance = 1e-6)
  expect_equal(cl_phase2, median(phase2), tolerance = 1e-6)
})

test_that("bfh_qic auto-subs BOTH phases when both trigger (cycle 02 H1)", {
  phase1 <- c(rep(1, 12), 2, 2, 3, 3, 4, 4)
  phase2 <- c(rep(5, 12), 6, 6, 7, 7, 8, 8)
  data <- data.frame(x = 1:36, y = c(phase1, phase2))

  result <- bfh_qic(data, x = x, y = y, chart_type = "run", part = 18)
  expect_true(isTRUE(attr(result$summary, "cl_auto_mean")))

  cl_phase1 <- unique(result$qic_data$cl[result$qic_data$part == 1])
  cl_phase2 <- unique(result$qic_data$cl[result$qic_data$part == 2])
  expect_equal(cl_phase1, mean(phase1), tolerance = 1e-6)
  expect_equal(cl_phase2, mean(phase2), tolerance = 1e-6)
})

test_that("bfh_qic respects exclude= when computing replacement mean (cycle 02 H3)", {
  # 10 included tied at 1 + 6 included non-tied + 4 EXCLUDED extreme outliers.
  # Pre-fix: replacement mean = mean(all 20) = 21.4 (extreme outliers leak in).
  # Post-fix: replacement mean = mean(included 16) = 1.75 (outliers ignored).
  d <- data.frame(
    x = 1:20,
    y = c(rep(1, 10), 2, 2, 3, 3, 4, 4, 100, 100, 100, 100)
  )
  result <- bfh_qic(d, x = x, y = y, chart_type = "run", exclude = 17:20)
  expect_true(isTRUE(attr(result$summary, "cl_auto_mean")))
  expected_mean <- mean(c(rep(1, 10), 2, 2, 3, 3, 4, 4))
  # qic_data$cl is constant for the phase; pick first INCLUDED row.
  cl_first_included <- result$qic_data$cl[result$qic_data$include][1]
  expect_equal(cl_first_included, expected_mean, tolerance = 1e-6)
})

test_that("bfh_qic ignores excluded rows when evaluating trigger ratio (cycle 02 H3)", {
  # 4 included tied + 6 included non-tied (4/10 = 40%, below threshold).
  # + 4 EXCLUDED rows that ARE tied. Without include-respect, ratio
  # would be 8/14 = 57% and wrongly fire. Post-fix: stays 40%, no fire.
  d <- data.frame(
    x = 1:14,
    y = c(rep(1, 4), 2, 3, 4, 5, 6, 7, rep(1, 4))
  )
  result <- bfh_qic(d, x = x, y = y, chart_type = "run", exclude = 11:14)
  expect_false(isTRUE(attr(result$summary, "cl_auto_mean")))
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
