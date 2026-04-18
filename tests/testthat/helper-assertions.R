# ============================================================================
# Custom testthat Expectations
# ============================================================================
#
# Delte custom expectations for BFHcharts-specifikke assertions. Bruges på
# tværs af testfiler til at give bedre failure-beskeder.
#
# Reference: openspec/changes/strengthen-test-infrastructure (Fase 2 task 6.3)
# Spec: test-infrastructure, "Rendered outputs SHALL have content verification"

# ----------------------------------------------------------------------------
# PDF-content-verifikation (flyttet fra test-export_pdf-content.R)
# ----------------------------------------------------------------------------

#' Verificér at en PDF-fil indeholder forventet tekst-pattern
#'
#' Bruger pdftools::pdf_text() til at ekstrahere al tekst fra PDF og matcher
#' mod regex. Ignorerer whitespace-variationer og case-sensitivitet som default.
#'
#' @param pdf_path Sti til PDF-fil
#' @param pattern Regex-pattern forventet i PDF-tekst
#' @param ignore_case Logical; TRUE = case-insensitiv match (default)
#' @return Invisible TRUE hvis match, ellers fejler testthat-expectation
#' @keywords internal
expect_pdf_contains <- function(pdf_path, pattern, ignore_case = TRUE) {
  act <- testthat::quasi_label(rlang::enquo(pdf_path), arg = "pdf_path")

  testthat::expect_true(
    file.exists(pdf_path),
    info = paste("PDF file does not exist:", pdf_path)
  )

  text <- pdftools::pdf_text(pdf_path)
  combined <- paste(text, collapse = "\n")

  # Normalisér whitespace for robust matching
  normalized <- gsub("[[:space:]]+", " ", combined)

  testthat::expect_match(
    normalized,
    pattern,
    fixed = FALSE,
    ignore.case = ignore_case,
    info = paste0(
      "Pattern not found in PDF content.\n",
      "Pattern: ", pattern, "\n",
      "PDF path: ", act$val, "\n",
      "First 500 chars of content: ", substr(normalized, 1, 500)
    )
  )
}

# ----------------------------------------------------------------------------
# bfh_qic_result-struktur validering
# ----------------------------------------------------------------------------

#' Verificér at objektet er et korrekt struktureret bfh_qic_result
#'
#' Tjekker både S3-klasse og at alle forventede komponenter findes med
#' korrekt type. Bruges til at strengere erstatte bare `expect_s3_class(...)`.
#'
#' @param object Objekt at validere
#' @return Invisible TRUE hvis valid, ellers fejler testthat-expectations
#' @keywords internal
expect_valid_bfh_qic_result <- function(object) {
  act <- testthat::quasi_label(rlang::enquo(object), arg = "object")

  testthat::expect_s3_class(object, "bfh_qic_result",
                            label = act$lab)
  testthat::expect_true(all(c("plot", "summary", "qic_data", "config") %in% names(object)),
                        info = "bfh_qic_result mangler forventede komponenter")
  testthat::expect_s3_class(object$plot, "ggplot",
                            label = paste0(act$lab, "$plot"))
  testthat::expect_s3_class(object$summary, "data.frame",
                            label = paste0(act$lab, "$summary"))
  testthat::expect_s3_class(object$qic_data, "data.frame",
                            label = paste0(act$lab, "$qic_data"))
  testthat::expect_type(object$config, "list")
  invisible(TRUE)
}

#' Verificér numerisk værdi i SPC-summary med tolerance
#'
#' Udvidet assertion der også rapporterer row-index ved failure.
#'
#' @param summary data.frame (typisk bfh_qic_result$summary)
#' @param column Kolonne-navn (streng)
#' @param expected Forventet værdi
#' @param row Række-index (default 1 for første fase)
#' @param tolerance Numerisk tolerance (default 1e-6)
#' @keywords internal
expect_summary_value <- function(summary, column, expected, row = 1, tolerance = 1e-6) {
  testthat::expect_true(column %in% names(summary),
                        info = paste("Kolonne", column, "findes ikke i summary"))
  actual <- summary[[column]][row]
  testthat::expect_equal(
    actual,
    expected,
    tolerance = tolerance,
    label = paste0("summary$", column, "[", row, "]")
  )
}
