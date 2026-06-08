## ADDED Requirements

### Requirement: bfh_qic SHALL support I-prime chart type

`bfh_qic()` SHALL accept `chart_type = "i'"` as a valid value and render an
I'-control chart (I-prime, Taylor) with control limits adjusted for varying
denominator (subgroup size). The value `"i'"` SHALL be a member of
`CHART_TYPES_EN`.

#### Scenario: I-prime chart accepted as valid chart type

- **WHEN** `bfh_qic(data, x, y, n, chart_type = "i'")` is called with valid input
- **THEN** the call succeeds and returns a `bfh_qic_result` object
- **AND** no "invalid chart_type" error is raised

#### Scenario: Varying denominator yields varying control limits

- **WHEN** an I'-chart is rendered with a non-constant `n` (denominator)
- **THEN** the resulting `ucl` and `lcl` columns are non-constant across rows
- **AND** the centerline `cl` equals `sum(numerator) / sum(denominator)`

### Requirement: I-prime computation SHALL be delegated to pbcharts

I'-chart control limits and Anhoej signals SHALL be computed by
`pbcharts::pbc(chart = "i")`, not re-implemented. The package SHALL NOT
duplicate Taylor's I-prime formula.

#### Scenario: Control limits pass through unchanged

- **WHEN** an I'-chart is computed via `bfh_qic(chart_type = "i'")`
- **THEN** the `cl`, `ucl`, and `lcl` values in the returned `qic_data` are
  `identical` to the values `pbcharts::pbc()` computes for the same input
- **AND** no centerline substitution (e.g. auto-mean) alters them

#### Scenario: pbc output mapped to qic contract

- **WHEN** `pbcharts::pbc()` returns its `$data` data frame
- **THEN** the adapter produces a `qic_data` data frame containing every
  column the downstream render/label/summary pipeline reads
  (`x, y, cl, ucl, lcl, target, part, sigma.signal, anhoej.signal, n, notes`)
- **AND** the `n` column equals pbc's `den` column

### Requirement: I-prime denominator semantics SHALL match ratio-chart model

For `chart_type = "i'"`, `y` SHALL be treated as the numerator and `n` as the
denominator; the plotted value SHALL be `y / n` with denominator-adjusted
limits — the same mental model as p/u-charts, distinct from the `"i"` chart
where `y` is plotted directly. When `n` is omitted, the chart SHALL degenerate
to a classic individuals chart (denominator = 1, constant limits).

#### Scenario: Missing denominator degenerates to individuals

- **WHEN** `bfh_qic(chart_type = "i'")` is called without `n`
- **THEN** the plotted `y` equals the raw numerator (denominator defaults to 1)
- **AND** the control limits are constant
- **AND** an informative `message()` notes the degeneration

### Requirement: pbcharts SHALL be an optional dependency

pbcharts SHALL be declared in `Suggests:` (with a `Remotes:` GitHub pin), not
`Imports:`. A runtime guard SHALL produce a clear error with an install hint
when `chart_type = "i'"` is used but pbcharts is not installed.

#### Scenario: Missing pbcharts produces actionable error

- **WHEN** `bfh_qic(chart_type = "i'")` is called and pbcharts is not installed
- **THEN** a `stop()` error is raised
- **AND** the message instructs the user to run
  `remotes::install_github("anhoej/pbcharts")`

### Requirement: Notes annotations SHALL be supported on I-prime charts

Notes/annotations supplied via the `notes` argument SHALL render on I'-charts
at the correct x-position, aligned by x-value lookup (robust to pbc's internal
row sorting). The assumed cardinality is one note per unique x.

#### Scenario: Annotation renders at correct point under reordered output

- **WHEN** `bfh_qic(chart_type = "i'", notes = v)` is called with a note
  attached to a specific x-value, and pbc sorts its output rows differently
  from input order
- **THEN** the annotation appears at the x-value it was assigned to, not at a
  shifted position

#### Scenario: Unsupported aggregation warns

- **WHEN** a non-default `agg.fun` is supplied with `chart_type = "i'"`
- **THEN** a `warning()` notes that pbc auto-sums numerator/denominator and
  `agg.fun` is ignored
