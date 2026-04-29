## ADDED Requirements

### Requirement: bfh_qic SHALL warn when baseline is statistically insufficient

`bfh_qic()` SHALL emit a `warning()` when `freeze` is supplied with a value below `MIN_BASELINE_N` (default 8), AND when any phase produced by `part` has fewer than `MIN_BASELINE_N` observations. The constant SHALL be defined in `R/globals.R` with a rationale comment.

**Rationale:** Frozen baselines or phases shorter than ~8 points produce control limits with statistical uncertainty too wide to be clinically meaningful. The vignette already documents this guideline; the code must surface it.

#### Scenario: short freeze emits warning

- **GIVEN** `bfh_qic(data, x, y, freeze = 3, ...)`
- **WHEN** the call executes
- **THEN** a `warning()` SHALL be emitted naming `freeze = 3` and the recommended minimum
- **AND** the chart SHALL still be produced (warning, not error)

#### Scenario: short phase from part emits warning

- **GIVEN** 18 observations and `part = c(3, 9)` (phases of length 3, 6, 9)
- **WHEN** `bfh_qic()` executes
- **THEN** a warning SHALL list which phase indices fall below `MIN_BASELINE_N`

#### Scenario: adequate baseline emits no warning

- **GIVEN** `freeze = 8` or `part` producing only phases ≥ 8
- **WHEN** `bfh_qic()` executes
- **THEN** no baseline-related warning SHALL be emitted

### Requirement: bfh_qic SHALL warn when custom cl is combined with Anhøj reporting

When `cl` is supplied (non-NULL) AND the resulting `qic_data` contains `runs.signal` or `crossings.signal`, `bfh_qic()` SHALL emit a warning explaining that Anhøj rules are computed against the user-supplied centerline, not the data-estimated process mean.

**Rationale:** Anhøj rules assume CL = process mean. Against a benchmark CL, run-length and crossing counts are statistically invalid and may declare false special-cause signals.

#### Scenario: non-null cl with Anhøj signals triggers warning

- **GIVEN** `bfh_qic(data, x, y, cl = 50, chart_type = "p")` with sufficient data
- **WHEN** the call executes
- **THEN** a warning SHALL be emitted naming the cl value and clarifying the Anhøj contract

#### Scenario: null cl does not trigger warning

- **GIVEN** `bfh_qic(data, x, y, chart_type = "p")` with no `cl`
- **WHEN** the call executes
- **THEN** no cl-related warning SHALL be emitted

### Requirement: anhoej.signal SHALL preserve NA for inevaluable series

`add_anhoej_signal()` SHALL NOT coerce `NA` Anhøj signals to `FALSE`. The summary and downstream analysis text SHALL render an explicit "ikke evaluerbar" / "not evaluable" state when the underlying value is `NA`.

**Rationale:** qicharts2 returns `NA` when n is too small to evaluate Anhøj criteria. Coercing to FALSE silently reports "no signal" — clinically equivalent to claiming evaluation succeeded with negative result.

#### Scenario: short series reports not-evaluable

- **GIVEN** a 6-observation run chart
- **WHEN** `bfh_qic()` is called and `qic_summary` is rendered
- **THEN** Anhøj-signal cells SHALL be `NA` in `qic_data`
- **AND** the summary text SHALL include the i18n key `analysis.anhoej_not_evaluable`
- **AND** the text SHALL NOT claim "0 Anhøj signaler"

```r
short_data <- data.frame(date = seq.Date(as.Date("2025-01-01"), by = "month", length.out = 6),
                         value = c(10, 12, 11, 13, 14, 12))
res <- bfh_qic(short_data, x = date, y = value, chart_type = "i")
expect_true(any(is.na(res$qic_data$runs.signal) | is.na(res$qic_data$crossings.signal)))
expect_match(format_qic_summary(res$qic_data, lang = "da"),
             "ikke evaluerbar", ignore.case = TRUE)
```
