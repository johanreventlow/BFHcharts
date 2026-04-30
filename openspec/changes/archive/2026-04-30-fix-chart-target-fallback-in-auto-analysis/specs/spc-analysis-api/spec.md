## MODIFIED Requirements

### Requirement: bfh_build_analysis_context SHALL resolve target via fallback chain

The function SHALL resolve the analysis context's target value/direction/display by checking, in order:

1. `metadata$target` (explicit caller-provided target — highest priority)
2. `x$config$target_text` (target string supplied via `bfh_qic(target = "≥ 90%")`)
3. `x$config$target_value` (numeric target supplied via `bfh_qic(target = 0.9)`)
4. NULL (no target — `target_value`, `target_direction`, `target_display` all NULL)

When the resolved value is a character string, it SHALL pass through `resolve_target()` for operator parsing (`<=`, `>=`, `<`, `>`, `≤`, `≥`) so `target_direction` is derived. When resolved to a numeric value, `target_direction` SHALL be NULL.

After resolution, `.normalize_percent_target()` SHALL apply when `y_axis_unit == "percent"` so the analysis text compares correctly to centerline values on the data scale.

**Rationale:**
- A target supplied to `bfh_qic()` already drives a target line on the chart. The analysis text must include target-fulfilment assessment for the same target — otherwise PDFs show the line without the corresponding interpretation.
- Without the fallback, callers must duplicate target in two places (chart config + metadata list), which is error-prone in batch workflows.
- The order metadata-first preserves existing override behavior for callers that intentionally analyze against a different target than the chart line.

#### Scenario: metadata-only target preserved

- **GIVEN** `metadata = list(target = "≥ 95%")` and `x$config$target_text = NULL`, `x$config$target_value = NULL`
- **WHEN** `bfh_build_analysis_context(x, metadata)` is called
- **THEN** the result `target_value` SHALL equal 0.95 after percent-normalization
- **AND** `target_direction` SHALL equal `">="`

#### Scenario: chart target_text used when metadata target absent

- **GIVEN** `x$config$target_text = "≥ 90%"`, `x$config$target_value = NULL`, and `metadata$target` not provided
- **WHEN** `bfh_build_analysis_context(x, metadata = list())` is called
- **THEN** `target_value` SHALL equal 0.90
- **AND** `target_direction` SHALL equal `">="`
- **AND** `target_display` SHALL equal `"≥ 90%"`

#### Scenario: chart target_value used when metadata target absent

- **GIVEN** `x$config$target_value = 0.85`, `x$config$target_text = NULL`, and `metadata$target` not provided
- **WHEN** `bfh_build_analysis_context(x, metadata = list())` is called
- **THEN** `target_value` SHALL equal 0.85
- **AND** `target_direction` SHALL be NULL

#### Scenario: metadata target overrides chart config

- **GIVEN** `metadata = list(target = "≤ 50%")` and `x$config$target_text = "≥ 90%"`
- **WHEN** `bfh_build_analysis_context(x, metadata)` is called
- **THEN** `target_value` SHALL reflect 0.50
- **AND** `target_direction` SHALL equal `"<="`

#### Scenario: no target anywhere

- **GIVEN** `metadata$target` NULL and both `x$config$target_text` and `x$config$target_value` NULL
- **WHEN** `bfh_build_analysis_context(x, metadata = list())` is called
- **THEN** `target_value`, `target_direction`, and `target_display` SHALL all be NULL
- **AND** subsequent analysis text SHALL omit goal-assessment phrases
