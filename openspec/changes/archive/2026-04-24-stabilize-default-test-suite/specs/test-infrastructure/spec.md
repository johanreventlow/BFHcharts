## ADDED Requirements

### Requirement: Default test suite SHALL run cleanly without external dependencies

Running `devtools::test()` on a fresh developer machine SHALL pass without
requiring Quarto, Mari font, pandoc, or any other external binary — heavy
tests SHALL skip gracefully.

**Rationale:**
- Reproducibility is foundational for TDD
- Environmental divergence between CI and local breaks trust in the runner
- "Works on my machine" regressions become systematic otherwise

**Environment variables controlling tiers:**
- `BFHCHARTS_RUN_RENDER_TESTS=true` enables PDF/Quarto/visual render tests
- `BFHCHARTS_RUN_FULL_TESTS=true` enables full end-to-end export chains

#### Scenario: Default run on minimal environment passes

**Given** a machine without Quarto, without Mari font, and with neither env-var set
**When** `devtools::test()` is invoked
**Then** all tests SHALL either pass or skip
**And** zero tests SHALL fail or error

#### Scenario: Render tier runs full render tests

**Given** Quarto is installed and `BFHCHARTS_RUN_RENDER_TESTS=true`
**When** `devtools::test()` is invoked
**Then** render/PDF/Quarto tests SHALL execute (not skip)
**And** tests SHALL pass

### Requirement: Test skip helpers SHALL be canonical and documented

The package test suite SHALL provide a single canonical set of skip helpers
centralized in `tests/testthat/helper-skip.R`:

- `skip_if_not_render_test()` — gate on `BFHCHARTS_RUN_RENDER_TESTS`
- `skip_if_not_full_test()` — gate on `BFHCHARTS_RUN_FULL_TESTS`
- `skip_if_no_quarto()` — binary check
- `skip_if_no_mari_font()` — font availability

All render/Quarto/visual tests SHALL call the appropriate helper at the top
of the `test_that()` block.

#### Scenario: Helper file is the single source of truth

**Given** the package test infrastructure
**When** a developer searches for skip logic
**Then** the canonical helpers SHALL reside in `tests/testthat/helper-skip.R`
**And** no test SHALL define its own bespoke skip logic for these categories
