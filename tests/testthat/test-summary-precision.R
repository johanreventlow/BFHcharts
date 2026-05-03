# =============================================================================
# Tests: result$summary numeric kolonner bevarer raa qicharts2 precision
#
# Spec: openspec/changes/anhoej-signals-and-summary-precision/specs/public-api
#
# Slice C kontrakt: format_qic_summary() returnerer cl/lcl/ucl ved den raa
# precision qicharts2 producerer. Display-formattere (format_target_value,
# format_centerline_for_details) afrunder selv ved string-emission.
# =============================================================================

# -----------------------------------------------------------------------------
# centerlinje = qic_data$cl[part == p][1] eksakt per fase
# -----------------------------------------------------------------------------

test_that("summary$centerlinje matcher qic_data$cl raat", {
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    events = c(7, 8, 6, 9, 7, 8, 6, 7, 9, 8, 6, 7),
    total = rep(100L, 12)
  )
  result <- bfh_qic(d,
    x = month, y = events, n = total,
    chart_type = "p", y_axis_unit = "percent"
  )

  # Eksakt match: ingen tolerance
  expect_identical(result$summary$centerlinje[1], result$qic_data$cl[1])

  # Verificér at det IKKE er den afrundede vaerdi
  rounded <- round(result$qic_data$cl[1], 2)
  if (abs(result$qic_data$cl[1] - rounded) > .Machine$double.eps^0.5) {
    expect_false(identical(result$summary$centerlinje[1], rounded),
      info = "summary skal IKKE vaere afrundet (Slice C)"
    )
  }
})

# -----------------------------------------------------------------------------
# Multi-fase: centerlinje matcher per-fase qic_data$cl
# -----------------------------------------------------------------------------

test_that("multi-fase summary$centerlinje matcher qic_data$cl per fase", {
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(rnorm(12, 50, 2), rnorm(12, 60, 2))
  )
  result <- bfh_qic(d, x = month, y = value, chart_type = "i", part = c(12))

  for (p in seq_len(nrow(result$summary))) {
    phase_cl <- result$qic_data$cl[result$qic_data$part == p][1]
    expect_identical(
      result$summary$centerlinje[p],
      phase_cl,
      info = sprintf("Fase %d centerlinje skal matche qic_data raat", p)
    )
  }
})

# -----------------------------------------------------------------------------
# Konstante kontrolgraenser: scalar matcher qic_data$lcl/ucl raat
# -----------------------------------------------------------------------------

test_that("scalar nedre/oevre_kontrolgraense matcher qic_data raat", {
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = c(48, 52, 49, 51, 50, 53, 47, 50, 52, 49, 51, 48)
  )
  result <- bfh_qic(d, x = month, y = value, chart_type = "i")

  # I-chart skal have konstante graenser -> scalar kolonner
  expect_true(result$summary$kontrolgrænser_konstante[1])
  expect_identical(
    result$summary$nedre_kontrolgrænse[1],
    result$qic_data$lcl[1]
  )
  expect_identical(
    result$summary$øvre_kontrolgrænse[1],
    result$qic_data$ucl[1]
  )
})

# -----------------------------------------------------------------------------
# Variable kontrolgraenser: min/max matcher qic_data raat
# -----------------------------------------------------------------------------

test_that("variable kontrolgraenser min/max matcher qic_data$lcl/ucl raat", {
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    events = c(5, 12, 7, 3, 9, 4, 11, 6, 8, 5, 7, 10),
    total = c(100, 250, 150, 80, 200, 90, 220, 130, 170, 110, 140, 200)
  )
  result <- bfh_qic(d,
    x = month, y = events, n = total,
    chart_type = "p", y_axis_unit = "percent"
  )

  expect_false(result$summary$kontrolgrænser_konstante[1])
  expect_identical(
    result$summary$nedre_kontrolgrænse_min[1],
    min(result$qic_data$lcl, na.rm = TRUE)
  )
  expect_identical(
    result$summary$nedre_kontrolgrænse_max[1],
    max(result$qic_data$lcl, na.rm = TRUE)
  )
  expect_identical(
    result$summary$øvre_kontrolgrænse_min[1],
    min(result$qic_data$ucl, na.rm = TRUE)
  )
  expect_identical(
    result$summary$øvre_kontrolgrænse_max[1],
    max(result$qic_data$ucl, na.rm = TRUE)
  )
})

# -----------------------------------------------------------------------------
# Konstans-detektion bevarer toleranceadfaerd
# -----------------------------------------------------------------------------

test_that("kontrolgraenser_konstante haandterer floating-point drift via tolerance", {
  # Konstrueret data hvor lcl varierer i 5. decimal kun (under decimal_places+2 = 4)
  qic_data <- data.frame(
    part = rep(1L, 6),
    n.obs = 1:6,
    n.useful = 1:6,
    longest.run = rep(2L, 6),
    longest.run.max = rep(7L, 6),
    n.crossings = rep(3L, 6),
    n.crossings.min = rep(2L, 6),
    runs.signal = rep(FALSE, 6),
    sigma.signal = rep(FALSE, 6),
    cl = rep(50, 6),
    # lcl varierer i 5. decimal -- skal detekteres som "konstant" med tolerance=4
    lcl = c(40.00001, 40.00002, 40.00001, 40.00003, 40.00002, 40.00001),
    ucl = rep(60, 6)
  )

  result <- format_qic_summary(qic_data, y_axis_unit = "count")

  expect_true(result$kontrolgrænser_konstante[1],
    info = "Drift under tolerance skal stadig detekteres som konstant"
  )
  expect_true("nedre_kontrolgrænse" %in% names(result),
    info = "Konstans -> scalar kolonner"
  )
  # Den scalar vaerdi skal vaere RAA (ikke afrundet)
  expect_equal(result$nedre_kontrolgrænse[1], 40.00001, tolerance = 1e-6)
})

# -----------------------------------------------------------------------------
# Display-helper: format_target_value rounder selv ved emission
# -----------------------------------------------------------------------------

test_that("format_target_value haandterer raa centerlinje korrekt", {
  # Slice C aendrer summary fra 0.07 (afrundet) til 0.07195946 (raa).
  # format_target_value rounder selv internt -> output skal vaere identisk.
  raw_cl <- 0.07195946
  rounded_cl <- 0.07

  out_raw <- format_target_value(raw_cl, y_axis_unit = "percent")
  out_rounded <- format_target_value(rounded_cl, y_axis_unit = "percent")

  expect_equal(out_raw, out_rounded,
    info = "format_target_value skal producere samme output pre/post Slice C"
  )
})
