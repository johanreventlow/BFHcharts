# ============================================================================
# ACCEPTANCE TESTS FOR I-PRIME (I') CHART -- STATISTICAL INTEGRITY
# ============================================================================
# Group 4: statistical acceptance gate for the pbcharts adapter.
# Every test is wrapped with skip_if_not_installed("pbcharts").
#
# Tests:
#   4.1  CL-identity:      cl/ucl/lcl are identical() to a direct pbc() call
#   4.2  Varying vs const: ucl/lcl vary with varying den; const with const den
#   4.3  Anhoej mapping:   anhoej.signal == as.logical(runs.signal) from pbc
#   4.4  Notes alignment:  shuffled rows -> notes attach by x-value, not pos
#   4.5  Contract cols:    all downstream-required columns are present

# ----------------------------------------------------------------------------
# HELPER: deterministic dataset with VARYING denominator
# ----------------------------------------------------------------------------

make_iprime_varying <- function() {
  set.seed(101L)
  data.frame(
    period = 1:20L,
    num = as.integer(round(runif(20, 3, 25))),
    den = as.integer(round(runif(20, 40, 200))),
    stringsAsFactors = FALSE
  )
}

# ----------------------------------------------------------------------------
# 4.1 CL-identity: THE critical gate
# ----------------------------------------------------------------------------
# Assert that cl/ucl/lcl returned by bfh_qic() are identical() -- not just
# equal with tolerance -- to the values from a direct pbcharts::pbc() call
# with the same data and arguments.
# If this fails the adapter has introduced a silent transformation (e.g. an
# auto-mean substitution or scaling). Report BLOCKED in that case -- do NOT
# weaken to tolerance.
# ----------------------------------------------------------------------------

test_that("4.1: CL-identity -- cl/ucl/lcl identical() to direct pbc()", {
  skip_if_not_installed("pbcharts")

  d <- make_iprime_varying()

  res <- bfh_qic(d,
    x = period, y = num, n = den,
    chart_type = "i'", return.data = TRUE
  )
  direct <- pbcharts::pbc(period, num, den,
    data = d,
    chart = "i", plot = FALSE
  )$data

  # Strict identity -- same numeric vector contents, same class, no drift.
  expect_identical(res$cl, direct$cl)
  expect_identical(res$ucl, direct$ucl)
  expect_identical(res$lcl, direct$lcl)
})

# ----------------------------------------------------------------------------
# 4.2 Varying vs constant limits
# ----------------------------------------------------------------------------
# (a) Varying den -> ucl/lcl must NOT all be equal (pbc-style variable limits)
# (b) Constant den -> ucl/lcl must all be equal
# (c) Missing n (no den) -> limits constant AND plotted y equals raw num
# ----------------------------------------------------------------------------

test_that("4.2a: varying den produces varying ucl (and lcl)", {
  skip_if_not_installed("pbcharts")

  d <- make_iprime_varying()

  res <- bfh_qic(d,
    x = period, y = num, n = den,
    chart_type = "i'", return.data = TRUE
  )

  # At least two distinct rounded values means limits vary with den
  expect_gt(length(unique(round(res$ucl, 9L))), 1L)
})

test_that("4.2b: constant den produces constant ucl/lcl", {
  skip_if_not_installed("pbcharts")

  set.seed(202L)
  d <- data.frame(
    period = 1:15L,
    num = as.integer(round(runif(15, 3, 25))),
    den = rep(50L, 15L),
    stringsAsFactors = FALSE
  )

  res <- bfh_qic(d,
    x = period, y = num, n = den,
    chart_type = "i'", return.data = TRUE
  )

  expect_equal(length(unique(round(res$ucl, 9L))), 1L)
  expect_equal(length(unique(round(res$lcl, 9L))), 1L)
})

test_that("4.2c: missing n gives constant limits and y equals raw num", {
  skip_if_not_installed("pbcharts")

  set.seed(303L)
  d <- data.frame(
    period = 1:12L,
    num = as.integer(round(runif(12, 2, 20))),
    stringsAsFactors = FALSE
  )

  # Suppress the expected degeneration message
  res <- suppressMessages(
    bfh_qic(d,
      x = period, y = num,
      chart_type = "i'", return.data = TRUE
    )
  )

  # Limits are constant (no denominator -> individuals chart degeneration)
  expect_equal(length(unique(round(res$ucl, 9L))), 1L)
  expect_equal(length(unique(round(res$lcl, 9L))), 1L)

  # Plotted y equals raw num (pbc passes num through unchanged when no den)
  expect_equal(res$y, as.numeric(d$num))
})

# ----------------------------------------------------------------------------
# 4.3 Anhoej signal mapping
# ----------------------------------------------------------------------------
# Construct data with an obvious run (9 consecutive observations above CL).
# Assert anhoej.signal is logical and equals as.logical(runs.signal) from the
# same direct pbc() call.
# Note: pbc emits only runs.signal (no crossings.signal), so add_anhoej_signal
# maps: anhoej.signal <- as.logical(runs.signal).
# ----------------------------------------------------------------------------

test_that("4.3: anhoej.signal is logical and maps from pbc runs.signal", {
  skip_if_not_installed("pbcharts")

  # 9 consecutive observations on each side of CL -> obvious run signal
  d <- data.frame(
    period = 1:20L,
    num = c(rep(1L, 9), rep(9L, 9), 1L, 9L),
    den = rep(10L, 20L),
    stringsAsFactors = FALSE
  )

  res <- bfh_qic(d,
    x = period, y = num, n = den,
    chart_type = "i'", return.data = TRUE
  )
  direct <- pbcharts::pbc(period, num, den,
    data = d,
    chart = "i", plot = FALSE
  )$data

  # anhoej.signal must exist and be logical
  expect_true("anhoej.signal" %in% names(res))
  expect_type(res$anhoej.signal, "logical")

  # pbc has no crossings.signal; anhoej.signal = as.logical(runs.signal)
  expect_equal(res$anhoej.signal, as.logical(direct$runs.signal))

  # Sanity: at least one signal must fire on the obvious run pattern
  expect_true(any(res$anhoej.signal, na.rm = TRUE))
})

# ----------------------------------------------------------------------------
# 4.4 Notes alignment under reordered output -- THE notes gate
# ----------------------------------------------------------------------------
# Input rows in non-sorted order. Notes aligned to INPUT order.
# After pbc stable-sorts by x, the note for x=3 must still land on x=3
# (x-value lookup), not on position 3 of the output.
# ----------------------------------------------------------------------------

test_that("4.4: notes attached by x-value not position after pbc sort", {
  skip_if_not_installed("pbcharts")

  # Shuffled input: rows in order x=3, x=1, x=5, x=2, x=4
  d <- data.frame(
    period = c(3L, 1L, 5L, 2L, 4L),
    num = c(5L, 3L, 7L, 4L, 6L),
    den = c(20L, 18L, 25L, 22L, 24L),
    stringsAsFactors = FALSE
  )

  # Notes aligned to INPUT order: note for x=3 (row 1) and x=5 (row 3)
  notes_vec <- c(
    "note_x3", NA_character_, "note_x5",
    NA_character_, NA_character_
  )

  res <- bfh_qic(d,
    x = period, y = num, n = den,
    chart_type = "i'", notes = notes_vec,
    return.data = TRUE
  )

  # pbc output is sorted ascending by x: 1, 2, 3, 4, 5
  expect_equal(res$notes[res$x == 3L], "note_x3")
  expect_equal(res$notes[res$x == 5L], "note_x5")
  expect_true(is.na(res$notes[res$x == 1L]))
  expect_true(is.na(res$notes[res$x == 2L]))
  expect_true(is.na(res$notes[res$x == 4L]))
})

# ----------------------------------------------------------------------------
# 4.5 Contract completeness
# ----------------------------------------------------------------------------
# All columns that the downstream pipeline reads must be present in qic_data.
# ----------------------------------------------------------------------------

test_that("4.5: qic_data contains all downstream-required columns", {
  skip_if_not_installed("pbcharts")

  d <- make_iprime_varying()

  res <- bfh_qic(d,
    x = period, y = num, n = den,
    chart_type = "i'", return.data = TRUE
  )

  required_cols <- c(
    "x", "y", "cl", "ucl", "lcl",
    "target", "part", "sigma.signal",
    "anhoej.signal", "n", "notes"
  )

  for (col in required_cols) {
    expect_true(
      col %in% names(res),
      info = paste("qic_data missing required column:", col)
    )
  }
})
