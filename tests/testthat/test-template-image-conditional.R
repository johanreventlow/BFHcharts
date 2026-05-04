# Conditional template image rendering tests.
#
# Validates the contract from change add-conditional-template-image:
#   1. PDF compiles successfully when no logo_path is supplied (default).
#      The foreground logo slot stays empty; layout is preserved.
#   2. PDF compiles successfully with a caller-supplied logo image.
#   3. Invalid logo_path surfaces a clear error from Typst (not silent).
#
# Tests are gated behind BFHCHARTS_TEST_RENDER + Quarto/pdftools availability
# to keep default test runs fast.

# Helper: minimal bfh_qic result for smoke rendering. Mirrors the helper in
# test-production-template-renders.R but localized to avoid cross-file
# coupling.
.make_image_test_result <- function() {
  data <- data.frame(
    x = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    y = c(5, 6, 4, 7, 5, 6, 5, 8, 4, 6, 5, 7)
  )
  # bfh_qic() uses NSE for x/y -- pass unquoted column names.
  bfh_qic(data, x = x, y = y, chart_type = "i")
}

test_that("PDF compiles successfully without logo_path (default)", {
  skip_if_not_render_test()
  skip_if_no_pdf_render_deps()

  result <- .make_image_test_result()
  output_pdf <- withr::local_tempfile(fileext = ".pdf")

  # No metadata$logo_path supplied. Template's logo_path: none default
  # SHALL be used. PDF SHALL compile without file-not-found errors.
  expect_no_error(
    bfh_export_pdf(result, output_pdf),
    message = "bfh_export_pdf() without logo_path should not error"
  )

  expect_true(file.exists(output_pdf), label = "PDF created without logo")
  expect_gt(file.info(output_pdf)$size, 1000L, label = "PDF size > 1 KB")

  info <- pdftools::pdf_info(output_pdf)
  expect_gte(info$pages, 1L, label = "PDF has at least 1 page")
})

test_that("PDF compiles successfully with explicit logo_path", {
  skip_if_not_render_test()
  skip_if_no_pdf_render_deps()

  # Build a fixture image accessible from the staged template directory.
  # The Typst template resolves image() paths relative to the .typ file,
  # so we use an inject_assets callback to drop the fixture image into
  # the staged template's images/ subdirectory and let auto-detect pick
  # it up (covers the canonical companion-package flow).
  # Build a known-valid PNG via ggplot2::ggsave (already an Imports dep).
  # Avoids both raw-byte CRC pitfalls and base R graphics-device init issues.
  inject_fixture_logo <- function(stage_dir) {
    images_dest <- file.path(stage_dir, "images")
    dir.create(images_dest, recursive = TRUE, showWarnings = FALSE)
    ggplot2::ggsave(
      filename = file.path(images_dest, "Hospital_Maerke_RGB_A1_str.png"),
      plot = ggplot2::ggplot() +
        ggplot2::geom_blank(),
      width = 2, height = 2, units = "cm", dpi = 72
    )
    invisible(stage_dir)
  }

  result <- .make_image_test_result()
  output_pdf <- withr::local_tempfile(fileext = ".pdf")

  expect_no_error(
    bfh_export_pdf(result, output_pdf, inject_assets = inject_fixture_logo),
    message = "bfh_export_pdf() with inject_assets dropping logo should not error"
  )

  expect_true(file.exists(output_pdf), label = "PDF created with logo")
  info <- pdftools::pdf_info(output_pdf)
  expect_gte(info$pages, 1L)
})

test_that("Invalid logo_path surfaces a clear error from Typst", {
  skip_if_not_render_test()
  skip_if_no_pdf_render_deps()

  result <- .make_image_test_result()
  output_pdf <- withr::local_tempfile(fileext = ".pdf")

  # An explicit logo_path pointing to a path that does not resolve at
  # compile time SHALL fail loudly. Typst surfaces a file-not-found error
  # which bfh_compile_typst() captures and re-stops with diagnostic.
  expect_error(
    bfh_export_pdf(
      result, output_pdf,
      metadata = list(logo_path = "no/such/logo/file.png")
    ),
    regexp = "Quarto compilation failed|file not found|PDF compilation failed",
    info = "Typst should surface file-not-found for invalid logo_path"
  )
})
