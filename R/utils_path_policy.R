ALLOWED_EXPORT_EXTENSIONS <- c("png", "pdf", "svg", "typ")

SHELL_METACHARS_EXPORT <- c(";", "|", "&", "$", "`", "(", ")", "{", "}", "<", ">", "\n", "\r")

#' Validate an export file path
#'
#' Checks that `path` is a safe, non-empty character string free of path
#' traversal components (`..`) and shell metacharacters.  Optionally validates
#' the file extension and resolves symlinks to verify the resolved path stays
#' within `allow_root`.
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
  if (any(vapply(SHELL_METACHARS_EXPORT, function(ch) grepl(ch, path, fixed = TRUE), logical(1L)))) {
    stop("path contains disallowed unsafe characters", call. = FALSE)
  }
}
