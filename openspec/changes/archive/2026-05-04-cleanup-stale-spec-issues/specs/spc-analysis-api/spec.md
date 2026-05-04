## MODIFIED Requirements

### Requirement: SPC analysis API specification ownership

The `spc-analysis-api` capability SHALL govern internal
signal-detection logic and analysis-text generation: Anhoej rule
interpretation, fallback-narrative dispatch, threshold semantics,
target-direction parsing, and percent-target normalization rules.
It SHALL NOT govern exported API surfaces (function signatures,
return types, attribute existence) -- those concerns are owned by
`public-api`.

When a contract spans both capabilities, this spec SHALL document the
underlying meaning (when a signal fires, what semantic interpretation
applies, how thresholds are evaluated) without restating the API
surface details documented in `public-api`.

Cross-references SHALL be expressed as prose ("See public-api
Requirement: X for the API contract") rather than formal links.

**Rationale:**
- Anhoej rule interpretation, narrative-text dispatch, and target-
  direction semantics evolve as the package gains nuance from clinical
  feedback -- these refinements are typically additive or
  clarifying, not breaking.
- API stability concerns (does the function exist? what does it
  return?) belong with the user-facing surface contract.
- Without explicit ownership boundaries, requirements describing the
  same thing from different angles drift apart over time.

#### Scenario: Purpose section identifies ownership

- **WHEN** a contributor reads
  `openspec/specs/spc-analysis-api/spec.md`
- **THEN** the `## Purpose` section SHALL state that this capability
  owns internal signal-detection logic, fallback-narrative dispatch,
  and threshold/target semantics
- **AND** the Purpose SHALL explicitly delegate exported API surface
  contracts (signatures, return types, attribute existence) to
  `public-api`

#### Scenario: Cross-reference rather than duplication

- **WHEN** an `spc-analysis-api` requirement describes signal
  semantics whose API surface is governed by `public-api` (e.g.
  `cl_user_supplied` attribute meaning, custom-`cl` Anhoej-signal
  caveat)
- **THEN** the `spc-analysis-api` requirement SHALL state the
  semantic meaning (what the signal implies for interpretation)
- **AND** SHALL include a prose cross-reference like "See public-api
  Requirement: <name> for the API surface contract"
- **AND** SHALL NOT duplicate signature or return-type details
