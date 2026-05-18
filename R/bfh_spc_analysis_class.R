# S3-class for bfh_spc_analysis
#
# Returned by bfh_analyse() and consumed by bfh_render_analysis(). The
# class is intentionally "key-only" (Model A): conclusions, caveats and
# suggested_actions store i18n-keys -- text resolution happens in
# bfh_render_analysis() via texts_loader.
#
# Refs: openspec change restructure-spc-analysis-architecture
# Spec: openspec/specs/spc-analysis-api/spec.md ADDED requirement
#       "bfh_analyse SHALL return a structured bfh_spc_analysis S3 object
#       (key-only model)"
#
# ASCII-only source (CRAN policy).


# Current schema-version. Bumped independently of package-version when
# the top-level structure changes:
#  MAJOR: breaking change i top-level struktur (felt fjernet, type
#         aendret, semantik flyttet)
#  MINOR: tilfoejelse af nyt felt med bagudkompatibel default
#  PATCH: dokumentations-/klargoeringsopdatering uden struktur-aendring
BFH_SPC_ANALYSIS_SCHEMA_VERSION <- "1.0.0"


#' Construct a bfh_spc_analysis Object
#'
#' Internal S3-class constructor. Callers should use `bfh_analyse()`
#' rather than this constructor directly. The constructor validates
#' top-level field-types and assigns the class; semantic validation of
#' feature-axis-values lives in `validate_bfh_spc_analysis()`.
#'
#' @param features Named list with 12 ortogonale fortolknings-akser.
#' @param aux Named list with computed helper-values (sigma_hat,
#'   sigma_data, n_points, centerline, analysis_date, ...).
#' @param render_context Named list with preserved render-state
#'   (target_display, y_axis_unit, centerline_formatted,
#'   operator_unicode, outliers_word_key, effective_window, chart_type).
#' @param conclusions Named list with i18n-noegler (`stability_key`,
#'   `target_key`, `action_key`).
#' @param confidence Character scalar: "low" | "medium" | "high".
#' @param caveats Named list of active caveat-noegler (NULL for inactive).
#' @param suggested_actions Character-vektor af i18n-noegler.
#' @param language Character scalar: "da" | "en".
#' @param schema_version Character semver-pattern (default
#'   `BFH_SPC_ANALYSIS_SCHEMA_VERSION`).
#'
#' @return Object of class `bfh_spc_analysis`.
#'
#' @keywords internal
#' @noRd
new_bfh_spc_analysis <- function(features,
                                 aux,
                                 render_context,
                                 conclusions,
                                 confidence,
                                 caveats,
                                 suggested_actions,
                                 language = "da",
                                 schema_version = BFH_SPC_ANALYSIS_SCHEMA_VERSION) {
  # Top-level type-validation
  if (!is.list(features)) {
    stop("features must be a named list", call. = FALSE)
  }
  if (!is.list(aux)) {
    stop("aux must be a named list", call. = FALSE)
  }
  if (!is.list(render_context)) {
    stop("render_context must be a named list", call. = FALSE)
  }
  if (!is.list(conclusions)) {
    stop("conclusions must be a named list", call. = FALSE)
  }
  if (!is.character(confidence) || length(confidence) != 1L ||
    !confidence %in% c("low", "medium", "high")) {
    stop(
      "confidence must be one of \"low\", \"medium\", \"high\"",
      call. = FALSE
    )
  }
  if (!is.list(caveats)) {
    stop("caveats must be a named list", call. = FALSE)
  }
  if (!is.character(suggested_actions)) {
    stop("suggested_actions must be a character vector (of i18n-keys)", call. = FALSE)
  }
  if (!is.character(language) || length(language) != 1L ||
    !language %in% c("da", "en")) {
    stop("language must be one of \"da\", \"en\"", call. = FALSE)
  }
  if (!is.character(schema_version) || length(schema_version) != 1L ||
    !grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", schema_version)) {
    stop("schema_version must be semver-pattern (e.g. \"1.0.0\")", call. = FALSE)
  }

  structure(
    list(
      schema_version = schema_version,
      language = language,
      features = features,
      aux = aux,
      render_context = render_context,
      conclusions = conclusions,
      confidence = confidence,
      caveats = caveats,
      suggested_actions = suggested_actions
    ),
    class = c("bfh_spc_analysis", "list")
  )
}


#' Validate Internal Consistency of bfh_spc_analysis
#'
#' Internal helper. Performs semantic validation beyond constructor's
#' type-checks: required feature-axes present, axis-values within
#' documented enums, conclusion-keys non-empty. Returns the object
#' unchanged on success; stops with informative message on failure.
#'
#' @param x A `bfh_spc_analysis`-object.
#'
#' @return `x` (invisibly) on success.
#'
#' @keywords internal
#' @noRd
validate_bfh_spc_analysis <- function(x) {
  if (!inherits(x, "bfh_spc_analysis")) {
    stop("x must be a bfh_spc_analysis object", call. = FALSE)
  }

  required_features <- c(
    "stability_pattern", "trend_form", "magnitude", "direction",
    "target_relation", "confidence_tier", "phase_context",
    "freshness", "chart_class", "data_quality", "cl_source",
    "outlier_history",
    # Cycle 05 finding #5: low_confidence_reason driver template-dispatch
    # ved confidence_tier=="low". Schema-required for konsumenter der
    # bygger UI-badges/AI-prompts paa low-confidence-aarsag.
    "low_confidence_reason"
  )
  missing_features <- setdiff(required_features, names(x$features))
  if (length(missing_features) > 0) {
    stop(
      sprintf(
        "features mangler obligatoriske akser: %s",
        paste(missing_features, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  required_conclusions <- c("stability_key", "target_key", "action_key")
  missing_conclusions <- setdiff(required_conclusions, names(x$conclusions))
  if (length(missing_conclusions) > 0) {
    stop(
      sprintf(
        "conclusions mangler obligatoriske noegler: %s",
        paste(missing_conclusions, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  required_render_context <- c(
    "target_display", "centerline_formatted", "y_axis_unit",
    "operator_unicode", "outliers_word_key", "effective_window",
    "chart_type"
  )
  missing_render <- setdiff(required_render_context, names(x$render_context))
  if (length(missing_render) > 0) {
    stop(
      sprintf(
        "render_context mangler obligatoriske felter: %s",
        paste(missing_render, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  required_aux <- c("analysis_date")
  missing_aux <- setdiff(required_aux, names(x$aux))
  if (length(missing_aux) > 0) {
    stop(
      sprintf(
        "aux mangler obligatoriske felter: %s",
        paste(missing_aux, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  # Confidence-tier-enum
  if (!is.null(x$features$confidence_tier) &&
    !x$features$confidence_tier %in% c("low", "medium", "high")) {
    stop(
      sprintf(
        "features$confidence_tier = %s er ej i {low, medium, high}",
        sQuote(x$features$confidence_tier)
      ),
      call. = FALSE
    )
  }

  invisible(x)
}


#' Print Method for bfh_spc_analysis
#'
#' Displays a compact summary of features, conclusions, confidence, and
#' active caveats. Use `format()` for a single-line summary or
#' `as.list()` to inspect raw structure.
#'
#' @param x A `bfh_spc_analysis` object.
#' @param ... Ignored.
#'
#' @return `x` (invisibly).
#'
#' @export
print.bfh_spc_analysis <- function(x, ...) {
  cat("<bfh_spc_analysis>\n")
  cat(sprintf(
    "  schema_version: %s | language: %s | confidence: %s\n",
    x$schema_version, x$language, x$confidence
  ))

  cat("  features:\n")
  feat_summary <- vapply(
    names(x$features),
    function(k) {
      v <- x$features[[k]]
      if (is.list(v)) {
        return(paste0(k, ": <list>"))
      }
      if (is.null(v) || length(v) == 0L) {
        return(paste0(k, ": <NA>"))
      }
      paste0(k, ": ", format(v[[1L]]))
    },
    character(1L)
  )
  cat(paste0("    ", feat_summary, "\n"), sep = "")

  cat("  conclusions:\n")
  cat(sprintf("    stability_key: %s\n", x$conclusions$stability_key %||% "<NA>"))
  cat(sprintf("    target_key:    %s\n", x$conclusions$target_key %||% "<NA>"))
  cat(sprintf("    action_key:    %s\n", x$conclusions$action_key %||% "<NA>"))

  active_caveats <- names(x$caveats)[!vapply(x$caveats, is.null, logical(1L))]
  if (length(active_caveats) > 0L) {
    cat(sprintf("  active caveats: %s\n", paste(active_caveats, collapse = ", ")))
  } else {
    cat("  active caveats: <none>\n")
  }

  if (length(x$suggested_actions) > 0L) {
    cat(sprintf(
      "  suggested_actions: %s\n",
      paste(x$suggested_actions, collapse = ", ")
    ))
  }

  invisible(x)
}


#' Format Method for bfh_spc_analysis
#'
#' Returns a single-line character summary. Used by `paste()`, format-
#' contexts, and debugging-helpers.
#'
#' @param x A `bfh_spc_analysis` object.
#' @param ... Ignored.
#'
#' @return Character scalar.
#'
#' @export
format.bfh_spc_analysis <- function(x, ...) {
  sprintf(
    "<bfh_spc_analysis %s, %s, %s confidence: %s/%s>",
    x$schema_version, x$language, x$confidence,
    x$conclusions$stability_key %||% "?",
    x$conclusions$action_key %||% "?"
  )
}


#' Convert bfh_spc_analysis to Plain List
#'
#' Strips the S3-class and returns a plain named list suitable for
#' JSON-serialization or downstream-tools that do not understand the
#' class. The structure is preserved verbatim; no field-renaming or
#' filtering occurs.
#'
#' @param x A `bfh_spc_analysis` object.
#' @param ... Ignored.
#'
#' @return Named list.
#'
#' @examples
#' \dontrun{
#' analysis <- bfh_analyse(result)
#' flat <- as.list(analysis)
#' json <- jsonlite::toJSON(flat, auto_unbox = TRUE)
#' }
#'
#' @export
as.list.bfh_spc_analysis <- function(x, ...) {
  unclass(x)
}


#' Check if Object is bfh_spc_analysis
#'
#' @param x Object to test.
#'
#' @return Logical indicating whether x inherits from
#'   `bfh_spc_analysis`.
#'
#' @export
is_bfh_spc_analysis <- function(x) {
  inherits(x, "bfh_spc_analysis")
}
