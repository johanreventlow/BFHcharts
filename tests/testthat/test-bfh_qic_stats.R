# ============================================================================
# bfh_qic_stats(): compute-only results, equivalent to bfh_qic()
# ============================================================================
# Contract (openspec/changes/add-qic-stats-compute-only): for the same
# computation arguments, bfh_qic_stats()$summary and $qic_data are
# identical() to bfh_qic()'s - including summary attributes - without a plot
# being built.

# Deterministic inputs (no RNG): one row per period, numerator + denominator.
stats_monthly <- function(n = 24L) {
  num <- rep_len(c(14, 16, 13, 15, 18, 12, 17, 14, 19, 13, 15, 16), n)
  data.frame(
    month = seq(as.Date("2023-01-01"), by = "month", length.out = n),
    num = num,
    den = num * 10 + rep_len(c(3, 7, 5, 9), n)
  )
}

# Subgroup data for xbar/s: several rows per period.
stats_subgroups <- function(n_periods = 12L, per = 4L) {
  vals <- rep_len(c(10.2, 9.8, 10.5, 9.9, 10.1, 10.7, 9.6, 10.3),
                  n_periods * per)
  data.frame(
    month = rep(seq(as.Date("2023-01-01"), by = "month",
                    length.out = n_periods), each = per),
    val = vals
  )
}

# Compare both functions on identical arguments; warnings/messages from the
# shared computation phase are asserted separately below.
expect_same_numbers <- function(..., info = NULL) {
  full <- suppressWarnings(suppressMessages(bfh_qic(...)))
  stats <- suppressWarnings(suppressMessages(bfh_qic_stats(...)))
  expect_identical(stats$summary, full$summary, info = info)
  expect_identical(stats$qic_data, full$qic_data, info = info)
}

test_that("bfh_qic_stats matches bfh_qic for charts without denominator", {
  d <- stats_monthly()
  for (ct in c("run", "i", "mr", "c", "g", "t")) {
    expect_same_numbers(d, x = month, y = num, chart_type = ct, info = ct)
  }
})

test_that("bfh_qic_stats matches bfh_qic for ratio charts (y + n)", {
  d <- stats_monthly()
  for (ct in c("run", "p", "pp", "u", "up")) {
    expect_same_numbers(d, x = month, y = num, n = den, chart_type = ct,
                        info = ct)
  }
  expect_same_numbers(d, x = month, y = num, n = den, chart_type = "p",
                      y_axis_unit = "percent", multiply = 100,
                      info = "p percent")
})

test_that("bfh_qic_stats matches bfh_qic for subgroup charts (xbar, s)", {
  d <- stats_subgroups()
  for (ct in c("xbar", "s")) {
    expect_same_numbers(d, x = month, y = val, chart_type = ct, info = ct)
  }
})

test_that("bfh_qic_stats matches bfh_qic for the I-prime chart", {
  skip_if_not_installed("pbcharts")
  d <- stats_monthly()
  expect_same_numbers(d, x = month, y = num, n = den, chart_type = "ip",
                      info = "ip with n")
  expect_same_numbers(d, x = month, y = num, chart_type = "ip",
                      info = "ip without n")
})

test_that("bfh_qic_stats matches bfh_qic with phases, exclude, target, notes", {
  d <- stats_monthly()
  expect_same_numbers(d, x = month, y = num, chart_type = "i", part = 12,
                      info = "part")
  expect_same_numbers(d, x = month, y = num, chart_type = "run", freeze = 10,
                      info = "freeze")
  expect_same_numbers(d, x = month, y = num, chart_type = "i",
                      exclude = c(3, 7), info = "exclude")
  expect_same_numbers(d, x = month, y = num, chart_type = "run",
                      target_value = 15, info = "target")
  notes <- rep(NA_character_, nrow(d))
  notes[5] <- "note"
  expect_same_numbers(d, x = month, y = num, chart_type = "run", notes = notes,
                      info = "notes")
})

test_that("bfh_qic_stats matches bfh_qic with a user-supplied centerline", {
  d <- stats_monthly()
  expect_same_numbers(d, x = month, y = num, chart_type = "run", cl = 15,
                      info = "cl")
  s <- suppressWarnings(bfh_qic_stats(d, x = month, y = num, chart_type = "run",
                                      cl = 15))
  expect_true(isTRUE(attr(s$summary, "cl_user_supplied")))
})

test_that("bfh_qic_stats matches bfh_qic when auto-mean substitution fires", {
  # >= 50% of the observations sit exactly on the median -> CL becomes the mean
  d <- data.frame(
    month = seq(as.Date("2023-01-01"), by = "month", length.out = 16),
    num = c(5, 5, 5, 5, 5, 5, 5, 5, 3, 9, 4, 8, 2, 7, 6, 1)
  )
  full <- suppressWarnings(bfh_qic(d, x = month, y = num, chart_type = "run"))
  skip_if_not(isTRUE(attr(full$summary, "cl_auto_mean")),
              "fixture does not trigger auto-mean in this qicharts2 version")
  expect_same_numbers(d, x = month, y = num, chart_type = "run",
                      info = "auto-mean")
})

test_that("bfh_qic_stats builds no plot and is not a bfh_qic_result", {
  s <- bfh_qic_stats(stats_monthly(), x = month, y = num, chart_type = "i")
  expect_s3_class(s, "bfh_qic_stats")
  expect_false(is_bfh_qic_result(s))
  expect_null(s$plot)
  expect_named(s, c("summary", "qic_data", "config"))
  expect_identical(s$config$chart_type, "i")
  expect_false(s$config$has_denominator)
})

test_that("bfh_extract_spc_stats gives the same list for both result types", {
  d <- stats_monthly()
  for (ct in c("run", "i")) {
    full <- bfh_qic(d, x = month, y = num, chart_type = ct)
    stats <- bfh_qic_stats(d, x = month, y = num, chart_type = ct)
    expect_identical(bfh_extract_spc_stats(stats), bfh_extract_spc_stats(full),
                     info = ct)
  }
  full <- bfh_qic(d, x = month, y = num, n = den, chart_type = "p")
  stats <- bfh_qic_stats(d, x = month, y = num, n = den, chart_type = "p")
  expect_identical(bfh_extract_spc_stats(stats), bfh_extract_spc_stats(full),
                   info = "p")
})

test_that("computation-phase warnings are raised by bfh_qic_stats too", {
  expect_warning(
    bfh_qic_stats(stats_monthly(), x = month, y = num, chart_type = "run",
                  cl = 15),
    "Custom cl"
  )
})

test_that("bfh_qic_stats validates computation inputs like bfh_qic", {
  expect_error(bfh_qic_stats(stats_monthly()[0, ], x = month, y = num),
               class = "bfhcharts_input_error")
  expect_error(bfh_qic_stats(stats_monthly(), x = month, y = num,
                             chart_type = "nope"))
})

test_that("print.bfh_qic_stats summarises without plotting", {
  s <- bfh_qic_stats(stats_monthly(), x = month, y = num, chart_type = "i")
  out <- utils::capture.output(res <- withVisible(print(s)))
  expect_match(out[1], "<bfh_qic_stats> chart_type = i, 24 observations",
               fixed = TRUE)
  expect_false(res$visible)
  expect_identical(res$value, s)
})
