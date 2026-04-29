## ADDED Requirements

### Requirement: Public API SHALL validate denominator column content for ratio charts

The package SHALL validate the content of the denominator column (`n` argument) for ratio chart types (`p`, `pp`, `u`, `up`) to prevent silently misleading rate plots from invalid denominator data.

**Rationale:**
- Healthcare data routinely contain rows with missing or zero denominators (e.g., months with no patients, missing data ingest)
- Without content validation, qicharts2 produces NaN/Inf rates that render as silent gaps or out-of-range points
- For P-charts, `y > n` violates the proportion contract (proportion ≤ 1) but qicharts2 plots it anyway
- Strict failure with row-numbered messages makes invalid data visible to users instead of hidden

**Contract:**

| Chart type | `n` required | Validations on `n` content |
|---|---|---|
| `p`, `pp` | yes | `n > 0`, finite, `y <= n` per row |
| `u`, `up` | yes | `n > 0`, finite |
| `c`, `g`, `t` | no | n/a |
| `i`, `mr`, `run` | no | n/a |
| `xbar`, `s` | no (uses duplicated x as subgrouping) | n/a |

`NA` in individual rows of `n` is permitted (qicharts2 drops them as missing data).

#### Scenario: ratio chart without n rejected

- **GIVEN** `chart_type = "p"` and no `n` argument
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the message SHALL identify which chart types require `n`

```r
data <- data.frame(period = 1:8, events = rep(5L, 8))
expect_error(
  bfh_qic(data, x = period, y = events, chart_type = "p"),
  "requires denominator"
)
```

#### Scenario: zero denominator rejected

- **GIVEN** `chart_type = "p"`, `n = c(100, 0, 100, 100)`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the message SHALL state that `n` must be > 0

```r
data <- data.frame(
  period = 1:4,
  events = c(5L, 0L, 5L, 5L),
  total = c(100L, 0L, 100L, 100L)
)
expect_error(
  bfh_qic(data, x = period, y = events, n = total, chart_type = "p"),
  "must be > 0"
)
```

#### Scenario: negative denominator rejected

- **GIVEN** `chart_type = "u"`, `n = c(100, -5, 100, 100)`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised

#### Scenario: infinite denominator rejected

- **GIVEN** `n` column contains `Inf`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised mentioning Inf/-Inf

#### Scenario: NA in individual rows of n permitted

- **GIVEN** `chart_type = "p"`, `n = c(100, NA, 100, 100)`, `y` valid otherwise
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL succeed
- **AND** qicharts2 SHALL drop the NA row from calculations

```r
data <- data.frame(
  period = 1:4,
  events = c(5L, 5L, 5L, 5L),
  total = c(100L, NA_integer_, 100L, 100L)
)
result <- bfh_qic(data, x = period, y = events, n = total, chart_type = "p")
expect_s3_class(result, "bfh_qic_result")
```

#### Scenario: y greater than n on P-chart rejected with row numbers

- **GIVEN** `chart_type = "p"`, `y = c(5, 6, 200, 8)`, `n = c(100, 100, 100, 100)`
- **WHEN** `bfh_qic(...)` is called
- **THEN** an error SHALL be raised
- **AND** the message SHALL identify the violation row(s) (row 3 in this example)

```r
data <- data.frame(
  period = 1:4,
  events = c(5L, 6L, 200L, 8L),
  total = rep(100L, 4)
)
expect_error(
  bfh_qic(data, x = period, y = events, n = total, chart_type = "p"),
  "y <= n"
)
```

#### Scenario: u-chart allows y > n

- **GIVEN** `chart_type = "u"`, `y = c(50, 60, 200)`, `n = c(100, 100, 100)`
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL succeed
- **AND** rates can exceed 1 (events per unit, not proportion)

```r
data <- data.frame(
  period = 1:3,
  events = c(50L, 60L, 200L),
  exposure = rep(100L, 3)
)
result <- bfh_qic(data, x = period, y = events, n = exposure, chart_type = "u")
expect_s3_class(result, "bfh_qic_result")
```

#### Scenario: xbar chart skips n validation

- **GIVEN** `chart_type = "xbar"` with subgroup data (duplicated x values, no n)
- **WHEN** `bfh_qic(...)` is called
- **THEN** the function SHALL NOT validate denominator content
- **AND** the function SHALL succeed
