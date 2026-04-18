# ============================================================================
# Test Mocking Factories
# ============================================================================
#
# Delt mocking-infrastruktur for isolation-tests. Disse factories tillader
# tests at kontrollere Quarto-detektion, versions-check og system2-return
# uden live-dependencies.
#
# Reference: openspec/changes/strengthen-test-infrastructure (task 5.1–5.6)
# Spec: test-infrastructure, "External dependencies SHALL be testable in isolation"

# ----------------------------------------------------------------------------
# Cache-manipulation for Quarto-detektion
# ----------------------------------------------------------------------------

#' Ryd Quarto-cache og gendan efter test
#'
#' Quarto-detektion caches på session-niveau via `.quarto_cache`. Denne helper
#' rydder cachen før testen og gendanner den originale tilstand efter.
#'
#' @param env environment der kalder (bruges til `withr::defer`)
#' @keywords internal
local_clean_quarto_cache <- function(env = parent.frame()) {
  cache <- BFHcharts:::.quarto_cache

  # Gem nuværende cache-nøgler
  saved_keys <- ls(envir = cache)
  saved_values <- mget(saved_keys, envir = cache)

  # Ryd cache
  rm(list = saved_keys, envir = cache)

  # Gendan efter test
  withr::defer(
    {
      rm(list = ls(envir = cache), envir = cache)
      for (key in names(saved_values)) {
        assign(key, saved_values[[key]], envir = cache)
      }
    },
    envir = env
  )
}

#' Sæt forud-beregnet Quarto-cache-værdier
#'
#' Erstatter Quarto-detektions-cachen midlertidigt med kendte værdier.
#' Nyttig til at teste caching-adfærd uden at udføre reelle system-kald.
#'
#' @param quarto_available Logical; hvilken værdi skal returneres
#' @param min_version Minimum-version-nøgle der skal cacheres
#' @param quarto_path Character; hvilken sti skal returneres af get_quarto_path()
#' @param env environment der kalder
#' @keywords internal
local_mock_quarto_cache <- function(quarto_available = TRUE,
                                     min_version = "1.4.0",
                                     quarto_path = "/usr/local/bin/quarto",
                                     env = parent.frame()) {
  local_clean_quarto_cache(env = env)
  cache_key <- paste0("quarto_", min_version)
  assign(cache_key, quarto_available, envir = BFHcharts:::.quarto_cache)
  if (quarto_available) {
    assign("quarto_path", quarto_path, envir = BFHcharts:::.quarto_cache)
  }
}

# ----------------------------------------------------------------------------
# Mock-factories for system2-return-værdier
# ----------------------------------------------------------------------------

#' Opret mock der returnerer succes-output
#'
#' @param version_string Character; fx "quarto 1.4.557"
#' @return Function med samme signatur som system2()
#' @keywords internal
make_system2_success_mock <- function(version_string = "1.4.557") {
  function(command, args, ...) {
    version_string
  }
}

#' Opret mock der returnerer non-zero exit (compile-failure)
#'
#' @param exit_code Integer; fx 1 (failure)
#' @param output Character; simuleret stdout/stderr
#' @return Function med samme signatur som system2()
#' @keywords internal
make_system2_failure_mock <- function(exit_code = 1L,
                                       output = "Error: compilation failed") {
  function(command, args, ...) {
    result <- output
    attr(result, "status") <- exit_code
    result
  }
}

#' Opret mock der fejler med error (binær ikke fundet)
#'
#' @param message Character; fejlbesked
#' @return Function med samme signatur som system2() der kaster fejl
#' @keywords internal
make_system2_error_mock <- function(message = "cannot find quarto executable") {
  function(command, args, ...) {
    stop(message, call. = FALSE)
  }
}

# ----------------------------------------------------------------------------
# Mock-factories for BFHllm-integration
# ----------------------------------------------------------------------------

#' Mock BFHllm::llm_complete() der returnerer fikseret analyse-tekst
#'
#' Sandsynligvis anvendt via `local_mocked_bindings(.package = "BFHllm")`
#' når BFHllm er installeret. Når BFHllm mangler (CRAN/CI uden AI), skal
#' tests i stedet bruge skip_if_not_installed("BFHllm").
#'
#' @param response Character; forventet analyse-tekst
#' @return Function med signatur matchende BFHllm::llm_complete()
#' @keywords internal
make_bfhllm_success_mock <- function(
    response = "Processen er stabil. Ingen signaler.") {
  function(...) {
    list(text = response, status = "ok")
  }
}

#' Mock BFHllm::llm_complete() der fejler
#'
#' @param message Character; fejlbesked
#' @return Function der kaster fejl
#' @keywords internal
make_bfhllm_failure_mock <- function(message = "API rate limit exceeded") {
  function(...) {
    stop(message, call. = FALSE)
  }
}
