## ADDED Requirements

### Requirement: Tests SHALL mock external process calls via injection

Test suites touching Typst/Quarto compilation SHALL use the `.system2`
dependency-injection hook to avoid spawning external processes, unless
explicitly marked as integration tests gated behind an environment variable.

**Rationale:**
- Default `devtools::test()` must be reproducible on any developer machine
- External process failures pollute unit test results with environmental noise

#### Scenario: Unit tests do not require Quarto binary

**Given** a fresh R environment without Quarto installed
**When** `devtools::test()` runs the default unit test subset
**Then** all Typst/Quarto-related unit tests SHALL pass using mocked `.system2`
**And** no test SHALL fail due to missing Quarto binary
