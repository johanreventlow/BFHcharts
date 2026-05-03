# =============================================================================
# Tests for decomposed Anhoej signals: anhoej_signal + runs_signal + crossings_signal
#
# Spec: openspec/changes/anhoej-signals-and-summary-precision/specs/public-api/spec.md
#
# Bakgrund: qicharts2::runs.signal er det KOMBINEREDE Anhoej-signal
# (runs.signal = crsignal(n.useful, n.crossings, longest.run) i runs.analysis()).
# Det legacy navn løbelængde_signal læstes som "kun runs", hvilket forvirrede
# klinikere ved crossing-only data. Dette modul verificerer at:
#   - anhoej_signal forbliver kombineret (matcher qicharts2-semantik)
#   - runs_signal og crossings_signal dekomponerer korrekt per fase
#   - krydsende-data trigger crossings_signal alene (regression for issue #290)
# =============================================================================

# -----------------------------------------------------------------------------
# Scenario 1: Krydsende data → crossings_signal=TRUE, runs_signal=FALSE
# -----------------------------------------------------------------------------

test_that("crossing-only data trigger crossings_signal men ikke runs_signal", {
  # 4 alternerende blokke a 5 punkter: ingen lange runs, for få kryds.
  # Per qicharts2: longest.run = 5 < longest.run.max (~7-8 for n=20),
  # n.crossings = 3 < n.crossings.min (~6-7 for n=20).
  value <- c(rep(10, 5), rep(20, 5), rep(10, 5), rep(20, 5))
  d <- data.frame(idx = seq_along(value), value = value)

  result <- bfh_qic(d, x = idx, y = value, chart_type = "run")

  expect_true(result$summary$crossings_signal[1],
    info = "Crossing-only data skal trigge crossings_signal"
  )
  expect_false(result$summary$runs_signal[1],
    info = "Crossing-only data skal IKKE trigge runs_signal"
  )
  expect_true(result$summary$anhoej_signal[1],
    info = "anhoej_signal er kombineret -> TRUE naar enten regel udloest"
  )
})

# -----------------------------------------------------------------------------
# Scenario 2: Lang-run data → runs_signal=TRUE, anhoej_signal=TRUE
# -----------------------------------------------------------------------------

test_that("long-run data trigger runs_signal og anhoej_signal", {
  # Step-shift: 12 lave punkter, derefter 12 hoeje. 12-punkts run > max (~8).
  value <- c(rep(10, 12), rep(20, 12))
  d <- data.frame(idx = seq_along(value), value = value)

  result <- bfh_qic(d, x = idx, y = value, chart_type = "i")

  expect_true(result$summary$runs_signal[1],
    info = "12-punkts run skal trigge runs_signal"
  )
  expect_true(result$summary$anhoej_signal[1],
    info = "anhoej_signal skal vaere TRUE naar runs_signal er TRUE"
  )
})

# -----------------------------------------------------------------------------
# Scenario 3: Tilfaeldig stabil data → ingen signaler
# -----------------------------------------------------------------------------

test_that("stabil tilfaeldig data trigger ingen signaler", {
  set.seed(42)
  d <- data.frame(idx = 1:30, value = rnorm(30, mean = 100, sd = 5))
  result <- bfh_qic(d, x = idx, y = value, chart_type = "i")

  expect_false(isTRUE(result$summary$runs_signal[1]),
    info = "Tilfaeldig data: ingen runs_signal"
  )
  expect_false(isTRUE(result$summary$crossings_signal[1]),
    info = "Tilfaeldig data: ingen crossings_signal"
  )
  expect_false(isTRUE(result$summary$anhoej_signal[1]),
    info = "Tilfaeldig data: ingen anhoej_signal"
  )
})

# -----------------------------------------------------------------------------
# Scenario 4: Decomposed signaler matcher per-fase derivation
# -----------------------------------------------------------------------------

test_that("runs_signal og crossings_signal er korrekt deriveret per fase", {
  # Multi-fase: fase 1 stabil, fase 2 step-shift
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(rnorm(12, 10, 0.5), rep(c(10, 20), 6))
  )
  result <- bfh_qic(d, x = month, y = value, chart_type = "i", part = c(12))

  loeb_col <- grep("ngste_løb$", names(result$summary), value = TRUE)[1]
  loeb_max_col <- grep("ngste_løb_max$", names(result$summary), value = TRUE)[1]

  for (i in seq_len(nrow(result$summary))) {
    expected_runs <- isTRUE(
      result$summary[[loeb_col]][i] > result$summary[[loeb_max_col]][i]
    )
    expected_cross <- isTRUE(
      result$summary$antal_kryds[i] < result$summary$antal_kryds_min[i]
    )
    actual_runs <- as.logical(result$summary$runs_signal[i])
    actual_cross <- as.logical(result$summary$crossings_signal[i])

    expect_equal(actual_runs, expected_runs,
      info = sprintf("Fase %d runs_signal", i)
    )
    expect_equal(actual_cross, expected_cross,
      info = sprintf("Fase %d crossings_signal", i)
    )
  }
})

# -----------------------------------------------------------------------------
# Scenario 5: anhoej_signal matcher qicharts2 runs.signal per fase
# -----------------------------------------------------------------------------

test_that("anhoej_signal[p] matcher any(qic_data$runs.signal[part == p])", {
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(rep(15, 8), rep(5, 4), 20, 22, 18, 21, 19, 22, 18, 21, 19, 22, 18, 21)
  )
  result <- bfh_qic(d, x = month, y = value, chart_type = "i", part = c(12))

  for (i in seq_len(nrow(result$summary))) {
    phase_signal <- any(
      result$qic_data$runs.signal[result$qic_data$part == i],
      na.rm = TRUE
    )
    expect_equal(
      as.logical(result$summary$anhoej_signal[i]),
      phase_signal,
      info = sprintf("Fase %d anhoej_signal vs qic_data runs.signal", i)
    )
  }
})

# -----------------------------------------------------------------------------
# Scenario 6: Alle signaler tilstede for diverse chart-typer
# -----------------------------------------------------------------------------

test_that("anhoej_signal/runs_signal/crossings_signal tilstede for alle chart-typer", {
  set.seed(42)
  chart_specs <- list(
    list(type = "i", make = function() {
      data.frame(
        m = 1:24, v = rnorm(24, 100, 5)
      )
    }),
    list(type = "run", make = function() {
      data.frame(
        m = 1:24, v = rnorm(24, 100, 5)
      )
    }),
    list(type = "c", make = function() {
      data.frame(
        m = 1:24, v = rpois(24, 8)
      )
    }),
    list(type = "p", make = function() {
      data.frame(
        m = 1:24, v = rpois(24, 8), n = rep(100L, 24)
      )
    }),
    list(type = "u", make = function() {
      data.frame(
        m = 1:24, v = rpois(24, 8), n = rep(50L, 24)
      )
    }),
    list(type = "mr", make = function() {
      data.frame(
        m = 1:24, v = rnorm(24, 100, 5)
      )
    })
  )

  for (spec in chart_specs) {
    d <- spec$make()
    args <- list(d, x = quote(m), y = quote(v), chart_type = spec$type)
    if ("n" %in% names(d)) args$n <- quote(n)
    result <- do.call(bfh_qic, args)

    expect_true(
      all(c("anhoej_signal", "runs_signal", "crossings_signal") %in%
        names(result$summary)),
      info = sprintf("chart_type=%s mangler en eller flere signal-kolonner", spec$type)
    )
    expect_type(result$summary$anhoej_signal, "logical")
    expect_type(result$summary$runs_signal, "logical")
    expect_type(result$summary$crossings_signal, "logical")
  }
})
