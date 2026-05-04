# Tests for cl_user_supplied attribute (Slice B of harden-pdf-export-for-production).
#
# Risk model: clinical PDFs reach quality-improvement leadership where R-side
# warnings never surface. When bfh_qic() receives a non-NULL `cl` argument,
# Anhoej run/crossing signals are computed against the user-supplied centerline,
# not the data-estimated process mean. The `cl_user_supplied` attribute (and
# its surface via bfh_extract_spc_stats()) lets the PDF template render a
# caveat note so warning-blind clinical readers see the qualifier alongside
# the SPC table. See ADR-003.

test_that("summary has cl_user_supplied = TRUE when cl supplied", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 18),
    value = rnorm(18, mean = 50, sd = 5)
  )

  # Suppress the R-side warning emitted at bfh_qic.R:674-682 (custom cl).
  result <- suppressWarnings(
    bfh_qic(data, x = month, y = value, chart_type = "i", cl = 50)
  )

  expect_true(isTRUE(attr(result$summary, "cl_user_supplied")))
})

test_that("summary has cl_user_supplied = FALSE when cl absent", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 18),
    value = rnorm(18, mean = 50, sd = 5)
  )

  result <- bfh_qic(data, x = month, y = value, chart_type = "i")

  expect_identical(attr(result$summary, "cl_user_supplied"), FALSE)
})

test_that("attribute does NOT add a column to summary (lapply-iteration safe)", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 18),
    value = rnorm(18, mean = 50, sd = 5)
  )

  result_with <- suppressWarnings(
    bfh_qic(data, x = month, y = value, chart_type = "i", cl = 50)
  )
  result_without <- bfh_qic(data, x = month, y = value, chart_type = "i")

  # Column-iteration patterns must remain stable: same column names with/without cl.
  expect_identical(names(result_with$summary), names(result_without$summary))
  expect_false("cl_user_supplied" %in% names(result_with$summary))
})

test_that("bfh_extract_spc_stats surfaces cl_user_supplied", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 18),
    value = rnorm(18, mean = 50, sd = 5)
  )

  result_with <- suppressWarnings(
    bfh_qic(data, x = month, y = value, chart_type = "i", cl = 50)
  )
  stats_with <- bfh_extract_spc_stats(result_with)
  expect_true(stats_with$cl_user_supplied)

  result_without <- bfh_qic(data, x = month, y = value, chart_type = "i")
  stats_without <- bfh_extract_spc_stats(result_without)
  expect_identical(stats_without$cl_user_supplied, FALSE)
})

test_that("attribute attaches to raw qic_data when return.data = TRUE", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 18),
    value = rnorm(18, mean = 50, sd = 5)
  )

  qic <- suppressWarnings(
    bfh_qic(data,
      x = month, y = value, chart_type = "i",
      cl = 50, return.data = TRUE
    )
  )

  expect_true(isTRUE(attr(qic, "cl_user_supplied")))
})

test_that("empty_spc_stats() exposes cl_user_supplied as NULL", {
  empty <- BFHcharts:::empty_spc_stats()
  expect_true("cl_user_supplied" %in% names(empty))
  expect_null(empty$cl_user_supplied)
})

test_that("i18n caveat key resolves in da and en", {
  da <- BFHcharts:::i18n_lookup("labels.caveats.cl_user_supplied", "da")
  en <- BFHcharts:::i18n_lookup("labels.caveats.cl_user_supplied", "en")

  expect_type(da, "character")
  expect_type(en, "character")
  expect_match(da, "fastsat manuelt")
  expect_match(en, "manually specified")
})

# Run charts hide outlier rows in PDF; the early-return in
# bfh_extract_spc_stats.bfh_qic_result() must NOT drop cl_user_supplied
# (set BEFORE the early-return). A future refactor that swaps the
# ordering would silently omit the clinical caveat for run charts.
test_that("cl_user_supplied survives the run-chart early-return path", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 18),
    value = rnorm(18, mean = 50, sd = 5)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = month, y = value, chart_type = "run", cl = 50)
  )
  stats <- bfh_extract_spc_stats(result)
  expect_true(stats$cl_user_supplied)
  expect_true(stats$is_run_chart)
  # Run charts have no control limits -> outlier fields must remain NULL.
  expect_null(stats$outliers_actual)
  expect_null(stats$outliers_expected)
})

# v0.16.1: data.frame dispatch must surface cl_user_supplied via attr,
# parallel with the bfh_qic_result method. Prior to v0.16.1, calling
# bfh_extract_spc_stats(result$summary) directly returned NULL for the
# flag, silently omitting the PDF caveat for any consumer that routed
# through the data.frame method (e.g. partial-stats users).
test_that("bfh_extract_spc_stats.data.frame surfaces cl_user_supplied", {
  set.seed(42)
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 18),
    value = rnorm(18, mean = 50, sd = 5)
  )

  result_with <- suppressWarnings(
    bfh_qic(data, x = month, y = value, chart_type = "i", cl = 50)
  )
  stats_summary_with <- bfh_extract_spc_stats(result_with$summary)
  expect_true(stats_summary_with$cl_user_supplied)

  result_without <- bfh_qic(data, x = month, y = value, chart_type = "i")
  stats_summary_without <- bfh_extract_spc_stats(result_without$summary)
  expect_identical(stats_summary_without$cl_user_supplied, FALSE)
})

test_that("bfh_extract_spc_stats.data.frame returns FALSE for plain data.frame", {
  # No attr set -> NULL attr -> isTRUE(NULL) = FALSE. Defensive sanity check.
  df <- data.frame(
    "længste_løb_max" = 5L,
    antal_kryds = 3L, check.names = FALSE
  )
  stats <- BFHcharts::bfh_extract_spc_stats(df)
  expect_identical(stats$cl_user_supplied, FALSE)
})
