# Tests: Slice 9 INCLUDE -- CL-disclosure i prose
#
# Refs: openspec change restructure-spc-analysis-architecture, Slice 9

set.seed(909L)
TEST_DATA_S9 <- data.frame(
  date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
  value = round(rnorm(24L, 50, 5), 1)
)


test_that("Slice 9: cl_user_supplied caveat appendes til prose-output", {
  suppressWarnings({
    res <- bfh_qic(TEST_DATA_S9, x = date, y = value, chart_type = "i", cl = 50)
  })
  analysis <- bfh_analyse(res, metadata = list(analysis_date = as.Date("2026-05-18")))
  expect_equal(analysis$caveats$cl_source, "cl_user_supplied")

  text <- bfh_render_analysis(analysis, max_chars = 800L)
  expect_match(text, "midtlinje fastsat manuelt", ignore.case = TRUE)
  expect_match(text, "anhøj.signal", ignore.case = TRUE)
})


test_that("Slice 9: data_estimated cl_source udloser ingen caveat-prose", {
  res <- bfh_qic(TEST_DATA_S9, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(res, metadata = list(analysis_date = as.Date("2026-05-18")))
  expect_equal(analysis$features$cl_source, "data_estimated")
  expect_null(analysis$caveats$cl_source)

  text <- bfh_render_analysis(analysis)
  expect_no_match(text, "midtlinje fastsat manuelt", ignore.case = TRUE)
})


test_that("Slice 9: en.yaml fallback (manglende key) producerer ingen broken-output", {
  suppressWarnings({
    res <- bfh_qic(TEST_DATA_S9, x = date, y = value, chart_type = "i", cl = 50)
  })
  analysis <- bfh_analyse(res,
    metadata = list(analysis_date = as.Date("2026-05-18")),
    language = "en"
  )

  # Renderer SKAL ej fejle uanset en-yaml-completeness; output skal vaere
  # character af length 1 og inden for max_chars.
  text <- bfh_render_analysis(analysis, max_chars = 800L)
  expect_type(text, "character")
  expect_length(text, 1L)
})
