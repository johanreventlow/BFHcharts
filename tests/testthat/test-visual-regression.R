# ============================================================================
# VISUAL REGRESSION TESTS (vdiffr)
# ============================================================================
#
# Golden images for kanoniske chart-konfigurationer. Beskytter mod utilsigtede
# visuelle regressioner i theme, layer-ordering, farve-mapping og label-
# placering som strukturelle assertions ikke fanger.
#
# HVORDAN:
#   - Hver test kalder vdiffr::expect_doppelganger("navn", plot)
#   - Første lokale kørsel genererer snapshot i tests/testthat/_snaps/visual-regression/
#   - Efterfølgende kørsler sammenligner plot mod snapshot
#
# FONT-AFHÆNGIGHED:
#   - BFHtheme bruger proprietære Mari-fonts
#   - På CI/miljøer uden Mari: tests skippes via skip_if_no_mari_font() per test
#   - Visuel regression fanges kun på udviklermaskiner med Mari installeret
#
# RE-BASELINE:
#   - Ved bevidst visuel ændring: kopier .new.svg over .svg eller brug
#     `testthat::snapshot_accept("visual-regression")` fra package-root
#   - Commit med begrundelse i commit-beskeden
#
# Reference: openspec/changes/strengthen-test-infrastructure (Fase 2 task 7)
# Spec: test-infrastructure, "Plot rendering SHALL have visual regression protection"

# vdiffr kan være fraværende — hop over hele filen
skip_if_not_installed("vdiffr")

# ============================================================================
# GOLDEN IMAGES pr. canonical chart-type
# ============================================================================

test_that("vdiffr: run-chart (basic)", {
  skip_if_no_mari_font()
  data <- fixture_deterministic_chart_data()
  result <- bfh_qic(
    data,
    x = month,
    y = infections,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Run Chart Reference"
  )
  vdiffr::expect_doppelganger("run-chart-basic", result$plot)
})

test_that("vdiffr: i-chart med UCL/LCL", {
  skip_if_no_mari_font()
  data <- fixture_deterministic_chart_data()
  result <- bfh_qic(
    data,
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "I-Chart Reference"
  )
  vdiffr::expect_doppelganger("i-chart-with-limits", result$plot)
})

test_that("vdiffr: p-chart med variabel denominator", {
  skip_if_no_mari_font()
  # Deterministisk p-chart data
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    events = c(5, 8, 12, 10, 15, 11, 9, 14, 13, 16, 12, 10),
    total = c(100, 120, 150, 110, 180, 130, 115, 160, 145, 170, 135, 125)
  )

  result <- bfh_qic(
    data,
    x = month,
    y = events,
    n = total,
    chart_type = "p",
    y_axis_unit = "percent",
    chart_title = "P-Chart Reference"
  )
  vdiffr::expect_doppelganger("p-chart-variable-limits", result$plot)
})

test_that("vdiffr: u-chart", {
  skip_if_no_mari_font()
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    events = c(3, 5, 8, 4, 7, 6, 5, 9, 7, 8, 6, 5),
    exposure = c(50, 60, 80, 55, 75, 65, 58, 90, 72, 85, 68, 62)
  )

  result <- bfh_qic(
    data,
    x = month,
    y = events,
    n = exposure,
    chart_type = "u",
    y_axis_unit = "count",
    chart_title = "U-Chart Reference"
  )
  vdiffr::expect_doppelganger("u-chart-basic", result$plot)
})

test_that("vdiffr: c-chart", {
  skip_if_no_mari_font()
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    count = c(3, 7, 5, 5, 5, 5, 6, 4, 5, 6, 4, 5)
  )

  result <- bfh_qic(
    data,
    x = month,
    y = count,
    chart_type = "c",
    y_axis_unit = "count",
    chart_title = "C-Chart Reference"
  )
  vdiffr::expect_doppelganger("c-chart-basic", result$plot)
})

# ============================================================================
# MULTI-PHASE
# ============================================================================

test_that("vdiffr: multi-phase i-chart", {
  skip_if_no_mari_font()
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(
      rep(c(19, 20, 21), 4),
      rep(c(14, 15, 16), 4)
    )
  )

  result <- bfh_qic(
    data,
    x = month,
    y = value,
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Multi-Phase Reference",
    part = 12
  )
  vdiffr::expect_doppelganger("i-chart-multi-phase", result$plot)
})

# ============================================================================
# TARGET LINE
# ============================================================================

test_that("vdiffr: chart med target line", {
  skip_if_no_mari_font()
  data <- fixture_deterministic_chart_data()
  result <- bfh_qic(
    data,
    x = month,
    y = infections,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Chart with Target",
    target_value = 15,
    target_text = "Target: 15"
  )
  vdiffr::expect_doppelganger("run-chart-with-target", result$plot)
})

# ============================================================================
# NOTES / ANNOTATIONS
# ============================================================================

test_that("vdiffr: p-chart med notes-annotationer", {
  skip_if_no_mari_font()
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    events = c(5, 8, 12, 10, 15, 11, 9, 14, 13, 16, 12, 10),
    total = c(100, 120, 150, 110, 180, 130, 115, 160, 145, 170, 135, 125)
  )

  # bfh_qic evaluerer notes eagerly (ikke NSE), så vektoren skal passes direkte
  notes_vec <- c(
    NA, NA, "Intervention", NA, NA, NA,
    "Audit", NA, NA, NA, NA, "Follow-up"
  )

  result <- bfh_qic(
    data,
    x = month,
    y = events,
    n = total,
    notes = notes_vec,
    chart_type = "p",
    y_axis_unit = "percent",
    chart_title = "P-Chart with Notes"
  )
  vdiffr::expect_doppelganger("p-chart-with-notes", result$plot)
})

test_that("vdiffr: chart med custom labels", {
  skip_if_no_mari_font()
  data <- fixture_deterministic_chart_data()

  result <- bfh_qic(
    data,
    x = month,
    y = infections,
    chart_type = "run",
    y_axis_unit = "count",
    chart_title = "Chart with Custom Labels",
    xlab = "Måned",
    ylab = "Infektioner pr. måned"
  )
  vdiffr::expect_doppelganger("run-chart-with-custom-labels", result$plot)
})
