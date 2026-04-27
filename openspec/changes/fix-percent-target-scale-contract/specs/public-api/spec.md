## ADDED Requirements

### Requirement: Public API SHALL validate target_value scale against y_axis_unit contract

The package SHALL validate `target_value` against an explicit scale derived from `y_axis_unit` and `multiply` to prevent silent unit-mismatch bugs that produce clinically misleading target lines.

**Rationale:**
- Healthcare context: silent magic is more dangerous than a clear, actionable error
- Most common user-intuition error: passing `target_value = 2.0` for "2%" instead of `0.02`
- Without validation, target line renders at 200% on a 0-100% axis — clinically misleading and a real risk for quality reports

**Contract:**

| `y_axis_unit` | `multiply` | Expected `target_value` range |
|---|---|---|
| `"percent"` | `1` (default) | `[0, 1.5]` (proportion) |
| `"percent"` | `100` | `[0, 150]` (percent) |
| `"percent"` | other `m` | `[0, m * 1.5]` |
| `"count"` / `"rate"` / `"time"` | any | not validated against scale (subject to existing numeric validation only) |

The 1.5x slack on the upper bound permits legitimate targets near the edge (e.g., aspirational stretch targets at 105%) while still catching the common 100x mismatch.

The contract applies uniformly across all chart types — including run-chart, which has no control limits but still renders a target line.

#### Scenario: percent target_value > 1.5 with default multiply rejected

- **GIVEN** `y_axis_unit = "percent"`, `multiply = 1`, `target_value = 2.0`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the error message SHALL identify the expected scale (`[0, 1.5]`)
- **AND** the error message SHALL include an actionable migration hint suggesting `target_value = 0.02` or `multiply = 100`

```r
expect_error(
  bfh_qic(data, x = period, y = events, n = total,
          chart_type = "p", y_axis_unit = "percent",
          target_value = 2.0),
  "uden for forventet skala"
)
```

#### Scenario: percent target_value as proportion accepted

- **GIVEN** `y_axis_unit = "percent"`, `multiply = 1`, `target_value = 0.02`
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL succeed
- **AND** the underlying `qic_data$target` SHALL equal `0.02`

```r
result <- bfh_qic(data, x = period, y = events, n = total,
                  chart_type = "p", y_axis_unit = "percent",
                  target_value = 0.02)
expect_equal(unique(result$qic_data$target[!is.na(result$qic_data$target)]), 0.02)
```

#### Scenario: percent target_value with multiply=100 accepted as percent

- **GIVEN** `y_axis_unit = "percent"`, `multiply = 100`, `target_value = 2.0`
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL succeed
- **AND** the underlying `qic_data$target` SHALL equal `2.0`

```r
result <- bfh_qic(data, x = period, y = events, n = total,
                  chart_type = "p", y_axis_unit = "percent",
                  target_value = 2.0, multiply = 100)
expect_equal(unique(result$qic_data$target[!is.na(result$qic_data$target)]), 2.0)
```

#### Scenario: negative target_value rejected for percent

- **GIVEN** `y_axis_unit = "percent"`, `target_value = -0.1`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the error message SHALL state that proportion targets must be non-negative

```r
expect_error(
  bfh_qic(data, x = period, y = events, n = total,
          chart_type = "p", y_axis_unit = "percent",
          target_value = -0.1),
  "non-negative|ikke-negativ"
)
```

#### Scenario: boundary values within contract accepted

- **GIVEN** `y_axis_unit = "percent"`, `multiply = 1`
- **WHEN** `target_value = 1.0` (valid 100% target) OR `target_value = 1.5` (boundary)
- **THEN** the function SHALL succeed for both
- **AND** the underlying `qic_data$target` SHALL preserve the input value

```r
# 100% target
result_100 <- bfh_qic(data, x = period, y = events, n = total,
                      chart_type = "p", y_axis_unit = "percent",
                      target_value = 1.0)
expect_equal(unique(result_100$qic_data$target[!is.na(result_100$qic_data$target)]), 1.0)

# Upper boundary
result_boundary <- bfh_qic(data, x = period, y = events, n = total,
                           chart_type = "p", y_axis_unit = "percent",
                           target_value = 1.5)
expect_equal(unique(result_boundary$qic_data$target[!is.na(result_boundary$qic_data$target)]), 1.5)
```

#### Scenario: non-percent units skip scale validation

- **GIVEN** `y_axis_unit = "count"`, `target_value = 9999`
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL NOT validate target_value against any scale ceiling
- **AND** the function SHALL succeed (subject to existing numeric parameter validation)

```r
data <- data.frame(period = 1:10, value = rpois(10, lambda = 50))
result <- bfh_qic(data, x = period, y = value,
                  chart_type = "i", y_axis_unit = "count",
                  target_value = 9999)
expect_s3_class(result, "bfh_qic_result")
```

#### Scenario: contract applies to run-chart despite no control limits

- **GIVEN** `chart_type = "run"`, `y_axis_unit = "percent"`, `target_value = 2.0`, `multiply = 1`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the contract SHALL be enforced regardless of chart type

```r
expect_error(
  bfh_qic(data, x = period, y = events, n = total,
          chart_type = "run", y_axis_unit = "percent",
          target_value = 2.0),
  "uden for forventet skala"
)
```
