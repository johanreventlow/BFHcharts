## MODIFIED Requirements

### Requirement: Recency-window stats SHALL be computed on x-sorted observations

`bfh_extract_spc_stats.bfh_qic_result()` and any recency-window analysis (e.g. `outliers_recent_count`, "last N observations" narrative) SHALL sort `qic_data` by the x-variable before slicing. The result SHALL NOT depend on input row order.

**Rationale:** Healthcare data pipelines frequently produce non-chronological data frames via `bind_rows`, joins, or filter-reassemble patterns. Recency reporting computed on raw row position silently misreports which observations are "recent", driving wrong clinical narratives.

#### Scenario: reversed input produces same result as sorted input

- **GIVEN** a `bfh_qic_result` with 20 observations and signaling concentrated at the most recent 3 dates
- **WHEN** the input data is sorted ascending vs reversed
- **THEN** `bfh_extract_spc_stats(result)$outliers_recent_count` SHALL be identical for both
- **AND** the count SHALL reflect the chronologically-recent signals, not row-position-recent signals

```r
data_asc <- fixture_with_recent_signals()
data_rev <- data_asc[rev(seq_len(nrow(data_asc))), ]
res_asc <- bfh_qic(data_asc, x = date, y = value, chart_type = "i")
res_rev <- bfh_qic(data_rev, x = date, y = value, chart_type = "i")
expect_equal(
  bfh_extract_spc_stats(res_asc)$outliers_recent_count,
  bfh_extract_spc_stats(res_rev)$outliers_recent_count
)
```

#### Scenario: scrambled input produces same result as sorted input

- **GIVEN** a `bfh_qic_result` with 20 observations
- **WHEN** the input data is randomly permuted before passing to `bfh_qic()`
- **THEN** `outliers_recent_count` SHALL equal the value computed on chronologically sorted input

#### Scenario: signaling at start of x-range yields zero recent count

- **GIVEN** observations at x = 1..20 with sigma.signal only at x ∈ {1,2,3}
- **WHEN** the input is sorted, reversed, or scrambled
- **THEN** `outliers_recent_count` SHALL be 0 in all three cases
