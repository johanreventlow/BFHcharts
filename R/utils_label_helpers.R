# utils_label_helpers.R
# Marquee label helper functions for advanced label placement
#
# Extracted from bfh_layout_reference_dev.R POC
# Provides caching, sanitization, and responsive label formatting

# ============================================================================
# PERFORMANCE: Marquee style cache
# ============================================================================
# Cache for marquee style objects keyed by lineheight
# Eliminerer redundant style creation når samme lineheight genbruges
.marquee_style_cache <- new.env(parent = emptyenv())

#' Get cached right-aligned marquee style
#'
#' PERFORMANCE: Returnerer cached style object hvis tilgængelig.
#' Style creation er relativt dyrt (~1-2ms), og styles er immutable baseret
#' på lineheight parameter, så caching er sikkert.
#'
#' @param lineheight numeric lineheight værdi (default 0.9)
#' @return marquee style object
#' @keywords internal
#' @noRd
get_right_aligned_marquee_style <- function(lineheight = 0.9) {
  cache_key <- paste0("right_aligned_", lineheight)

  if (!exists(cache_key, envir = .marquee_style_cache)) {
    # CACHE MISS: Opret ny style
    style <- marquee::modify_style(
      marquee::classic_style(),
      "p",
      margin = marquee::trbl(0),
      align = "right",
      lineheight = lineheight
    )
    .marquee_style_cache[[cache_key]] <- style
  }

  # CACHE HIT: Returnér cached style
  .marquee_style_cache[[cache_key]]
}

#' Clear marquee style cache (for testing or memory management)
#'
#' @keywords internal
#' @noRd
clear_marquee_style_cache <- function() {
  rm(list = ls(envir = .marquee_style_cache), envir = .marquee_style_cache)
  invisible(NULL)
}

# ============================================================================
# INPUT SANITIZATION
# ============================================================================

#' Sanitize text for marquee markup
#'
#' Escaper specialtegn der har betydning i marquee markup
#' for at forhindre injection attacks
#'
#' @param text Character string to sanitize
#' @return Sanitized character string
#' @keywords internal
#' @noRd
sanitize_marquee_text <- function(text) {
  if (is.null(text) || length(text) == 0) {
    return("")
  }

  if (!is.character(text)) {
    warning("sanitize_marquee_text: Konverterer ikke-character input til character")
    text <- as.character(text)
  }

  if (length(text) > 1) {
    warning("sanitize_marquee_text: Flere værdier modtaget, bruger kun første")
    text <- text[1]
  }

  # Escape marquee-relevante specialtegn (strikt sanitizer)
  # Operatorer (<, <=, >=, >) i target-labels håndteres SEPARAT via
  # parse_target_input() som returnerer en struktureret model (operator + value).
  # Denne sanitizer er generel og SKAL escape alt potentielt farligt.
  text <- gsub("&", "&amp;", text)   # Ampersand først (undgå double-escaping)
  text <- gsub("<", "&lt;", text)    # Left angle bracket
  text <- gsub(">", "&gt;", text)    # Right angle bracket

  # Escape marquee special characters
  text <- gsub("\\{", "&#123;", text) # Left brace
  text <- gsub("\\}", "&#125;", text) # Right brace

  # Fjern kontroltegn (men bevar \n for linjeskift)
  # Remove common control characters
  text <- gsub("\t", "", text)       # Tab
  text <- gsub("\r", "", text)       # Carriage return
  text <- gsub("\f", "", text)       # Form feed
  text <- gsub("\v", "", text)       # Vertical tab
  text <- gsub("\b", "", text)       # Backspace

  # Begræns længde for at forhindre memory exhaustion
  max_length <- 200
  if (nchar(text) > max_length) {
    warning(sprintf("Text afkortet fra %d til %d tegn", nchar(text), max_length))
    text <- substr(text, 1, max_length)
  }

  text
}

# ============================================================================
# TARGET INPUT PARSING (struktureret model)
# ============================================================================

#' Parse target input til struktureret model
#'
#' Splitter bruger-input i en whitelisted operator og en value-del.
#' Operatoren konverteres til Unicode-symbol. Value-delen kan derefter
#' sanitizes separat via sanitize_marquee_text().
#'
#' @param target_text character bruger-input (fx ">=90", "<= 25", "<", ">80")
#' @return list med:
#'   - `operator`: character Unicode-symbol ("≥", "≤", "↓", "↑", "<", ">", eller "")
#'   - `value`: character rest-tekst (IKKE sanitized endnu)
#'   - `is_arrow`: logical TRUE hvis operator er en pil (↓/↑)
#'   - `display`: character samlet display-tekst (operator + value)
#' @keywords internal
#' @noRd
parse_target_input <- function(target_text) {
  empty_result <- list(operator = "", value = "", is_arrow = FALSE, display = "")

  if (is.null(target_text) || length(target_text) == 0) return(empty_result)
  if (!is.character(target_text)) target_text <- as.character(target_text)
  if (nchar(trimws(target_text)) == 0) return(empty_result)

  # Whitelist: kun disse operatorer accepteres i starten af strengen
  # Rækkefølge er vigtig: >= og <= skal matches FØR > og <
  patterns <- list(
    list(re = "^>=\\s*", symbol = "\U2265", arrow = FALSE),  # ≥
    list(re = "^<=\\s*", symbol = "\U2264", arrow = FALSE),  # ≤
    list(re = "^<\\s*$", symbol = "\U2193", arrow = TRUE),   # ↓ (kun < uden tal)
    list(re = "^>\\s*$", symbol = "\U2191", arrow = TRUE),   # ↑ (kun > uden tal)
    list(re = "^<\\s*",  symbol = "<",      arrow = FALSE),  # < med tal
    list(re = "^>\\s*",  symbol = ">",      arrow = FALSE)   # > med tal
  )

  for (pat in patterns) {
    if (grepl(pat$re, target_text)) {
      value <- sub(pat$re, "", target_text)

      # For < og > med tal: check at der faktisk er et tal
      if (pat$symbol %in% c("<", ">") && !grepl("^-?[0-9]", trimws(value))) {
        # Intet tal efter < eller > → pil
        arrow_sym <- if (pat$symbol == "<") "\U2193" else "\U2191"
        return(list(operator = arrow_sym, value = "", is_arrow = TRUE,
                    display = arrow_sym))
      }

      display <- if (pat$arrow) pat$symbol else paste0(pat$symbol, value)
      return(list(operator = pat$symbol, value = value,
                  is_arrow = pat$arrow, display = display))
    }
  }

  # Ingen operator fundet → alt er value
  list(operator = "", value = target_text, is_arrow = FALSE, display = target_text)
}

# ============================================================================
# TARGET PREFIX FORMATTING
# ============================================================================

#' Check if text contains intelligent arrow symbols
#'
#' Detekterer om tekst indeholder pil-symboler (↓ eller ↑) som kræver
#' speciel label positionering uden targetline.
#'
#' @param text character string to check
#' @return logical TRUE hvis pil-symbol detekteret, FALSE ellers
#' @keywords internal
#' @noRd
has_arrow_symbol <- function(text) {
  if (is.null(text) || length(text) == 0 || !is.character(text)) {
    return(FALSE)
  }

  # Check for Unicode arrow symbols (down U+2193 or up U+2191)
  if (grepl("\U2193|\U2191", text)) {
    return(TRUE)
  }

  # Check for < or > without numbers. These are rendered as direction arrows.
  # Match < or > at start, optionally followed by whitespace, but NOT followed by digit
  if (grepl("^<\\s*$|^>\\s*$", text)) {
    return(TRUE)
  }

  return(FALSE)
}

# ============================================================================
# RESPONSIVE LABEL FORMATTING
# ============================================================================

#' Generer responsive marquee label med skalerede font-størrelser
#'
#' @param header character header text
#' @param value character value text
#' @param label_size numeric label size parameter (default 6, som i legacy code)
#' @param header_pt numeric header font size ved label_size=6 (default 10)
#' @param value_pt numeric value font size ved label_size=6 (default 30)
#' @return character marquee-formateret label string
#'
#' @details
#' Funktionen bruger `label_size` semantik (baseline = 6) frem for `base_size` (baseline = 14)
#' for at matche legacy SPC plot sizing konventioner.
#'
#' @examples
#' \dontrun{
#' create_responsive_label("MÅL", ">= 90%", label_size = 6)
#' }
#'
#' @keywords internal
#' @noRd
create_responsive_label <- function(header, value, label_size = 6, header_pt = 10, value_pt = 30,
                                    operator_prefix = "") {
  # Input validation
  if (!is.numeric(label_size) || length(label_size) != 1 || label_size <= 0) {
    stop("label_size skal være et positivt tal, modtog: ", label_size)
  }

  if (label_size < 1 || label_size > 24) {
    warning("label_size uden for normalt interval (1-24), modtog: ", label_size)
  }

  if (!is.numeric(header_pt) || !is.numeric(value_pt)) {
    stop("header_pt og value_pt skal være numeriske")
  }

  if (header_pt <= 0 || value_pt <= 0) {
    stop("header_pt og value_pt skal være positive")
  }

  # Sanitize inputs (operator_prefix er allerede whitelisted via parse_target_input)
  header <- sanitize_marquee_text(header)
  value <- sanitize_marquee_text(value)

  # Sammensæt: operator bypasser sanitizer, value er sanitized
  display_value <- if (nchar(operator_prefix) > 0) {
    paste0(operator_prefix, value)
  } else {
    value
  }

  # Compute scaled sizes (baseline: label_size = 6)
  scale_factor <- label_size / 6
  header_size <- round(header_pt * scale_factor)
  value_size <- round(value_pt * scale_factor)

  # Sanity check sizes
  if (header_size < 1 || header_size > 100) {
    stop(sprintf("Beregnet header_size uden for gyldigt interval: %d", header_size))
  }
  if (value_size < 1 || value_size > 100) {
    stop(sprintf("Beregnet value_size uden for gyldigt interval: %d", value_size))
  }

  sprintf(
    "{.%d **%s**}  \n{.%d **%s**}",
    header_size,
    header,
    value_size,
    display_value
  )
}
