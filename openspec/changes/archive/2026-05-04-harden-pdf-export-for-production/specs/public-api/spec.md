## ADDED Requirements

### Requirement: Summary SHALL carry `cl_user_supplied` attribute

The summary returned by `bfh_qic()$summary` SHALL carry an attribute
`cl_user_supplied` (logical scalar) reflecting whether the caller
supplied a non-NULL `cl` argument to `bfh_qic()`.

**Rationale:**
- Downstream consumers (PDF rendering, biSPCharts UI, analysis text)
  need to know whether the centerline is data-derived or user-supplied
  WITHOUT introspecting the entire `config` slot.
- An attribute (rather than a column) preserves backward compatibility
  for column-iteration patterns (e.g. `lapply(summary, ...)`,
  `dplyr::summarise(across(...))`).
- Scalar (rather than per-phase vector) matches the API: `cl` is a
  single global value supplied via one parameter; per-phase encoding
  would suggest distinct per-phase user-cl values that the API does not
  support.

**Encoding:**
- `attr(summary, "cl_user_supplied") = TRUE` when user passed
  `bfh_qic(..., cl = <non-NULL>)`.
- `attr(summary, "cl_user_supplied") = FALSE` when user did not pass
  `cl` (default; centerline is data-estimated).

**Consumer pattern:**
- Safe check: `isTRUE(attr(result$summary, "cl_user_supplied"))`.
- The attribute SHALL also be exposed via
  `bfh_extract_spc_stats(result)$cl_user_supplied` for discovery
  parity with `is_run_chart` and other surfaced flags.

#### Scenario: Attribute set to TRUE when cl supplied

- **GIVEN** `bfh_qic(data, x, y, chart_type = "i", cl = 50)` is called
- **WHEN** the result is returned
- **THEN** `attr(result$summary, "cl_user_supplied")` SHALL be `TRUE`
- **AND** `isTRUE(attr(result$summary, "cl_user_supplied"))` SHALL
  evaluate to `TRUE`

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i", cl = 50)
expect_true(isTRUE(attr(result$summary, "cl_user_supplied")))
```

#### Scenario: Attribute set to FALSE when cl absent

- **GIVEN** `bfh_qic(data, x, y, chart_type = "i")` is called (no `cl`)
- **WHEN** the result is returned
- **THEN** `attr(result$summary, "cl_user_supplied")` SHALL be `FALSE`

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i")
expect_identical(attr(result$summary, "cl_user_supplied"), FALSE)
```

#### Scenario: bfh_extract_spc_stats surfaces the attribute

- **GIVEN** a `bfh_qic_result` with `cl` supplied
- **WHEN** `bfh_extract_spc_stats(result)` is called
- **THEN** the returned list SHALL include
  `cl_user_supplied = TRUE`

```r
result <- bfh_qic(data, x = month, y = value, chart_type = "i", cl = 50)
stats <- bfh_extract_spc_stats(result)
expect_true(stats$cl_user_supplied)

result_no_cl <- bfh_qic(data, x = month, y = value, chart_type = "i")
stats_no_cl <- bfh_extract_spc_stats(result_no_cl)
expect_identical(stats_no_cl$cl_user_supplied, FALSE)
```

#### Scenario: Attribute survives return.data = TRUE path

- **GIVEN** `bfh_qic(..., cl = 50, return.data = TRUE)` is called
- **WHEN** the raw qic_data data.frame is returned
- **THEN** `attr(result, "cl_user_supplied")` SHALL also be `TRUE`
  (attribute attaches to the returned data.frame for discovery
  parity with the S3 path)

```r
qic <- bfh_qic(data, x = month, y = value, chart_type = "i",
               cl = 50, return.data = TRUE)
expect_true(isTRUE(attr(qic, "cl_user_supplied")))
```
