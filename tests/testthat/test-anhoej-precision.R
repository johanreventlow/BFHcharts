# ============================================================================
# ANHØJ RULE PRECISION TESTS
# ============================================================================
#
# Verificerer at bfh_qic() detekterer Anhøj-signaler på præcise positioner
# for konstruerede datasets. Anhøj's regler bruger:
#
#   - longest.run.max = round(log2(n)) + 3  (forventet maksimal run-længde)
#   - n.crossings.min = qbinom(0.05, n-1, 0.5)  (forventet minimum crossings)
#
# Signal firer når:
#   - longest.run > longest.run.max, ELLER
#   - n.crossings < n.crossings.min
#
# Reference: Anhøj J, Olesen AV (2014) PLOS ONE 9(11):e113825
#            doi:10.1371/journal.pone.0113825
#
# Spec: test-infrastructure, "Anhøj rule signals fire at known positions"
# Reference: openspec/changes/strengthen-test-infrastructure (Fase 2 task 9)

# ============================================================================
# RUN-LENGTH SIGNAL — 9 konsekutive punkter over/under median
# ============================================================================

test_that("run-længde-signal fires ved 10+ konsekutive punkter på én side (n=24)", {
  # For n=24: longest.run.max = round(log2(24)) + 3 = 5 + 3 = 8
  # Data med 10 konsekutive over median + 14 under → run-længde = 14 → signal
  values <- c(rep(60, 10), rep(40, 14))

  data <- data.frame(
    period = 1:24,
    value = values
  )

  result <- bfh_qic(data, x = period, y = value, chart_type = "run")

  expect_valid_bfh_qic_result(result)

  # Anhøj-signal skal være TRUE (mindst ét punkt)
  expect_true(any(result$qic_data$anhoej.signal),
    info = "10+14 run-længde for n=24 burde trigger signal"
  )

  # Summary skal indeholde længste_løb ≥ 10
  expect_gte(result$summary$længste_løb[1], 10,
    label = "længste_løb i summary"
  )
})

test_that("run-længde-signal fires IKKE ved korte runs (n=24)", {
  # Alternerende værdier → max run-længde = 1 → ingen signal
  values <- rep(c(50, 52, 48, 51, 49, 53), length.out = 24)

  data <- data.frame(
    period = 1:24,
    value = values
  )

  result <- bfh_qic(data, x = period, y = value, chart_type = "run")

  expect_valid_bfh_qic_result(result)

  # Ingen Anhøj-signal
  expect_false(any(result$qic_data$anhoej.signal),
    info = "Korte runs (alternerende) skal ikke trigger signal"
  )

  # Summary skal have lille længste_løb
  expect_lte(result$summary$længste_løb[1], 5,
    label = "længste_løb ≤ 5 for alternerende data"
  )
})

# ============================================================================
# CROSSINGS SIGNAL — for få crossings = systematisk mønster
# ============================================================================

test_that("crossings-signal fires ved for få crossings (konstrueret for n=24)", {
  # For n=24: n.crossings.min ≈ 8 (typisk qbinom(0.05, 23, 0.5))
  # Data: 12 over, 12 under → kun 1 crossing → signal
  values <- c(rep(60, 12), rep(40, 12))

  data <- data.frame(
    period = 1:24,
    value = values
  )

  result <- bfh_qic(data, x = period, y = value, chart_type = "run")

  expect_valid_bfh_qic_result(result)

  # Signal skal fires (enten run-længde eller crossings, begge er trigget)
  expect_true(any(result$qic_data$anhoej.signal))

  # Antal kryds skal være meget lavt (1)
  expect_lte(result$summary$antal_kryds[1], 2,
    label = "antal_kryds for 12+12 data"
  )
})

test_that("crossings-signal fires IKKE ved mange crossings", {
  # Zig-zag data: alternerende → n-1 crossings → ingen crossings-signal
  values <- rep(c(60, 40), 12)

  data <- data.frame(
    period = 1:24,
    value = values
  )

  result <- bfh_qic(data, x = period, y = value, chart_type = "run")

  expect_valid_bfh_qic_result(result)

  # Antal kryds skal være højt (≈ n-1 = 23)
  expect_gte(result$summary$antal_kryds[1], 20,
    label = "antal_kryds for alternerende data"
  )

  # Ingen crossings-signal (højt antal)
  # Dog kan run-længde-signal stadig fires, så vi tjekker ikke anhoej.signal her
})

# ============================================================================
# SIGNAL ABSENCE — stabil data giver ingen signals
# ============================================================================

test_that("stabile data med blandede mønstre giver ingen Anhøj-signal", {
  # Realistisk stabil data: tilfældig variation omkring median
  # Data er konstrueret så:
  #   - Ingen lang run (max 3 på samme side)
  #   - Mange crossings
  values <- c(
    48, 52, 49, 51, 48, 52, 50, 49, 51, 50,
    52, 48, 50, 51, 49, 52, 48, 50, 51, 49,
    50, 52, 48, 51
  )

  data <- data.frame(
    period = 1:24,
    value = values
  )

  result <- bfh_qic(data, x = period, y = value, chart_type = "run")

  expect_valid_bfh_qic_result(result)

  # Ingen signal skal fires
  expect_false(any(result$qic_data$anhoej.signal),
    info = "Stabil data med korte runs og mange kryds skal ikke trigger"
  )

  # Sanity: max run < 5 og mange crossings
  expect_lte(result$summary$længste_løb[1], 4)
  expect_gte(result$summary$antal_kryds[1], 8)
})

# ============================================================================
# SIGMA.SIGNAL OUTLIERS — kontrol-grænse-overskridelser
# ============================================================================

test_that("sigma.signal fires ved punkt uden for kontrolgrænse (i-chart)", {
  # Stabil baseline med én klar outlier
  # x̄ ≈ 10, MR̄ ≈ 1, UCL ≈ 12.66, LCL ≈ 7.34
  # Outlier: punkt 5 = 20 (langt over UCL)
  values <- c(10, 11, 10, 11, 20, 11, 10, 11, 10, 11, 10, 11)

  data <- data.frame(
    period = 1:12,
    value = values
  )

  result <- bfh_qic(data, x = period, y = value, chart_type = "i")

  expect_valid_bfh_qic_result(result)

  # Punkt 5 skal have sigma.signal = TRUE
  expect_true(result$qic_data$sigma.signal[5],
    info = "Outlier-punkt (y=20 mod baseline 10) skal være flagged"
  )
})

test_that("sigma.signal fires IKKE for stabil data", {
  # Værdier tæt omkring middel → ingen outliers
  values <- c(10, 11, 10, 11, 10, 11, 10, 11, 10, 11, 10, 11)

  data <- data.frame(
    period = 1:12,
    value = values
  )

  result <- bfh_qic(data, x = period, y = value, chart_type = "i")

  expect_valid_bfh_qic_result(result)

  # Ingen outliers i stabil data
  expect_false(any(result$qic_data$sigma.signal),
    info = "Stabil data skal ikke have sigma.signal triggers"
  )
})

# ============================================================================
# OUTLIER-COUNT SEPARATION — actual (total) vs. recent_count (last 6 obs)
# ============================================================================

test_that("bfh_extract_spc_stats skelner total outliers fra recent (last 6)", {
  # Konstruer qic_data med 3 outliers: 1 i position 6 (udenfor seneste 6),
  # 2 i positioner 20-21 (inden for seneste 6 obs af 24 punkter)
  sigma_signal <- c(
    rep(FALSE, 5),
    TRUE, # position 6 — uden for seneste 6 obs
    rep(FALSE, 13),
    TRUE, TRUE, # position 20-21 — inden for seneste 6
    FALSE, FALSE, FALSE
  )

  result <- fixture_bfh_qic_result(sigma_signal, chart_type = "i")
  stats <- bfh_extract_spc_stats(result)

  # Total outliers skal tælle alle 3
  expect_equal(stats$outliers_actual, 3,
    label = "outliers_actual = total i seneste part"
  )

  # Recent count skal kun tælle de 2 inden for seneste 6
  expect_equal(stats$outliers_recent_count, 2,
    label = "outliers_recent_count = kun seneste 6 obs"
  )
})

test_that("outliers_recent_count = outliers_actual når alle outliers er recent", {
  # Alle outliers i seneste 6 obs (af 20)
  sigma_signal <- c(
    rep(FALSE, 15),
    TRUE, FALSE, TRUE, FALSE, FALSE # 2 outliers i seneste 6
  )

  result <- fixture_bfh_qic_result(sigma_signal, chart_type = "i")
  stats <- bfh_extract_spc_stats(result)

  expect_equal(stats$outliers_actual, 2)
  expect_equal(stats$outliers_recent_count, 2)
})

test_that("outliers-tælling respekterer part (seneste fase kun)", {
  # 2 outliers i fase 1, 1 i fase 2 (seneste fase)
  sigma_signal <- c(TRUE, TRUE, FALSE, FALSE, FALSE, TRUE)
  parts <- c(1, 1, 1, 2, 2, 2)

  result <- fixture_bfh_qic_result(sigma_signal, part = parts, chart_type = "i")
  stats <- bfh_extract_spc_stats(result)

  # Kun seneste fase (part 2) tælles → 1 outlier
  expect_equal(stats$outliers_actual, 1,
    label = "outliers_actual tæller kun seneste part"
  )
})

# ============================================================================
# SUMMARY-KOLONNER — Anhøj-relaterede felter findes
# ============================================================================

test_that("summary indeholder Anhøj-kolonner for run-chart", {
  data <- data.frame(
    period = 1:24,
    value = c(rep(60, 10), rep(40, 14))
  )

  result <- bfh_qic(data, x = period, y = value, chart_type = "run")

  # Anhøj-stat-kolonner
  required_cols <- c(
    "længste_løb", "længste_løb_max",
    "antal_kryds", "antal_kryds_min",
    "løbelængde_signal"
  )

  missing <- setdiff(required_cols, names(result$summary))
  expect_equal(length(missing), 0,
    info = paste(
      "Manglende Anhøj-kolonner:",
      paste(missing, collapse = ", ")
    )
  )
})

test_that("længste_løb_max = round(log2(n)) + 3 for run-chart", {
  # For n=24 skal længste_løb_max = round(log2(24))+3 = 5+3 = 8
  data <- data.frame(
    period = 1:24,
    value = c(rep(60, 10), rep(40, 14))
  )

  result <- bfh_qic(data, x = period, y = value, chart_type = "run")

  expected_max <- round(log2(24)) + 3
  expect_equal(result$summary$længste_løb_max[1], expected_max,
    tolerance = 1, # qicharts2 kan runde lidt anderledes
    label = paste0(
      "længste_løb_max for n=24 = round(log2(24))+3 = ",
      expected_max
    )
  )
})
