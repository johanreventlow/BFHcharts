## ADDED Requirements

### Requirement: Package SHALL export bfh_qic_stats for compute-only SPC results

The package SHALL export `bfh_qic_stats()`, which computes the same SPC
statistics as `bfh_qic()` without building a plot. It SHALL accept the
computation parameters of `bfh_qic()` (`data`, `x`, `y`, `n`, `chart_type`,
`y_axis_unit`, `part`, `freeze`, `exclude`, `cl`, `multiply`, `agg_fun`,
`target_value`, `notes`) and SHALL return an object of class
`bfh_qic_stats` with components `summary`, `qic_data` and `config`.

**Rationale:**
- Callers that only need the numbers (e.g. signal scanning over thousands of
  diagrams) currently pay for plot construction and label placement.
- A separate class keeps the `bfh_qic_result` invariant (it always carries a
  ggplot) and is rejected by export functions that require a plot.

#### Scenario: Compute-only result has the same numbers as bfh_qic

- **WHEN** `bfh_qic_stats(data, x, y, ...)` and `bfh_qic(data, x, y, ...)`
  are called with the same computation arguments
- **THEN** `bfh_qic_stats(...)$summary` is `identical()` to
  `bfh_qic(...)$summary`
- **AND** `bfh_qic_stats(...)$qic_data` is `identical()` to
  `bfh_qic(...)$qic_data`
- **AND** this holds for every chart type in `CHART_TYPES_EN` and with
  `part`, `freeze`, `exclude`, a user-supplied `cl`, a denominator, and a
  run chart that triggers auto-mean substitution

#### Scenario: No plot is built

- **WHEN** `bfh_qic_stats()` is called
- **THEN** the returned object has no `plot` component
- **AND** `is_bfh_qic_result()` returns `FALSE` for it

#### Scenario: SPC statistics extraction works on the compute-only result

- **WHEN** `bfh_extract_spc_stats(bfh_qic_stats(...))` is called
- **THEN** it returns the same list as
  `bfh_extract_spc_stats(bfh_qic(...))` for the same arguments

### Requirement: bfh_qic output SHALL be unchanged by the compute/render split

Splitting `bfh_qic()` into a shared computation phase and a render phase
SHALL NOT change the value, warnings or messages `bfh_qic()` produces.

#### Scenario: Existing visual snapshots unchanged

- **WHEN** the visual regression suite runs after the split
- **THEN** every existing snapshot matches without being re-recorded
