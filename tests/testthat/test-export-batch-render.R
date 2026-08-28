# ============================================================================
# RENDER TESTS FOR BATCH PDF EXPORT
#
# End-to-end smoke tests through the real Quarto/Typst pipeline. Gated by
# BFHCHARTS_TEST_RENDER=true plus Quarto availability, mirroring the other
# render suites. Fonts: on machines without Mari, pass a system font path
# (BFHCHARTS_SMOKE_FONT_PATH, default /usr/share/fonts) so the template's
# fallback chain resolves to Roboto/DejaVu, matching .github/workflows/
# pdf-smoke.yaml.
# ============================================================================

smoke_font_path <- function() {
  path <- Sys.getenv("BFHCHARTS_SMOKE_FONT_PATH", "/usr/share/fonts")
  if (dir.exists(path)) path else NULL
}

test_that("batch export compiles staged pages into one multi-page PDF", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")

  cache <- withr::local_tempdir()
  x <- fixture_test_chart(title = "Batch smoke")
  for (id in c("side-a", "side-b", "side-c")) {
    bfh_stage_pdf_page(x, cache, id = id)
  }
  out <- file.path(withr::local_tempdir(), "batch.pdf")

  bfh_export_batch_pdf(cache, out, font_path = smoke_font_path())

  expect_true(file.exists(out))
  info <- pdftools::pdf_info(out)
  expect_identical(info$pages, 3L)
})

test_that("one-page batch output matches bfh_export_pdf for the same result", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")

  x <- fixture_test_chart(title = "Ekvivalens")
  meta <- list(department = "Afdeling E")
  fonts <- smoke_font_path()
  tmp <- withr::local_tempdir()

  single_pdf <- file.path(tmp, "single.pdf")
  bfh_export_pdf(x, single_pdf, metadata = meta, font_path = fonts)

  cache <- file.path(tmp, "cache")
  dir.create(cache)
  bfh_stage_pdf_page(x, cache, id = "ekviv", metadata = meta)
  batch_pdf <- file.path(tmp, "batch.pdf")
  bfh_export_batch_pdf(cache, batch_pdf, font_path = fonts)

  single_info <- pdftools::pdf_info(single_pdf)
  batch_info <- pdftools::pdf_info(batch_pdf)
  expect_identical(batch_info$pages, single_info$pages)

  single_size <- pdftools::pdf_pagesize(single_pdf)
  batch_size <- pdftools::pdf_pagesize(batch_pdf)
  expect_equal(batch_size$width, single_size$width, tolerance = 0.01)
  expect_equal(batch_size$height, single_size$height, tolerance = 0.01)

  # Text content identical modulo whitespace layout differences
  norm <- function(pdf) gsub("[[:space:]]+", " ", trimws(pdftools::pdf_text(pdf)))
  expect_identical(norm(batch_pdf), norm(single_pdf))
})

test_that("batch PDF embeds each font face at most once", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")

  cache <- withr::local_tempdir()
  x <- fixture_test_chart(title = "Fontsubset")
  for (id in sprintf("side-%d", 1:4)) {
    bfh_stage_pdf_page(x, cache, id = id)
  }
  out <- file.path(withr::local_tempdir(), "fonts.pdf")

  bfh_export_batch_pdf(cache, out, font_path = smoke_font_path())

  fonts <- pdftools::pdf_fonts(out)
  # Subset prefixes (ABCDEF+Name) would hide duplicates of the same face;
  # strip them before counting.
  base_names <- sub("^[A-Z]{6}\\+", "", fonts$name)
  expect_identical(anyDuplicated(base_names), 0L)
})

test_that("chunked batch bounds font subsets by chunk count", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_if_not_installed("pdftools")
  skip_if_not_installed("qpdf")

  cache <- withr::local_tempdir()
  x <- fixture_test_chart(title = "Chunket")
  for (id in sprintf("side-%d", 1:4)) {
    bfh_stage_pdf_page(x, cache, id = id)
  }
  out <- file.path(withr::local_tempdir(), "chunked.pdf")

  bfh_export_batch_pdf(cache, out,
    pages_per_chunk = 2, font_path = smoke_font_path()
  )

  expect_identical(pdftools::pdf_info(out)$pages, 4L)
  fonts <- pdftools::pdf_fonts(out)
  base_names <- sub("^[A-Z]{6}\\+", "", fonts$name)
  # 2 chunks -> each face embedded at most twice
  expect_true(all(table(base_names) <= 2L))
})
