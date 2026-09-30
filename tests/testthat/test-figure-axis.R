test_that("bfh_apply_date_axis() giver datetime-skala og ugenumre som i SPC", {
  skip_if_not_installed("BFHtheme")
  uger <- as.POSIXct(seq(as.Date("2026-01-05"), by = "week", length.out = 30), tz = "UTC")
  p <- ggplot2::ggplot(data.frame(x = uger, y = seq_along(uger)), ggplot2::aes(x, y)) +
    ggplot2::geom_col()
  q <- bfh_apply_date_axis(p, uger)

  skala <- q$scales$get_scales("x")
  expect_true(inherits(skala, "ScaleContinuousDatetime"))
  tekst <- Filter(function(l) inherits(l$geom, "GeomText"), q$layers)
  expect_length(tekst, 1)
  # Foerste ugeetiket har praefikset paa egen linje
  expect_match(tekst[[1]]$data$label[1], "^UGE\\n[0-9]{2}$")

  # Date-input accepteres og konverteres
  expect_s3_class(bfh_apply_date_axis(p, as.Date(uger)), "ggplot")
})

test_that("bfh_apply_date_axis() afviser ugyldigt input", {
  p <- ggplot2::ggplot()
  expect_error(bfh_apply_date_axis("x", Sys.Date()), class = "bfhcharts_input_error")
  expect_error(bfh_apply_date_axis(p, 1:3), class = "bfhcharts_input_error")
  expect_error(bfh_apply_date_axis(p, as.Date(NA)), class = "bfhcharts_input_error")
})
