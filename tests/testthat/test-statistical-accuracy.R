# ============================================================================
# STATISTICAL ACCURACY — numerisk verificerede UCL/LCL/centerlinje-tests
# ============================================================================
#
# Verificerer at bfh_qic() producerer korrekt beregnede kontrolgrænser for
# kanoniske datasets hvor formlerne er standardiserede og velkendte.
#
# Formål: fange regressioner i egen brug af qicharts2, og detektere
# breaking changes ved qicharts2-opgraderinger.
#
# Referencer:
# - Montgomery DC (2009) "Introduction to Statistical Quality Control", 6th ed.
# - Provost LP & Murray SK (2011) "The Health Care Data Guide"
# - qicharts2 package documentation
#
# Alle test-data er håndlavede deterministiske vektorer — ingen RNG —
# så tests er robuste over R-version og RNGkind-ændringer.
#
# Reference: openspec/changes/strengthen-test-infrastructure (Fase 2 task 8)
# Spec: test-infrastructure, "Statistical calculations SHALL have numerical verification"

# ============================================================================
# P-CHART — proportions (events / denominator)
# ============================================================================
#
# Formler (Montgomery 7.1):
#   p̄ = sum(events) / sum(n)  (pooled)
#   UCL_i = p̄ + 3·sqrt(p̄(1-p̄)/n_i)
#   LCL_i = max(0, p̄ - 3·sqrt(p̄(1-p̄)/n_i))

test_that("p-chart UCL/LCL matches Montgomery formula (p̄=0.10, n=100)", {
  # Data: 10 events ud af 100, over 8 perioder → p̄ = 0.10 konstant
  data <- data.frame(
    period = 1:8,
    events = rep(10L, 8),
    total = rep(100L, 8)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
  )

  expect_valid_bfh_qic_result(result)

  # Forventede værdier (hand-calculated):
  #   p̄ = 80/800 = 0.10
  #   UCL = 0.10 + 3·sqrt(0.10·0.90/100) = 0.10 + 3·0.03 = 0.19
  #   LCL = max(0, 0.10 - 0.09) = 0.01
  p_bar <- 0.10
  ucl_expected <- p_bar + 3 * sqrt(p_bar * (1 - p_bar) / 100)
  lcl_expected <- max(0, p_bar - 3 * sqrt(p_bar * (1 - p_bar) / 100))

  # Centerlinje skal være exact 0.10
  expect_equal(result$qic_data$cl[1], p_bar, tolerance = 1e-6,
               label = "p-chart centerlinje")

  # UCL og LCL konstante (constant n) — verificér første punkt
  expect_equal(result$qic_data$ucl[1], ucl_expected, tolerance = 1e-4,
               label = "p-chart UCL")
  expect_equal(result$qic_data$lcl[1], lcl_expected, tolerance = 1e-4,
               label = "p-chart LCL")
})

test_that("p-chart LCL clippes til 0 ved lille p̄", {
  # p̄ = 0.02 er så lille at teoretisk LCL bliver negativ og skal clippes
  data <- data.frame(
    period = 1:10,
    events = rep(2L, 10),
    total = rep(100L, 10)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
  )

  expect_valid_bfh_qic_result(result)

  # Teoretisk LCL = 0.02 - 3·sqrt(0.02·0.98/100) = 0.02 - 0.042 = -0.022
  # Forventer at qicharts2 clipper til 0
  lcl_values <- result$qic_data$lcl
  if (any(!is.na(lcl_values))) {
    expect_true(all(lcl_values >= 0),
                info = "p-chart LCL må ikke være negativ")
  }
})

# ============================================================================
# C-CHART — counts (events per constant sample size)
# ============================================================================
#
# Formler (Montgomery 7.3):
#   c̄ = mean(y)
#   UCL = c̄ + 3·sqrt(c̄)
#   LCL = max(0, c̄ - 3·sqrt(c̄))

test_that("c-chart UCL/LCL matches Montgomery formula (c̄=5)", {
  # Data: værdier omkring 5 — gennemsnit præcis 5
  # mean(c(3,7,5,5,5,5,6,4)) = 40/8 = 5
  data <- data.frame(
    period = 1:8,
    count = c(3, 7, 5, 5, 5, 5, 6, 4)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = count, chart_type = "c")
  )

  expect_valid_bfh_qic_result(result)

  # Forventede værdier:
  #   c̄ = 5
  #   UCL = 5 + 3·sqrt(5) ≈ 11.7082
  #   LCL = max(0, 5 - 3·sqrt(5)) = max(0, -1.7082) = 0
  c_bar <- 5
  ucl_expected <- c_bar + 3 * sqrt(c_bar)
  lcl_expected <- max(0, c_bar - 3 * sqrt(c_bar))

  expect_equal(result$qic_data$cl[1], c_bar, tolerance = 1e-6,
               label = "c-chart centerlinje")
  expect_equal(result$qic_data$ucl[1], ucl_expected, tolerance = 1e-3,
               label = "c-chart UCL = c̄ + 3√c̄ ≈ 11.708")
  expect_equal(result$qic_data$lcl[1], lcl_expected, tolerance = 1e-6,
               label = "c-chart LCL (clippet til 0)")
})

test_that("c-chart med c̄=20 giver ikke-nul LCL", {
  # For c̄=20 er LCL = 20 - 3·sqrt(20) ≈ 20 - 13.416 = 6.584
  data <- data.frame(
    period = 1:10,
    count = c(18, 22, 20, 19, 21, 20, 22, 19, 20, 19)  # mean = 20
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = count, chart_type = "c")
  )

  expect_valid_bfh_qic_result(result)

  c_bar <- mean(data$count)
  lcl_expected <- max(0, c_bar - 3 * sqrt(c_bar))

  expect_equal(result$qic_data$cl[1], c_bar, tolerance = 1e-6,
               label = "c-chart centerlinje = mean(count)")
  expect_equal(result$qic_data$lcl[1], lcl_expected, tolerance = 1e-3,
               label = "c-chart LCL = c̄ - 3√c̄")
  expect_gt(result$qic_data$lcl[1], 0)
})

# ============================================================================
# U-CHART — rates (events per variable exposure)
# ============================================================================
#
# Formler (Montgomery 7.4):
#   ū = sum(events) / sum(n)
#   UCL_i = ū + 3·sqrt(ū/n_i)
#   LCL_i = max(0, ū - 3·sqrt(ū/n_i))

test_that("u-chart UCL/LCL matches Montgomery formula (ū=0.05, n=100)", {
  # Data: 5 events per 100 exposure, over 8 perioder → ū = 0.05 konstant
  data <- data.frame(
    period = 1:8,
    events = rep(5L, 8),
    exposure = rep(100L, 8)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = exposure, chart_type = "u")
  )

  expect_valid_bfh_qic_result(result)

  # Forventede værdier:
  #   ū = 40/800 = 0.05
  #   UCL = 0.05 + 3·sqrt(0.05/100) ≈ 0.05 + 0.0671 = 0.1171
  #   LCL = max(0, 0.05 - 0.0671) = 0
  u_bar <- 0.05
  ucl_expected <- u_bar + 3 * sqrt(u_bar / 100)
  lcl_expected <- max(0, u_bar - 3 * sqrt(u_bar / 100))

  expect_equal(result$qic_data$cl[1], u_bar, tolerance = 1e-6,
               label = "u-chart centerlinje")
  expect_equal(result$qic_data$ucl[1], ucl_expected, tolerance = 1e-4,
               label = "u-chart UCL")
  expect_equal(result$qic_data$lcl[1], lcl_expected, tolerance = 1e-6,
               label = "u-chart LCL (clippet til 0)")
})

# ============================================================================
# I-CHART — individual measurements med moving range
# ============================================================================
#
# Formler (Montgomery 6.4):
#   x̄ = mean(y)
#   MR̄ = mean(|diff(y)|)
#   UCL = x̄ + 2.66 · MR̄   (2.66 = 3/d2 hvor d2=1.128 for n=2)
#   LCL = x̄ - 2.66 · MR̄

test_that("i-chart UCL/LCL matches Montgomery moving-range method", {
  # Data: alternerende 10/11 → x̄=10.5, MR̄=1.0
  data <- data.frame(
    period = 1:10,
    value = c(10, 11, 10, 11, 10, 11, 10, 11, 10, 11)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = value, chart_type = "i")
  )

  expect_valid_bfh_qic_result(result)

  # Forventede værdier:
  #   x̄ = 10.5
  #   diff = c(1,-1,1,-1,1,-1,1,-1,1), |diff| = c(1,1,1,1,1,1,1,1,1)
  #   MR̄ = 1.0
  #   UCL = 10.5 + 2.66 · 1.0 = 13.16
  #   LCL = 10.5 - 2.66 · 1.0 = 7.84
  x_bar <- 10.5
  mr_bar <- 1.0
  d2_inv_times_3 <- 3 / 1.128   # ≈ 2.66

  ucl_expected <- x_bar + d2_inv_times_3 * mr_bar
  lcl_expected <- x_bar - d2_inv_times_3 * mr_bar

  expect_equal(result$qic_data$cl[1], x_bar, tolerance = 1e-6,
               label = "i-chart centerlinje = mean(y)")
  # Tolerance 0.1 pga. d2 approximation — qicharts2 kan bruge 2.66 vs 2.659574
  expect_equal(result$qic_data$ucl[1], ucl_expected, tolerance = 0.1,
               label = "i-chart UCL = x̄ + 2.66·MR̄")
  expect_equal(result$qic_data$lcl[1], lcl_expected, tolerance = 0.1,
               label = "i-chart LCL = x̄ - 2.66·MR̄")
})

test_that("i-chart med større MR giver bredere limits", {
  # Data med højere variabilitet
  data <- data.frame(
    period = 1:10,
    value = c(10, 15, 10, 15, 10, 15, 10, 15, 10, 15)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = value, chart_type = "i")
  )

  expect_valid_bfh_qic_result(result)

  # x̄ = 12.5, MR̄ = 5
  # UCL = 12.5 + 2.66·5 = 25.80
  # LCL = 12.5 - 2.66·5 = -0.80
  expect_equal(result$qic_data$cl[1], 12.5, tolerance = 1e-6)
  expect_equal(result$qic_data$ucl[1], 12.5 + 2.66 * 5, tolerance = 0.5)
  expect_equal(result$qic_data$lcl[1], 12.5 - 2.66 * 5, tolerance = 0.5)
})

# ============================================================================
# FREEZE — baseline-CL forbliver konstant når freeze-parameter bruges
# ============================================================================

test_that("freeze-parameter fryser CL efter baseline-perioden", {
  # 24 punkter: første 12 omkring 10, sidste 12 omkring 20
  # Uden freeze: CL skifter (mean af alle) ≈ 15
  # Med freeze=12: CL forbliver baseline mean ≈ 10 for alle 24 punkter
  data <- data.frame(
    period = 1:24,
    value = c(9, 10, 11, 10, 9, 11, 10, 9, 11, 10, 9, 11,     # baseline: mean ≈ 10
              19, 20, 21, 20, 19, 21, 20, 19, 21, 20, 19, 21)  # post: mean ≈ 20
  )

  result_frozen <- suppressWarnings(
    bfh_qic(data, x = period, y = value, chart_type = "i", freeze = 12)
  )

  expect_valid_bfh_qic_result(result_frozen)

  # Baseline-mean er 10 (fra første 12 punkter)
  baseline_mean <- mean(data$value[1:12])
  expect_equal(baseline_mean, 10, tolerance = 0.01,
               label = "Sanity: baseline mean = 10")

  # CL skal være konstant og lig baseline-mean for ALLE punkter
  cl_values <- result_frozen$qic_data$cl
  expect_equal(length(unique(round(cl_values, 2))), 1,
               label = "CL skal være konstant når freeze er aktiv")
  expect_equal(cl_values[1], baseline_mean, tolerance = 0.1,
               label = "Frozen CL = baseline mean")
  expect_equal(cl_values[24], baseline_mean, tolerance = 0.1,
               label = "Frozen CL (sidste punkt) = baseline mean")
})

# ============================================================================
# PART — phase-split giver separate CL'er pr. phase
# ============================================================================

test_that("part-parameter producerer separate CL'er pr. phase", {
  data <- data.frame(
    period = 1:20,
    value = c(rep(10, 10), rep(20, 10))  # Tydelig level-shift ved punkt 11
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = value, chart_type = "i", part = 10)
  )

  expect_valid_bfh_qic_result(result)

  # To faser: første 10 har CL=10, sidste 10 har CL=20
  cl_phase_1 <- result$qic_data$cl[1:10]
  cl_phase_2 <- result$qic_data$cl[11:20]

  expect_equal(unique(cl_phase_1), 10, tolerance = 0.01,
               label = "Phase 1 CL")
  expect_equal(unique(cl_phase_2), 20, tolerance = 0.01,
               label = "Phase 2 CL")

  # Summary skal have 2 rækker
  expect_equal(nrow(result$summary), 2)
})

# ============================================================================
# CENTERLINE consistency across chart types
# ============================================================================

test_that("centerlinje-beregning er konsistent for kendte datasets", {
  # Konstant data → CL = den konstante værdi
  constant_data <- data.frame(
    period = 1:10,
    value = rep(25L, 10)
  )

  # c-chart (mean = 25)
  result_c <- suppressWarnings(
    bfh_qic(constant_data, x = period, y = value, chart_type = "c")
  )
  expect_equal(result_c$qic_data$cl[1], 25, tolerance = 1e-6)

  # i-chart (mean = 25)
  result_i <- suppressWarnings(
    bfh_qic(constant_data, x = period, y = value, chart_type = "i")
  )
  expect_equal(result_i$qic_data$cl[1], 25, tolerance = 1e-6)

  # run-chart (median = 25)
  result_run <- suppressWarnings(
    bfh_qic(constant_data, x = period, y = value, chart_type = "run")
  )
  expect_equal(result_run$qic_data$cl[1], 25, tolerance = 1e-6)
})

test_that("run-chart centerlinje er median (ikke mean)", {
  # Data hvor median != mean
  # y = c(1, 2, 3, 4, 100) → median = 3, mean = 22
  data <- data.frame(
    period = 1:5,
    value = c(1, 2, 3, 4, 100)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = value, chart_type = "run")
  )

  expect_valid_bfh_qic_result(result)
  expect_equal(result$qic_data$cl[1], 3, tolerance = 1e-6,
               label = "run-chart CL = median(y), ikke mean")
})
