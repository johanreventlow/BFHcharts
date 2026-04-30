## ADDED Requirements

### Requirement: bfh_export_pdf SHALL default to strict-baseline mode

`bfh_export_pdf()` and `bfh_create_export_session()` SHALL accept a parameter `strict_baseline` defaulting to `TRUE`. When `strict_baseline = TRUE`:

- `bfh_qic_result$config$freeze < MIN_BASELINE_N` (8) SHALL produce an error before render
- Any phase in the result containing fewer than `MIN_BASELINE_N` data points SHALL produce an error before render
- Error messages SHALL identify the offending freeze value or phase index, reference `MIN_BASELINE_N`, and explicitly mention `strict_baseline = FALSE` as the documented opt-out

When `strict_baseline = FALSE`, the existing warning-only behavior is preserved.

`bfh_qic()` (interactive direct call) is unaffected — it continues to emit warnings rather than errors. The strict mode applies only to the export pipeline where the result lands in PDFs that may bypass console oversight.

**Rationale:**
- PDFs from `bfh_export_pdf()` typically land on quality-improvement leadership desks where the original R warning never reaches a human reviewer
- Anhøj & Olesen (2014) recommend ≥8 baseline points for reliable run/crossing detection; charts with shorter baselines have tight but statistically unreliable control limits
- Hard error in the export path forces the operator to acknowledge short-baseline output explicitly via `strict_baseline = FALSE`
- Interactive `bfh_qic()` retains warning behavior because the analyst is present to make an informed decision

**Inheritance:**
- `bfh_create_export_session(strict_baseline = X)` SHALL set the session default
- `bfh_export_pdf(..., session = s)` SHALL use `s$strict_baseline` unless an explicit per-call value is provided
- Per-call value overrides session value

#### Scenario: Default export errors on short freeze

- **GIVEN** a `bfh_qic_result` constructed with `freeze = 5` (below `MIN_BASELINE_N = 8`)
- **WHEN** `bfh_export_pdf(x, "/tmp/out.pdf", metadata = list())` is called with default arguments
- **THEN** an error SHALL be raised before any render
- **AND** the error message SHALL state `freeze = 5`, reference `MIN_BASELINE_N`, and mention `strict_baseline = FALSE` as opt-out

#### Scenario: Explicit opt-out succeeds with warning

- **GIVEN** a `bfh_qic_result` with `freeze = 5`
- **WHEN** `bfh_export_pdf(x, "/tmp/out.pdf", strict_baseline = FALSE)` is called
- **THEN** the export SHALL succeed
- **AND** a warning SHALL be emitted noting the short baseline

#### Scenario: Phase with too few points errors

- **GIVEN** a `bfh_qic_result` where one phase has 4 data points
- **WHEN** `bfh_export_pdf(x, "/tmp/out.pdf")` is called with default arguments
- **THEN** an error SHALL be raised identifying the offending phase index

#### Scenario: Session inheritance applies

- **GIVEN** `s <- bfh_create_export_session(strict_baseline = FALSE)`
- **WHEN** `bfh_export_pdf(x_short_baseline, ..., session = s)` is called without per-call override
- **THEN** the export SHALL succeed (session default flows through)

#### Scenario: Per-call override beats session

- **GIVEN** `s <- bfh_create_export_session(strict_baseline = FALSE)`
- **WHEN** `bfh_export_pdf(x_short_baseline, ..., session = s, strict_baseline = TRUE)` is called
- **THEN** an error SHALL be raised (per-call wins)

#### Scenario: Interactive bfh_qic preserves warning behavior

- **GIVEN** a direct call `bfh_qic(data, x, y, freeze = 5)` (no export pipeline)
- **WHEN** the call is made
- **THEN** a warning SHALL be emitted
- **AND** the call SHALL succeed (no error)
