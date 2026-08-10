# ==============================================================================
# X-Axis Formatting Utilities
# ==============================================================================
#
# Modular functions for formatting x-axis in SPC charts.
# Extracted from apply_x_axis_formatting() to improve maintainability.
#
# Created: 2025-12-02
# ==============================================================================

# Map sprogkode til en ordnet liste af LC_TIME-locales.
# Forsoeger den foerste der virker; falder tilbage til "C" (engelsk POSIX)
# hvis ingen platform-locale er tilgaengelig.
.locales_for_language <- function(language) {
  switch(language,
    "en" = c("en_US.UTF-8", "en_US.utf8", "C.UTF-8", "C", "en_GB.UTF-8"),
    "da" = c("da_DK.UTF-8", "da_DK.utf8", "Danish_Denmark.utf8", "da_DK"),
    character(0)
  )
}

# Package-level cache: maps language -> resolved locale string (or NA if none
# worked). Avoids re-running the candidate search on every label evaluation.
# NA sentinel means "we tried and nothing worked" -- do not re-search.
.locale_cache <- new.env(parent = emptyenv())

# Resolve the best available LC_TIME locale for a language, caching the result.
# Returns the winning locale string, or NA_character_ if none is available.
.resolve_locale_for_language <- function(language, candidates) {
  if (exists(language, envir = .locale_cache)) {
    return(.locale_cache[[language]])
  }
  resolved <- NA_character_
  for (loc in candidates) {
    ok <- tryCatch(
      suppressWarnings({
        set <- Sys.setlocale("LC_TIME", loc)
        !identical(set, "")
      }),
      error = function(e) FALSE
    )
    if (isTRUE(ok)) {
      resolved <- loc
      break
    }
  }
  .locale_cache[[language]] <- resolved
  resolved
}

# Wrap en label-funktion saa den evaluerer med passende LC_TIME-locale.
# Bevarer original locale via on.exit-restore; fejl ved locale-set logges
# stilfaerdigt (ikke fatal) saa cross-platform robusthed bevares.
# Fix #461: locale candidate resolution is cached per language after the first
# call; subsequent calls skip the search loop and use the cached winner.
with_lc_time_labeler <- function(label_fn, language = "da") {
  if (!is.function(label_fn)) {
    return(label_fn)
  }
  candidates <- .locales_for_language(language)
  if (length(candidates) == 0) {
    return(label_fn)
  }
  function(x) {
    current <- Sys.getlocale("LC_TIME")
    on.exit(suppressWarnings(Sys.setlocale("LC_TIME", current)), add = TRUE)
    resolved <- .resolve_locale_for_language(language, candidates)
    if (!is.na(resolved)) {
      suppressWarnings(Sys.setlocale("LC_TIME", resolved))
    }
    label_fn(x)
  }
}

#' Normalize Date or POSIXct to POSIXct
#'
#' Converts Date objects to POSIXct while leaving POSIXct unchanged.
#'
#' @param x Date or POSIXct vector
#' @return POSIXct vector
#' @keywords internal
#' @noRd
normalize_to_posixct <- function(x) {
  if (inherits(x, "Date")) {
    return(as.POSIXct(x))
  }
  x
}

#' Round Date to Interval Start
#'
#' Floors a date to the beginning of its interval (day, week, or month).
#' Weeks start on Monday (ISO-8601), which lubridate does not do by default:
#' `floor_date(unit = "week")` uses Sunday unless `lubridate.week.start` is
#' set, so `week_start` is passed explicitly rather than relying on session
#' state.
#'
#' @param date POSIXct date
#' @param interval_type Character: "daily", "weekly", or "monthly"
#' @return POSIXct date rounded to interval start
#' @keywords internal
#' @noRd
round_to_interval_start <- function(date, interval_type) {
  if (interval_type == "monthly") {
    lubridate::floor_date(date, unit = "month")
  } else if (interval_type == "weekly") {
    lubridate::floor_date(date, unit = "week", week_start = 1)
  } else {
    date # daily or unknown \u2192 no rounding
  }
}

#' Calculate Base Interval in Seconds
#'
#' Returns the base interval duration in seconds for a given interval type.
#'
#' @param interval_type Character: "daily", "weekly", or "monthly"
#' @return Numeric seconds, or NULL if interval type unknown
#' @keywords internal
#' @noRd
calculate_base_interval_secs <- function(interval_type) {
  switch(interval_type,
    "daily" = 24 * 60 * 60, # 86400 seconds
    "weekly" = 7 * 24 * 60 * 60, # 604800 seconds
    "monthly" = 30 * 24 * 60 * 60, # 2592000 seconds (approximate)
    NULL
  )
}

#' Maximum Date Breaks on a Temporal X-Axis
#'
#' Upper bound on labelled breaks for temporal axes. Serves two purposes:
#' (1) selects the interval multiplier in [calculate_interval_multiplier()],
#' and (2) triggers the switch to calendar-anchored breaks for daily/weekly
#' series in `get_optimal_formatting()`. Exceeding this count means labels
#' would need thinning, which is precisely when off-calendar break positions
#' start to appear.
#'
#' @keywords internal
#' @noRd
BFH_MAX_DATE_BREAKS <- 15L

#' Calculate Interval Multiplier for Dense Data
#'
#' Determines the multiplier to apply to base interval when there are more
#' than [BFH_MAX_DATE_BREAKS] potential breaks on the axis.
#'
#' @param potential_breaks Numeric: number of breaks without multiplier
#' @param interval_type Character: "daily", "weekly", or "monthly"
#' @return Numeric multiplier (1, 2, 3, 4, 6, 8, 12, or 13)
#' @keywords internal
#' @noRd
calculate_interval_multiplier <- function(potential_breaks, interval_type) {
  if (potential_breaks <= BFH_MAX_DATE_BREAKS) {
    return(1) # No multiplier needed
  }

  # Define multiplier candidates per interval type
  multipliers <- switch(interval_type,
    "weekly" = c(2, 4, 13),
    "monthly" = c(3, 6, 12),
    c(2, 4, 8) # daily or fallback
  )

  # Find smallest multiplier that reduces breaks to <= BFH_MAX_DATE_BREAKS
  for (m in multipliers) {
    if (potential_breaks / m <= BFH_MAX_DATE_BREAKS) {
      return(m)
    }
  }

  # If all multipliers still exceed the cap, use largest
  utils::tail(multipliers, 1)
}

#' Generate a Calendar-Anchored Date Sequence
#'
#' Builds a sequence of calendar boundaries between two instants. The
#' sequence is generated at Date resolution and converted to POSIXct
#' afterwards: POSIXct arithmetic with `by = "1 week"` drifts by an hour
#' across DST transitions, which would leave minor ticks off midnight.
#'
#' @param from POSIXct lower bound (inclusive after trimming)
#' @param to POSIXct upper bound (inclusive after trimming)
#' @param by Character passed to [base::seq.Date()], e.g. "1 month", "1 week"
#' @param unit Character: "month" or "week" -- which boundary to snap to
#' @return POSIXct vector trimmed to `[from, to]`, possibly length zero
#' @keywords internal
#' @noRd
generate_calendar_sequence <- function(from, to, by, unit) {
  # week_start only applies to week units; floor_date() rejects NULL.
  floored <- if (identical(unit, "week")) {
    lubridate::floor_date(from, unit = unit, week_start = 1)
  } else {
    lubridate::floor_date(from, unit = unit)
  }

  start_date <- as.Date(format(floored, "%Y-%m-%d"))
  end_date <- as.Date(format(
    lubridate::ceiling_date(to, unit = unit),
    "%Y-%m-%d"
  ))

  dates <- seq(from = start_date, to = end_date, by = by)

  # Rebuild in the input's own timezone. Using the session timezone instead
  # would offset every break by the UTC delta, and the trim below would then
  # discard a boundary that in fact coincides with the first observation.
  tz <- attr(from, "tzone")
  if (is.null(tz) || !nzchar(tz[1])) {
    tz <- Sys.timezone()
  }
  breaks <- as.POSIXct(as.character(dates), tz = tz[1])

  # Trim at BOTH ends: breaks past the last observation render as empty
  # labels and stretch the panel (there is no right-hand expansion).
  breaks[breaks >= from & breaks <= to]
}

#' Calculate Calendar-Anchored Breaks for X-Axis
#'
#' Places major breaks on calendar boundaries -- month starts, or week
#' starts for spans too short to contain enough months -- with optional
#' unlabelled minor ticks at a finer boundary. Used for daily and weekly
#' series whose span exceeds [BFH_MAX_DATE_BREAKS], where per-unit labels
#' would need thinning and thus drift off the calendar.
#'
#' No break is forced at `data_x_min`: the calendar grid is the anchor, and
#' an extra off-grid break breaks the rhythm without adding information.
#'
#' @param data_x_min POSIXct minimum x value
#' @param data_x_max POSIXct maximum x value
#' @param label_multiplier Integer: label every Nth unit (1 = every unit)
#' @param minor_unit Character "day"/"week"/"month", or NULL for no minor
#'   ticks
#' @param major_unit Character: "month" (default) or "week" -- the boundary
#'   major breaks snap to
#' @return List with `major` (POSIXct) and `minor` (POSIXct or NULL)
#' @keywords internal
#' @noRd
calculate_anchored_breaks <- function(data_x_min, data_x_max,
                                            label_multiplier = 1,
                                            minor_unit = NULL,
                                            major_unit = "month") {
  major <- generate_calendar_sequence(
    data_x_min, data_x_max,
    by = paste(label_multiplier, paste0(major_unit, "s")),
    unit = major_unit
  )

  minor <- NULL
  if (!is.null(minor_unit)) {
    minor <- generate_calendar_sequence(
      data_x_min, data_x_max,
      by = paste("1", minor_unit),
      unit = minor_unit
    )
  }

  list(major = major, minor = minor)
}

#' Calculate Date Breaks for X-Axis
#'
#' Computes optimal break points for temporal x-axes. When `format_config`
#' carries a `break_unit` of "month" the breaks are anchored to calendar
#' month starts; otherwise breaks step through the interval's own unit with
#' a multiplier that keeps the count at or below [BFH_MAX_DATE_BREAKS].
#'
#' Breaks are trimmed to the observed span in both directions and no break
#' is forced at `data_x_min`, so an axis never carries an off-grid label or
#' an empty label past the last observation.
#'
#' @param data_x_min POSIXct minimum x value
#' @param data_x_max POSIXct maximum x value
#' @param interval_type Character: interval type from detect_date_interval()
#' @param format_config List: format configuration from get_optimal_formatting()
#' @return POSIXct vector of break points
#' @keywords internal
#' @noRd
calculate_date_breaks <- function(data_x_min, data_x_max, interval_type,
                                  format_config) {
  base_interval_secs <- calculate_base_interval_secs(interval_type)

  if (is.null(base_interval_secs)) {
    # Unknown interval type -> return NULL (caller will use breaks_pretty)
    return(NULL)
  }

  # Calculate density and multiplier
  timespan_secs <- as.numeric(difftime(data_x_max, data_x_min, units = "secs"))
  potential_breaks <- timespan_secs / base_interval_secs
  mult <- calculate_interval_multiplier(potential_breaks, interval_type)

  # Calendar-anchored path: daily/weekly series past the label cap, plus
  # every monthly series. Label cadence is derived from how many anchor
  # units the span holds, so dense spans thin to quarterly/half-yearly
  # labels rather than drifting off the calendar.
  anchor_unit <- format_config$break_unit
  if (identical(anchor_unit, "month") || identical(anchor_unit, "week")) {
    span_secs <- potential_breaks * base_interval_secs
    units_in_span <- if (identical(anchor_unit, "month")) {
      span_secs / (30 * 86400)
    } else {
      span_secs / 604800
    }
    label_mult <- calculate_interval_multiplier(
      units_in_span,
      if (identical(anchor_unit, "month")) "monthly" else "weekly"
    )

    anchored <- calculate_anchored_breaks(
      data_x_min, data_x_max,
      label_multiplier = label_mult,
      minor_unit = format_config$minor_break_unit,
      major_unit = anchor_unit
    )
    return(anchored$major)
  }

  # Interval size as difftime
  interval_size <- as.difftime(base_interval_secs * mult, units = "secs")

  # Generate breaks based on interval type
  if (interval_type == "monthly") {
    rounded_start <- round_to_interval_start(data_x_min, "monthly")
    rounded_end <- lubridate::ceiling_date(data_x_max, unit = "month")
    interval_months <- round(as.numeric(interval_size) / (30 * 24 * 60 * 60))
    extended_end <- seq(rounded_end,
      by = paste(interval_months, "months"),
      length.out = 2
    )[2]
    breaks_posix <- seq(
      from = rounded_start, to = extended_end,
      by = paste(interval_months, "months")
    )
  } else if (interval_type == "weekly") {
    rounded_start <- round_to_interval_start(data_x_min, "weekly")
    rounded_end <- lubridate::ceiling_date(data_x_max, unit = "week")
    breaks_posix <- seq(
      from = rounded_start, to = rounded_end + interval_size,
      by = interval_size
    )
  } else {
    # daily
    rounded_start <- round_to_interval_start(data_x_min, interval_type)
    breaks_posix <- seq(
      from = rounded_start, to = data_x_max + interval_size,
      by = interval_size
    )
  }

  # Trim to the observed span at both ends. No break is forced at
  # data_x_min: an off-grid first label breaks the rhythm of the grid, and
  # label_date_short() still shows the year on the first visible label.
  breaks_posix <- breaks_posix[
    breaks_posix >= data_x_min & breaks_posix <= data_x_max
  ]

  # Ensure POSIXct
  as.POSIXct(breaks_posix)
}

#' Calculate Minor Tick Breaks
#'
#' Returns the unlabelled tick positions for a temporal axis, or NULL when
#' the format config asks for none.
#'
#' @param data_x_min POSIXct minimum x value
#' @param data_x_max POSIXct maximum x value
#' @param format_config List from get_optimal_formatting()
#' @return POSIXct vector, or NULL
#' @keywords internal
#' @noRd
calculate_minor_breaks <- function(data_x_min, data_x_max, format_config) {
  minor_unit <- format_config$minor_break_unit
  if (is.null(minor_unit)) {
    return(NULL)
  }

  minor <- generate_calendar_sequence(
    data_x_min, data_x_max,
    by = paste("1", minor_unit),
    unit = minor_unit
  )

  if (length(minor) == 0) NULL else minor
}

#' Does a Plot Carry Explicit Minor X Breaks?
#'
#' @param plot ggplot object
#' @return Logical
#' @keywords internal
#' @noRd
has_x_minor_breaks <- function(plot) {
  if (!inherits(plot, "gg") || is.null(plot$scales)) {
    return(FALSE)
  }
  x_scales <- Filter(
    function(s) "x" %in% s$aesthetics,
    plot$scales$scales
  )
  if (length(x_scales) == 0) {
    return(FALSE)
  }
  minor <- x_scales[[length(x_scales)]]$minor_breaks
  !is.null(minor) && !inherits(minor, "waiver") && length(minor) > 0
}

#' Apply Temporal X-Axis Formatting
#'
#' Orchestrates temporal x-axis formatting using interval detection,
#' break calculation, and smart label application.
#'
#' @param plot ggplot object
#' @param x_col POSIXct or Date vector
#' @param data_x_min POSIXct minimum (pre-computed)
#' @param data_x_max POSIXct maximum (pre-computed)
#' @return Modified ggplot object with datetime scale
#' @keywords internal
#' @noRd
apply_temporal_x_axis <- function(plot, x_col, data_x_min, data_x_max,
                                  language = "da") {
  .ensure_bfhtheme()
  # Normalize to POSIXct
  x_col <- normalize_to_posixct(x_col)

  # Detect interval and get format config
  interval_info <- detect_date_interval(x_col)
  format_config <- get_optimal_formatting(interval_info)

  # Locale-wrap labeler so %b/%a tokens reflect the requested language.
  # Best-effort: if requested locale is unavailable on the host, falls back
  # silently to system default. Spec: locale-aware-en-formatting.
  if (!is.null(format_config$labels)) {
    format_config$labels <- with_lc_time_labeler(format_config$labels, language)
  }

  # Calculate breaks if we have format config with breaks enabled
  if (!is.null(format_config$breaks) ||
    (!is.null(format_config$use_smart_labels) && format_config$use_smart_labels)) {
    breaks_posix <- calculate_date_breaks(
      data_x_min, data_x_max,
      interval_info$type, format_config
    )

    # Unlabelled ticks on the finer calendar boundary. They keep a
    # month-labelled axis countable at week resolution without adding text.
    #
    # NB: these are currently computed but not visible. BFHtheme::theme_bfh()
    # sets axis.ticks = element_blank(), and minor ticks inherit that
    # blanking, so rendering them requires a BFHtheme decision rather than a
    # local override here. The breaks are attached to the scale so they start
    # rendering as soon as the theme supports them.
    minor_breaks <- calculate_minor_breaks(
      data_x_min, data_x_max, format_config
    )
    minor_args <- if (is.null(minor_breaks)) {
      list()
    } else {
      list(
        minor_breaks = minor_breaks,
        guide = ggplot2::guide_axis(minor.ticks = TRUE)
      )
    }

    if (!is.null(breaks_posix)) {
      # Apply scale with calculated breaks
      if (!is.null(format_config$use_smart_labels) && format_config$use_smart_labels) {
        plot <- plot + do.call(
          BFHtheme::scale_x_datetime_bfh,
          c(
            list(
              expand = ggplot2::expansion(mult = c(0.025, 0)),
              labels = format_config$labels,
              breaks = breaks_posix
            ),
            minor_args
          )
        )
      } else {
        plot <- plot + do.call(
          BFHtheme::scale_x_datetime_bfh,
          c(
            list(
              labels = format_config$labels,
              breaks = breaks_posix
            ),
            minor_args
          )
        )
      }

      # NB: the theme override for minor tick length is NOT applied here.
      # A complete theme (BFHtheme::theme_bfh) is added downstream and would
      # reset it; apply_spc_theme() re-applies it after the theme instead.
      return(plot)
    }
  }

  # Fallback to breaks_pretty
  plot + BFHtheme::scale_x_datetime_bfh(
    labels = format_config$labels,
    breaks = scales::breaks_pretty(n = format_config$n_breaks)
  )
}

#' Apply Numeric X-Axis Formatting
#'
#' Applies pretty breaks to numeric x-axes (observation sequences).
#'
#' @param plot ggplot object
#' @return Modified ggplot object with continuous scale
#' @keywords internal
#' @noRd
apply_numeric_x_axis <- function(plot) {
  .ensure_bfhtheme()
  plot + BFHtheme::scale_x_continuous_bfh(
    breaks = scales::pretty_breaks(n = 8)
  )
}

#' Maximum Visible Text X-Axis Labels
#'
#' Default cap on number of categorical x-axis labels rendered horizontally
#' without rotation. Drives [bfh_subsample_label_indices()] when caller does
#' not override `max_visible`. Threshold chosen to fit standard A4 PDF export
#' width (200mm @ 300dpi) with horizontal Roboto Medium labels.
#'
#' @keywords internal
BFH_MAX_X_LABELS_TEXT <- 12L

#' Subsample Text X-Axis Label Indices
#'
#' Returns deterministic, evenly-spaced indices for selecting which categorical
#' x-axis labels to display on a chart. First index is always 1. Intermediate
#' indices follow integer step `ceiling((n_labels - 1) / (max_visible - 1))`.
#' The last index `n_labels` is included only when it lands naturally on the
#' step grid (i.e. when `(n_labels - 1)` is divisible by `step`); otherwise
#' the sequence ends at the highest step-aligned position <= `n_labels`.
#' Designed for tekst-x-data (month names, weekdays, observation IDs) where
#' showing all labels would overlap or require rotation.
#'
#' Algorithm scales smoothly: for n <= max_visible all indices returned;
#' otherwise step-based thinning preserves a constant label-density and
#' avoids the asymmetric-rounding gap-bug that
#' `round(seq(..., length.out))` produces for moderate n (issue #396).
#'
#' Note: prior versions (0.22.0) appended `n_labels` as a force-last anchor,
#' producing a shorter tail-gap mid-rhythm. This was removed because the
#' rhythm-break was visually jarring (e.g. n=24 jumped from a constant step=3
#' to a step=2 tail). Callers requiring the last label as anchor must append
#' it explicitly.
#'
#' @param n_labels Integer. Total number of labels available.
#' @param max_visible Integer. Maximum number of labels to display.
#'   Default [BFH_MAX_X_LABELS_TEXT] (currently 12).
#'
#' @return Integer vector of indices into the label sequence. First index is
#'   always 1; last index is `n_labels` only when it falls on the step grid,
#'   otherwise the highest step-aligned position <= `n_labels`.
#'   Length <= `max_visible`.
#'
#' @export
#'
#' @examples
#' # All 12 months visible when n <= max
#' bfh_subsample_label_indices(12)
#' # [1] 1 2 3 4 5 6 7 8 9 10 11 12
#'
#' # 24 months: step=3, no force-last (sidste = 22, ej 24)
#' bfh_subsample_label_indices(24)
#' # [1]  1  4  7 10 13 16 19 22
#'
#' # 100 obs: step=9, n=100 lands naturally on grid -> included
#' bfh_subsample_label_indices(100)
#' # [1]   1  10  19  28  37  46  55  64  73  82  91 100
#'
#' # Custom max
#' bfh_subsample_label_indices(24, max_visible = 6)
#' # [1]  1  6 11 16 21
bfh_subsample_label_indices <- function(n_labels, max_visible = BFH_MAX_X_LABELS_TEXT) {
  if (!is.numeric(n_labels) || length(n_labels) != 1L || is.na(n_labels) ||
    n_labels < 1) {
    stop("n_labels must be a positive integer scalar", call. = FALSE)
  }
  if (!is.numeric(max_visible) || length(max_visible) != 1L || is.na(max_visible) ||
    max_visible < 1) {
    stop("max_visible must be a positive integer scalar", call. = FALSE)
  }
  n_labels <- as.integer(n_labels)
  max_visible <- as.integer(max_visible)
  if (n_labels <= max_visible) {
    return(seq_len(n_labels))
  }
  if (max_visible == 1L) {
    return(1L)
  }
  # Deterministic step keeps idx count within max_visible. Last index is
  # included only when (n_labels - 1) %% step == 0 -- preserves constant
  # rhythm and avoids the jarring shorter tail-gap from force-last anchoring.
  step <- as.integer(ceiling((n_labels - 1L) / (max_visible - 1L)))
  seq.int(1L, n_labels, by = step)
}
