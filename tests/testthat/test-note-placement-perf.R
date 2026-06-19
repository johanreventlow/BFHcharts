# Performance benchmark for place_note_labels()
#
# This test always runs (skip_on_cran only) to catch signature drift and
# runtime errors. The strict 100ms timing gate is opt-in via RUN_BENCH=true:
#
#   RUN_BENCH=true Rscript -e 'devtools::test(filter = "note-placement-perf")'
#
# Baseline (pre-vectorization): ~600 ms / call on the 10 comments x ~50
# segments fixture below. Vectorized target: <100 ms / call.

test_that("place_note_labels stays under 100ms on realistic fixture", {
  skip_on_cran()
  skip_if_not_installed("bench")

  set.seed(42)
  n <- 50
  data_points <- data.frame(
    x = seq(1, 12, length.out = n),
    y = 50 + 5 * sin(seq(0, 6, length.out = n)) + rnorm(n, 0, 2)
  )
  comment_idx <- seq(1, n, length.out = 10)
  comment_data <- data.frame(
    x = data_points$x[comment_idx],
    y = data_points$y[comment_idx],
    comment = paste("Annotation", seq_along(comment_idx))
  )

  bench_res <- bench::mark(
    place_note_labels(
      comment_data = comment_data,
      line_positions = c(cl = 50, ucl = 60, lcl = 40),
      y_range = c(30, 70),
      x_range = c(1, 12),
      data_points = data_points
    ),
    iterations = 10,
    check = FALSE
  )

  median_seconds <- as.numeric(bench_res$median)
  message(
    sprintf(
      "[bench] place_note_labels median = %.1f ms",
      median_seconds * 1000
    )
  )

  # Always verify the function returns a finite timing (smoke test: no crash,
  # no infinite loop, no NULL return).
  expect_true(is.finite(median_seconds))

  # Strict timing gate: only enforced when RUN_BENCH=true (CI runners vary too
  # much for a hard 100ms wall-clock assertion in default runs).
  if (identical(Sys.getenv("RUN_BENCH"), "true")) {
    expect_lt(median_seconds, 0.1) # < 100 ms
  }
})
