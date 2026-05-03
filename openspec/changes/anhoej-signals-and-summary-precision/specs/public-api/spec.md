## ADDED Requirements

### Requirement: Summary SHALL expose Anhoej signals as combined plus decomposed flags

The summary returned by `bfh_qic()$summary` SHALL expose three logical columns describing the Anhoej rule outcome per phase:

- `anhoej_signal` — combined Anhoej signal, sourced directly from `qicharts2::runs.signal`. TRUE when EITHER the runs-rule OR the crossings-rule is violated for the phase. This matches `qicharts2`'s `crsignal()` model exactly.
- `runs_signal` — runs-rule outcome alone. TRUE when `længste_løb > længste_løb_max` for the phase. Derived per-phase from existing summary columns.
- `crossings_signal` — crossings-rule outcome alone. TRUE when `antal_kryds < antal_kryds_min` for the phase. Derived per-phase from existing summary columns.

**Rationale:**
- `qicharts2::runs.signal` is the *combined* Anhoej signal (`crsignal(n.useful, n.crossings, longest.run)`), but the legacy column name `loebelaengde_signal` ("run-length signal") misled clinicians into reading it as runs-only — causing crossings-only violations to be mis-attributed as level-shifts.
- Decomposed flags let downstream consumers (PDF rendering, biSPCharts UI, analysis text) explain WHICH rule fired without re-deriving from raw fields.
- Derivation is purely arithmetic from already-present summary columns — no new statistical computation.

**NA semantics:**
- When `længste_løb` or `antal_kryds` is NA for a phase (degenerate phase: all-equal values, single-observation phase), the derived `runs_signal` / `crossings_signal` SHALL also be NA. `anhoej_signal` follows `qicharts2::runs.signal`'s NA semantics (typically NA when the Anhoej rules cannot be evaluated).

#### Scenario: Combined and decomposed signals present for all chart types

- **GIVEN** any chart type that produces an Anhoej signal (i, p, pp, u, up, c, mr, run, xbar)
- **WHEN** `bfh_qic(..., return.data = FALSE)` is called
- **THEN** `result$summary` SHALL contain logical columns `anhoej_signal`, `runs_signal`, `crossings_signal`
- **AND** each column SHALL be of type `logical`
- **AND** `length(result$summary$anhoej_signal)` SHALL equal the number of phases

```r
data <- data.frame(month = 1:24, value = c(rep(10, 12), rep(20, 12)))
result <- bfh_qic(data, x = month, y = value, chart_type = "i")
expect_true(all(c("anhoej_signal", "runs_signal", "crossings_signal") %in%
                names(result$summary)))
expect_type(result$summary$anhoej_signal, "logical")
expect_type(result$summary$runs_signal, "logical")
expect_type(result$summary$crossings_signal, "logical")
```

#### Scenario: Crossings-only data trips crossings_signal but not runs_signal

- **GIVEN** an alternating-step pattern that produces too-few crossings but no over-long run
- **WHEN** `bfh_qic(..., chart_type = "run")` is called
- **THEN** `summary$crossings_signal[1]` SHALL be `TRUE`
- **AND** `summary$runs_signal[1]` SHALL be `FALSE`
- **AND** `summary$anhoej_signal[1]` SHALL be `TRUE` (combined: any rule fires)

```r
# Crossing-only data: 4 alternating phases of 5 points each.
# longest.run = 5 < longest.run.max (typically 7-8 for n=20), so no run-violation.
# n.crossings = 3 < n.crossings.min (typically 6-7 for n=20), so crossings-violation.
value <- c(rep(10, 5), rep(20, 5), rep(10, 5), rep(20, 5))
data <- data.frame(idx = seq_along(value), value = value)
result <- bfh_qic(data, x = idx, y = value, chart_type = "run")
expect_true(result$summary$crossings_signal[1])
expect_false(result$summary$runs_signal[1])
expect_true(result$summary$anhoej_signal[1])
```

#### Scenario: Long-run data trips runs_signal but not crossings_signal

- **GIVEN** a step-shift pattern with a long run on one side of the centre line
- **WHEN** `bfh_qic(..., chart_type = "i")` is called
- **THEN** `summary$runs_signal[1]` SHALL be `TRUE`
- **AND** `summary$crossings_signal[1]` SHALL be `FALSE`
- **AND** `summary$anhoej_signal[1]` SHALL be `TRUE`

```r
# Long-run data: 12 points below CL, then 12 points above CL.
# longest.run = 12 > longest.run.max (8 for n=24), so run-violation.
# n.crossings = 1 ≥ n.crossings.min check (depends on n) — verify case.
value <- c(rep(10, 12), rep(20, 12))
data <- data.frame(idx = seq_along(value), value = value)
result <- bfh_qic(data, x = idx, y = value, chart_type = "i")
expect_true(result$summary$runs_signal[1])
expect_true(result$summary$anhoej_signal[1])
```

#### Scenario: Random data trips neither signal

- **GIVEN** randomly distributed observations around a stable mean
- **WHEN** `bfh_qic()` is called
- **THEN** `summary$runs_signal[1]` SHALL be `FALSE`
- **AND** `summary$crossings_signal[1]` SHALL be `FALSE`
- **AND** `summary$anhoej_signal[1]` SHALL be `FALSE`

```r
set.seed(42)
data <- data.frame(idx = 1:30, value = rnorm(30, mean = 100, sd = 5))
result <- bfh_qic(data, x = idx, y = value, chart_type = "i")
expect_false(result$summary$runs_signal[1])
expect_false(result$summary$crossings_signal[1])
expect_false(result$summary$anhoej_signal[1])
```

#### Scenario: Multi-phase data evaluates signals per phase

- **GIVEN** a multi-phase chart where phase 1 has a runs-violation and phase 2 has a crossings-violation
- **WHEN** `bfh_qic(..., part = ...)` is called
- **THEN** `summary$runs_signal` SHALL be `TRUE` for phase 1 and `FALSE` for phase 2
- **AND** `summary$crossings_signal` SHALL be `FALSE` for phase 1 and `TRUE` for phase 2
- **AND** `summary$anhoej_signal` SHALL be `TRUE` for both phases

#### Scenario: Combined signal matches qicharts2::runs.signal

- **GIVEN** any chart input that qicharts2 evaluates Anhoej signals on
- **WHEN** `bfh_qic(..., return.data = TRUE)` is called
- **THEN** for each phase `summary$anhoej_signal[p]` SHALL equal `any(qic_data$runs.signal[part == p], na.rm = TRUE)`

### Requirement: Summary numeric columns SHALL preserve raw qicharts2 precision

The summary returned by `bfh_qic()$summary` SHALL carry numeric values at the precision returned by `qicharts2::qic()`. Specifically, `centerlinje`, `nedre_kontrolgrænse`, `øvre_kontrolgrænse`, `nedre_kontrolgrænse_min`, `nedre_kontrolgrænse_max`, `øvre_kontrolgrænse_min`, `øvre_kontrolgrænse_max`, `nedre_kontrolgrænse_95`, and `øvre_kontrolgrænse_95` SHALL NOT be rounded by `format_qic_summary()`.

**Rationale:**
- Downstream consumers performing logical comparisons (`target >= centerlinje`, statistical further-analysis) need full precision. Pre-change rounding to 1-2 decimals introduced clinically wrong answers near round-off boundaries (verified via biSPCharts #470).
- Display-layer rounding is the responsibility of consumers (PDF render, print methods, UI rendering). The summary is the source of truth.
- Single source of truth eliminates the previous `summary$centerlinje` (rounded) vs `qic_data$cl` (raw) split that confused downstream usage.

**Internal logic preserved:**
- The `kontrolgrænser_konstante` constancy flag continues to use `round_prec = decimal_places + 2` to absorb floating-point drift in qicharts2's per-row limit values. That logic operates on raw `qic_data$lcl/ucl` columns and is unchanged.

#### Scenario: centerlinje matches raw qic_data$cl

- **GIVEN** any chart input
- **WHEN** `bfh_qic(..., return.data = TRUE)` is called
- **THEN** for each phase `summary$centerlinje[p]` SHALL equal `qic_data$cl[part == p][1]` exactly (no rounding)

```r
data <- data.frame(month = 1:12,
                   events = c(7, 8, 6, 9, 7, 8, 6, 7, 9, 8, 6, 7),
                   total = rep(100, 12))
result <- bfh_qic(data, x = month, y = events, n = total,
                  chart_type = "p", y_axis_unit = "percent",
                  return.data = TRUE)
expect_identical(result$summary$centerlinje[1], result$qic_data$cl[1])
# Pre-change: 0.07 (rounded). Post-change: 0.07195946... (raw).
```

#### Scenario: Control limits match raw qic_data$lcl/ucl

- **GIVEN** any non-run chart with constant limits within a phase
- **WHEN** `bfh_qic(..., return.data = TRUE)` is called
- **THEN** `summary$nedre_kontrolgrænse[p]` SHALL equal `qic_data$lcl[part == p][1]` exactly
- **AND** `summary$øvre_kontrolgrænse[p]` SHALL equal `qic_data$ucl[part == p][1]` exactly

#### Scenario: Variable limit min/max preserve raw precision

- **GIVEN** a P-chart with varying denominators within a phase
- **WHEN** `bfh_qic(..., return.data = TRUE)` is called
- **THEN** `summary$nedre_kontrolgrænse_min[p]` SHALL equal `min(qic_data$lcl[part == p], na.rm = TRUE)` exactly
- **AND** `summary$nedre_kontrolgrænse_max[p]` SHALL equal `max(qic_data$lcl[part == p], na.rm = TRUE)` exactly
- **AND** the same SHALL hold for `øvre_kontrolgrænse_min/max` against `qic_data$ucl`

#### Scenario: kontrolgrænser_konstante still uses tolerance

- **GIVEN** a phase where `qic_data$lcl` values vary only in the 4th decimal (typical qicharts2 floating-point drift for "constant" limits)
- **WHEN** `format_qic_summary(..., y_axis_unit = "percent")` is called (`decimal_places + 2 = 4` precision)
- **THEN** `summary$kontrolgrænser_konstante[p]` SHALL be `TRUE`
- **AND** scalar columns `nedre_kontrolgrænse` / `øvre_kontrolgrænse` SHALL be populated with raw (unrounded) values

## REMOVED Requirements

### Requirement: Summary column `loebelaengde_signal`

**Reason:** The column name implied "runs-only signal", but its source `qicharts2::runs.signal` is the combined Anhoej signal (runs OR crossings). Clinicians mis-attributed crossings-only violations as level-shifts. Replaced by `anhoej_signal` (combined, same semantics) plus `runs_signal` and `crossings_signal` (decomposed).

**Migration:**
- Read `summary$anhoej_signal` for the same logical value previously read from `summary$loebelaengde_signal` (or `summary$løbelængde_signal` in pre-ASCII-migration code).
- Where the consumer specifically wants to detect a runs-rule violation, read `summary$runs_signal`.
- Where the consumer specifically wants to detect a crossings-rule violation, read `summary$crossings_signal`.
- biSPCharts: tracked in johanreventlow/biSPCharts#468.

```r
# BEFORE (BFHcharts ≤ 0.14.x)
if (result$summary$loebelaengde_signal[phase]) { ... }

# AFTER (BFHcharts ≥ 0.15.0)
if (isTRUE(result$summary$anhoej_signal[phase])) { ... }              # same combined semantics
if (isTRUE(result$summary$runs_signal[phase])) { ... }                # runs-rule only
if (isTRUE(result$summary$crossings_signal[phase])) { ... }           # crossings-rule only
```
