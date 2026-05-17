# Tests: .resolve_analysis_date() 3-vejs praecedens
#
# Refs: openspec change restructure-spc-analysis-architecture, Phase 0.4
# Spec: openspec/specs/spc-analysis-api/spec.md ADDED requirement
#       "bfh_extract_spc_features SHALL compute orthogonal feature axes"
#       (analysis_date injection)

# Level 1: metadata$analysis_date vinder altid
test_that(".resolve_analysis_date(): metadata$analysis_date vinder over option og default", {
  withr::with_options(
    list(BFHcharts.analysis_date = as.Date("2025-12-31")),
    {
      result <- BFHcharts:::.resolve_analysis_date(
        metadata = list(analysis_date = as.Date("2026-01-15"))
      )
      expect_equal(result, as.Date("2026-01-15"))
    }
  )
})

# Level 2: option vinder over Sys.Date() naar metadata mangler
test_that(".resolve_analysis_date(): option bruges naar metadata mangler", {
  withr::with_options(
    list(BFHcharts.analysis_date = as.Date("2025-12-31")),
    {
      result <- BFHcharts:::.resolve_analysis_date(metadata = list())
      expect_equal(result, as.Date("2025-12-31"))
    }
  )
})

# Level 3: Sys.Date() default naar intet sat
test_that(".resolve_analysis_date(): Sys.Date() default naar metadata + option mangler", {
  withr::with_options(
    list(BFHcharts.analysis_date = NULL),
    {
      result <- BFHcharts:::.resolve_analysis_date(metadata = list())
      expect_equal(result, Sys.Date())
    }
  )
})

# Empty metadata-list samme som NULL
test_that(".resolve_analysis_date(): NULL metadata behandles som tom liste", {
  withr::with_options(
    list(BFHcharts.analysis_date = NULL),
    {
      result <- BFHcharts:::.resolve_analysis_date(metadata = NULL)
      expect_equal(result, Sys.Date())
    }
  )
})

# Coercion-tests
test_that(".resolve_analysis_date(): YYYY-MM-DD character coerces til Date", {
  result <- BFHcharts:::.resolve_analysis_date(
    metadata = list(analysis_date = "2026-01-15")
  )
  expect_s3_class(result, "Date")
  expect_equal(result, as.Date("2026-01-15"))
})

test_that(".resolve_analysis_date(): POSIXct coerces til Date", {
  result <- BFHcharts:::.resolve_analysis_date(
    metadata = list(analysis_date = as.POSIXct("2026-01-15 14:30:00", tz = "UTC"))
  )
  expect_s3_class(result, "Date")
  expect_equal(result, as.Date("2026-01-15"))
})

test_that(".resolve_analysis_date(): option-vaerdi som character coerces", {
  withr::with_options(
    list(BFHcharts.analysis_date = "2025-12-31"),
    {
      result <- BFHcharts:::.resolve_analysis_date(metadata = list())
      expect_equal(result, as.Date("2025-12-31"))
    }
  )
})

# Error-cases: informativ besked, ej silent fallback
test_that(".resolve_analysis_date(): un-coercible character fejler eksplicit", {
  expect_error(
    BFHcharts:::.resolve_analysis_date(
      metadata = list(analysis_date = "ikke-en-dato")
    ),
    "could not be coerced to Date"
  )
})

test_that(".resolve_analysis_date(): NA Date fejler eksplicit", {
  expect_error(
    BFHcharts:::.resolve_analysis_date(
      metadata = list(analysis_date = as.Date(NA))
    ),
    "non-NA Date"
  )
})

test_that(".resolve_analysis_date(): multi-length Date fejler eksplicit", {
  expect_error(
    BFHcharts:::.resolve_analysis_date(
      metadata = list(analysis_date = as.Date(c("2026-01-15", "2026-01-16")))
    ),
    "length=2"
  )
})

test_that(".resolve_analysis_date(): numerisk input fejler med klasse-besked", {
  expect_error(
    BFHcharts:::.resolve_analysis_date(
      metadata = list(analysis_date = 19012L)
    ),
    "must be a Date.*got class"
  )
})

# Source-feltet i error-besked: metadata vs option
test_that(".resolve_analysis_date(): error-besked identificerer kilde", {
  expect_error(
    BFHcharts:::.resolve_analysis_date(
      metadata = list(analysis_date = "bad-date")
    ),
    "metadata\\$analysis_date"
  )

  withr::with_options(
    list(BFHcharts.analysis_date = "bad-date"),
    {
      expect_error(
        BFHcharts:::.resolve_analysis_date(metadata = list()),
        "getOption"
      )
    }
  )
})

# Determinisme-egenskab: samme metadata + Sys.Date forskellig dato
# bekraefter at pinned analysis_date eliminerer Sys.Date-afhaengighed
test_that(".resolve_analysis_date(): pinned dato uafhaengig af Sys.Date()", {
  metadata <- list(analysis_date = as.Date("2026-01-15"))

  result1 <- BFHcharts:::.resolve_analysis_date(metadata)
  result2 <- BFHcharts:::.resolve_analysis_date(metadata)

  expect_identical(result1, result2)
  expect_equal(result1, as.Date("2026-01-15"))
})
