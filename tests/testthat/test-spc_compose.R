# Tests: bfh_analyse() (Phase 1.2)
#
# Refs: openspec change restructure-spc-analysis-architecture
# Spec: openspec/specs/spc-analysis-api/spec.md ADDED requirement
#       "bfh_analyse SHALL return a structured bfh_spc_analysis S3 object
#       (key-only model)"

set.seed(101L)
TEST_DATA_COMPOSE <- data.frame(
  date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
  value = round(rnorm(24L, mean = 50, sd = 5), 1)
)

make_compose_fixture <- function(target_text = NULL, chart_type = "i") {
  bfh_qic(TEST_DATA_COMPOSE,
    x = date, y = value,
    chart_type = chart_type, target_text = target_text
  )
}


# ==========================================================================
# Returnerer S3-class-objekt
# ==========================================================================

test_that("bfh_analyse(): returnerer bfh_spc_analysis-objekt", {
  result <- make_compose_fixture()
  analysis <- bfh_analyse(result)

  expect_s3_class(analysis, "bfh_spc_analysis")
  expect_true(is_bfh_spc_analysis(analysis))
  expect_invisible(BFHcharts:::validate_bfh_spc_analysis(analysis))
})

test_that("bfh_analyse(): schema_version semver-pattern", {
  result <- make_compose_fixture()
  analysis <- bfh_analyse(result)
  expect_match(analysis$schema_version, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
})


# ==========================================================================
# Key-only model: conclusions, caveats, suggested_actions er ej tekst
# ==========================================================================

test_that("bfh_analyse(): conclusions lagrer i18n-noegler (ikke tekst)", {
  result <- make_compose_fixture()
  analysis <- bfh_analyse(result)

  # Stability-key matcher 10-vaerdi-enum
  expect_true(analysis$conclusions$stability_key %in% c(
    "no_signals", "runs_only", "crossings_only", "outliers_only",
    "runs_crossings", "runs_outliers", "crossings_outliers",
    "all_signals", "no_variation", "majority_at_centerline"
  ))

  # Action-key matcher kendt enum (12 vaerdier)
  expect_true(analysis$conclusions$action_key %in% c(
    "stable_at_target", "stable_not_at_target", "stable_no_target",
    "unstable_at_target", "unstable_not_at_target", "unstable_no_target",
    "stable_goal_met", "stable_goal_not_met", "stable_near_target",
    "unstable_goal_met", "unstable_near_target", "unstable_goal_not_met"
  ))

  # Target-key er nuvaerdig (ingen target sat)
  expect_equal(analysis$conclusions$target_key, "")
})

test_that("bfh_analyse(): suggested_actions er character-vektor af noegler", {
  result <- make_compose_fixture()
  analysis <- bfh_analyse(result)

  expect_type(analysis$suggested_actions, "character")
  expect_true(length(analysis$suggested_actions) >= 1L)
  # Action-key bevares som foerste element
  expect_equal(analysis$suggested_actions[1], analysis$conclusions$action_key)
})


# ==========================================================================
# Target-arm dispatch: direction-aware vs value-neutral
# ==========================================================================

test_that("bfh_analyse(): direction-aware target med target_text = '<=' grenen", {
  result <- make_compose_fixture(target_text = "<= 100")
  analysis <- bfh_analyse(result)

  expect_true(analysis$features$target_relation %in% c("met", "near", "not_met"))
  expect_true(analysis$conclusions$target_key %in% c(
    "goal_met", "near_target", "goal_not_met"
  ))
})

test_that("bfh_analyse(): value-neutral target (numeric input via metadata)", {
  result <- make_compose_fixture()
  analysis <- bfh_analyse(result, metadata = list(target = 50))

  expect_true(analysis$features$target_relation %in% c("met", "not_met"))
  expect_true(analysis$conclusions$target_key %in% c(
    "at_target", "over_target", "under_target"
  ))
})


# ==========================================================================
# Caveats: NULL for inaktiv, noegle for aktiv
# ==========================================================================

test_that("bfh_analyse(): caveats er NULL for inaktive slots", {
  result <- make_compose_fixture()
  analysis <- bfh_analyse(result)

  expect_null(analysis$caveats$freshness) # Slice 10 SKIP
  expect_null(analysis$caveats$historic_outliers) # Slice 11 DEFER
  expect_null(analysis$caveats$seasonality) # Slice 13 SKIP
})

test_that("bfh_analyse(): cl_user_supplied caveat aktiveres af cl=", {
  result <- bfh_qic(TEST_DATA_COMPOSE,
    x = date, y = value,
    chart_type = "i", cl = 50
  )
  analysis <- bfh_analyse(result)
  expect_equal(analysis$caveats$cl_source, "cl_user_supplied")
})

test_that("bfh_analyse(): few_obs caveat aktiveres for n < 12", {
  short_data <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 8L),
    value = c(50, 52, 48, 51, 49, 53, 47, 50)
  )
  result <- bfh_qic(short_data, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(result)

  expect_equal(analysis$caveats$few_obs, "few_obs")
  expect_equal(analysis$confidence, "low")
})


# ==========================================================================
# Language-felt og bagudkompat
# ==========================================================================

test_that("bfh_analyse(): language = 'da' default", {
  result <- make_compose_fixture()
  analysis <- bfh_analyse(result)
  expect_equal(analysis$language, "da")
})

test_that("bfh_analyse(): language = 'en' respected", {
  result <- make_compose_fixture()
  analysis <- bfh_analyse(result, language = "en")
  expect_equal(analysis$language, "en")
})

test_that("bfh_analyse(): rejicerer invalid language", {
  result <- make_compose_fixture()
  expect_error(bfh_analyse(result, language = "fr"))
})


# ==========================================================================
# JSON-roundtrip via as.list()
# ==========================================================================

test_that("bfh_analyse(): as.list() returnerer JSON-serializerbar struktur", {
  skip_if_not_installed("jsonlite")
  result <- make_compose_fixture(target_text = ">= 40")
  analysis <- bfh_analyse(result, metadata = list(analysis_date = as.Date("2026-05-17")))

  flat <- as.list(analysis)
  expect_type(flat, "list")
  expect_false(inherits(flat, "bfh_spc_analysis"))

  json <- jsonlite::toJSON(flat, auto_unbox = TRUE, Date = "ISO8601")
  expect_true(jsonlite::validate(json))
})


# ==========================================================================
# Determinisme: pinned analysis_date
# ==========================================================================

test_that("bfh_analyse(): deterministisk paa identisk input med pinned analysis_date", {
  result <- make_compose_fixture()
  metadata <- list(analysis_date = as.Date("2026-05-17"))

  analysis1 <- bfh_analyse(result, metadata = metadata)
  analysis2 <- bfh_analyse(result, metadata = metadata)

  expect_identical(analysis1, analysis2)
})
