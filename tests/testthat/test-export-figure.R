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
