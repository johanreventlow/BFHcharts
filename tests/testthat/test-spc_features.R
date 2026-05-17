# Tests: bfh_extract_spc_features() (Phase 1.1)
#
# Refs: openspec change restructure-spc-analysis-architecture
# Spec: openspec/specs/spc-analysis-api/spec.md ADDED requirement
#       "bfh_extract_spc_features SHALL compute orthogonal feature axes"

# Test-fixture: standard data, alle tests pinner analysis_date for
# determinisme.
make_stable_data <- function(n = 24) {
  data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = n),
    value = round(rnorm(n, mean = 50, sd = 5), 1)
  )
}

set.seed(42L)
TEST_DATA_N24 <- make_stable_data(24L)
set.seed(43L)
TEST_DATA_N8 <- make_stable_data(8L)
set.seed(44L)
TEST_DATA_N15 <- make_stable_data(15L)

# Helper til at undgaa boilerplate
make_fixture_result <- function(data = TEST_DATA_N24, chart_type = "i", target_text = NULL) {
  bfh_qic(data, x = date, y = value, chart_type = chart_type, target_text = target_text)
}


# ==========================================================================
# Determinisme + analysis_date-injection
# ==========================================================================

test_that("bfh_extract_spc_features(): deterministisk paa identisk input", {
  result <- make_fixture_result()
  metadata <- list(analysis_date = as.Date("2026-01-15"))

  features1 <- BFHcharts:::bfh_extract_spc_features(result, metadata)
  features2 <- BFHcharts:::bfh_extract_spc_features(result, metadata)

  expect_identical(features1, features2)
})

test_that("bfh_extract_spc_features(): analysis_date pinned via metadata", {
  result <- make_fixture_result()
  features <- BFHcharts:::bfh_extract_spc_features(
    result,
    metadata = list(analysis_date = as.Date("2026-01-15"))
  )
  expect_equal(features$aux$analysis_date, as.Date("2026-01-15"))
})

test_that("bfh_extract_spc_features(): analysis_date default = Sys.Date() naar ej pinned", {
  result <- make_fixture_result()
  features <- BFHcharts:::bfh_extract_spc_features(result, metadata = list())
  expect_equal(features$aux$analysis_date, Sys.Date())
})


# ==========================================================================
# Schema-stabilitet: alle 12 akser tilstede + render_context komplet
# ==========================================================================

test_that("features-output indeholder alle 12 obligatoriske akser", {
  result <- make_fixture_result()
  out <- BFHcharts:::bfh_extract_spc_features(result)

  required_axes <- c(
    "stability_pattern", "trend_form", "magnitude", "direction",
    "target_relation", "confidence_tier", "phase_context",
    "freshness", "chart_class", "data_quality", "cl_source",
    "outlier_history"
  )
  expect_true(all(required_axes %in% names(out$features)))
})

test_that("render_context indeholder alle obligatoriske felter", {
  result <- make_fixture_result()
  out <- BFHcharts:::bfh_extract_spc_features(result)

  required_fields <- c(
    "target_display", "centerline_formatted", "y_axis_unit",
    "operator_unicode", "outliers_word_key", "effective_window",
    "chart_type"
  )
  expect_true(all(required_fields %in% names(out$render_context)))
})

test_that("aux indeholder obligatoriske felter inkl. analysis_date", {
  result <- make_fixture_result()
  out <- BFHcharts:::bfh_extract_spc_features(result)

  required_aux <- c(
    "sigma_hat", "sigma_data", "n_points", "centerline",
    "analysis_date", "effective_window"
  )
  expect_true(all(required_aux %in% names(out$aux)))
})


# ==========================================================================
# Chart-type-aware confidence_tier (spec ADDED requirement)
# ==========================================================================

test_that("confidence_tier = 'low' for n < N_MIN (12)", {
  result <- make_fixture_result(data = TEST_DATA_N8, chart_type = "i")
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$features$confidence_tier, "low")
})

test_that("confidence_tier = 'medium' for n in [12, 19]", {
  result <- make_fixture_result(data = TEST_DATA_N15, chart_type = "i")
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$features$confidence_tier, "medium")
})

test_that("confidence_tier = 'high' for n >= 20 paa i-chart", {
  result <- make_fixture_result(data = TEST_DATA_N24, chart_type = "i")
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$features$confidence_tier, "high")
})

test_that("confidence_tier = 'high' for run-chart n=24 trods is.na(sigma_hat)", {
  result <- make_fixture_result(data = TEST_DATA_N24, chart_type = "run")
  features <- BFHcharts:::bfh_extract_spc_features(result)

  # Run-chart har sigma_hat = NA by design
  expect_true(is.na(features$aux$sigma_hat))
  # Men sigma_data SKAL vaere finite
  expect_true(is.finite(features$aux$sigma_data))
  # Og confidence_tier SKAL vaere "high" (chart-type-aware)
  expect_equal(features$features$confidence_tier, "high")
})


# ==========================================================================
# stability_pattern (10 vaerdier inkl no_variation + majority_at_centerline)
# ==========================================================================

test_that("stability_pattern = 'no_signals' for stabil proces", {
  result <- make_fixture_result()
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$features$stability_pattern, "no_signals")
})

test_that("stability_pattern = 'no_variation' for konstant data", {
  constant_data <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = rep(50, 24L)
  )
  result <- bfh_qic(constant_data, x = date, y = value, chart_type = "i")
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$features$stability_pattern, "no_variation")
})


# ==========================================================================
# target_relation (4 vaerdier)
# ==========================================================================

test_that("target_relation = 'none' uden target", {
  result <- make_fixture_result()
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$features$target_relation, "none")
})

test_that("target_relation reflekterer target-vurdering naar target sat", {
  result <- make_fixture_result(target_text = "<= 100")
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_true(features$features$target_relation %in% c("met", "near", "not_met"))
})


# ==========================================================================
# cl_source (Slice 9 INCLUDE)
# ==========================================================================

test_that("cl_source = 'data_estimated' default", {
  result <- make_fixture_result()
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$features$cl_source, "data_estimated")
})

test_that("cl_source = 'user_supplied' naar cl= arg passet", {
  result <- bfh_qic(TEST_DATA_N24, x = date, y = value, chart_type = "i", cl = 50)
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$features$cl_source, "user_supplied")
})


# ==========================================================================
# chart_class mapping
# ==========================================================================

test_that("chart_class mappes korrekt fra chart_type", {
  result_i <- make_fixture_result(chart_type = "i")
  expect_equal(
    BFHcharts:::bfh_extract_spc_features(result_i)$features$chart_class,
    "individuals"
  )

  result_run <- make_fixture_result(chart_type = "run")
  expect_equal(
    BFHcharts:::bfh_extract_spc_features(result_run)$features$chart_class,
    "run"
  )
})


# ==========================================================================
# phase_context (single vs multi)
# ==========================================================================

test_that("phase_context = 'single' uden part-knaek", {
  result <- make_fixture_result()
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$features$phase_context, "single")
})


# ==========================================================================
# render_context: target_display invariant + operator_unicode
# ==========================================================================

test_that("render_context bevarer target_display verbatim", {
  result <- make_fixture_result(target_text = ">= 90")
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$render_context$target_display, ">= 90")
})

test_that("render_context.operator_unicode = '\U2265' for '>= 90'", {
  result <- make_fixture_result(target_text = ">= 90")
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$render_context$operator_unicode, "\U2265")
})

test_that("render_context.operator_unicode = '\U2264' for '<= 5'", {
  result <- make_fixture_result(target_text = "<= 200")
  features <- BFHcharts:::bfh_extract_spc_features(result)
  expect_equal(features$render_context$operator_unicode, "\U2264")
})


# ==========================================================================
# SKIP/DEFER-akser: NA-default for schema-stabilitet
# ==========================================================================

test_that("SKIP-akser (freshness, trend_form, magnitude) lagres som NA i Phase 1", {
  result <- make_fixture_result()
  features <- BFHcharts:::bfh_extract_spc_features(result)

  expect_true(is.na(features$features$freshness))
  expect_true(is.na(features$features$trend_form))
  expect_true(is.na(features$features$magnitude))
})


# ==========================================================================
# _intermediate state for composition-lag
# ==========================================================================

test_that("_intermediate indeholder pass-through state til bfh_analyse", {
  result <- make_fixture_result(target_text = "<= 100")
  out <- BFHcharts:::bfh_extract_spc_features(result)

  expect_true("_intermediate" %in% names(out))
  expect_true(all(c(
    "target_direction", "target_value", "has_target",
    "goal_met", "at_target", "near_target", "flags"
  ) %in% names(out$`_intermediate`)))
})
