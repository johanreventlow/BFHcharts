## ADDED Requirements

### Requirement: bfh_export_pdf SHALL follow the orchestrator-helper pattern

`bfh_export_pdf()` SHALL be refactored to act as a thin orchestrator delegating distinct responsibilities to internal helpers, mirroring the pattern established by `bfh_qic()` (see `refactor-bfh_qic-orchestrator` change). Function body SHOULD target ≤ 80 lines excluding Roxygen.

**Rationale:**
- Current 330-line implementation mixes validation, IO, security checks, plot manipulation, Typst generation, and Quarto execution
- Security check ordering is currently spread across the function — risk of regression when modifying any single step
- Companion to `bfh_qic()` refactor for consistency

**Pattern:**

```
bfh_export_pdf(args) [≤ 80 lines]
  ├── validate_bfh_export_pdf_inputs(args)
  ├── metadata <- prepare_export_metadata(x, metadata, auto_analysis, use_ai, ...)
  ├── temp_dir <- prepare_temp_workspace(batch_session)
  ├── plot <- prepare_export_plot(x)
  ├── chart_svg <- export_chart_svg(plot, temp_dir, dpi)
  ├── typst_file <- compose_typst_document(chart_svg, metadata, temp_dir, ...)
  ├── compile_pdf_via_quarto(typst_file, output, font_path)
  └── invisible(x)
```

**Security ordering preserved:**
1. Validation (no IO yet)
2. File system operations
3. Quarto execution
4. Cleanup (registered before any allocation)

#### Scenario: orchestrator under target size after refactor

- **GIVEN** the refactored `bfh_export_pdf()` function
- **WHEN** the function body is measured (excluding Roxygen, blank lines)
- **THEN** the body SHALL be ≤ 80 lines

#### Scenario: helpers callable in isolation

- **GIVEN** any of the new helpers
- **WHEN** called with appropriate arguments
- **THEN** the helper SHALL produce its expected output without invoking the full orchestrator

#### Scenario: security check ordering preserved

- **GIVEN** the refactored function
- **WHEN** an invalid `output` path with shell metachars is passed
- **THEN** validation SHALL fail BEFORE any tempdir is created
- **AND** no Quarto invocation SHALL occur

#### Scenario: public API unchanged after refactor

- **GIVEN** existing tests calling `bfh_export_pdf()` from any caller
- **WHEN** running `devtools::test()` after the refactor
- **THEN** all pre-existing tests SHALL pass without modification
