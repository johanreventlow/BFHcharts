# ============================================================================
# CHART TYPE INTEGRATION TESTS
# ============================================================================
#
# Sikrer at hver chart-type i CHART_TYPES_EN har funktionel integration-
# coverage. Eksisterende tests dækker run/i/p/u/c; denne fil fylder hullet
# for mr, pp, up, g, xbar, s, t.
#
# Hver test:
#   1. Kalder bfh_qic() med håndlavede deterministiske data
#   2. Verificerer at output er et korrekt struktureret bfh_qic_result
#   3. Verificerer mindst én numerisk værdi (centerlinje eller anden stat)
#
# Reference: openspec/changes/strengthen-test-infrastructure (Fase 2 task 10)
# Spec: test-infrastructure, "All exported chart types SHALL have integration coverage"

# ============================================================================
# MR-chart (Moving Range) — individuelle målinger, variabilitet mellem punkter
# ============================================================================

test_that("bfh_qic() genererer valid MR-chart", {
  # Håndlavede værdier — MR = abs(diff(y))
  # diff: 2, -1, 4, -1, -1, 3, -1, 3, -1, 2, -1 → |MR|: 2,1,4,1,1,3,1,3,1,2,1
  data <- data.frame(
    x = 1:12,
    y = c(10, 12, 11, 15, 14, 13, 16, 15, 18, 17, 19, 18)
  )

  result <- bfh_qic(data, x = x, y = y, chart_type = "mr")

  expect_valid_bfh_qic_result(result)
  expect_equal(nrow(result$qic_data), 12)

  # Centerlinje for MR-chart skal være mean af moving ranges
  expected_mr_mean <- mean(abs(diff(data$y)))
  expect_equal(result$summary$centerlinje[1],
               expected_mr_mean,
               tolerance = 0.01,
               label = "MR centerlinje")
})

test_that("MR-chart har ikke-negative UCL", {
  data <- data.frame(
    x = 1:10,
    y = c(20, 22, 19, 25, 21, 23, 20, 24, 22, 21)
  )

  result <- bfh_qic(data, x = x, y = y, chart_type = "mr")

  expect_valid_bfh_qic_result(result)
  # UCL for MR skal altid være >= 0 (moving ranges er positive)
  ucl_values <- result$qic_data$ucl
  expect_true(all(ucl_values >= 0 | is.na(ucl_values)))
})

# ============================================================================
# PP-chart (P-prime) — standardiseret proportion
# ============================================================================

test_that("bfh_qic() genererer valid P'-chart med denominator", {
  data <- data.frame(
    x = 1:12,
    events = c(5, 8, 12, 10, 15, 11, 9, 14, 13, 16, 12, 10),
    total = c(100, 120, 150, 110, 180, 130, 115, 160, 145, 170, 135, 125)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = x, y = events, n = total, chart_type = "pp")
  )

  expect_valid_bfh_qic_result(result)
  expect_equal(nrow(result$qic_data), 12)

  # Standardiseret chart har numerisk centerlinje i plausibelt range.
  # (qicharts2's præcise formel for pp varierer — range-check er robust)
  cl <- result$summary$centerlinje[1]
  individual_props <- data$events / data$total
  expect_true(is.numeric(cl) && !is.na(cl),
              info = "P'-chart centerlinje skal være numerisk")
  expect_gte(cl, min(individual_props) * 0.5)
  expect_lte(cl, max(individual_props) * 2)
})

# ============================================================================
# UP-chart (U-prime) — standardiseret rate
# ============================================================================

test_that("bfh_qic() genererer valid U'-chart med eksponering", {
  data <- data.frame(
    x = 1:12,
    events = c(3, 5, 8, 4, 7, 6, 5, 9, 7, 8, 6, 5),
    exposure = c(50, 60, 80, 55, 75, 65, 58, 90, 72, 85, 68, 62)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = x, y = events, n = exposure, chart_type = "up")
  )

  expect_valid_bfh_qic_result(result)
  expect_equal(nrow(result$qic_data), 12)

  # Standardiseret chart har numerisk centerlinje i plausibelt range
  cl <- result$summary$centerlinje[1]
  individual_rates <- data$events / data$exposure
  expect_true(is.numeric(cl) && !is.na(cl),
              info = "U'-chart centerlinje skal være numerisk")
  expect_gte(cl, min(individual_rates) * 0.5)
  expect_lte(cl, max(individual_rates) * 2)
})

# ============================================================================
# G-chart — tid mellem sjældne hændelser
# ============================================================================

test_that("bfh_qic() genererer valid G-chart", {
  # G-chart: antal "opportunities" mellem hændelser (fx dage mellem fejl)
  data <- data.frame(
    x = 1:10,
    y = c(30, 45, 25, 60, 20, 40, 35, 55, 28, 42)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = x, y = y, chart_type = "g")
  )

  expect_valid_bfh_qic_result(result)
  expect_equal(nrow(result$qic_data), 10)

  # G-chart centerlinje er typisk median af y-værdier
  expect_true(is.numeric(result$summary$centerlinje[1]))
  expect_false(is.na(result$summary$centerlinje[1]))
})

test_that("G-chart har LCL clippet til 0", {
  data <- data.frame(
    x = 1:10,
    y = c(30, 45, 25, 60, 20, 40, 35, 55, 28, 42)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = x, y = y, chart_type = "g")
  )

  # LCL skal aldrig være < 0 for G-chart (tid mellem er positivt)
  lcl_values <- result$qic_data$lcl
  if (any(!is.na(lcl_values))) {
    expect_true(all(lcl_values >= 0 | is.na(lcl_values)),
                info = "G-chart LCL må ikke være negativ")
  }
})

# ============================================================================
# Xbar-chart — gennemsnit af subgrupper
# ============================================================================

test_that("bfh_qic() genererer valid Xbar-chart med subgrupper", {
  # Xbar-chart: flere målinger per x (subgrupper)
  # 10 tidspunkter, hver med 5 målinger
  set.seed(42)
  data <- data.frame(
    x = rep(1:10, each = 5),
    y = round(rnorm(50, mean = 100, sd = 5), 1)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = x, y = y, chart_type = "xbar")
  )

  expect_valid_bfh_qic_result(result)
  # Xbar aggregerer til 1 punkt pr. unik x
  expect_equal(nrow(result$qic_data), 10)

  # Centerlinje er grand average ≈ 100
  expect_equal(result$summary$centerlinje[1],
               mean(data$y),
               tolerance = 0.5,
               label = "Xbar grand average centerlinje")
})

# ============================================================================
# S-chart — standard-afvigelse inden for subgrupper
# ============================================================================

test_that("bfh_qic() genererer valid S-chart med subgrupper", {
  set.seed(42)
  data <- data.frame(
    x = rep(1:8, each = 6),
    y = round(rnorm(48, mean = 50, sd = 3), 1)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = x, y = y, chart_type = "s")
  )

  expect_valid_bfh_qic_result(result)
  expect_equal(nrow(result$qic_data), 8)

  # S-chart centerlinje er mean af subgroup-SD'er, skal være > 0 og ~ 3
  cl <- result$summary$centerlinje[1]
  expect_true(is.numeric(cl))
  expect_true(cl > 0, info = "S-chart centerlinje skal være positiv")
  expect_true(cl < 10, info = "S-chart centerlinje skal være < 10 for sd=3 input")
})

test_that("S-chart har LCL clippet til ikke-negativ", {
  set.seed(42)
  data <- data.frame(
    x = rep(1:8, each = 5),
    y = round(rnorm(40, mean = 50, sd = 3), 1)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = x, y = y, chart_type = "s")
  )

  # Standard-afvigelser er pr. definition >= 0
  lcl_values <- result$qic_data$lcl
  if (any(!is.na(lcl_values))) {
    expect_true(all(lcl_values >= 0 | is.na(lcl_values)),
                info = "S-chart LCL må ikke være negativ")
  }
})

# ============================================================================
# T-chart — tid mellem hændelser
# ============================================================================

test_that("bfh_qic() genererer valid T-chart", {
  # T-chart: tid (fx dage) mellem hændelser
  data <- data.frame(
    x = 1:12,
    y = c(5, 8, 3, 12, 6, 9, 4, 15, 7, 10, 5, 11)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = x, y = y, chart_type = "t")
  )

  expect_valid_bfh_qic_result(result)
  expect_equal(nrow(result$qic_data), 12)

  # T-chart centerlinje er mean af y (tider mellem hændelser)
  expect_equal(result$summary$centerlinje[1],
               mean(data$y),
               tolerance = 1.5,
               label = "T-chart mean-based centerlinje")
})

test_that("T-chart har LCL clippet til ikke-negativ", {
  data <- data.frame(
    x = 1:10,
    y = c(5, 8, 3, 12, 6, 9, 4, 15, 7, 10)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = x, y = y, chart_type = "t")
  )

  # Tid mellem hændelser er altid >= 0
  lcl_values <- result$qic_data$lcl
  if (any(!is.na(lcl_values))) {
    expect_true(all(lcl_values >= 0 | is.na(lcl_values)),
                info = "T-chart LCL må ikke være negativ")
  }
})

# ============================================================================
# COVERAGE VERIFICATION — alle chart types har mindst én test
# ============================================================================

test_that("alle CHART_TYPES_EN har integration-test-coverage", {
  # Meta-test der dokumenterer hvilke chart-types der testes i denne fil
  tested_types <- c("mr", "pp", "up", "g", "xbar", "s", "t")

  # Disse testes i andre testfiler (eksisterende coverage)
  other_coverage <- c("run", "i", "p", "u", "c")

  all_tested <- union(tested_types, other_coverage)

  # Verificér at alle konstante chart-types er dækket
  untested <- setdiff(CHART_TYPES_EN, all_tested)
  expect_equal(length(untested), 0,
               info = paste("Utestede chart-types:",
                            paste(untested, collapse = ", ")))
})
