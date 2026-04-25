#' Reset alle interne caches i BFHcharts
#'
#' Tømmer alle package-level cache-environments:
#' - `.font_cache`: løste font-families per (fontfamily, device-type)
#' - `.marquee_style_cache`: marquee style-objekter per lineheight
#' - `.quarto_cache`: Quarto CLI tilgængelighed og sti
#' - `.i18n_cache`: i18n YAML-tekster per sprog
#'
#' Bruges primært i testmiljø for at sikre reproducerbare resultater
#' på tværs af tests der ændrer fonts eller Quarto-konfiguration.
#'
#' @return invisible(NULL)
#' @keywords internal
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
