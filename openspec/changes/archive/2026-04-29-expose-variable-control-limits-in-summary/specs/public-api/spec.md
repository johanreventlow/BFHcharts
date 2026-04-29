## ADDED Requirements

### Requirement: Summary SHALL expose variable control limits via min/max columns

When control limits vary across observations within a part (typical for P-charts and U-charts with varying denominators), the summary returned by `bfh_qic()$summary` SHALL include explicit per-part minimum and maximum bounds plus a flag indicating whether limits are constant.

**Rationale:**
- Healthcare-typical P/U charts have variable denominators per period
- Without exposed bounds, downstream consumers cannot distinguish "no limits available" from "limits vary"
- Silent omission can be misread as a stable process when limits actually fluctuated
- Exposing min/max preserves correctness while keeping summary actionable for reports

**Contract:**

| Limit constancy in part | `kontrolgrænser_konstante` | `nedre_/øvre_kontrolgrænse` (scalar) | `*_min`/`*_max` columns |
|---|---|---|---|
| Constant | `TRUE` | populated with single value | absent or NA |
| Variable | `FALSE` | absent or NA | populated with min/max across part |

#### Scenario: constant limits expose scalar columns and TRUE flag

- **GIVEN** an i-chart with constant control limits within a single part
- **WHEN** `format_qic_summary(...)` is called
- **THEN** the summary SHALL contain `nedre_kontrolgrænse` and `øvre_kontrolgrænse` as scalar columns
- **AND** `kontrolgrænser_konstante` SHALL be `TRUE`

```r
data <- data.frame(period = 1:10, value = c(10, 11, 10, 11, 10, 11, 10, 11, 10, 11))
result <- bfh_qic(data, x = period, y = value, chart_type = "i")
expect_true(result$summary$kontrolgrænser_konstante[1])
expect_true("nedre_kontrolgrænse" %in% names(result$summary))
expect_false(is.na(result$summary$nedre_kontrolgrænse[1]))
```

#### Scenario: variable limits expose min/max columns and FALSE flag

- **GIVEN** a P-chart with varying denominators within a part (e.g., `n = c(100, 200, 50)`)
- **WHEN** `format_qic_summary(...)` is called
- **THEN** the summary SHALL contain `nedre_kontrolgrænse_min`, `nedre_kontrolgrænse_max`, `øvre_kontrolgrænse_min`, `øvre_kontrolgrænse_max` columns
- **AND** `kontrolgrænser_konstante` SHALL be `FALSE`
- **AND** the min ≤ max relationship SHALL hold

```r
data <- data.frame(
  period = 1:6,
  events = c(5, 10, 5, 10, 5, 10),
  total = c(100, 200, 50, 200, 100, 50)  # varying n
)
result <- bfh_qic(data, x = period, y = events, n = total,
                  chart_type = "p", y_axis_unit = "percent")
expect_false(result$summary$kontrolgrænser_konstante[1])
expect_true("nedre_kontrolgrænse_min" %in% names(result$summary))
expect_lte(result$summary$nedre_kontrolgrænse_min[1],
           result$summary$nedre_kontrolgrænse_max[1])
```

#### Scenario: backward-compatible reads on constant-limit summaries

- **GIVEN** existing downstream code that reads `summary$nedre_kontrolgrænse` for a constant-limit chart
- **WHEN** `format_qic_summary(...)` is called
- **THEN** the column SHALL be present and populated as before
- **AND** existing tests SHALL pass without modification

#### Scenario: mixed constancy across multi-part summary

- **GIVEN** a multi-part chart where part 1 has constant limits and part 2 has variable limits
- **WHEN** `format_qic_summary(...)` is called
- **THEN** `kontrolgrænser_konstante` SHALL be `TRUE` for part 1 and `FALSE` for part 2
- **AND** scalar columns SHALL be populated for part 1 (NA or absent for part 2)
- **AND** min/max columns SHALL be populated for part 2 (NA for part 1)
