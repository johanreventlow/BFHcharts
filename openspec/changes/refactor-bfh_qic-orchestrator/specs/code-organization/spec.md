## ADDED Requirements

### Requirement: Primary public entry points SHALL be thin orchestrators

Primary public entry points (`bfh_qic()`, `bfh_export_pdf()`, `bfh_export_png()`) SHALL act as thin orchestrators that delegate distinct responsibilities (validation, computation, rendering, IO, return-routing) to internal helpers. Orchestrator function bodies SHOULD target ≤ 80 lines excluding Roxygen.

**Rationale:**
- Single function carrying 380+ lines mixes 8+ concerns and is impossible to test in isolation
- Failure localization is slow when one giant function breaks
- Architectural pattern documented for future entry points

**Pattern:**

```
bfh_qic(args) [≤ 80 lines]
  ├── validate_bfh_qic_inputs(args)
  ├── qic_args <- build_qic_args(args, validated_columns)
  ├── qic_data <- invoke_qicharts2(qic_args)
  ├── viewport_info <- compute_viewport_base_size(args)
  ├── plot <- render_bfh_plot(qic_data, args, viewport_info)
  ├── plot <- apply_spc_labels_to_export(plot, qic_data, args, viewport_info)
  ├── summary <- format_qic_summary(qic_data, args$y_axis_unit)
  └── build_bfh_qic_return(qic_data, plot, summary, config, args$return.data, args$print.summary)
```

#### Scenario: orchestrator under target size after refactor

- **GIVEN** the refactored `bfh_qic()` function in `R/create_spc_chart.R`
- **WHEN** the function body is measured (excluding Roxygen, blank lines)
- **THEN** the body SHALL be ≤ 80 lines

#### Scenario: helpers callable in isolation

- **GIVEN** any of the new helpers (`validate_bfh_qic_inputs`, `build_qic_args`, etc.)
- **WHEN** called with appropriate arguments in isolation
- **THEN** the helper SHALL produce its expected output without invoking the full orchestrator
- **AND** unit tests SHALL exercise each helper independently

```r
# Example — validation helper testable alone
expect_error(
  validate_bfh_qic_inputs(args = list(chart_type = "invalid_type", ...)),
  "chart_type must be"
)
```

#### Scenario: public API unchanged after refactor

- **GIVEN** existing tests calling `bfh_qic()` from any caller
- **WHEN** running `devtools::test()` after the refactor
- **THEN** all pre-existing tests SHALL pass without modification
- **AND** `bfh_qic()` signature, return values, and behavior SHALL be identical
