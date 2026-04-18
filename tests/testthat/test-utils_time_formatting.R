# ============================================================================
# FORMAT_TIME_COMPOSITE — KOMPOSIT TIDSFORMAT
# ============================================================================

test_that("format_time_composite håndterer minutter", {
  expect_equal(format_time_composite(0), "0m")
  expect_equal(format_time_composite(1), "1m")
  expect_equal(format_time_composite(30), "30m")
  expect_equal(format_time_composite(45), "45m")
  expect_equal(format_time_composite(59), "59m")
})

test_that("format_time_composite håndterer timer og timer+minutter", {
  expect_equal(format_time_composite(60), "1t")
  expect_equal(format_time_composite(90), "1t 30m")
  expect_equal(format_time_composite(120), "2t")
  expect_equal(format_time_composite(125), "2t 5m")
  expect_equal(format_time_composite(720), "12t")
})

test_that("format_time_composite håndterer dage", {
  expect_equal(format_time_composite(1440), "1d")
  expect_equal(format_time_composite(2880), "2d")
  # Dage + timer (ingen minutter — max 2 komponenter)
  expect_equal(format_time_composite(3660), "2d 13t")
})

test_that("format_time_composite runder overflow korrekt", {
  # 59,7 min rundet til 60 -> 1t (ikke 60m)
  expect_equal(format_time_composite(59.7), "1t")
  # 60,4 min rundet til 60 -> 1t
  expect_equal(format_time_composite(60.4), "1t")
  # 1439,7 min rundet til 1440 -> 1d
  expect_equal(format_time_composite(1439.7), "1d")
  # 119,5 min rundet til 120 -> 2t
  expect_equal(format_time_composite(119.5), "2t")
})

test_that("format_time_composite håndterer sub-minut værdier", {
  # 0,25 min -> rundes til 0 -> "0m"
  expect_equal(format_time_composite(0.25), "0m")
  # 0,6 min -> rundes til 1 -> "1m"
  expect_equal(format_time_composite(0.6), "1m")
})

test_that("format_time_composite håndterer negative værdier", {
  expect_equal(format_time_composite(-30), "-30m")
  expect_equal(format_time_composite(-90), "-1t 30m")
  expect_equal(format_time_composite(-1440), "-1d")
})

test_that("format_time_composite håndterer NA og tomme vektorer", {
  expect_true(is.na(format_time_composite(NA)))
  expect_true(is.na(format_time_composite(NA_real_)))
  expect_equal(format_time_composite(numeric(0)), character(0))
})

test_that("format_time_composite er vektoriseret", {
  input <- c(0, 60, 90, NA, 1440)
  expected <- c("0m", "1t", "1t 30m", NA_character_, "1d")
  expect_equal(format_time_composite(input), expected)
})

test_that("format_time_composite: regression for 0,8541667 timer-bug (issue #138)", {
  # 0,8541667 timer = 51,25 minutter.
  # Bug: BFHcharts producerede "0,8541667 timer" på y-aksen.
  # Fix: skal producere "51m", ikke et 7-cifret kommatal.
  minutes_51 <- 0.8541667 * 60
  expect_equal(format_time_composite(minutes_51), "51m")
})

# ============================================================================
# TIME_BREAKS — TIDS-NATURLIGE TICK-BREAKS
# ============================================================================

test_that("time_breaks producerer runde minutter for små ranges", {
  # 0-120 min -> interval 30 giver 5 ticks (0, 30, 60, 90, 120)
  breaks <- time_breaks(c(0, 120))
  expect_equal(breaks, c(0, 30, 60, 90, 120))
})

test_that("time_breaks floor-snapper begge ender", {
  # 15-185 min: floor start til 0, floor end til 180 (30-min interval)
  breaks <- time_breaks(c(15, 185))
  expect_equal(breaks, c(0, 30, 60, 90, 120, 150, 180))
})

test_that("time_breaks vælger timer for medium ranges", {
  # 0-480 min (8 timer): bør vælge 120-min (2t) interval
  breaks <- time_breaks(c(0, 480))
  expect_equal(breaks, c(0, 120, 240, 360, 480))
})

test_that("time_breaks vælger største interval der giver >= target_n ticks", {
  # 0-1440 min (24 timer): flere kandidater giver >= 5 ticks;
  # største er 360 min (6 timer) -> 0, 360, 720, 1080, 1440 (5 ticks).
  breaks <- time_breaks(c(0, 1440))
  expect_gte(length(breaks), 5L)
  # Alle tick-værdier skal være multipla af chosen interval
  expect_true(all(breaks %% diff(breaks)[1] == 0))
})

test_that("time_breaks håndterer konstant range", {
  expect_equal(time_breaks(c(60, 60)), 60)
  expect_equal(time_breaks(c(0, 0)), 0)
})

test_that("time_breaks håndterer NA og ikke-finite værdier defensivt", {
  # ggplot2 kan passere Inf/-Inf under layout — filtrering påkrævet
  expect_equal(time_breaks(c(NA, NA)), numeric(0))
  expect_equal(time_breaks(numeric(0)), numeric(0))
  expect_equal(time_breaks(c(Inf, -Inf)), numeric(0))
  expect_equal(time_breaks(c(NaN, NA)), numeric(0))

  # Blandet input: finite værdier bevares
  breaks <- time_breaks(c(0, 120, Inf, NA))
  expect_equal(breaks, c(0, 30, 60, 90, 120))
})

test_that("time_breaks falder tilbage til data-bracketing for sub-unit range", {
  # 0,3-0,9 min: ingen kandidat giver >= 2 ticks; fallback til c(y_min, y_max)
  breaks <- time_breaks(c(0.3, 0.9))
  expect_equal(breaks, c(0.3, 0.9))
})

test_that("time_breaks respekterer target_n parameter", {
  # Med target_n = 10 bør algoritmen vælge et mindre interval for flere ticks
  breaks_5 <- time_breaks(c(0, 480), target_n = 5L)
  breaks_10 <- time_breaks(c(0, 480), target_n = 10L)
  expect_gte(length(breaks_10), length(breaks_5))
})

# ============================================================================
# INTEGRATION: apply_y_axis_formatting med time-enhed
# ============================================================================

test_that("apply_y_axis_formatting med time-enhed bruger komposit-format", {
  qic_data <- data.frame(x = 1:5, y = c(30, 60, 90, 120, 150))
  plot <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_point()

  result <- apply_y_axis_formatting(plot, "time", qic_data)
  expect_s3_class(result, "ggplot")

  built <- ggplot2::ggplot_build(result)
  y_labels <- built$layout$panel_params[[1]]$y$get_labels()
  y_labels_clean <- y_labels[!is.na(y_labels)]

  # Alle labels skal matche komposit-pattern: "30m", "1t", "1t 30m", "1d", "1d 4t"
  expect_true(all(
    grepl("^-?(\\d+d( \\d+t)?|\\d+t( \\d+m)?|\\d+m)$", y_labels_clean)
  ))
  # Ingen labels må indeholde "timer", "minutter" eller 7-cifrede decimaler
  expect_false(any(grepl("timer|minutter|dage", y_labels_clean)))
  expect_false(any(grepl("\\d+,\\d{3,}", y_labels_clean)))
})
