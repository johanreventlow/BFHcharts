## ADDED Requirements

### Requirement: outliers_recent_count window SHALL be configurable via named constant and report effective window

The package SHALL define a named constant `RECENT_OBS_WINDOW` in `R/globals.R` documenting the recency window used by `bfh_extract_spc_stats.bfh_qic_result()` for `outliers_recent_count`. The stats output SHALL include an `effective_window` field reporting the actual number of observations considered (capped by `n_obs`).

**Rationale:**
- The hardcoded "6" lacks documented rationale and is not derived from Anhøj literature
- Downstream consumers and analysis text need to know the actual window used (especially for short parts)
- A named constant enables future configurability without scattering the magic number
- Boundary correctness (n_obs < window) cannot be verified without exposed effective_window

**Contract:**

| `n_obs` | `effective_window` | `outliers_recent_count` |
|---|---|---|
| 0 | 0 | 0 |
| 1 | 1 | sum(sigma.signal[1:1]) |
| 5 | 5 | sum(sigma.signal[1:5]) |
| 6 | 6 | sum(sigma.signal[1:6]) |
| 7 | 6 | sum(sigma.signal[2:7]) |
| 100 | 6 | sum(sigma.signal[95:100]) |

#### Scenario: short part returns truncated effective_window

- **GIVEN** a `bfh_qic_result` whose latest part has only 3 observations
- **WHEN** `bfh_extract_spc_stats(result)` is called
- **THEN** `stats$effective_window` SHALL equal 3
- **AND** `stats$outliers_recent_count` SHALL equal `sum(sigma.signal[1:3])`

```r
sigma <- c(TRUE, FALSE, TRUE)  # 2 outliers in 3 obs
result <- fixture_bfh_qic_result(sigma, chart_type = "i")
stats <- bfh_extract_spc_stats(result)
expect_equal(stats$effective_window, 3)
expect_equal(stats$outliers_recent_count, 2)
```

#### Scenario: long part caps effective_window at RECENT_OBS_WINDOW

- **GIVEN** a `bfh_qic_result` with 100 observations and outliers only at indexes 1–10
- **WHEN** `bfh_extract_spc_stats(result)` is called
- **THEN** `stats$effective_window` SHALL equal `RECENT_OBS_WINDOW` (6)
- **AND** `stats$outliers_recent_count` SHALL equal 0 (none in last 6)

```r
sigma <- c(rep(TRUE, 10), rep(FALSE, 90))
result <- fixture_bfh_qic_result(sigma, chart_type = "i")
stats <- bfh_extract_spc_stats(result)
expect_equal(stats$effective_window, 6)
expect_equal(stats$outliers_recent_count, 0)
```

#### Scenario: empty sigma.signal returns zero values

- **GIVEN** a part with `sigma.signal = logical(0)` or all NA
- **WHEN** `bfh_extract_spc_stats(result)` is called
- **THEN** `stats$outliers_recent_count` SHALL be 0
- **AND** `stats$effective_window` SHALL be 0 or `min(RECENT_OBS_WINDOW, n_obs)`

#### Scenario: fallback analysis text references effective window

- **GIVEN** a part with 3 observations, all outliers
- **WHEN** `bfh_generate_analysis(result)` is called with fallback (no AI)
- **THEN** the output text SHALL reference "seneste 3 observationer" (NOT hardcoded "6")
- **AND** the count SHALL match `effective_window`

```r
result <- fixture_bfh_qic_result(rep(TRUE, 3), chart_type = "i")
text <- bfh_generate_analysis(result, use_ai = FALSE)
expect_match(text, "seneste 3 observationer", ignore.case = TRUE)
expect_false(grepl("seneste 6 observationer", text))
```
