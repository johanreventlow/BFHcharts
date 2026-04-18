# ============================================================================
# Test-lag skip-helpers
# ============================================================================
#
# Gated test-udførelse via miljøvariabler. Lader udviklere iterere hurtigt
# lokalt uden at skulle køre alle tests, mens CI får det fulde sæt.
#
# Lag (fra hurtigt til tungt):
#   1. Unit tests (default)             — kører altid
#   2. Full tests (integration)          — kun når BFHCHARTS_TEST_FULL=="true"
#   3. Render tests (live Quarto/Typst)  — kun når BFHCHARTS_TEST_RENDER=="true"
#
# CI sætter begge env vars til "true".
# Lokalt: default kørsel er hurtig (<10s); brug Sys.setenv() for fuld kørsel.
#
# Reference: openspec/changes/strengthen-test-infrastructure (design.md D2, task 13)
# Spec: test-infrastructure, "Test suite SHALL be portable across environments"

# ----------------------------------------------------------------------------
# Env var-læsning med case-insensitiv parsing
# ----------------------------------------------------------------------------

.read_env_flag <- function(name, default = FALSE) {
  raw <- Sys.getenv(name, unset = "")
  if (!nzchar(raw)) return(default)
  tolower(trimws(raw)) %in% c("true", "t", "yes", "y", "1")
}

#' Er fuld test-kørsel aktiveret?
#'
#' @return TRUE hvis BFHCHARTS_TEST_FULL env var er "true" (case-insensitiv)
#' @keywords internal
is_full_test <- function() {
  .read_env_flag("BFHCHARTS_TEST_FULL")
}

#' Er render-test-kørsel aktiveret?
#'
#' @return TRUE hvis BFHCHARTS_TEST_RENDER env var er "true" (case-insensitiv)
#' @keywords internal
is_render_test <- function() {
  .read_env_flag("BFHCHARTS_TEST_RENDER")
}

# ----------------------------------------------------------------------------
# testthat skip-helpers
# ----------------------------------------------------------------------------

#' Skip test hvis fuld test-kørsel ikke er aktiveret
#'
#' Brug på toppen af tunge integration-tests. Unit-tests skal IKKE bruge denne
#' (de skal altid køre).
#'
#' @param msg Besked der vises i testthat-output ved skip
#' @keywords internal
#' @examples
#' \dontrun{
#' test_that("fuld integration test", {
#'   skip_if_not_full_test()
#'   # ... tung test-logik
#' })
#' }
skip_if_not_full_test <- function(
    msg = "Skipping full-only test (set BFHCHARTS_TEST_FULL=true to enable)") {
  if (!is_full_test()) {
    testthat::skip(msg)
  }
  invisible(TRUE)
}

#' Skip test hvis render-test-kørsel ikke er aktiveret
#'
#' Brug på tests der kalder Quarto / Typst / andre tunge rendering-pipelines.
#'
#' @param msg Besked der vises ved skip
#' @keywords internal
skip_if_not_render_test <- function(
    msg = "Skipping render test (set BFHCHARTS_TEST_RENDER=true to enable)") {
  if (!is_render_test()) {
    testthat::skip(msg)
  }
  invisible(TRUE)
}
