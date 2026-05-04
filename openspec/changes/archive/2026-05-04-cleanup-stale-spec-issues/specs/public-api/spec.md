## MODIFIED Requirements

### Requirement: Public API specification ownership

The `public-api` capability SHALL govern user-facing API contracts:
exported function signatures, parameter types, return types, attribute
existence, and stability guarantees. It SHALL NOT govern internal
signal-detection logic, fallback-narrative dispatch, or threshold
semantics -- those concerns are owned by `spc-analysis-api`.

When a contract spans both capabilities (e.g.
`bfh_extract_spc_stats(result)$cl_user_supplied`), the `public-api`
spec SHALL document the API surface (presence, type, stable name) and
the `spc-analysis-api` spec SHALL document the underlying meaning
(when the flag is set, what it implies for Anhoej-signal
interpretation).

Cross-references SHALL be expressed as prose ("See spc-analysis-api
Requirement: X for Y") rather than formal links, since OpenSpec does
not support cross-spec linking and prose remains valid across spec
versions.

**Rationale:**
- Stable surface (signatures, return types) and semantic meaning
  (what signals imply) evolve at different rates -- `public-api`
  changes require MAJOR/MINOR bumps, while `spc-analysis-api`
  refinements may be subtler.
- Without explicit ownership boundaries, future changes risk updating
  one spec and forgetting the other, producing inconsistencies.
- Prose cross-references survive renaming and don't fail validation.

#### Scenario: Purpose section identifies ownership

- **WHEN** a contributor reads `openspec/specs/public-api/spec.md`
- **THEN** the `## Purpose` section SHALL state that this capability
  owns user-facing API contracts (signatures, eksport status, return
  types, attribute existence, stability guarantees)
- **AND** the Purpose SHALL explicitly delegate signal-detection
  semantics to `spc-analysis-api`

#### Scenario: Cross-reference rather than duplication

- **WHEN** a `public-api` requirement describes a contract that has
  semantic meaning owned by `spc-analysis-api` (e.g. `cl_user_supplied`
  attribute, target-direction operator parsing)
- **THEN** the `public-api` requirement SHALL state the API surface
  (attribute name, type, when present)
- **AND** SHALL include a prose cross-reference like "See
  spc-analysis-api Requirement: <name> for the underlying signal
  interpretation"
- **AND** SHALL NOT duplicate the semantic interpretation rules
