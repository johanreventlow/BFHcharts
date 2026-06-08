# ============================================================================
# TESTS FOR I-PRIME (I') ADAPTER HELPERS
# ============================================================================
# TDD: tests written before implementation.
# Tests adapter functions that bridge pbcharts::pbc() output to the
# qicharts2 data.frame contract used by the downstream pipeline.
#
# Functions under test:
#   build_pbc_args()        -- pure: builds arg list for do.call(pbcharts::pbc, .)
#   invoke_pbcharts()       -- calls pbcharts::pbc, returns pbc_obj$data
#   map_pbc_to_qic_data()   -- pure: adapts pbc $data to qicharts2 column contract

# ============================================================================
# HELPER: construct realistic pbc-style $data without calling pbc
# ============================================================================

make_pbc_data <- function(n = 5L, sorted = TRUE) {
  xs <- if (sorted) seq_len(n) else rev(seq_len(n))
  data.frame(
    facet = NA_character_,
    part = 1L,
    x = xs,
    num = xs * 0.1,
    den = rep(10L, n),
    y = xs * 0.01,
    target = NA_real_,
    longest.run = rep(3L, n),
    longest.run.max = rep(5L, n),
    n.crossings = rep(2L, n),
    n.crossings.min = rep(2L, n),
    lcl = rep(0.0, n),
    cl = rep(0.05, n),
    ucl = rep(0.15, n),
    runs.signal = rep(FALSE, n),
    sigma.signal = rep(FALSE, n),
    freeze = rep(FALSE, n),
    include = rep(TRUE, n),
    base = rep(TRUE, n),
    n.obs = rep(n, n),
    n.useful = rep(n, n),
    stringsAsFactors = FALSE
  )
}

# ============================================================================
# build_pbc_args()
# ============================================================================

test_that("build_pbc_args maps y_expr to num", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_identical(result$num, as.name("y"))
})

test_that("build_pbc_args maps n_expr to den when non-NULL", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5, n = rep(10, 5)),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = as.name("n"),
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_identical(result$den, as.name("n"))
})

test_that("build_pbc_args omits den entirely when n_expr is NULL", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_false("den" %in% names(result))
})

test_that("build_pbc_args maps part to split when non-NULL", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:20, y = 1:20),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = c(10L),
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_equal(result$split, c(10L))
})

test_that("build_pbc_args omits split when part is NULL", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_false("split" %in% names(result))
})

test_that("build_pbc_args maps target_value to target when numeric and non-NULL", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = 0.1,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_equal(result$target, 0.1)
})

test_that("build_pbc_args omits target when target_value is NULL", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_false("target" %in% names(result))
})

test_that("build_pbc_args sets ypct = TRUE when y_axis_unit is percent", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5, n = rep(10, 5)),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = as.name("n"),
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "percent"
  )
  expect_true(isTRUE(result$ypct))
})

test_that("build_pbc_args does not set ypct for non-percent y_axis_unit", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_false("ypct" %in% names(result))
})

test_that("build_pbc_args includes multiply when != 1", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 100,
    y_axis_unit  = "percent"
  )
  expect_equal(result$multiply, 100)
})

test_that("build_pbc_args omits multiply when == 1", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_false("multiply" %in% names(result))
})

test_that("build_pbc_args always sets chart='i' and plot=FALSE", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_identical(result$chart, "i")
  expect_identical(result$plot, FALSE)
})

test_that("build_pbc_args does not pass notes or agg.fun to pbc", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:5, y = 1:5),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_false("notes" %in% names(result))
  expect_false("agg.fun" %in% names(result))
})

test_that("build_pbc_args includes freeze, exclude, cl when non-NULL", {
  result <- build_pbc_args(
    data         = data.frame(x = 1:20, y = 1:20),
    x_expr       = as.name("x"),
    y_expr       = as.name("y"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = 10L,
    target_value = NULL,
    exclude      = c(3L),
    cl           = 8.5,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  expect_equal(result$freeze, 10L)
  expect_equal(result$exclude, c(3L))
  expect_equal(result$cl, 8.5)
})

# ============================================================================
# invoke_pbcharts()
# ============================================================================

test_that("invoke_pbcharts stops with install hint when pbcharts unavailable", {
  # Uses function-arg injection to simulate missing pbcharts (project pattern
  # from utils_dep_guards.R -- no mockery needed).
  err <- tryCatch(
    invoke_pbcharts(
      pbc_args   = list(),
      envir      = environment(),
      require_fn = function(...) FALSE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "remotes::install_github", fixed = TRUE)
  expect_match(conditionMessage(err), "anhoej/pbcharts", fixed = TRUE)
})

test_that("invoke_pbcharts returns a data.frame with pbc columns (happy path)", {
  skip_if_not_installed("pbcharts")
  df <- data.frame(x = 1:15, num = rnorm(15, 10, 2))
  pbc_args <- build_pbc_args(
    data         = df,
    x_expr       = as.name("x"),
    y_expr       = as.name("num"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  result <- invoke_pbcharts(pbc_args, envir = environment())
  expect_s3_class(result, "data.frame")
  # Required pbc output columns present
  pbc_cols <- c(
    "x", "y", "cl", "ucl", "lcl", "target",
    "runs.signal", "sigma.signal", "den", "part"
  )
  for (col in pbc_cols) {
    expect_true(col %in% names(result),
      info = paste("pbc $data should contain column:", col)
    )
  }
})

test_that("invoke_pbcharts does NOT call add_anhoej_signal (no anhoej.signal column)", {
  skip_if_not_installed("pbcharts")
  df <- data.frame(x = 1:15, num = rnorm(15, 10, 2))
  pbc_args <- build_pbc_args(
    data         = df,
    x_expr       = as.name("x"),
    y_expr       = as.name("num"),
    n_expr       = NULL,
    part         = NULL,
    freeze       = NULL,
    target_value = NULL,
    exclude      = NULL,
    cl           = NULL,
    multiply     = 1,
    y_axis_unit  = "count"
  )
  result <- invoke_pbcharts(pbc_args, envir = environment())
  # anhoej.signal is added by Group 3; invoke_pbcharts must NOT add it
  expect_false("anhoej.signal" %in% names(result))
})

# ============================================================================
# map_pbc_to_qic_data()
# ============================================================================

test_that("map_pbc_to_qic_data sets n equal to den", {
  pbc_data <- make_pbc_data()
  result <- map_pbc_to_qic_data(pbc_data, notes = NULL, input_x = 1:5)
  expect_equal(result$n, pbc_data$den)
})

test_that("map_pbc_to_qic_data sets notes to NA_character_ when notes=NULL", {
  pbc_data <- make_pbc_data()
  result <- map_pbc_to_qic_data(pbc_data, notes = NULL, input_x = 1:5)
  expect_true(all(is.na(result$notes)))
  expect_type(result$notes, "character")
})

test_that("map_pbc_to_qic_data attaches notes to correct x even when pbc_data is sorted differently", {
  # Simulate pbc stable-sorting: pbc_data rows sorted by x ascending (1..5),
  # but input_x was supplied in shuffled order with notes aligned to input order.
  input_x <- c(3L, 1L, 5L, 2L, 4L)
  notes_vec <- c("note_x3", NA, "note_x5", NA, NA)
  # pbc_data has x sorted ascending: 1, 2, 3, 4, 5
  pbc_data <- make_pbc_data(n = 5L, sorted = TRUE) # x = 1:5

  result <- map_pbc_to_qic_data(pbc_data, notes = notes_vec, input_x = input_x)

  # x=3 gets "note_x3", x=5 gets "note_x5", others NA
  expect_equal(result$notes[result$x == 3L], "note_x3")
  expect_equal(result$notes[result$x == 5L], "note_x5")
  expect_true(is.na(result$notes[result$x == 1L]))
  expect_true(is.na(result$notes[result$x == 2L]))
  expect_true(is.na(result$notes[result$x == 4L]))
})

test_that("map_pbc_to_qic_data: first non-NA note wins per unique x (tapply contract)", {
  # Two input rows with same x, different notes -- first non-NA should win.
  input_x <- c(1L, 1L, 2L)
  notes_vec <- c("first", "second", "other")
  pbc_data <- make_pbc_data(n = 2L, sorted = TRUE) # x = 1, 2

  result <- map_pbc_to_qic_data(pbc_data, notes = notes_vec, input_x = input_x)
  # For x=1 the lookup table takes nn[1] of non-NA values; "first" comes first
  expect_equal(result$notes[result$x == 1L], "first")
  expect_equal(result$notes[result$x == 2L], "other")
})

test_that("map_pbc_to_qic_data contract guard: stops when required column missing", {
  pbc_data <- make_pbc_data()
  # Remove a required column to trigger the guard
  pbc_data$ucl <- NULL
  expect_error(
    map_pbc_to_qic_data(pbc_data, notes = NULL, input_x = 1:5),
    regexp = "ucl"
  )
})

test_that("map_pbc_to_qic_data contract guard: reports all missing columns", {
  pbc_data <- make_pbc_data()
  pbc_data$ucl <- NULL
  pbc_data$notes <- NULL # notes would be added, but lcl is also gone
  pbc_data$lcl <- NULL
  err <- tryCatch(
    map_pbc_to_qic_data(pbc_data, notes = NULL, input_x = 1:5),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "ucl")
  expect_match(err, "lcl")
})

test_that("map_pbc_to_qic_data preserves all original pbc columns", {
  pbc_data <- make_pbc_data()
  original_cols <- names(pbc_data)
  result <- map_pbc_to_qic_data(pbc_data, notes = NULL, input_x = 1:5)
  for (col in original_cols) {
    expect_true(col %in% names(result),
      info = paste("original column should be preserved:", col)
    )
  }
})
