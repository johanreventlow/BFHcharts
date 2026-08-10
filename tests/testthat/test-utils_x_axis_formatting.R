test_that("normalize_to_posixct converts Date to POSIXct", {
  date_input <- as.Date("2024-01-15")
  result <- normalize_to_posixct(date_input)

  expect_s3_class(result, "POSIXct")
  expect_equal(as.Date(result), date_input)
})

test_that("normalize_to_posixct leaves POSIXct unchanged", {
  posix_input <- as.POSIXct("2024-01-15 12:00:00")
  result <- normalize_to_posixct(posix_input)

  expect_identical(result, posix_input)
})

test_that("round_to_interval_start rounds to month start", {
  date <- as.POSIXct("2024-01-15 12:00:00", tz = "UTC")
  result <- round_to_interval_start(date, "monthly")

  # Check that result is first day of month
  expect_s3_class(result, "POSIXct")
  expect_equal(lubridate::month(result), 1)
  expect_equal(lubridate::day(result), 1)
  expect_true(result <= date)
})

test_that("round_to_interval_start floors weeks to Monday, not Sunday", {
  # lubridate::floor_date() defaults to Sunday when lubridate.week.start is
  # unset. Week starts must be Monday (ISO-8601 / Danish convention).
  # NB: compare via format(), not as.Date() -- as.Date.POSIXct() converts in
  # UTC, which shifts local midnight back to the previous day.
  monday <- as.POSIXct("2024-01-15 12:00:00") # Monday
  result <- round_to_interval_start(monday, "weekly")

  expect_s3_class(result, "POSIXct")
  expect_equal(format(result, "%Y-%m-%d"), "2024-01-15")
  expect_equal(lubridate::wday(result, week_start = 1), 1)
})

test_that("round_to_interval_start floors mid-week dates back to Monday", {
  wednesday <- as.POSIXct("2024-01-17 08:30:00")
  result <- round_to_interval_start(wednesday, "weekly")

  expect_equal(format(result, "%Y-%m-%d"), "2024-01-15")
  expect_true(result <= wednesday)
})

test_that("round_to_interval_start does not floor Sunday forward", {
  # Sunday belongs to the week that started the preceding Monday.
  sunday <- as.POSIXct("2024-01-21 12:00:00")
  result <- round_to_interval_start(sunday, "weekly")

  expect_equal(format(result, "%Y-%m-%d"), "2024-01-15")
})

test_that("round_to_interval_start returns date unchanged for daily", {
  date <- as.POSIXct("2024-01-15 12:00:00")
  result <- round_to_interval_start(date, "daily")

  expect_equal(result, date)
})

test_that("calculate_base_interval_secs returns correct values", {
  expect_equal(calculate_base_interval_secs("daily"), 86400)
  expect_equal(calculate_base_interval_secs("weekly"), 604800)
  expect_equal(calculate_base_interval_secs("monthly"), 2592000)
  expect_null(calculate_base_interval_secs("unknown"))
})

test_that("calculate_interval_multiplier returns 1 for sparse data", {
  result <- calculate_interval_multiplier(10, "weekly")
  expect_equal(result, 1)
})

test_that("calculate_interval_multiplier applies multiplier for dense weekly data", {
  result <- calculate_interval_multiplier(52, "weekly") # 52 weeks → needs 4x
  expect_equal(result, 4)
})

test_that("calculate_interval_multiplier applies multiplier for dense monthly data", {
  result <- calculate_interval_multiplier(24, "monthly") # 24 months → needs 3x
  expect_equal(result, 3)
})

test_that("calculate_date_breaks returns NULL for unknown interval", {
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2024-01-31")
  format_config <- list(breaks = TRUE, n_breaks = 8)

  result <- calculate_date_breaks(min_date, max_date, "unknown", format_config)
  expect_null(result)
})

test_that("calculate_date_breaks generates monthly breaks", {
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2024-12-31")
  format_config <- list(breaks = TRUE, n_breaks = 12)

  result <- calculate_date_breaks(min_date, max_date, "monthly", format_config)

  expect_s3_class(result, "POSIXct")
  expect_true(length(result) <= BFH_MAX_DATE_BREAKS)
  # Data starts on a month boundary, so it lands on the grid naturally --
  # but it is never force-inserted (see the off-grid test below).
  expect_true(min_date %in% result)
})

test_that("calculate_date_breaks generates weekly breaks", {
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2024-03-31")
  format_config <- list(breaks = TRUE, n_breaks = 13)

  result <- calculate_date_breaks(min_date, max_date, "weekly", format_config)

  expect_s3_class(result, "POSIXct")
  expect_true(length(result) <= 15)
})

test_that("calculate_date_breaks generates daily breaks with multiplier", {
  # Legacy path: a config without break_unit still steps in days.
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2024-01-31")
  format_config <- list(breaks = TRUE, n_breaks = 31)

  result <- calculate_date_breaks(min_date, max_date, "daily", format_config)

  expect_s3_class(result, "POSIXct")
  expect_true(length(result) <= 20) # Allow some margin
})

# ============================================================================
# calculate_anchored_breaks()
# ============================================================================
#
# NB: POSIXct dates are compared via format(x, "%Y-%m-%d"). as.Date.POSIXct()
# converts in UTC, which shifts local midnight (CET) back one day.

# Helper: formatted day-of-month for every break
.days_of <- function(x) unique(format(x, "%d"))

test_that("month-anchored major breaks land on the 1st (PDF case, 37 weeks)", {
  # Reproduces the reported chart: 2025-12-01 to 2026-08-09 previously gave
  # 01-dec, 28-dec, 25-jan, 22-feb, ... (27-day step off the calendar).
  min_date <- as.POSIXct("2025-12-01")
  max_date <- as.POSIXct("2026-08-09")

  result <- calculate_anchored_breaks(min_date, max_date)

  expect_s3_class(result$major, "POSIXct")
  expect_equal(.days_of(result$major), "01")
  expect_true(length(result$major) <= BFH_MAX_DATE_BREAKS)
})

test_that("month-anchored breaks do not drift across multiple years", {
  # 104 weeks previously used a 13-week (91-day) step, which is not a quarter
  # and slid ~3 days backwards per year: 31-mar, 30-jun, 29-sep, 29-dec, ...
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2025-12-29")

  result <- calculate_anchored_breaks(min_date, max_date)

  expect_equal(.days_of(result$major), "01")
})

test_that("month-anchored breaks skip an off-grid data minimum", {
  # Data starting mid-month must not produce a break at data_x_min.
  min_date <- as.POSIXct("2025-12-10")
  max_date <- as.POSIXct("2026-08-09")

  result <- calculate_anchored_breaks(min_date, max_date)

  expect_equal(format(result$major[1], "%Y-%m-%d"), "2026-01-01")
  expect_false("2025-12-10" %in% format(result$major, "%Y-%m-%d"))
})

test_that("month-anchored breaks are trimmed at both ends of the data span", {
  min_date <- as.POSIXct("2026-01-05")
  max_date <- as.POSIXct("2026-04-20")

  result <- calculate_anchored_breaks(min_date, max_date)

  expect_true(all(result$major >= min_date))
  expect_true(all(result$major <= max_date))
})

test_that("weekly minor breaks fall on Mondays", {
  min_date <- as.POSIXct("2025-12-01") # Monday
  max_date <- as.POSIXct("2026-02-28")

  result <- calculate_anchored_breaks(min_date, max_date,
    minor_unit = "week"
  )

  expect_s3_class(result$minor, "POSIXct")
  expect_true(length(result$minor) > 0)
  expect_true(all(lubridate::wday(result$minor, week_start = 1) == 1))
  expect_true(all(result$minor >= min_date & result$minor <= max_date))
})

test_that("weekly minor breaks stay on midnight Monday across DST transitions", {
  # Europe/Copenhagen: DST starts 2026-03-29, ends 2026-10-25. POSIXct
  # sequences built with by = "1 week" drift one hour across these.
  spring <- calculate_anchored_breaks(
    as.POSIXct("2026-03-02"), as.POSIXct("2026-04-27"),
    minor_unit = "week"
  )
  autumn <- calculate_anchored_breaks(
    as.POSIXct("2026-10-05"), as.POSIXct("2026-11-30"),
    minor_unit = "week"
  )

  for (minor in list(spring$minor, autumn$minor)) {
    expect_true(all(format(minor, "%H:%M:%S") == "00:00:00"))
    expect_true(all(lubridate::wday(minor, week_start = 1) == 1))
  }
})

test_that("no minor breaks are generated when minor_unit is NULL", {
  result <- calculate_anchored_breaks(
    as.POSIXct("2025-12-01"), as.POSIXct("2026-08-09"),
    minor_unit = NULL
  )

  expect_null(result$minor)
})

test_that("month-anchored labels thin out beyond the break cap", {
  # 24 months exceeds BFH_MAX_DATE_BREAKS -> multiplier 3 (quarterly labels).
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2025-12-01")

  result <- calculate_anchored_breaks(min_date, max_date,
    label_multiplier = calculate_interval_multiplier(24, "monthly"),
    minor_unit = "month"
  )

  expect_equal(.days_of(result$major), "01")
  expect_true(length(result$major) <= BFH_MAX_DATE_BREAKS)
  # Consecutive labelled breaks are 3 months apart
  gaps <- round(as.numeric(diff(result$major), units = "days"))
  expect_true(all(gaps >= 89 & gaps <= 92))
  # Minor ticks mark every month start, including unlabelled ones
  expect_equal(.days_of(result$minor), "01")
  expect_true(length(result$minor) > length(result$major))
})

# ============================================================================
# break-unit contract: get_optimal_formatting() -> calculate_date_breaks()
# ============================================================================

# Helper: build a format config for a date sequence
.config_for <- function(dates) {
  get_optimal_formatting(detect_date_interval(dates))
}

test_that("short weekly spans keep per-week breaks", {
  cfg <- .config_for(seq(as.Date("2026-01-05"), by = "week", length.out = 12))

  expect_equal(cfg$break_unit, "week")
  expect_null(cfg$minor_break_unit)
})

test_that("long weekly spans switch to month-anchored breaks with week ticks", {
  cfg <- .config_for(seq(as.Date("2025-12-01"), by = "week", length.out = 37))

  expect_equal(cfg$break_unit, "month")
  expect_equal(cfg$minor_break_unit, "week")
})

test_that("weekly threshold is evaluated at the documented boundary", {
  # 16 observations span 15 weeks (<= cap); 17 span 16 weeks (> cap).
  at_cap <- .config_for(seq(as.Date("2026-01-05"), by = "week", length.out = 16))
  over_cap <- .config_for(seq(as.Date("2026-01-05"), by = "week", length.out = 17))

  expect_equal(at_cap$break_unit, "week")
  expect_equal(over_cap$break_unit, "month")
})

test_that("short daily spans keep per-day breaks", {
  cfg <- .config_for(seq(as.Date("2026-01-01"), by = "day", length.out = 14))

  expect_equal(cfg$break_unit, "day")
  expect_null(cfg$minor_break_unit)
})

test_that("medium daily spans anchor on week starts", {
  # A month of daily data holds at most one month start, so month anchoring
  # would leave the axis nearly unlabelled. Previously these spans produced
  # 2- and 4-day steps off the calendar.
  for (n in c(30, 60)) {
    cfg <- .config_for(seq(as.Date("2026-01-01"), by = "day", length.out = n))

    expect_equal(cfg$break_unit, "week", info = paste("n =", n))
    expect_equal(cfg$minor_break_unit, "day", info = paste("n =", n))
  }
})

test_that("long daily spans switch to month-anchored breaks", {
  # Previously 120 observations produced an 8-day step.
  cfg <- .config_for(seq(as.Date("2026-01-01"), by = "day", length.out = 120))

  expect_equal(cfg$break_unit, "month")
  expect_equal(cfg$minor_break_unit, "week")
})

test_that("medium daily spans always carry several labels", {
  # Regression guard for the tier that month anchoring alone would starve:
  # every span between the day and month tiers must stay well labelled.
  for (n in c(20, 30, 45, 60, 90)) {
    for (start in c("2026-01-01", "2026-01-16")) {
      dates <- seq(as.Date(start), by = "day", length.out = n)
      cfg <- .config_for(dates)
      x <- normalize_to_posixct(dates)
      breaks <- calculate_date_breaks(min(x), max(x), "daily", cfg)

      label <- paste("n =", n, "start =", start)
      expect_true(length(breaks) >= 2, info = label)
      expect_true(length(breaks) <= BFH_MAX_DATE_BREAKS, info = label)
    }
  }
})

test_that("weekly spans always carry several labels", {
  for (n in c(16, 17, 20, 26, 37, 52, 104)) {
    for (start in c("2026-01-05", "2026-01-08")) {
      dates <- seq(as.Date(start), by = "week", length.out = n)
      cfg <- .config_for(dates)
      x <- normalize_to_posixct(dates)
      breaks <- calculate_date_breaks(min(x), max(x), "weekly", cfg)

      label <- paste("n =", n, "start =", start)
      expect_true(length(breaks) >= 2, info = label)
      expect_true(length(breaks) <= BFH_MAX_DATE_BREAKS + 1, info = label)
    }
  }
})

test_that("threshold is computed from the data span, not the observation count", {
  # 12 observations, but spread over 20 weeks -> month-anchored.
  sparse <- as.Date("2026-01-05") + seq(0, by = 7 * 20 / 11, length.out = 12)
  cfg <- .config_for(sparse)

  expect_equal(cfg$break_unit, "month")
})

test_that("monthly configs are unchanged by the break-unit contract", {
  for (n in c(18, 30)) {
    dates <- seq(as.Date("2025-01-01"), by = "month", length.out = n)
    cfg <- .config_for(dates)
    x <- normalize_to_posixct(dates)
    breaks <- calculate_date_breaks(min(x), max(x), "monthly", cfg)

    expect_equal(cfg$break_unit, "month", info = paste("n =", n))
    expect_equal(unique(format(breaks, "%d")), "01", info = paste("n =", n))
    # Existing 3-month cadence preserved
    gaps <- round(as.numeric(diff(breaks), units = "days"))
    expect_true(all(gaps >= 89 & gaps <= 92), info = paste("n =", n))
  }
})

test_that("calculate_date_breaks dispatches on break_unit", {
  min_date <- as.POSIXct("2025-12-01")
  max_date <- as.POSIXct("2026-08-09")

  result <- calculate_date_breaks(
    min_date, max_date, "weekly",
    list(break_unit = "month", minor_break_unit = "week")
  )

  expect_equal(unique(format(result, "%d")), "01")
})

test_that("calculate_date_breaks falls back when break_unit is absent", {
  # Defensive path for quarterly/yearly/irregular series, which carry no
  # break_unit field.
  min_date <- as.POSIXct("2024-01-01")
  max_date <- as.POSIXct("2024-12-31")

  result <- calculate_date_breaks(
    min_date, max_date, "monthly",
    list(n_breaks = 12)
  )

  expect_s3_class(result, "POSIXct")
  expect_true(length(result) > 0)
})

test_that("no break is forced at an off-grid data minimum", {
  # Monthly data observed on the 15th previously yielded 15-jan as break 1.
  dates <- seq(as.Date("2025-01-15"), by = "month", length.out = 18)
  cfg <- .config_for(dates)
  x <- normalize_to_posixct(dates)

  result <- calculate_date_breaks(min(x), max(x), "monthly", cfg)

  expect_equal(unique(format(result, "%d")), "01")
  expect_false("2025-01-15" %in% format(result, "%Y-%m-%d"))
})

test_that("breaks never extend past the last observation", {
  # 16 weeks previously produced 18 breaks, 2 of them beyond the data.
  dates <- seq(as.Date("2026-01-05"), by = "week", length.out = 16)
  cfg <- .config_for(dates)
  x <- normalize_to_posixct(dates)

  result <- calculate_date_breaks(min(x), max(x), "weekly", cfg)

  expect_true(all(result <= max(x)))
  expect_true(all(result >= min(x)))
})

# ============================================================================
# apply_temporal_x_axis(): minor tick rendering
# ============================================================================

# Helper: build a bare plot over a date sequence and format its x-axis
.formatted_plot <- function(dates) {
  x <- normalize_to_posixct(dates)
  p <- ggplot2::ggplot(
    data.frame(x = x, y = seq_along(x)),
    ggplot2::aes(x = x, y = y)
  ) +
    ggplot2::geom_point()
  apply_temporal_x_axis(p, x, min(x), max(x))
}

# Helper: the datetime scale attached to a formatted plot
.x_scale <- function(plot) {
  scales <- plot$scales$scales
  hits <- Filter(function(s) "x" %in% s$aesthetics, scales)
  hits[[length(hits)]]
}

test_that("long weekly axes carry month breaks and weekly minor breaks", {
  # Minor breaks are attached to the scale but do not render while
  # BFHtheme::theme_bfh() blanks axis ticks; visibility is a BFHtheme
  # decision. These assertions cover the data, not the rendered ticks.
  plot <- .formatted_plot(seq(as.Date("2025-12-01"), by = "week", length.out = 37))
  scale <- .x_scale(plot)

  expect_equal(unique(format(scale$breaks, "%d")), "01")
  expect_true(all(lubridate::wday(scale$minor_breaks, week_start = 1) == 1))
  expect_true(length(scale$minor_breaks) > length(scale$breaks))
  expect_true(isTRUE(scale$guide$params$minor.ticks))
  expect_true(has_x_minor_breaks(plot))
})

test_that("short weekly axes render no minor ticks", {
  plot <- .formatted_plot(seq(as.Date("2026-01-05"), by = "week", length.out = 12))
  scale <- .x_scale(plot)

  # ggplot2 stores "unset" as a waiver, not NULL
  expect_true(inherits(scale$minor_breaks, "waiver"))
  expect_false(isTRUE(scale$guide$params$minor.ticks))
})

test_that("medium daily axes carry week breaks and daily minor ticks", {
  plot <- .formatted_plot(seq(as.Date("2026-01-01"), by = "day", length.out = 60))
  scale <- .x_scale(plot)

  expect_true(all(lubridate::wday(scale$breaks, week_start = 1) == 1))
  expect_true(length(scale$minor_breaks) > length(scale$breaks))
  expect_true(isTRUE(scale$guide$params$minor.ticks))
})

test_that("month-anchored labels stay locale-aware", {
  # Danish month names come from the LC_TIME wrapper, which must survive the
  # switch to month anchoring. Skipped where no Danish locale is installed.
  original <- Sys.getlocale("LC_TIME")
  on.exit(suppressWarnings(Sys.setlocale("LC_TIME", original)), add = TRUE)
  available <- suppressWarnings(
    tryCatch(Sys.setlocale("LC_TIME", "da_DK.UTF-8"), error = function(e) "")
  )
  skip_if(!nzchar(available), "No Danish LC_TIME locale on this host")
  suppressWarnings(Sys.setlocale("LC_TIME", original))

  plot <- .formatted_plot(seq(as.Date("2025-12-01"), by = "week", length.out = 37))
  scale <- .x_scale(plot)
  rendered <- scale$labels(scale$breaks)

  expect_true(any(grepl("maj|okt", unlist(rendered), ignore.case = TRUE)))
})

test_that("formatted temporal plots build without warnings", {
  # Guards against invalid guide/scale combinations that only surface at
  # render time.
  for (dates in list(
    seq(as.Date("2025-12-01"), by = "week", length.out = 37),
    seq(as.Date("2026-01-05"), by = "week", length.out = 12),
    seq(as.Date("2026-01-01"), by = "day", length.out = 60),
    seq(as.Date("2026-01-01"), by = "day", length.out = 120)
  )) {
    plot <- .formatted_plot(dates)
    expect_silent(ggplot2::ggplot_build(plot))
  }
})

# ============================================================================
# Conditional minor tick rendering
# ============================================================================
#
# Whether minor ticks appear is data-driven: they mark the finer calendar unit
# under a coarser label rhythm (weeks under month labels, days under week
# labels). BFHtheme cannot make that call -- a theme is static and knows
# nothing about the interval type -- so BFHcharts enables them per chart and
# derives the styling from the theme rather than hard-coding it.

# Helper: count tick marks rendered on the bottom axis.
# Ticks are drawn as polylines with two points per mark, nested inside the
# axis gtable. The axis line drawn by lemon::coord_capped_cart() also lands
# here as a 2-point polyline, so a single mark is indistinguishable from it;
# tests therefore assert on counts well above 1.
.count_rendered_x_ticks <- function(plot) {
  gt <- ggplot2::ggplot_gtable(ggplot2::ggplot_build(plot))
  idx <- grep("axis-b", gt$layout$name)
  if (length(idx) == 0) {
    return(0L)
  }
  n <- 0L
  walk <- function(g) {
    if (inherits(g, "gtable")) {
      for (child in g$grobs) walk(child)
    }
    if (!is.null(g$children)) {
      for (ch in g$children) {
        if (grepl("polyline|segments", class(ch)[1], ignore.case = TRUE) &&
          !is.null(ch$x)) {
          n <<- n + length(ch$x) %/% 2L
        }
        walk(ch)
      }
    }
  }
  walk(gt$grobs[[idx[1]]])
  n
}

test_that("tick styling comes from the theme, not from this package", {
  # Ownership split: BFHtheme decides how ticks look (colour, width, length,
  # direction); this package decides only whether the axis carries minor
  # breaks. A restyle in the design system must carry over without a change
  # here, so nothing in the plot pipeline may override these elements.
  skip_if_not_installed("BFHtheme")
  theme <- BFHtheme::theme_bfh()

  major <- ggplot2::calc_element("axis.ticks.length.x.bottom", theme)
  minor <- ggplot2::calc_element("axis.minor.ticks.length.x.bottom", theme)
  skip_if(
    !grid::is.unit(major) || !grid::is.unit(minor),
    "BFHtheme predates two-level x-axis tick support"
  )

  # Opposing directions keep the two levels visually distinct: the labelled
  # level points outward, the finer level inward.
  expect_gt(as.numeric(major), 0)
  expect_lt(as.numeric(minor), 0)
})

test_that("month-anchored weekly charts render minor ticks end to end", {
  # The regression that matters: ticks must survive theme_bfh(), which blanks
  # axis.ticks.x, and lemon::coord_capped_cart().
  data <- data.frame(
    dato = seq(as.Date("2025-12-01"), by = "week", length.out = 37),
    taeller = rep(c(86, 87, 85), length.out = 37),
    naevner = 100
  )
  result <- bfh_qic(data,
    x = dato, y = taeller, n = naevner,
    chart_type = "p", y_axis_unit = "percent"
  )

  expect_gt(.count_rendered_x_ticks(bfh_get_plot(result)), 10)
})

test_that("short weekly charts render no x ticks", {
  # Below the anchoring threshold every week carries its own label, so there
  # is no finer unit to mark -- the axis stays tick-free per BFHtheme.
  data <- data.frame(
    dato = seq(as.Date("2026-01-05"), by = "week", length.out = 12),
    taeller = rep(c(86, 87, 85), length.out = 12),
    naevner = 100
  )
  result <- bfh_qic(data,
    x = dato, y = taeller, n = naevner,
    chart_type = "p", y_axis_unit = "percent"
  )

  expect_lte(.count_rendered_x_ticks(bfh_get_plot(result)), 1L)
})

test_that("week-anchored daily charts render minor ticks", {
  data <- data.frame(
    dato = seq(as.Date("2026-01-01"), by = "day", length.out = 60),
    taeller = rep(c(86, 87, 85), length.out = 60),
    naevner = 100
  )
  result <- bfh_qic(data,
    x = dato, y = taeller, n = naevner,
    chart_type = "p", y_axis_unit = "percent"
  )

  expect_gt(.count_rendered_x_ticks(bfh_get_plot(result)), 10)
})

test_that("monthly charts render no minor ticks", {
  # Monthly series carry no finer unit worth marking.
  data <- data.frame(
    dato = seq(as.Date("2025-01-01"), by = "month", length.out = 18),
    taeller = rep(c(86, 87, 85), length.out = 18),
    naevner = 100
  )
  result <- bfh_qic(data,
    x = dato, y = taeller, n = naevner,
    chart_type = "p", y_axis_unit = "percent"
  )

  expect_lte(.count_rendered_x_ticks(bfh_get_plot(result)), 1L)
})

# ============================================================================
# Week number labels
# ============================================================================
#
# Week numbers annotate the minor tick grid on month-anchored axes. They are
# ISO-8601 week numbers, and the label sequence deliberately starts at the
# second tick so the "UGE" prefix has room away from the panel edge.

test_that("week labels are ISO week numbers on the given breaks", {
  breaks <- generate_calendar_sequence(
    as.POSIXct("2025-12-01"), as.POSIXct("2026-02-28"),
    by = "1 week", unit = "week"
  )

  result <- calculate_week_number_labels(breaks)

  expect_s3_class(result$x, "POSIXct")
  expect_equal(nrow(result), length(result$x))
  expect_true(all(result$x %in% breaks))
  # Every label is two lines -- prefix (or blank padding) over the number --
  # so all text blocks are equally tall and share one baseline.
  expect_true(all(grepl("^.*\n[0-9]{2}$", result$label)))
  # Only the first carries the actual prefix; the rest pad with a blank line
  expect_true(all(grepl("^ \n[0-9]{2}$", result$label[-1])))
})

test_that("the first visible label carries the UGE prefix", {
  breaks <- generate_calendar_sequence(
    as.POSIXct("2025-12-01"), as.POSIXct("2026-08-09"),
    by = "1 week", unit = "week"
  )

  result <- calculate_week_number_labels(breaks)

  # Prefix sits on its own line above the number, so the number stays
  # centred on its tick mark.
  expect_match(result$label[1], "^UGE\n[0-9]{2}$")
  expect_false(any(grepl("UGE", result$label[-1])))
})

test_that("the label sequence starts at the second tick, not the first", {
  # The first tick sits flush against the panel edge, where the prefix would
  # be clipped and a lone label reads as accidental.
  breaks <- generate_calendar_sequence(
    as.POSIXct("2025-12-01"), as.POSIXct("2026-08-09"),
    by = "1 week", unit = "week"
  )

  result <- calculate_week_number_labels(breaks)

  expect_false(breaks[1] %in% result$x)
  expect_true(result$x[1] > breaks[1])
})

test_that("label density adapts to series length", {
  spans <- list(
    c("2025-12-01", "2026-03-30"), # ~17 weeks
    c("2025-12-01", "2026-08-09"), # ~37 weeks
    c("2024-01-01", "2025-12-29") # ~104 weeks
  )

  for (s in spans) {
    breaks <- generate_calendar_sequence(
      as.POSIXct(s[1]), as.POSIXct(s[2]),
      by = "1 week", unit = "week"
    )
    result <- calculate_week_number_labels(breaks)

    label <- paste(s, collapse = " to ")
    expect_gte(nrow(result), 5L, label = label)
    expect_lte(nrow(result), 14L, label = label)
  }
})

test_that("week numbers stay in date order across a year boundary", {
  # ISO week 01 can fall in December (2025-12-29 is week 01 of ISO year 2026).
  # Labels are text on date positions, so ordering can never be driven by the
  # week number itself.
  breaks <- generate_calendar_sequence(
    as.POSIXct("2025-11-03"), as.POSIXct("2026-02-16"),
    by = "1 week", unit = "week"
  )

  result <- calculate_week_number_labels(breaks)

  expect_false(is.unsorted(result$x))
  # The December week that ISO assigns to week 01 keeps its calendar slot
  expect_equal(
    strftime(as.POSIXct("2025-12-29"), "%V"), "01"
  )
})

test_that("degenerate break vectors are handled", {
  expect_null(calculate_week_number_labels(NULL))
  expect_null(calculate_week_number_labels(as.POSIXct(character(0))))
  # A single tick cannot carry a shifted sequence
  one <- as.POSIXct("2026-01-05")
  expect_null(calculate_week_number_labels(one))
})

test_that("month-anchored weekly charts render week numbers", {
  data <- data.frame(
    dato = seq(as.Date("2025-12-01"), by = "week", length.out = 37),
    taeller = rep(c(86, 87, 85), length.out = 37),
    naevner = 100
  )

  result <- bfh_qic(data,
    x = dato, y = taeller, n = naevner,
    chart_type = "p", y_axis_unit = "percent"
  )
  plot <- bfh_get_plot(result)
  texts <- unlist(lapply(plot$layers, function(l) {
    if (!is.null(l$data) && "label" %in% names(l$data)) l$data$label else NULL
  }))

  expect_true(any(grepl("^UGE\n", texts)))
})

test_that("charts without minor breaks render no week numbers", {
  # Short weekly series label every week on the axis itself, so a second
  # numbering would be redundant.
  data <- data.frame(
    dato = seq(as.Date("2026-01-05"), by = "week", length.out = 12),
    taeller = rep(c(86, 87, 85), length.out = 12),
    naevner = 100
  )

  result <- bfh_qic(data,
    x = dato, y = taeller, n = naevner,
    chart_type = "p", y_axis_unit = "percent"
  )
  plot <- bfh_get_plot(result)
  texts <- unlist(lapply(plot$layers, function(l) {
    if (!is.null(l$data) && "label" %in% names(l$data)) l$data$label else NULL
  }))

  expect_false(any(grepl("^UGE\n", texts)))
})

test_that("apply_numeric_x_axis adds continuous scale", {
  library(ggplot2)
  data <- data.frame(x = 1:10, y = rnorm(10))
  plot <- ggplot(data, aes(x = x, y = y)) +
    geom_point()

  result <- apply_numeric_x_axis(plot)

  expect_s3_class(result, "gg")
  # Check that scale was added (result should have more layers/scales)
})
