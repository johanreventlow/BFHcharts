ALLOWED_EXPORT_EXTENSIONS <- c("png", "pdf", "svg", "typ")

# Output-path policy (argv[1+] til system2()):
#
# Begrundelse: hospital-filnavne indeholder rutinemaessigt parens, brackets,
# braces og ampersand ("rapport (final).pdf", "Q1 [2026].pdf",
# "Indikator & resultat.pdf"); strict afvisning af alle shell-metacharacters
# gav falske positiver der frustrerede brugere.
#
# **Vigtigt -- shell-mode med stdout/stderr capture:** R's `system2()` med
# `stdout = TRUE, stderr = TRUE` (som BFHcharts bruger til Quarto-output)
# invokerer faktisk shell for stream-omdirigering, og argumenter naar shellen
# UDEN automatisk shQuote() i alle R-versioner. Empiriske test viser at
# backtick triggrede shell-command-substitution i `output\`sub.pdf`. De
# stadig-afviste karakterer er derfor de der kan bryde shell-fortolkning:
#   - `;` `|` `<` `>` backtick -- shell-syntax (kommando-kaeder, redirection,
#     command-substitution)
#   - `\n` `\r` -- bryder Quarto's output-parser + log-filer
#   - NUL -- fil-system-graense
#   - `..` som path-komponent (separat .check_traversal())
#
# Tilladte (var tidligere afvist): spaces, parens `(` `)`, brackets `[` `]`,
# braces `{` `}`, `&`, `$`, single-quote `'`, og generel Unicode. Disse er
# enten legitim filnavn-syntax eller har lav blast-radius selv hvis shell
# fortolker dem (f.eks. `&` uden `;`/`&&` kan ikke kaede destruktive kald).
#
# Kontekst: Codex code review 2026-04-30 finding #10 + advisor-justering
# efter empirisk verifikation 2026-04-30.
SHELL_METACHARS_OUTPUT_PATH <- c(";", "|", "<", ">", "`", "\n", "\r")

# Metachars der er farlige i shell-kontekst -- bruges KUN til binary-stier
# (argv[0] til system2()) hvor R's interne wrappers kan re-quote i edge cases.
# Bevares strikt for at beskytte mod platform-specifikke quoting-nuancer.
# Note: parens/braces tillades i binary-stier (Windows Program Files (x86)),
# men shell-injection-tegn forbliver afvist.
SHELL_METACHARS_BINARY <- c(";", "|", "&", "$", "`", "<", ">", "\n", "\r")

#' Validate an export file path
#'
#' Checks that `path` is a safe, non-empty character string free of path
#' traversal components (`..`), NUL bytes, and characters that can break
#' shell parsing or output streams. Optionally validates the file extension
#' and resolves symlinks to verify the resolved path stays within
#' `allow_root`.
#'
#' **Output path policy (relaxed in v0.12.0):** Hospital filenames frequently
#' contain parens (`rapport (final).pdf`), brackets (`Q1 [2026].pdf`),
#' ampersands (`Indikator & resultat.pdf`) and spaces. These are now
#' **permitted**. The remaining rejections -- `;`, `|`, `<`, `>`, backtick,
#' newline (LF), carriage return (CR), NUL byte -- are kept because R's
#' `system2(... stdout = TRUE, stderr = TRUE)` invokes shell for
#' stream-capture and these characters can break shell parsing or chain
#' commands. `&` and `$` are permitted because without `;`/`&&` chaining (also
#' rejected) they have low blast-radius even if they reach shell.
#'
#' Binary paths (executables invoked as argv[0]) are validated separately
#' via `.check_metachars_binary()` and remain strictly checked because R's
#' internal handling of argv[0] varies by platform.
#'
#' @param path Character scalar.  The file path to validate.
#' @param extension Character scalar or `NULL`.  Expected file extension
#'   (without leading dot, e.g. `"png"`).  Case-insensitive.  If `NULL` no
#'   extension check is performed.
#' @param allow_root Character scalar or `NULL`.  If supplied and `normalize`
#'   is `TRUE`, the resolved path must start with `normalizePath(allow_root)`.
#' @param ext_action One of `"none"` (default), `"stop"`, or `"warn"`.
#'   Controls behaviour when `extension` is specified but the path does not end
#'   with that extension.
#' @param normalize Logical.  If `TRUE`, call `normalizePath(path,
#'   mustWork = TRUE)` (the file must already exist) and re-validate the
#'   resolved path.  Returns the normalized path on success.  Default `FALSE`.
#'
#' @return `path` invisibly (normalized when `normalize = TRUE`).
#'
#' @keywords internal
#' @noRd
validate_export_path <- function(path,
                                 extension = NULL,
                                 allow_root = NULL,
                                 ext_action = c("none", "stop", "warn"),
                                 normalize = FALSE) {
  ext_action <- match.arg(ext_action)

  if (!is.character(path) || length(path) != 1L || nchar(path) == 0L) {
    stop("path must be a non-empty character string specifying the file path",
      call. = FALSE
    )
  }

  .check_traversal(path)
  .check_metachars(path)

  if (!is.null(extension)) {
    if (!extension %in% ALLOWED_EXPORT_EXTENSIONS) {
      stop(
        "extension '", extension, "' is not in the allowed export extensions: ",
        paste(ALLOWED_EXPORT_EXTENSIONS, collapse = ", "),
        call. = FALSE
      )
    }
    pattern <- paste0("\\.", extension, "$")
    if (!grepl(pattern, path, ignore.case = TRUE)) {
      msg <- paste0("path does not have .", extension, " extension: ", basename(path))
      if (ext_action == "stop") stop(msg, call. = FALSE)
      if (ext_action == "warn") warning(msg, call. = FALSE)
    }
  }

  if (normalize) {
    resolved <- normalizePath(path, mustWork = TRUE)
    .check_traversal(resolved)
    .check_metachars(resolved)

    if (!is.null(allow_root)) {
      root <- normalizePath(allow_root, mustWork = TRUE)
      if (!startsWith(resolved, root)) {
        stop(
          "path resolves outside the allowed root\n",
          "  Resolved: ", resolved, "\n",
          "  Root:     ", root,
          call. = FALSE
        )
      }
    }

    return(invisible(resolved))
  }

  invisible(path)
}

.check_traversal <- function(path) {
  parts <- strsplit(path, "[/\\\\]")[[1]]
  if (any(parts == "..")) {
    stop(
      "path traversal attempt detected:",
      " '..' is not allowed as a path component\n",
      "  Provided path: ", basename(path),
      call. = FALSE
    )
  }
}

.check_metachars <- function(path) {
  # NUL-byte kan ikke optraede i R-strings under normale forhold, men kontroller
  # for sikkerheds skyld (rawToChar/Encoding-edgecases).
  if (any(charToRaw(path) == as.raw(0L))) {
    stop("path contains disallowed unsafe characters (NUL byte)", call. = FALSE)
  }
  if (any(vapply(SHELL_METACHARS_OUTPUT_PATH, function(ch) grepl(ch, path, fixed = TRUE), logical(1L)))) {
    stop("path contains disallowed unsafe characters", call. = FALSE)
  }
}

# Variant til binary-stier: tillader parens/braces (Windows Program Files-stier),
# men afviser egentlige shell-injection-tegn.
.check_metachars_binary <- function(path) {
  if (any(vapply(SHELL_METACHARS_BINARY, function(ch) grepl(ch, path, fixed = TRUE), logical(1L)))) {
    stop("binary path contains disallowed unsafe characters", call. = FALSE)
  }
}
