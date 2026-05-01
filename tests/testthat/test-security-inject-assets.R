# =============================================================================
# Tests for .validate_inject_assets() runtime security guard
# =============================================================================
#
# Covers: task 2.5-2.7, 6.1 (spec: pdf-export/spec.md)
# Scenarios:
#   - NULL inject_assets passes silently
#   - Non-function errors immediately
#   - Function from a package namespace passes silently
#   - Function from globalenv warns
#   - options(BFHcharts.allow_globalenv_inject = TRUE) suppresses warning


test_that(".validate_inject_assets: NULL passes silently", {
  expect_silent(BFHcharts:::.validate_inject_assets(NULL))
})

test_that(".validate_inject_assets: non-function stops with informative error", {
  expect_error(
    BFHcharts:::.validate_inject_assets("not_a_function"),
    regexp = "inject_assets must be a function or NULL"
  )
  expect_error(
    BFHcharts:::.validate_inject_assets(42L),
    regexp = "inject_assets must be a function or NULL"
  )
  expect_error(
    BFHcharts:::.validate_inject_assets(list(fn = identity)),
    regexp = "inject_assets must be a function or NULL"
  )
})

test_that(".validate_inject_assets: namespace function passes silently", {
  # Use an actual exported BFHcharts function as the inject_assets callback.
  # Functions exported from a package namespace have topenv() == that namespace,
  # not globalenv(), so no warning should be emitted.
  namespace_fn <- BFHcharts:::bfh_extract_spc_stats
  expect_silent(BFHcharts:::.validate_inject_assets(namespace_fn))
})

test_that(".validate_inject_assets: globalenv function warns", {
  # Define function at script scope, which lives in globalenv() during tests.
  # Use local() to ensure we control environment explicitly.
  local_fn <- local({
    f <- function(template_dir) invisible(NULL)
    environment(f) <- globalenv()
    f
  })

  expect_warning(
    BFHcharts:::.validate_inject_assets(local_fn),
    regexp = "global environment"
  )
})

test_that(".validate_inject_assets: globalenv warning mentions recommended pattern", {
  local_fn <- local({
    f <- function(template_dir) invisible(NULL)
    environment(f) <- globalenv()
    f
  })

  expect_warning(
    BFHcharts:::.validate_inject_assets(local_fn),
    regexp = "MyOrgAssets::inject_my_assets"
  )
})

test_that(".validate_inject_assets: globalenv warning mentions opt-out option", {
  local_fn <- local({
    f <- function(template_dir) invisible(NULL)
    environment(f) <- globalenv()
    f
  })

  expect_warning(
    BFHcharts:::.validate_inject_assets(local_fn),
    regexp = "allow_globalenv_inject"
  )
})

test_that(".validate_inject_assets: option suppresses globalenv warning", {
  local_fn <- local({
    f <- function(template_dir) invisible(NULL)
    environment(f) <- globalenv()
    f
  })

  withr::with_options(
    list(BFHcharts.allow_globalenv_inject = TRUE),
    expect_silent(BFHcharts:::.validate_inject_assets(local_fn))
  )
})

test_that(".validate_inject_assets: returns invisibly without error when valid", {
  namespace_fn <- BFHcharts:::bfh_extract_spc_stats
  # Should complete without error or warning
  expect_silent(BFHcharts:::.validate_inject_assets(namespace_fn))
})
