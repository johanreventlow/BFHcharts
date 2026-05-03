# =============================================================================
# Tests for .validate_inject_assets() runtime security guard
# =============================================================================
#
# Covers: task 2.5-2.7, 6.1 (spec: pdf-export/spec.md)
# H1 (harden-export-pipeline-security): warning -> stop; namespace allowlist.
# Scenarios:
#   - NULL inject_assets passes silently
#   - Non-function errors immediately
#   - Function from allowed package namespace (BFHcharts) passes silently
#   - Function from allowed namespace (biSPCharts) passes silently via allowlist
#   - Function from globalenv now ERRORS (breaking change from H1)
#   - Function from unrecognized namespace errors
#   - options(BFHcharts.allow_globalenv_inject = TRUE) suppresses error


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

test_that(".validate_inject_assets: BFHcharts namespace function passes silently", {
  # Functions from the BFHcharts namespace are in the default allowed_namespaces.
  # topenv() of a namespace function yields that namespace environment.
  namespace_fn <- BFHcharts:::bfh_extract_spc_stats
  expect_silent(BFHcharts:::.validate_inject_assets(namespace_fn))
})

test_that(".validate_inject_assets: explicit allowed_namespaces accepts base package function", {
  # Passing a function whose topenv is "base" with "base" in allowed_namespaces
  # should pass silently. This exercises the custom-allowlist path.
  # identity is a primitive so environment(identity) is NULL -> treated as trusted.
  # Use a non-primitive from base instead.
  base_fn <- base::Sys.time # non-primitive, topenv is "base"
  # environmentName(topenv(environment(base::Sys.time))) == "base"
  expect_silent(
    BFHcharts:::.validate_inject_assets(base_fn, allowed_namespaces = c("BFHcharts", "base"))
  )
})

test_that(".validate_inject_assets: globalenv function now errors (H1 breaking change)", {
  # H1: warning -> stop. Functions from .GlobalEnv are no longer silently
  # warned about -- they hard-fail to prevent privilege-escalation in production.
  local_fn <- local({
    f <- function(template_dir) invisible(NULL)
    environment(f) <- globalenv()
    f
  })

  expect_error(
    BFHcharts:::.validate_inject_assets(local_fn),
    regexp = "trusted package namespace"
  )
})

test_that(".validate_inject_assets: globalenv error mentions recommended pattern", {
  local_fn <- local({
    f <- function(template_dir) invisible(NULL)
    environment(f) <- globalenv()
    f
  })

  expect_error(
    BFHcharts:::.validate_inject_assets(local_fn),
    regexp = "MyOrgAssets::inject_my_assets"
  )
})

test_that(".validate_inject_assets: globalenv error mentions opt-out option", {
  local_fn <- local({
    f <- function(template_dir) invisible(NULL)
    environment(f) <- globalenv()
    f
  })

  expect_error(
    BFHcharts:::.validate_inject_assets(local_fn),
    regexp = "allow_globalenv_inject"
  )
})

test_that(".validate_inject_assets: option suppresses globalenv error", {
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

test_that(".validate_inject_assets: function from unrecognized namespace errors", {
  # A function from a namespace not in the allowlist must be rejected.
  f <- function(template_dir) invisible(NULL)
  environment(f) <- as.environment("package:base")

  expect_error(
    BFHcharts:::.validate_inject_assets(f),
    regexp = "trusted package namespace"
  )
})

test_that(".validate_inject_assets: returns invisibly without error when valid", {
  namespace_fn <- BFHcharts:::bfh_extract_spc_stats
  # Should complete without error or warning
  expect_silent(BFHcharts:::.validate_inject_assets(namespace_fn))
})
