## ADDED Requirements

### Requirement: bfh_qic SHALL delegate distinct post-processing responsibilities to internal helpers

The implementation of `bfh_qic()` SHALL isolate data post-processing and
return-routing in dedicated internal helpers so the public entrypoint can
focus on orchestration.

**Rationale:**
- Keeps the package's main chart-construction API readable
- Makes legacy return behavior testable in isolation
- Reduces regression risk in Anhøj signal computation

#### Scenario: Anhøj signal post-processing has a canonical helper

**Given** a `qicharts2::qic()` result data frame
**When** BFHcharts needs to derive `anhoej.signal`
**Then** that logic SHALL live in a dedicated internal helper
**And** `bfh_qic()` SHALL call that helper instead of inlining the full
mutation block

#### Scenario: Return routing has a canonical helper

**Given** `bfh_qic()` has produced `plot`, `summary`, `qic_data`, and
`config`
**When** it must return output for combinations of `return.data` and
`print.summary`
**Then** the routing logic SHALL live in a dedicated internal helper
**And** the helper SHALL preserve the documented legacy return formats and
warnings
