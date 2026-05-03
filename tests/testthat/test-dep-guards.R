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

# ============================================================================
# Co-location regression: BFHtheme:: usage requires .ensure_bfhtheme() guard
# ============================================================================
# Asserts that every R/*.R file referencing BFHtheme:: also calls
# .ensure_bfhtheme() in the same file. Catches drift where a new BFHtheme
# call site is added without the corresponding guard.
#
# Excludes utils_dep_guards.R itself (defines the guard) and
# BFHcharts-package.R (declarative namespace tag, not runtime usage).

test_that("every R/*.R using BFHtheme:: also calls .ensure_bfhtheme()", {
  pkg_root <- testthat::test_path("..", "..")
  r_dir <- file.path(pkg_root, "R")
  skip_if_not(dir.exists(r_dir))

  excluded <- c("utils_dep_guards.R", "BFHcharts-package.R")
  r_files <- setdiff(list.files(r_dir, pattern = "\\.R$"), excluded)

  offenders <- character()
  for (f in r_files) {
    src <- readLines(file.path(r_dir, f), warn = FALSE)
    # Strip comments to avoid false positives from doc strings/roxygen
    code <- sub("#.*$", "", src)
    uses_bfhtheme <- any(grepl("BFHtheme::", code, fixed = TRUE))
    has_guard <- any(grepl(".ensure_bfhtheme(", code, fixed = TRUE))
    if (uses_bfhtheme && !has_guard) {
      offenders <- c(offenders, f)
    }
  }

  expect_equal(
    offenders,
    character(),
    info = paste(
      "Files using BFHtheme:: without .ensure_bfhtheme() co-located:",
      paste(offenders, collapse = ", ")
    )
  )
})

# Reset cache after this test file so subsequent test files start clean
withr::defer(BFHcharts:::.reset_dep_guard_cache(), teardown_env())
