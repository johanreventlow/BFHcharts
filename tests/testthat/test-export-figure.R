# ============================================================================
# TESTS FOR FIGURE PDF EXPORT (add-figure-pdf-export)
#
# Spec: pdf-export + batch-pdf-export (full-width figure layout,
# bfh_export_figure_pdf(), bfh_stage_figure_page()). Tests der ikke kraever
# Quarto mocker Typst-compileren; render-gatede tests ligger i
# test-production-template-renders.R og test-export-batch-render.R.
# ============================================================================

# ---- 1. Forudsaetninger -----------------------------------------------------

test_that("PDF_IMAGE_WIDTH_FULL_MM udleder fuld kolonnebredde (297 - 26.4 - 6.6)", {
  expect_equal(BFHcharts:::PDF_IMAGE_WIDTH_FULL_MM, 297 - 26.4 - 6.6)
  expect_equal(BFHcharts:::PDF_IMAGE_WIDTH_FULL_MM, 264)
  # Haejde er uaendret: kun bredden aendres i fuld-bredde-tilstand
  expect_equal(BFHcharts:::PDF_IMAGE_HEIGHT_MM, 109)
})

test_that("bfh_merge_metadata() er uaendret og filtrerer spc_panel fra", {
  merged <- bfh_merge_metadata(list(spc_panel = FALSE), chart_title = "T")

  expect_setequal(
    names(merged),
    c(
      "hospital", "department", "title", "analysis", "details", "author",
      "date", "data_definition", "footer_content", "logo_path"
    )
  )
  expect_length(merged, 10L)
  expect_null(merged$spc_panel)
  expect_false("spc_panel" %in% names(merged))
})

# ---- 3. Parameter-builder ---------------------------------------------------

test_that("build_typst_page_params() emitterer spc_panel: false kun naar FALSE", {
  spc_stats <- list(runs_expected = 7, runs_actual = 5, is_run_chart = FALSE)
  base_md <- list(hospital = "H", title = "T")

  params_false <- BFHcharts:::build_typst_page_params(
    c(base_md, list(spc_panel = FALSE)), spc_stats
  )
  expect_match(params_false, "spc_panel: false", fixed = TRUE)

  # TRUE og NULL: ingen spc_panel-param, output byte-identisk med foer
  baseline <- BFHcharts:::build_typst_page_params(base_md, spc_stats)
  params_true <- BFHcharts:::build_typst_page_params(
    c(base_md, list(spc_panel = TRUE)), spc_stats
  )
  expect_false(grepl("spc_panel", baseline, fixed = TRUE))
  expect_identical(params_true, baseline)
})

test_that("build_typst_page_params() ignorerer ikke-logiske spc_panel-vaerdier", {
  for (bad in list("false", 0, NA, c(FALSE, FALSE))) {
    params <- BFHcharts:::build_typst_page_params(
      list(title = "T", spc_panel = bad), list()
    )
    expect_false(grepl("spc_panel", params, fixed = TRUE))
  }
})
