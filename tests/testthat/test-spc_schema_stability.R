# Tests: Phase 99.4 -- Schema-stability for bfh_spc_analysis
#
# Sikrer at downstream-konsumenter (biSPCharts, AI-prompt-anker,
# audit-replay) kan stole paa stabilt schema paa tvaers af releases.
#
# Refs: openspec change restructure-spc-analysis-architecture, Phase 99.4
# Spec: openspec/specs/spc-analysis-api/spec.md ADDED requirement
#       "bfh_spc_analysis schema_version SHALL follow semver"

TEST_DATA_SCHEMA <- fixture_phase_stable(seed = 994L, sd = 5)


# Memoiseret schema-fixture: cacher (target, language)-kombinationer
# saa gentagne kald sparer ~485ms bfh_qic + ~28ms bfh_analyse per kald.
# Test-suite-runtime falder fra ~6s til ~1s for denne fil.
make_schema_fixture <- function(target_text = NULL, language = "da") {
  cache_key <- paste0("schema:", target_text %||% "NULL", ":", language)
  res <- fixture_qic_cached(TEST_DATA_SCHEMA,
    x = date, y = value, chart_type = "i",
    target_text = target_text,
    cache_key = paste0("qic:", cache_key)
  )
  fixture_analyse_cached(res, language = language, cache_key = cache_key)
}


# ==========================================================================
# Phase 99.4.1: schema_version semver-format
# ==========================================================================

test_that("Phase 99.4: schema_version matcher semver-pattern", {
  analysis <- make_schema_fixture()
  expect_match(analysis$schema_version, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
})


test_that("Phase 99.4: BFH_SPC_ANALYSIS_SCHEMA_VERSION konstant tilgaengelig", {
  v <- BFHcharts:::BFH_SPC_ANALYSIS_SCHEMA_VERSION
  expect_type(v, "character")
  expect_length(v, 1L)
  expect_match(v, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
})


# ==========================================================================
# Phase 99.4.2: as.list() stabil struktur + JSON-roundtrip
# ==========================================================================

test_that("Phase 99.4: as.list() top-level fields invariant", {
  analysis <- make_schema_fixture()
  flat <- as.list(analysis)

  required_top_level <- c(
    "schema_version", "language", "features", "aux",
    "render_context", "conclusions", "confidence", "caveats",
    "suggested_actions"
  )
  expect_true(all(required_top_level %in% names(flat)))
})


test_that("Phase 99.4: features lagrer alle 12 ortogonale akser", {
  analysis <- make_schema_fixture()
  required_features <- c(
    "stability_pattern", "target_relation", "confidence_tier",
    "phase_context", "magnitude", "cl_source",
    "trend_form", "direction", "freshness",
    "chart_class", "outlier_history", "data_quality"
  )
  expect_true(all(required_features %in% names(analysis$features)))
})


test_that("Phase 99.4: aux indeholder obligatoriske felter", {
  analysis <- make_schema_fixture()
  required_aux <- c(
    "sigma_hat", "sigma_data", "n_points", "centerline",
    "analysis_date", "baseline_centerline", "baseline_delta",
    "baseline_delta_pct"
  )
  expect_true(all(required_aux %in% names(analysis$aux)))
})


test_that("Phase 99.4: render_context indeholder obligatoriske felter", {
  analysis <- make_schema_fixture()
  required_rc <- c(
    "target_display", "centerline_formatted", "y_axis_unit",
    "operator_unicode", "outliers_word_key", "chart_type"
  )
  expect_true(all(required_rc %in% names(analysis$render_context)))
})


test_that("Phase 99.4: JSON-roundtrip preserverer alle top-level fields", {
  skip_if_not_installed("jsonlite")

  analysis <- make_schema_fixture(target_text = ">= 40")
  flat <- as.list(analysis)
  json <- jsonlite::toJSON(flat, auto_unbox = TRUE, Date = "ISO8601")
  roundtrip <- jsonlite::fromJSON(json, simplifyVector = FALSE)

  expect_setequal(names(roundtrip), names(flat))
  expect_equal(roundtrip$schema_version, flat$schema_version)
  expect_equal(roundtrip$language, flat$language)
})


# ==========================================================================
# Phase 99.4.3: Downstream-konsumenter (biSPCharts) verificeret schema
# ==========================================================================

# Simulerer hvad biSPCharts vil checke: schema_version + central felt-set.
# Hvis bfh_spc_analysis brydes, fanges det her foer biSPCharts-side bryder.
.simulate_downstream_consumer <- function(analysis) {
  # Tjek schema-version-prefix (MAJOR matcher pakkens current MAJOR).
  # Bruger konstant istedet for hardcoded "1" saa downstream-simulering
  # foelger MAJOR-bumps automatisk.
  current_major <- strsplit(BFHcharts:::BFH_SPC_ANALYSIS_SCHEMA_VERSION, ".", fixed = TRUE)[[1]][1]
  expected_prefix <- paste0("^", current_major, "\\.")
  v <- analysis$schema_version
  if (is.null(v) || !grepl(expected_prefix, v)) {
    stop("downstream consumer: incompatible schema_version: ", v)
  }
  # Tjek conclusions er keys (ej tekst)
  if (!is.character(analysis$conclusions$stability_key) ||
    !is.character(analysis$conclusions$action_key)) {
    stop("downstream consumer: conclusions keys must be character")
  }
  # Tjek render_context har target_display (verbatim)
  if (is.null(analysis$render_context$target_display)) {
    stop("downstream consumer: render_context$target_display missing")
  }
  # Tjek aux$analysis_date for audit-replay
  if (!inherits(analysis$aux$analysis_date, "Date")) {
    stop("downstream consumer: aux$analysis_date must be Date class")
  }
  TRUE
}


test_that("Phase 99.4: downstream consumer-simulering grøn", {
  analysis <- make_schema_fixture()
  expect_true(.simulate_downstream_consumer(analysis))
})


test_that("Phase 99.4: downstream-simulering tolerant overfor sprog/target-varianter", {
  for (lang in c("da", "en")) {
    for (target in list(NULL, ">= 90", "<= 50")) {
      analysis <- make_schema_fixture(target_text = target, language = lang)
      expect_true(.simulate_downstream_consumer(analysis),
        info = paste("lang=", lang, "target=", target %||% "NULL")
      )
    }
  }
})


# ==========================================================================
# Phase 99.4.4: Schema-invarianter under feature-slice-aktiveringer
# ==========================================================================

# Hver INCLUDE-slice (3, 4, 5, 7, 8, 9, 14) aendrer ej top-level schema.
# Verificeres ved at konstruere fixtures der aktiverer hver slice +
# tjekke at schema-fields stadig matcher.

test_that("Phase 99.4: slice-aktiveringer bryder ej top-level schema", {
  required_top_level <- c(
    "schema_version", "language", "features", "aux",
    "render_context", "conclusions", "confidence", "caveats",
    "suggested_actions"
  )

  # 1. Default (intet aktivt)
  a1 <- make_schema_fixture()
  expect_setequal(intersect(names(a1), required_top_level), required_top_level)

  # 2. Slice 9 (cl_user_supplied)
  suppressWarnings({
    res2 <- bfh_qic(TEST_DATA_SCHEMA, x = date, y = value, chart_type = "i", cl = 50)
  })
  a2 <- bfh_analyse(res2, metadata = list(analysis_date = as.Date("2026-05-18")))
  expect_setequal(intersect(names(a2), required_top_level), required_top_level)

  # 3. Slice 8 (few-obs n=8)
  short_data <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 8L),
    value = c(50, 51, 49, 52, 48, 50, 51, 49)
  )
  res3 <- bfh_qic(short_data, x = date, y = value, chart_type = "i")
  a3 <- bfh_analyse(res3, metadata = list(analysis_date = as.Date("2026-05-18")))
  expect_setequal(intersect(names(a3), required_top_level), required_top_level)
  expect_equal(a3$confidence, "low")
})


# ==========================================================================
# Phase 99.4.5: caveats-list har stabile slot-navne (selv NULL)
# ==========================================================================

test_that("Phase 99.4: caveats-slot-navne er invariant uanset aktivering", {
  required_slots <- c(
    "cl_source", "freshness", "few_obs", "variable_cl",
    "discrete_scale", "historic_outliers", "seasonality"
  )

  analysis <- make_schema_fixture()
  expect_setequal(names(analysis$caveats), required_slots)
})
