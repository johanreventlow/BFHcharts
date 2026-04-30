# ============================================================================
# Dependency guards
# ============================================================================
# Internal helpers that fail fast with actionable error messages when an
# expected runtime dependency is missing or too old. BFHtheme is declared in
# Imports + Remotes (not on CRAN), so install-time validation can be bypassed
# by users who do not use pak/remotes. Without these guards a missing BFHtheme
# surfaces as a cryptic mid-plot "could not find function" error.

# Package-private cache so that only the first call per session pays the
# requireNamespace + packageVersion cost. Subsequent calls are O(1) lookups.
.dep_guard_cache <- new.env(parent = emptyenv())

#' Ensure BFHtheme is installed at the required minimum version
#'
#' Internal guard called from every BFHtheme:: use site. First call performs
#' `requireNamespace("BFHtheme", quietly = TRUE)` and `utils::packageVersion()`;
#' result is cached for the remainder of the session.
#'
#' Function-arg injection (`require_fn`, `version_fn`) enables tests to
#' simulate missing or out-of-date dependencies without mocking package
#' internals.
#'
#' @param min_version Character string parsed via `numeric_version()`.
#' @param require_fn Function used for namespace presence check (testable).
#' @param version_fn Function returning the installed package version (testable).
#' @return Invisibly TRUE on success.
#' @keywords internal
#' @noRd
.ensure_bfhtheme <- function(min_version = "0.5.0",
                             require_fn = requireNamespace,
                             version_fn = utils::packageVersion) {
  cache_key <- paste0("BFHtheme>=", min_version)
  if (isTRUE(.dep_guard_cache[[cache_key]])) {
    return(invisible(TRUE))
  }

  if (!require_fn("BFHtheme", quietly = TRUE)) {
    stop(
      sprintf(
        "BFHcharts requires BFHtheme >= %s; install with remotes::install_github('johanreventlow/BFHtheme@v%s')",
        min_version, min_version
      ),
      call. = FALSE
    )
  }

  installed <- tryCatch(
    version_fn("BFHtheme"),
    error = function(e) NULL
  )
  if (is.null(installed) || installed < numeric_version(min_version)) {
    installed_str <- if (is.null(installed)) "unknown" else as.character(installed)
    stop(
      sprintf(
        "BFHcharts requires BFHtheme >= %s (installed: %s); install with remotes::install_github('johanreventlow/BFHtheme@v%s')",
        min_version, installed_str, min_version
      ),
      call. = FALSE
    )
  }

  .dep_guard_cache[[cache_key]] <- TRUE
  invisible(TRUE)
}

#' Reset the dep-guard cache (test-only helper)
#'
#' Clears positive results from `.dep_guard_cache` so that the next call to
#' `.ensure_bfhtheme()` re-invokes `requireNamespace()`. Used by tests that
#' simulate missing/old dependencies via mocking.
#'
#' @keywords internal
#' @noRd
.reset_dep_guard_cache <- function() {
  rm(list = ls(envir = .dep_guard_cache), envir = .dep_guard_cache)
  invisible(NULL)
}
