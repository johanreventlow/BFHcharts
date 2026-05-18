# Tests: bfh_spc_analysis S3-class
#
# Refs: openspec change restructure-spc-analysis-architecture, Phase 0.2
# Spec: openspec/specs/spc-analysis-api/spec.md ADDED requirement
#       "bfh_analyse SHALL return a structured bfh_spc_analysis S3 object
#       (key-only model)"

# Helper: bygger minimal valid analyse-objekt-fixture til test-brug
make_test_analysis <- function(overrides = list()) {
  defaults <- list(
    features = list(
      stability_pattern = "no_signals",
      trend_form = NA_character_,
      magnitude = NA_character_,
      direction = "neutral",
      target_relation = "none",
      confidence_tier = "high",
      phase_context = "single",
      freshness = NA_character_,
      chart_class = "individuals",
      data_quality = list(
        few_obs = FALSE,
        variable_cl = FALSE,
        discrete_scale = "none",
        missing_denominators = FALSE
      ),
      cl_source = "data_estimated",
      outlier_history = "none"
    ),
    aux = list(
      sigma_hat = 0.02,
      sigma_data = 0.018,
      n_points = 24L,
      effective_window = 6L,
      centerline = 0.87,
      analysis_date = as.Date("2026-05-17")
    ),
    render_context = list(
      target_display = "",
      centerline_formatted = "0,87",
      y_axis_unit = "count",
      operator_unicode = "",
      outliers_word_key = "plural",
      chart_type = "i"
    ),
    conclusions = list(
      stability_key = "no_signals",
      target_key = "",
      action_key = "stable_no_target"
    ),
    confidence = "high",
    caveats = list(
      cl_source = NULL,
      freshness = NULL,
      few_obs = NULL,
      variable_cl = NULL,
      historic_outliers = NULL,
      seasonality = NULL
    ),
    suggested_actions = c("stable_no_target"),
    language = "da"
  )
  args <- utils::modifyList(defaults, overrides)
  do.call(BFHcharts:::new_bfh_spc_analysis, args)
}

# Constructor: type-validation
test_that("new_bfh_spc_analysis(): valid input returnerer class-objekt", {
  obj <- make_test_analysis()
  expect_s3_class(obj, "bfh_spc_analysis")
  expect_true(is_bfh_spc_analysis(obj))
  expect_equal(obj$schema_version, BFHcharts:::BFH_SPC_ANALYSIS_SCHEMA_VERSION)
})

test_that("new_bfh_spc_analysis(): rejicerer ej-listete features", {
  expect_error(
    BFHcharts:::new_bfh_spc_analysis(
      features = "string",
      aux = list(),
      render_context = list(),
      conclusions = list(),
      confidence = "high",
      caveats = list(),
      suggested_actions = character(0L)
    ),
    "features must be a named list"
  )
})

test_that("new_bfh_spc_analysis(): rejicerer invalid confidence-vaerdi", {
  expect_error(
    make_test_analysis(list(confidence = "invalid")),
    "confidence must be one of"
  )
})

test_that("new_bfh_spc_analysis(): rejicerer invalid language", {
  expect_error(
    make_test_analysis(list(language = "fr")),
    "language must be one of"
  )
})

test_that("new_bfh_spc_analysis(): rejicerer suggested_actions ej character", {
  expect_error(
    make_test_analysis(list(suggested_actions = list("a", "b"))),
    "suggested_actions must be a character vector"
  )
})

test_that("new_bfh_spc_analysis(): rejicerer ikke-semver schema_version", {
  expect_error(
    make_test_analysis(list(schema_version = "1.0")),
    "semver-pattern"
  )
})

# Validator: semantic checks
test_that("validate_bfh_spc_analysis(): grøn paa valid objekt", {
  obj <- make_test_analysis()
  expect_invisible(BFHcharts:::validate_bfh_spc_analysis(obj))
})

test_that("validate_bfh_spc_analysis(): fanger manglende features", {
  obj <- make_test_analysis()
  obj$features$confidence_tier <- NULL
  expect_error(
    BFHcharts:::validate_bfh_spc_analysis(obj),
    "features mangler obligatoriske akser"
  )
})

test_that("validate_bfh_spc_analysis(): fanger manglende conclusions", {
  obj <- make_test_analysis()
  obj$conclusions$action_key <- NULL
  expect_error(
    BFHcharts:::validate_bfh_spc_analysis(obj),
    "conclusions mangler obligatoriske noegler"
  )
})

test_that("validate_bfh_spc_analysis(): fanger manglende render_context", {
  obj <- make_test_analysis()
  obj$render_context$target_display <- NULL
  expect_error(
    BFHcharts:::validate_bfh_spc_analysis(obj),
    "render_context mangler obligatoriske felter"
  )
})

test_that("validate_bfh_spc_analysis(): fanger manglende analysis_date", {
  obj <- make_test_analysis()
  obj$aux$analysis_date <- NULL
  expect_error(
    BFHcharts:::validate_bfh_spc_analysis(obj),
    "aux mangler obligatoriske felter"
  )
})

test_that("validate_bfh_spc_analysis(): fanger invalid confidence_tier-enum", {
  obj <- make_test_analysis()
  obj$features$confidence_tier <- "ukendt"
  expect_error(
    BFHcharts:::validate_bfh_spc_analysis(obj),
    "confidence_tier.*ej i"
  )
})

# print/format/as.list methods
test_that("print.bfh_spc_analysis(): output indeholder klasse-id", {
  obj <- make_test_analysis()
  output <- capture.output(print(obj))
  expect_match(output[1], "<bfh_spc_analysis>")
  expect_true(any(grepl("schema_version", output)))
  expect_true(any(grepl("conclusions", output)))
})

test_that("print.bfh_spc_analysis(): returnerer x invisibly", {
  obj <- make_test_analysis()
  expect_invisible(print(obj))
})

test_that("format.bfh_spc_analysis(): single-line summary", {
  obj <- make_test_analysis()
  summary <- format(obj)
  expect_type(summary, "character")
  expect_length(summary, 1L)
  expect_match(summary, "<bfh_spc_analysis")
  expect_match(summary, "1\\.0\\.0")
})

test_that("as.list.bfh_spc_analysis(): stripper klasse + bevarer struktur", {
  obj <- make_test_analysis()
  flat <- as.list(obj)
  expect_type(flat, "list")
  expect_false(inherits(flat, "bfh_spc_analysis"))
  expect_true(all(c(
    "schema_version", "language", "features", "aux",
    "render_context", "conclusions", "confidence",
    "caveats", "suggested_actions"
  ) %in% names(flat)))
})

test_that("as.list.bfh_spc_analysis(): JSON-serializerbar", {
  skip_if_not_installed("jsonlite")
  obj <- make_test_analysis()
  flat <- as.list(obj)
  json <- jsonlite::toJSON(flat, auto_unbox = TRUE, Date = "ISO8601")
  expect_true(jsonlite::validate(json))

  # Round-trip preserverer top-level felter
  roundtrip <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_setequal(names(roundtrip), names(flat))
})

# is_bfh_spc_analysis predicate
test_that("is_bfh_spc_analysis(): TRUE for klasse-objekt, FALSE for andet", {
  obj <- make_test_analysis()
  expect_true(is_bfh_spc_analysis(obj))
  expect_false(is_bfh_spc_analysis(list()))
  expect_false(is_bfh_spc_analysis(NULL))
  expect_false(is_bfh_spc_analysis(42))
})

# Schema-version semver-format
test_that("BFH_SPC_ANALYSIS_SCHEMA_VERSION matcher semver-pattern", {
  expect_match(
    BFHcharts:::BFH_SPC_ANALYSIS_SCHEMA_VERSION,
    "^[0-9]+\\.[0-9]+\\.[0-9]+$"
  )
})
