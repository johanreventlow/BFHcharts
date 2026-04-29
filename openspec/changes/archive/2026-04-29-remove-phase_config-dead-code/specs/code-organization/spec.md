## ADDED Requirements

### Requirement: Internal infrastructure SHALL NOT carry unused scaffolding

The package SHALL NOT carry constructor functions, S3 methods, or function parameters that have no production call sites. Internal scaffolding for "future API" SHALL either be (a) wired into an active code path within one minor version, or (b) removed.

**Rationale:**
- Reserved-but-unused infrastructure carries maintenance and review weight without delivering value
- "Future API" tends to drift from current patterns and become incompatible by the time it would be used
- Easier to re-add when actually needed than to maintain dead code under test

**Examples of removed scaffolding:**
- `phase_config()` constructor + `print.phase_config()` method (was reserved, never wired)
- `bfh_spc_plot(phase = NULL)` parameter (read by no code path)

#### Scenario: dead constructor removed

- **GIVEN** an internal constructor function with zero production call sites (verified via grep)
- **WHEN** the next minor release is prepared
- **THEN** the constructor SHALL be either wired into a production code path OR removed entirely
- **AND** removal SHALL include constructor, related S3 methods, NAMESPACE entries, tests, and Rd files

#### Scenario: dead parameter removed from internal function

- **GIVEN** a function parameter that is accepted but never read in the function body
- **WHEN** the parameter is identified during refactor or review
- **THEN** the parameter SHALL be removed from the signature
- **AND** the removal SHALL be safe because the function is internal (not exported in NAMESPACE)
