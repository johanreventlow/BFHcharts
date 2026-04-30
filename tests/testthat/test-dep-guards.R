# ============================================================================
# Dependency-guard tests
# ============================================================================
# Verifies the BFHtheme presence + version guard implemented in
# R/utils_dep_guards.R per openspec change "bfhtheme-namespace-guards".
#
# Tests use function-arg injection (require_fn, version_fn) on
# .ensure_bfhtheme() to simulate missing/old BFHtheme without mocking
# package internals.

test_that(".ensure_bfhtheme() passes silently when BFHtheme is installed", {
  BFHcharts:::.reset_dep_guard_cache()
  expect_silent(BFHcharts:::.ensure_bfhtheme())
})

test_that(".ensure_bfhtheme() caches positive result", {
  BFHcharts:::.reset_dep_guard_cache()
  call_count <- 0L
  fake_require <- function(...) {
    call_count <<- call_count + 1L
    TRUE
  }
  fake_version <- function(...) numeric_version("0.5.0")

  # First call hits fake_require once; result cached
  BFHcharts:::.ensure_bfhtheme(
    require_fn = fake_require,
    version_fn = fake_version
  )
  expect_equal(call_count, 1L)

  # Second call short-circuits via cache - no require invocation
  BFHcharts:::.ensure_bfhtheme(
    require_fn = fake_require,
    version_fn = fake_version
  )
  expect_equal(call_count, 1L, info = "cache should prevent re-check")
})

test_that(".ensure_bfhtheme() errors with install hint when BFHtheme missing", {
  BFHcharts:::.reset_dep_guard_cache()
  fake_require <- function(...) FALSE
  err <- tryCatch(
    BFHcharts:::.ensure_bfhtheme(require_fn = fake_require),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "BFHtheme >= 0.5.0", fixed = TRUE)
  expect_match(conditionMessage(err), "remotes::install_github")
})

test_that(".ensure_bfhtheme() errors when BFHtheme version too low", {
  BFHcharts:::.reset_dep_guard_cache()
  fake_require <- function(...) TRUE
  fake_version <- function(...) numeric_version("0.4.9")
  err <- tryCatch(
    BFHcharts:::.ensure_bfhtheme(
      require_fn = fake_require,
      version_fn = fake_version
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "0.5.0", fixed = TRUE)
  expect_match(conditionMessage(err), "0.4.9", fixed = TRUE)
})

test_that(".ensure_bfhtheme() honours custom min_version argument", {
  BFHcharts:::.reset_dep_guard_cache()
  fake_require <- function(...) TRUE
  fake_version <- function(...) numeric_version("0.6.0")
  err <- tryCatch(
    BFHcharts:::.ensure_bfhtheme(
      min_version = "0.7.0",
      require_fn = fake_require,
      version_fn = fake_version
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "0.7.0", fixed = TRUE)
})

# Reset cache after this test file so subsequent test files start clean
withr::defer(BFHcharts:::.reset_dep_guard_cache(), teardown_env())
