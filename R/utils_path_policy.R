#' Export Path Policy Utilities
#'
#' Central validation helper for export file paths. Enforces security
#' constraints (shell metacharacters, path traversal) and optional extension
#' and root-confinement checks before any file system operation.
#'
#' @name utils_path_policy
#' @keywords internal
#' @noRd
NULL

stop_path_policy_error <- function(msg) {
  cond <- structure(
    class = c("bfhcharts_path_policy_error", "error", "condition"),
    list(message = msg, call = sys.call(-1))
  )
  stop(cond)
}

#' Validate and normalise an export file path
#'
#' Checks that `path` is a non-empty string free of shell metacharacters and
#' `..` path-traversal segments, optionally enforces a file extension, and
#' returns the path normalised to an absolute form. Call sites should assign
#' the return value so they work with the normalised path downstream.
#'
#' @param path Character scalar. File path to validate.
#' @param extension Character scalar or NULL. Required extension without the
#'   leading dot, e.g. `"png"`, `"pdf"`, `"typ"`. Case-insensitive. NULL skips
#'   the extension check.
#' @param allow_root Character scalar or NULL. When given, the resolved path
#'   must be inside this directory (guards against symlink-based escape).
#' @return Normalised absolute character path.
#' @keywords internal
validate_export_path <- function(path, extension = NULL, allow_root = NULL) {
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop_path_policy_error("path must be a non-empty character string")
  }

  # Reject shell metacharacters before any file system operation
  .shell_metachars <- c(
    ";", "|", "&", "$", "`", "(", ")", "{", "}", "<", ">", "\n", "\r"
  )
  if (any(vapply(.shell_metachars, function(ch) grepl(ch, path, fixed = TRUE), logical(1)))) {
    stop_path_policy_error(sprintf("path contains unsafe characters: %s", basename(path)))
  }

  # Reject '..' segments — split-based to avoid false positives on names like
  # "..extra" or filenames that happen to contain ".." as a substring
  segments <- strsplit(path, "[/\\\\]")[[1]]
  if (any(segments == "..")) {
    stop_path_policy_error(sprintf("path traversal detected ('..') in: %s", path))
  }

  # Extension check (before normalization; basename is still the user-provided name)
  if (!is.null(extension)) {
    ext <- tolower(tools::file_ext(path))
    if (ext != tolower(extension)) {
      stop_path_policy_error(sprintf(
        "path must have .%s extension (got '%s'): %s",
        tolower(extension), ext, basename(path)
      ))
    }
  }

  # Normalize: resolve symlinks on the *directory* part with mustWork = FALSE
  # (the output file typically does not exist yet). Append basename unchanged.
  norm_dir <- normalizePath(dirname(path), winslash = "/", mustWork = FALSE)
  normalized <- file.path(norm_dir, basename(path))

  # allow_root: verify the resolved path is inside the permitted tree
  if (!is.null(allow_root)) {
    root_norm <- normalizePath(allow_root, winslash = "/", mustWork = FALSE)
    root_prefix <- paste0(root_norm, "/")
    if (!startsWith(normalized, root_prefix)) {
      stop_path_policy_error(sprintf(
        "path escapes allowed root directory\n  Path: %s\n  Root: %s",
        normalized, root_norm
      ))
    }
  }

  normalized
}
