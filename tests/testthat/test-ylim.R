# Tests for ylim (y-axis display limits via coord_cartesian)
# validate_ylim() er ren logik (ingen fonts). Plot-niveau-tests kalder
# bfh_qic() men checker kun data/config -- ingen font-skip paakraevet.

# ============================================================================
# 1. validate_ylim() - ren input-validering (ingen fonts)
# ============================================================================

test_that("validate_ylim() returns NULL for NULL input", {
  expect_null(validate_ylim(NULL))
})

test_that("validate_ylim() passes a valid c(min, max) through", {
  expect_equal(validate_ylim(c(0, 1)), c(0, 1))
  expect_equal(validate_ylim(c(-5, 10)), c(-5, 10))
})

test_that("validate_ylim() allows NA per end (free limit)", {
  expect_equal(validate_ylim(c(0, NA)), c(0, NA))
  expect_equal(validate_ylim(c(NA, 100)), c(NA, 100))
})

test_that("validate_ylim() treats both-NA as no-op (NULL)", {
  expect_null(validate_ylim(c(NA, NA)))
  expect_null(validate_ylim(c(NA_real_, NA_real_)))
})

test_that("validate_ylim() warns and ignores when min >= max", {
  expect_warning(out <- validate_ylim(c(10, 0)), "min.*>=.*max")
  expect_null(out)
  expect_warning(out2 <- validate_ylim(c(5, 5)), "min.*>=.*max")
  expect_null(out2)
})

test_that("validate_ylim() rejects wrong length or non-numeric", {
  expect_error(validate_ylim(c(0, 1, 2)), "length 2")
  expect_error(validate_ylim(0), "length 2")
  expect_error(validate_ylim("0-1"), "numeric")
  expect_error(validate_ylim(list(0, 1)), "numeric")
})

# ============================================================================
# 2. spc_plot_config() carries ylim
# ============================================================================

test_that("spc_plot_config() stores ylim field (default NULL)", {
  cfg <- spc_plot_config(chart_type = "i", y_axis_unit = "count")
  expect_null(cfg$ylim)

  cfg2 <- spc_plot_config(chart_type = "i", y_axis_unit = "count", ylim = c(0, 1))
  expect_equal(cfg2$ylim, c(0, 1))
})

# ============================================================================
# 3. bfh_qic() applies coord_cartesian + does NOT drop data (font-gated)
# ============================================================================

make_ylim_test_data <- function() {
  data.frame(
    maaned = seq.Date(as.Date("2023-01-01"), by = "month", length.out = 12),
    vaerdi = c(10, 12, 11, 13, 10, 14, 11, 12, 10, 13, 11, 50)
  )
}

test_that("bfh_qic() with ylim sets coord_cartesian y-limits", {
  df <- make_ylim_test_data()

  res <- bfh_qic(df, x = maaned, y = vaerdi, chart_type = "i", ylim = c(0, 20))

  expect_equal(res$plot$coordinates$limits$y, c(0, 20))
})

test_that("bfh_qic() with ylim does NOT drop data points (zoom, not clip)", {
  df <- make_ylim_test_data()

  # Punkt #12 (vaerdi = 50) ligger uden for ylim c(0, 20).
  res_lim <- bfh_qic(df, x = maaned, y = vaerdi, chart_type = "i", ylim = c(0, 20))
  res_free <- bfh_qic(df, x = maaned, y = vaerdi, chart_type = "i")

  # qic_data + summary uaendret: coord_cartesian zoomer, dropper ikke.
  expect_equal(nrow(res_lim$qic_data), nrow(res_free$qic_data))
  expect_equal(res_lim$summary, res_free$summary)
})

test_that("bfh_qic() supports partial limit c(0, NA)", {
  df <- make_ylim_test_data()

  res <- bfh_qic(df, x = maaned, y = vaerdi, chart_type = "i", ylim = c(0, NA))

  expect_equal(res$plot$coordinates$limits$y, c(0, NA))
})

test_that("bfh_qic() without ylim leaves y-limits data-driven (NULL)", {
  df <- make_ylim_test_data()

  res <- bfh_qic(df, x = maaned, y = vaerdi, chart_type = "i")

  expect_null(res$plot$coordinates$limits$y)
})

test_that("percent p-chart plots on 0-1 proportion scale (ylim contract)", {
  # Coordinate-space-kontrakt: for percent-charts er data på 0-1-skalaen,
  # så ylim c(0, 1) svarer til 0%-100%. Downstream (biSPCharts) skal sende
  # proportion-værdier, ikke 0-100. Guarder antagelsen empirisk.
  set.seed(1)
  d <- data.frame(
    m = seq.Date(as.Date("2023-01-01"), by = "month", length.out = 12),
    events = c(5, 8, 6, 7, 9, 4, 6, 8, 5, 7, 6, 9),
    total = rep(100, 12)
  )
  qd <- bfh_qic(d,
    x = m, y = events, n = total, chart_type = "p",
    y_axis_unit = "percent", return.data = TRUE
  )
  # Andele 0.04-0.09, ikke 4-9 => 0-1-skala bekræftet.
  expect_true(all(qd$y <= 1, na.rm = TRUE))
  expect_true(max(qd$y, na.rm = TRUE) < 1)
})

test_that("bfh_qic() percent chart accepts ylim c(0, 1) for 0%-100%", {
  d <- data.frame(
    m = seq.Date(as.Date("2023-01-01"), by = "month", length.out = 12),
    events = c(5, 8, 6, 7, 9, 4, 6, 8, 5, 7, 6, 9),
    total = rep(100, 12)
  )
  res <- bfh_qic(d,
    x = m, y = events, n = total, chart_type = "p",
    y_axis_unit = "percent", ylim = c(0, 1)
  )
  expect_equal(res$plot$coordinates$limits$y, c(0, 1))
})

test_that("bfh_qic() warns and ignores ylim when min >= max", {
  df <- make_ylim_test_data()

  expect_warning(
    res <- bfh_qic(df, x = maaned, y = vaerdi, chart_type = "i", ylim = c(20, 0)),
    "min.*>=.*max"
  )
  expect_null(res$plot$coordinates$limits$y)
})

test_that("ylim placerer kommentarer inden for zoom-vinduet (ej fuld data-range)", {
  notes_vec <- rep(NA_character_, 12)
  notes_vec[3] <- "Intervention"
  notes_vec[8] <- "Ny protokol"
  df <- make_ylim_test_data()

  res <- bfh_qic(df,
    x = maaned, y = vaerdi, chart_type = "i",
    notes = notes_vec, ylim = c(0, 20)
  )
  b <- ggplot2::ggplot_build(res$plot)

  # Find kommentar-tekst-laget og bekraeft at dets y-positioner ligger inden
  # for zoom-vinduet [0, 20] -- uden ylim-bevidsthed ville placeringen score
  # mod data-range (~10-18) og kunne havne uden for det synlige vindue.
  comment_ys <- numeric(0)
  for (d in b$data) {
    if (all(c("label", "y") %in% names(d)) && nrow(d) > 0) {
      hit <- d$label %in% c("Intervention", "Ny protokol")
      if (any(hit)) comment_ys <- c(comment_ys, d$y[hit])
    }
  }
  expect_true(length(comment_ys) > 0)
  expect_true(all(comment_ys >= 0 & comment_ys <= 20))
})
