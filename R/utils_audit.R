# Audit event helper for BFHcharts
#
# Emits structured audit events for AI egress and other auditable actions.
# Written to getOption("BFHcharts.audit_log") as JSON-line if set,
# otherwise falls back to message() with a structured prefix.
#
# ASCII-only source (CRAN policy).


# Minimal base-R JSON serializer for scalar/vector audit events.
# Handles: NULL, logical, integer, double, character, POSIXct/POSIXlt/Date.
# Vectors become JSON arrays. Lists become JSON objects (one level deep).
.to_json_value <- function(x) {
  if (is.null(x)) {
    return("null")
  }
  if (is.logical(x) && length(x) == 1L && !is.na(x)) {
    return(if (x) "true" else "false")
  }
  if (inherits(x, c("POSIXct", "POSIXlt", "Date"))) {
    return(paste0('"', format(x, "%Y-%m-%dT%H:%M:%OS3Z"), '"'))
  }
  if (is.numeric(x) && length(x) == 1L && is.finite(x)) {
    return(as.character(x))
  }
  if (is.character(x) && length(x) == 1L) {
    escaped <- gsub("\\\\", "\\\\\\\\", x)
    escaped <- gsub('"', '\\\\"', escaped)
    escaped <- gsub("\n", "\\\\n", escaped)
    escaped <- gsub("\r", "\\\\r", escaped)
    return(paste0('"', escaped, '"'))
  }
  # Vectors (length > 1): JSON array of strings
  if (is.character(x) || is.numeric(x) || is.logical(x)) {
    items <- vapply(x, function(v) .to_json_value(v), character(1L))
    return(paste0("[", paste(items, collapse = ", "), "]"))
  }
  # Fallback: quoted string representation
  paste0('"', paste(as.character(x), collapse = " "), '"')
}


# Serialize a named list to a single-line JSON object (no jsonlite dependency).
.list_to_json_line <- function(lst) {
  if (!is.list(lst) || is.null(names(lst))) {
    return("{}")
  }
  pairs <- mapply(function(k, v) {
    paste0('"', k, '"', ": ", .to_json_value(v))
  }, names(lst), lst, SIMPLIFY = TRUE, USE.NAMES = FALSE)
  paste0("{", paste(pairs, collapse = ", "), "}")
}


#' Emit a structured audit event
#'
#' Internal helper. Writes to getOption("BFHcharts.audit_log") as a JSON-line
#' if the option is a non-empty character string; otherwise emits via message()
#' with prefix [BFHcharts/audit].
#'
#' @param event_data Named list of audit fields.
#'
#' @keywords internal
#' @noRd
.emit_audit_event <- function(event_data) {
  json_line <- .list_to_json_line(event_data)

  log_path <- getOption(BFHCHARTS_OPT_AUDIT_LOG, default = "")
  if (is.character(log_path) && nzchar(log_path)) {
    tryCatch(
      cat(json_line, "\n", file = log_path, append = TRUE, sep = ""),
      error = function(e) {
        message(
          "[BFHcharts/audit] WARNING: could not write to audit log '",
          log_path, "': ", conditionMessage(e),
          "\n[BFHcharts/audit] ", json_line
        )
      }
    )
  } else {
    message("[BFHcharts/audit] ", json_line)
  }

  invisible(NULL)
}
