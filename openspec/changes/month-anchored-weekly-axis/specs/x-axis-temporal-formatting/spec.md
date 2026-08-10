## ADDED Requirements

### Requirement: Daily and weekly series over threshold SHALL use month-anchored major breaks

When a temporal x-axis is classified as daily or weekly and the data span
contains more than 15 potential breaks in the interval's base unit (days for
daily, weeks for weekly), major axis breaks SHALL be placed on the first day
of each calendar month within the data range. No major break SHALL be
generated at a non-month-start position.

#### Scenario: Long weekly series gets month-start breaks

- **WHEN** breaks are calculated for 37 weeks of weekly data
  (2025-12-01 to 2026-08-09)
- **THEN** every major break falls on the 1st of a calendar month
- **AND** no break is a week-multiple offset from the data start
  (the 2/4/13-week multiplier path is not used)

#### Scenario: Multi-year weekly series does not drift

- **WHEN** breaks are calculated for 104 weeks of weekly data
- **THEN** every major break falls on the 1st of a calendar month
- **AND** breaks do not drift backwards through the calendar
  (the 13-week/91-day step, which loses ~3 days per year, is not used)

#### Scenario: Long daily series gets month-start breaks

- **WHEN** breaks are calculated for 120 days of daily data
- **THEN** every major break falls on the 1st of a calendar month
- **AND** the 2/4/8-day multiplier path is not used

#### Scenario: Medium daily series gets week-start breaks

- **WHEN** breaks are calculated for a daily series spanning more than 15
  days but no more than 15 weeks (e.g. 30 or 60 days)
- **THEN** every major break falls on a Monday
- **AND** the previously dead `"2 weeks"` configuration no longer yields
  2- or 4-day offset breaks

#### Scenario: Every series carries at least two labels

- **WHEN** breaks are calculated for any daily series between 16 days and
  15 weeks, starting on any day of the month
- **THEN** at least two major breaks are produced
- **AND** no more than 15 major breaks are produced

Month anchoring alone cannot satisfy this: a 30-day span contains at most
one month start, so such series anchor on week starts instead.

#### Scenario: Short series keep per-unit labels

- **WHEN** breaks are calculated for weekly data spanning 15 or fewer weeks,
  or daily data spanning 15 or fewer days
- **THEN** breaks remain in the base unit with multiplier 1
  (one break per week / per day), unchanged from prior behavior

#### Scenario: Threshold is computed from data span, not observation count

- **WHEN** a weekly series has gaps such that observation count and span
  disagree (e.g. 12 observations spanning 20 weeks)
- **THEN** the mode is selected from the span (20 weeks > 15 → month-anchored)

### Requirement: Calendar-anchored axes SHALL carry minor breaks

When a daily or weekly series uses calendar-anchored major breaks, the axis
SHALL carry unlabeled minor breaks at the next finer calendar boundary
within the data range — week starts under month anchoring, day starts under
week anchoring — attached to the scale together with
`guide_axis(minor.ticks = TRUE)`.

Whether those ticks are *visible* is out of scope: `BFHtheme::theme_bfh()`
blanks all axis ticks, and overriding the design system is a BFHtheme
decision. This package SHALL NOT override it locally; the breaks are
attached so ticks render if and when the theme supports them.

#### Scenario: Weekly minor breaks fall on Mondays

- **WHEN** a series using month-anchored breaks with month multiplier 1 is
  formatted
- **THEN** minor breaks are generated at every Monday within the data range
- **AND** minor breaks carry no labels

#### Scenario: Week-anchored axes carry daily minor breaks

- **WHEN** a daily series anchored on week starts is formatted
- **THEN** minor breaks are generated at every day within the data range

#### Scenario: Scale and guide combination renders

- **WHEN** a formatted plot from any anchoring mode is built
- **THEN** `ggplot_build()` completes without warnings

#### Scenario: Week flooring is Monday-based regardless of host locale

- **WHEN** week starts are computed on a host where
  `getOption("lubridate.week.start")` is unset (lubridate defaults to Sunday)
- **THEN** week boundaries are still Mondays (ISO-8601), because week
  flooring explicitly specifies `week_start = 1`
- **AND** a Monday date floors to itself, not to the preceding Sunday

#### Scenario: Minor ticks escalate to month level when labels are thinned

- **WHEN** the data span exceeds 15 months and month labels are thinned to
  every 3rd/6th/12th month
- **THEN** minor breaks are placed at each unlabeled month start instead of
  at week starts

#### Scenario: Series below threshold render no minor ticks

- **WHEN** a weekly series spanning 15 or fewer weeks is formatted
- **THEN** no minor breaks and no minor-tick guide are applied

### Requirement: Breaks SHALL be trimmed to the data span

Generated breaks SHALL be filtered at both ends of the data range. No break
SHALL fall before the first observation or after the last observation, and
no break SHALL be forced at the exact data minimum.

#### Scenario: No breaks beyond the last observation

- **WHEN** breaks are calculated for 16 weeks of weekly data
  (2026-01-05 to 2026-04-20)
- **THEN** no break falls after 2026-04-20
  (prior behavior emitted 2 trailing breaks past the data maximum)

#### Scenario: Data starting mid-month anchors to the next month start

- **WHEN** weekly data spans more than 15 weeks and starts mid-month
  (e.g. 2025-12-10)
- **THEN** the first major break is the first month start within the data
  range (2026-01-01)
- **AND** no off-grid break is inserted at the data minimum

#### Scenario: Monthly data not aligned to the 1st loses its off-grid start break

- **WHEN** breaks are calculated for monthly data observed on the 15th
  (e.g. 2025-01-15, 18 observations)
- **THEN** every break falls on the 1st of a calendar month
- **AND** no break is emitted at 2025-01-15

### Requirement: Hierarchical date labels SHALL be preserved

Month-anchored axes SHALL label major breaks using
`scales::label_date_short()` semantics with month-level format: month name
on every labeled break, year shown only at the first visible label and at
year transitions. Labels SHALL respect the requested language via the
existing LC_TIME locale wrapper.

#### Scenario: Year appears only when necessary

- **WHEN** a month-anchored weekly axis spans a year transition
  (e.g. Dec 2025 to Aug 2026)
- **THEN** the first visible label includes the year
- **AND** the January break includes the new year
- **AND** intermediate month labels show the month name only

#### Scenario: Danish month names under da language

- **WHEN** `language = "da"` and a Danish LC_TIME locale is available on the
  host
- **THEN** month labels use Danish month names (e.g. "maj", "okt.")

### Requirement: calculate_date_breaks SHALL honor the break-unit contract

`get_optimal_formatting()` SHALL express its break intention through
explicit `break_unit` and `minor_break_unit` fields, and
`calculate_date_breaks()` SHALL dispatch on `break_unit` rather than on the
raw interval type alone. The previously ignored `format_config` parameter
SHALL become the carrier of this contract.

#### Scenario: Break unit drives break generation

- **WHEN** a format config specifies `break_unit = "month"`
- **THEN** breaks are month-anchored regardless of the detected interval type

#### Scenario: Monthly series behavior is preserved

- **WHEN** breaks are calculated for monthly data aligned to the 1st
  (18 and 30 observations)
- **THEN** breaks remain on calendar month starts at the existing 3-month
  cadence, unchanged from prior behavior

#### Scenario: Config without break unit falls back unchanged

- **WHEN** a format config carries no `break_unit` field
- **THEN** break calculation behaves as before (interval-type based),
  preserving the defensive fallback path for quarterly, yearly and
  irregular series

### Requirement: Break sequence generation SHALL be DST-safe

Month and week break sequences SHALL be generated at Date resolution and
converted to POSIXct afterwards, so that breaks do not drift across
daylight-saving transitions.

#### Scenario: Weekly minor ticks across a DST transition

- **WHEN** weekly minor breaks are generated for a range spanning the
  March or October DST transition (Europe/Copenhagen)
- **THEN** every minor break falls exactly on midnight of a Monday
  (no one-hour drift)

#### Scenario: Breaks are rebuilt in the input's own timezone

- **WHEN** breaks are generated for UTC-based input while the session
  timezone is not UTC
- **THEN** breaks are offset by the input's timezone, not the session's
- **AND** a boundary coinciding with the first observation survives trimming
  (it is not pushed below `data_x_min` by a timezone delta)
