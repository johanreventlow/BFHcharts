#' Reset alle interne caches i BFHcharts
#'
#' Toemmer alle package-level cache-environments:
#' - `.font_cache`: loeste font-families per (fontfamily, device-type)
#' - `.marquee_style_cache`: marquee style-objekter per lineheight
#' - `.quarto_cache`: Quarto CLI tilgaengelighed og sti
#' - `.i18n_cache`: i18n YAML-tekster per sprog
#'
#' Bruges primaert i testmiljoe for at sikre reproducerbare resultater
#' paa tvaers af tests der aendrer fonts eller Quarto-konfiguration.
#'
#' @return invisible(NULL)
#' @keywords internal
#' @noRd
bfh_reset_caches <- function() {
  caches <- list(
    .font_cache,
    .marquee_style_cache,
    .quarto_cache,
    .i18n_cache
  )
  for (cache in caches) {
    rm(list = ls(envir = cache), envir = cache)
  }
  invisible(NULL)
}
