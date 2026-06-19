#' Reset alle interne caches i BFHcharts
#'
#' Toemmer alle package-level cache-environments:
#' - `.font_cache`: loeste font-families per (fontfamily, device-type)
#' - `.marquee_style_cache`: marquee style-objekter per lineheight
#' - `.quarto_cache`: Quarto CLI tilgaengelighed og sti
#' - `.i18n_cache`: i18n YAML-tekster per sprog
#' - `.bfh_template_cache`: staged Typst template-mappe (zzz.R)
#' - `.dep_guard_cache`: BFHtheme version-check resultater (utils_dep_guards.R)
#'
#' Bruges primaert i testmiljoe for at sikre reproducerbare resultater
#' paa tvaers af tests der aendrer fonts, Quarto-konfiguration eller
#' dependency-status.
#'
#' @return invisible(NULL)
#' @keywords internal
#' @noRd
bfh_reset_caches <- function() {
  caches <- list(
    .font_cache, # utils_add_right_labels_marquee.R
    .marquee_style_cache, # utils_label_helpers.R
    .quarto_cache, # utils_quarto.R
    .i18n_cache, # utils_i18n.R
    .bfh_template_cache, # zzz.R
    .dep_guard_cache # utils_dep_guards.R
  )
  for (cache in caches) {
    rm(list = ls(envir = cache), envir = cache)
  }
  invisible(NULL)
}
