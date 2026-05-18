# Tests: Slice 14 INCLUDE -- Discrete scale 3-tier udvidelse
#
# Refs: openspec change restructure-spc-analysis-architecture, Slice 14

# Helper: byg data hvor specifik andel af obs ligger eksakt paa median.
# Symmetrisk konstruktion sikrer median = 50:
#  - n_on_cl punkter med vaerdi 50
#  - lige antal punkter < 50 og > 50 (symmetric, eksakt parring)
# Deterministisk uden RNG saa fixture er stable uanset test-order.
make_discrete_data <- function(n_on_cl, n_total = 24) {
  n_off <- n_total - n_on_cl
  n_pairs <- n_off %/% 2L
  # Symmetric par: 47, 53, 46, 54, ... saa median bevares = 50
  below <- 50 - seq_len(n_pairs)
  above <- 50 + seq_len(n_pairs)
  off_cl <- as.numeric(rbind(below, above))[seq_len(n_off)]
  values <- c(rep(50, n_on_cl), off_cl)
  data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = n_total),
    value = values
  )
}


# ==========================================================================
# .resolve_discrete_scale_tier() thresholds
# ==========================================================================

test_that("Slice 14: tier=none for ratio < 0.20", {
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.0), "none")
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.15), "none")
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.19), "none")
})

test_that("Slice 14: tier=mild for ratio in [0.20, 0.35)", {
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.20), "mild")
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.30), "mild")
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.34), "mild")
})

test_that("Slice 14: tier=moderate for ratio in [0.35, 0.50)", {
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.35), "moderate")
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.40), "moderate")
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.49), "moderate")
})

test_that("Slice 14: tier=extreme for ratio >= 0.50", {
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.50), "extreme")
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(0.75), "extreme")
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(1.0), "extreme")
})

test_that("Slice 14: tier=none for NA/non-finite ratio", {
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(NA_real_), "none")
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(NULL), "none")
  expect_equal(BFHcharts:::.resolve_discrete_scale_tier(Inf), "none")
})


# ==========================================================================
# Integration: feature-extraction + compose-caveats + render
# ==========================================================================

test_that("Slice 14: extreme tier udloeser majority_at_centerline stability-base", {
  # 13/24 = 54% paa median(=50)
  data_extreme <- make_discrete_data(n_on_cl = 13)
  # chart_type="run" -> centerline=median; med 13/24 obs=50 er median=50
  res <- bfh_qic(data_extreme, x = date, y = value, chart_type = "run")
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18"))
  )

  # Extreme tier registreret i features
  expect_equal(analysis$features$data_quality$discrete_scale, "extreme")
  # Stability-pattern er majority_at_centerline (eksisterende override)
  expect_equal(analysis$features$stability_pattern, "majority_at_centerline")
  # discrete_scale-caveat IKKE aktiveret som tail (extreme haandteres via base)
  expect_null(analysis$caveats$discrete_scale)
})


test_that("Slice 14: render: extreme udloeser majority_at_centerline-prose (eksisterende)", {
  data_extreme <- make_discrete_data(n_on_cl = 13)
  # chart_type="run" -> centerline=median; med 13/24 obs=50 er median=50
  res <- bfh_qic(data_extreme, x = date, y = value, chart_type = "run")
  analysis <- bfh_analyse(res)

  text <- bfh_render_analysis(analysis, max_chars = 600L)
  expect_match(text, "datapunkter ligger præcis|niveaulinjen", ignore.case = TRUE)
})


# ==========================================================================
# Caveat-aktivering: mild + moderate
# ==========================================================================

test_that("Slice 14: caveats$discrete_scale = NULL ved tier=none", {
  set.seed(141L)
  data_clean <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = round(rnorm(24L, 50, 5), 1)
  )
  res <- bfh_qic(data_clean, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res)

  expect_null(analysis$caveats$discrete_scale)
})
