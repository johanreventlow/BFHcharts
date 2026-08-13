# ============================================================================
# FORMAT_CLOCK — KLOKKESLÆT-FORMAT (tt:mm fra sekunder siden midnat)
# ============================================================================
#
# Bruges til indikatorer hvor måleværdien er et tidspunkt på dagen (fx
# "median knivtidsstart"), ikke en varighed. Input er sekunder siden
# midnat (0-86399) — den enhed klokkeslæt-data typisk lagres i
# (period_to_seconds(hms(...))).

test_that("format_clock formaterer hele timer og minutter", {
  expect_equal(format_clock(0), "00:00")
  expect_equal(format_clock(29700), "08:15") # kl. 8:15
  expect_equal(format_clock(32400), "09:00")
  expect_equal(format_clock(45000), "12:30")
  expect_equal(format_clock(86340), "23:59")
})

test_that("format_clock runder til nærmeste hele minut", {
  expect_equal(format_clock(29729), "08:15") # 8:15:29 -> 08:15
  expect_equal(format_clock(29730), "08:16") # 8:15:30 -> 08:16 (round half up via round())
  expect_equal(format_clock(59.4), "00:01")
  expect_equal(format_clock(29), "00:00")
})

test_that("format_clock runder minut-overflow korrekt", {
  # 08:59:50 -> afrundes til 09:00, ikke 08:60
  expect_equal(format_clock(32390), "09:00")
  # 23:59:50 -> 24:00 (ingen wrap — værdier er samme-dags klokkeslæt)
  expect_equal(format_clock(86390), "24:00")
})

test_that("format_clock håndterer NA og tomt input", {
  expect_equal(format_clock(NA_real_), NA_character_)
  expect_equal(format_clock(numeric(0)), character(0))
  expect_equal(format_clock(c(29700, NA, 32400)), c("08:15", NA, "09:00"))
})

test_that("format_clock er vektoriseret", {
  expect_equal(
    format_clock(c(0, 21600, 43200, 64800)),
    c("00:00", "06:00", "12:00", "18:00")
  )
})

# ============================================================================
# CLOCK_BREAKS — KLOKKESLÆTS-NATURLIGE TICK-BREAKS (sekunder)
# ============================================================================

test_that("clock_breaks giver klokkeslæts-naturlige intervaller", {
  # Range 08:00-09:00 (3600 s span) -> ticks på hele/kvarte/halve timer
  b <- clock_breaks(c(28800, 32400))
  expect_true(length(b) >= 2)
  expect_true(all(b %% 60 == 0)) # aldrig skæve sekunder
  expect_true(all(diff(b) == diff(b)[1])) # ækvidistante
})

test_that("clock_breaks håndterer smal range (minutter)", {
  # Knivtid-scenarie: median svinger mellem 08:40 og 09:10
  b <- clock_breaks(c(31200, 33000))
  expect_true(length(b) >= 2)
  expect_true(all(b %% 60 == 0))
})

test_that("clock_breaks er defensiv over for ikke-finite input", {
  expect_equal(clock_breaks(c(NA, Inf, -Inf)), numeric(0))
  expect_equal(clock_breaks(numeric(0)), numeric(0))
  # Konstant range -> enkelt tick
  expect_equal(clock_breaks(c(29700, 29700)), 29700)
})

# ============================================================================
# INTEGRATION — format_y_value + apply_y_axis_formatting + Y_AXIS_UNITS
# ============================================================================

test_that("Y_AXIS_UNITS indeholder clock", {
  expect_true("clock" %in% Y_AXIS_UNITS)
})

test_that("format_y_value formaterer clock-værdier", {
  expect_equal(format_y_value(29700, "clock"), "08:15")
  expect_equal(format_y_value(NA_real_, "clock"), NA_character_)
})

test_that("apply_y_axis_formatting accepterer clock uden warning", {
  skip_if_not_installed("ggplot2")
  qic_data <- data.frame(
    x = seq.Date(as.Date("2026-01-05"), by = "week", length.out = 10),
    y = seq(31000, 33000, length.out = 10)
  )
  p <- ggplot2::ggplot(qic_data, ggplot2::aes(x = x, y = y)) +
    ggplot2::geom_line()
  expect_no_warning(apply_y_axis_formatting(p, "clock", qic_data))
})
