## ADDED Requirements

### Requirement: AI-driven analysis SHALL emit an audit message at egress

When `bfh_generate_analysis()` is called with `use_ai = TRUE`, the function SHALL emit a `message()` at the point of invoking `BFHllm::bfhllm_spc_suggestion()`. The message SHALL:
- include a stable, log-grep-able tag (e.g. `[BFHcharts/AI]`)
- name the fields being transmitted (e.g. x, y, n, chart_type, hospital, department)
- name the `use_rag` value

The message SHALL be suppressible via `options(BFHcharts.suppress_ai_audit_message = TRUE)`.

**Rationale:** Hospital deployments need an audit trail when patient-context SPC data is sent to an external LLM. The current opt-in is correct (use_ai = FALSE default), but no runtime signal exists to confirm whether the AI path was exercised. A `message()` provides minimal-cost observability without blocking the feature.

#### Scenario: AI branch emits audit message

- **GIVEN** `bfh_generate_analysis(result, use_ai = TRUE)` with BFHllm installed
- **WHEN** the call enters the AI branch
- **THEN** a `message()` SHALL be captured by `withCallingHandlers`
- **AND** the message SHALL contain the tag `[BFHcharts/AI]`
- **AND** SHALL list the fields transmitted

```r
result <- bfh_qic(simple_data, x, y, chart_type = "i")
msg <- capture_messages(
  bfh_generate_analysis(result, use_ai = TRUE)
)
expect_match(paste(msg, collapse = ""), "\\[BFHcharts/AI\\]")
expect_match(paste(msg, collapse = ""), "fields:.*x.*y.*n")
```

#### Scenario: opt-out suppresses message

- **GIVEN** `options(BFHcharts.suppress_ai_audit_message = TRUE)`
- **WHEN** the AI branch is invoked
- **THEN** no `[BFHcharts/AI]`-tagged message SHALL be emitted

#### Scenario: non-AI branch emits no audit message

- **GIVEN** `bfh_generate_analysis(result, use_ai = FALSE)` (default)
- **WHEN** the call executes
- **THEN** no `[BFHcharts/AI]`-tagged message SHALL be emitted
