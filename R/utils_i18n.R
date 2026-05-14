# Package-level cache for i18n oversaettelser
.i18n_cache <- new.env(parent = emptyenv())


validate_language <- function(language) {
  if (!language %in% c("da", "en")) {
    stop(
      sprintf("language must be one of: da, en (got '%s')", language),
      call. = FALSE
    )
  }
}


#' Indlaes oversaettelser fra inst/i18n/{language}.yaml
#'
#' Cacher resultatet per sprog i \code{.i18n_cache}.
#' Falder tilbage til dansk hvis filen ikke findes.
#'
#' @keywords internal
#' @noRd
load_translations <- function(language = "da") {
  validate_language(language)
  cached <- .i18n_cache[[language]]
  if (!is.null(cached)) {
    return(cached)
  }
  yaml_path <- system.file("i18n", paste0(language, ".yaml"), package = "BFHcharts")
  if (yaml_path == "") {
    warning(sprintf("i18n/%s.yaml not found, falling back to 'da'", language))
    if (language == "da") {
      return(list())
    }
    return(load_translations("da"))
  }
  translations <- yaml::read_yaml(yaml_path)
  .i18n_cache[[language]] <- translations
  translations
}


#' Slaa i18n-noegle op (punktum-separeret sti)
#'
#' Eksempel: \code{i18n_lookup("labels.interval.monthly", "en")} -> \code{"month"}.
#' Falder tilbage til "da" hvis noeglen mangler i target-sproget.
#'
#' @param key Punktum-separeret noeglesti, fx \code{"labels.details.periode"}.
#' @param language Sprogkode, \code{"da"} eller \code{"en"}.
#'
#' @keywords internal
#' @noRd
i18n_lookup <- function(key, language = "da") {
  translations <- load_translations(language)
  parts <- strsplit(key, ".", fixed = TRUE)[[1]]
  result <- translations
  for (part in parts) {
    result <- result[[part]]
    if (is.null(result)) break
  }
  if (is.character(result) && length(result) == 1L) {
    return(result)
  }
  if (language != "da") {
    return(i18n_lookup(key, "da"))
  }
  warning(sprintf("i18n key not found: %s", key), call. = FALSE)
  key
}


#' Hent analysetekster for givet sprog
#'
#' Returnerer \code{analysis}-sektionen af i18n-filen, som har samme
#' struktur som det gamle \code{inst/texts/spc_analysis.yml}
#' (stability, target, action paa oeverste niveau).
#'
#' @param language Sprogkode, \code{"da"} eller \code{"en"}.
#'
#' @keywords internal
#' @noRd
load_spc_texts <- function(language = "da") {
  translations <- load_translations(language)
  translations[["analysis"]] %||% list()
}
