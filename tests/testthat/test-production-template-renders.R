# Production template smoke tests (ADR-001 Option A + change
# add-conditional-template-image).
#
# Validates that the packaged production template renders a valid PDF using
# only bundled/system assets. Tests are gated behind render-test env var
# and Quarto availability to keep default test runs fast.
#
# Previously these tests skipped when images/ was absent; now the template
# renders successfully without a logo (graceful degradation -- foreground
# logo slot stays empty when logo_path is NULL). See ADR-001 + change
# add-conditional-template-image for the closed gap.

# Helper: build a minimal bfh_qic result for smoke rendering
.make_smoke_result <- function() {
  data <- data.frame(
    x = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    y = c(5, 6, 4, 7, 5, 6, 5, 8, 4, 6, 5, 7, 6, 5, 4, 6, 5, 7, 6, 5),
    n = rep(100L, 20)
  )
  # bfh_qic() uses NSE for x/y/n (unquoted column names) and does not accept
  # `metadata` as a parameter -- chart title flows through `chart_title`,
  # PDF metadata is supplied to bfh_export_pdf() in the calling test.
  bfh_qic(data,
    x = x, y = y, n = n,
    chart_type = "p",
    chart_title = "Smoke test"
  )
}

test_that("production template renders valid PDF with bundled assets only", {
  skip_if_not_render_test()
  skip_if_no_pdf_render_deps()

  # Per change add-conditional-template-image: the template now renders
  # successfully without a hospital logo. The foreground logo slot remains
  # empty when logo_path is NULL/none. PDF still has calibrated header,
  # title, SPC table, etc.
  result <- .make_smoke_result()

  output_pdf <- withr::local_tempfile(fileext = ".pdf")
  expect_no_error(
    bfh_export_pdf(result, output_pdf),
    message = "bfh_export_pdf() with production template should not error"
  )

  expect_true(file.exists(output_pdf), label = "PDF file created")
  expect_gt(file.info(output_pdf)$size, 1000L, label = "PDF size > 1 KB")

  info <- pdftools::pdf_info(output_pdf)
  expect_true(is.list(info), label = "pdftools::pdf_info() parses output")
  expect_gte(info$pages, 1L, label = "PDF has at least 1 page")
})

test_that("production template renders with simulated inject_assets (Mari skipped if unavailable)", {
  skip_if_not_render_test()
  skip_if_no_pdf_render_deps()

  # No images/-skip needed: per change add-conditional-template-image the
  # template renders without a logo. inject_assets here exercises the
  # font-injection path; logo auto-detect would also fire if the callback
  # added an images/ directory (covered separately in
  # test-template-image-conditional.R).

  # Check whether Mari fonts exist (companion-supplied fonts)
  mari_present <- tryCatch(
    {
      if (requireNamespace("systemfonts", quietly = TRUE)) {
        fonts <- systemfonts::system_fonts()
        any(grepl("Mari", fonts$family, ignore.case = TRUE))
      } else {
        FALSE
      }
    },
    error = function(e) FALSE
  )

  if (!mari_present) {
    skip("Skipping Mari inject_assets test: Mari fonts not available on this system")
  }

  # Simulate inject_assets by copying Mari fonts into session staging area
  inject_mari <- function(stage_dir) {
    fonts_dest <- file.path(stage_dir, "bfh-template", "fonts")
    dir.create(fonts_dest, recursive = TRUE, showWarnings = FALSE)

    # Find Mari font files via systemfonts
    all_fonts <- systemfonts::system_fonts()
    mari_fonts <- all_fonts[grepl("Mari", all_fonts$family, ignore.case = TRUE), ]
    if (nrow(mari_fonts) > 0) {
      paths <- unique(mari_fonts$path)
      file.copy(paths, fonts_dest, overwrite = TRUE)
    }
    invisible(stage_dir)
  }

  result <- .make_smoke_result()
  output_pdf <- withr::local_tempfile(fileext = ".pdf")

  expect_no_error(
    bfh_export_pdf(result, output_pdf, inject_assets = inject_mari),
    message = "bfh_export_pdf() with Mari inject_assets should not error"
  )

  expect_true(file.exists(output_pdf))
  info <- pdftools::pdf_info(output_pdf)
  expect_gte(info$pages, 1L)
})
