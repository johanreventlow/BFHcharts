# utils_text_da.R
# Danish text-formatting helpers.
#
# Pure string-manipulation utilities used by the SPC analysis pipeline
# (R/spc_analysis.R) and other internal label/summary code paths. Live in
# their own file so the analysis pipeline does not have to host
# language-specific text logic, and so future English-specific helpers can
# follow the same `R/utils_text_<lang>.R` pattern symmetrically.
#
# All exports here are `@keywords internal @noRd`.


# Vaelg ental eller flertal ud fra n. n == 1 -> singular, alt andet -> plural.
# NA og NULL behandles som flertal (neutral default).
pluralize_da <- function(n, singular, plural) {
  if (is.null(n) || length(n) == 0 || is.na(n)) {
    return(plural)
  }
  if (n == 1) singular else plural
}


# Garanter at tekst ikke overskrider max_chars. Trim ved sidste saetnings- eller
# klausulgraense (punktum, komma) foer graensen. Undgaa at klippe midt i et ord.
ensure_within_max <- function(text, max_chars) {
  if (is.null(text) || is.na(text)) {
    return("")
  }
  if (nchar(text) <= max_chars) {
    return(text)
  }

  cut <- substr(text, 1, max_chars)

  # Proev foerst at trimme ved sidste punktum-graense
  last_period <- max(
    gregexpr("\\.\\s", cut, perl = TRUE)[[1]],
    gregexpr("\\.$", cut, perl = TRUE)[[1]]
  )
  if (is.finite(last_period) && last_period > 0) {
    return(trimws(substr(text, 1, last_period)))
  }

  # Ellers trim ved sidste komma
  last_comma <- max(gregexpr(",\\s", cut, perl = TRUE)[[1]])
  if (is.finite(last_comma) && last_comma > 0) {
    trimmed <- trimws(substr(text, 1, last_comma - 1))
    if (!grepl("[.!?]$", trimmed)) trimmed <- paste0(trimmed, ".")
    return(trimmed)
  }

  # Sidste udvej: trim ved sidste space
  last_space <- max(gregexpr("\\s", cut, perl = TRUE)[[1]])
  if (is.finite(last_space) && last_space > 0) {
    trimmed <- trimws(substr(text, 1, last_space - 1))
    if (!grepl("[.!?]$", trimmed)) trimmed <- paste0(trimmed, ".")
    return(trimmed)
  }

  # Fallback (ord uden spaces): haard trim
  substr(text, 1, max_chars)
}


# Erstat {placeholders} med faktiske vaerdier i en tekststreng
substitute_placeholders <- function(text, data = list()) {
  for (key in names(data)) {
    text <- gsub(
      paste0("\\{", key, "\\}"),
      as.character(data[[key]] %||% ""),
      text
    )
  }
  text
}


# Vaelg tekstvariant baseret paa pladsbudget og erstat {placeholders}.
# Named variants (short/standard/detailed): vaelg laengste der passer.
# Bagudkompatibel med gammelt format (liste af strenge).
pick_text <- function(variants, data = list(), budget = Inf) {
  if (length(variants) == 0) {
    return("")
  }

  # Bagudkompatibilitet: gammelt format er en unamed liste af strenge
  if (is.null(names(variants)) && is.character(variants[[1]])) {
    text <- variants[[1]]
    return(substitute_placeholders(text, data))
  }

  # Nyt format: named list (short, standard, detailed)
  # Proev fra laengst til kortest, vaelg den laengste der passer i budgettet
  candidates <- c("detailed", "standard", "short")
  for (candidate in candidates) {
    if (!is.null(variants[[candidate]])) {
      text <- substitute_placeholders(variants[[candidate]], data)
      if (nchar(text) <= budget) {
        return(text)
      }
    }
  }

  # Fallback: korteste tilgaengelige variant (selv hvis den overstiger budget)
  available <- intersect(rev(candidates), names(variants))
  if (length(available) > 0) {
    return(substitute_placeholders(variants[[available[1]]], data))
  }

  return("")
}
