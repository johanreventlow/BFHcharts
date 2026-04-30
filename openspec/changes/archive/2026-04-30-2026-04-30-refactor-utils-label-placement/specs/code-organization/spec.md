## ADDED Requirements

### Requirement: Label-placement logic SHALL be modularized into named niveau-resolvers

The internal label-placement function `place_two_labels_npc()` SHALL be implemented as a thin orchestrator (≤30 lines) that delegates to named, independently-testable sub-functions:

- `.build_label_proposal()` — constructs initial layout from data
- `.has_collision()` — single predicate for collision detection (used by all niveaus)
- `.resolve_niveau_1_gap_reduction()` — first-pass: shrink gap between labels using `LABEL_PLACEMENT_GAP_REDUCTION_FACTORS`
- `.resolve_niveau_2_flip()` — second-pass: swap top/bottom label positions
- `.resolve_niveau_3_shelf()` — third-pass: shelf placement using `LABEL_PLACEMENT_SHELF_OFFSET_NPC`
- `.finalize_placement()` — convert proposal to NPC output

Magic numbers SHALL be replaced by named constants in `R/globals.R`:

- `LABEL_PLACEMENT_GAP_REDUCTION_FACTORS` (vector of fractional reductions)
- `LABEL_PLACEMENT_FLIP_THRESHOLD_NPC`
- `LABEL_PLACEMENT_SHELF_OFFSET_NPC`

The legacy NPC-only API signature (pre-list-based) SHALL be removed. Any caller using `BFHcharts:::place_two_labels_npc(top_npc, bottom_npc, ...)` directly with positional NPC arguments SHALL receive an error directing them to the list-based form.

**Rationale:**
- The pre-refactor monolith (565 lines, 1 function) was effectively untestable per-niveau — only end-to-end behavior could be validated
- Magic numbers prevent reasoned changes to placement aesthetics; named constants document intent
- Dual-path API (NPC-only + list-based) added complexity without active users; removing the legacy path simplifies maintenance
- Future label-placement features (configurable shelves, user-specified positions) require modular structure
- Visual regression via vdiffr SHALL remain unchanged — this is a refactor, not a behavior change

#### Scenario: Orchestrator delegates to niveau resolvers

- **GIVEN** a label proposal with collision detected
- **WHEN** `place_two_labels_npc()` is called
- **THEN** it SHALL call `.resolve_niveau_1_gap_reduction()` first
- **AND** SHALL only call `.resolve_niveau_2_flip()` if collision persists
- **AND** SHALL only call `.resolve_niveau_3_shelf()` if both prior niveaus fail

#### Scenario: Per-niveau resolver is independently testable

- **GIVEN** a known proposal with gap-reducible collision
- **WHEN** `BFHcharts:::.resolve_niveau_1_gap_reduction(proposal, params)` is called directly in tests
- **THEN** the result SHALL have gap reduced by the first factor in `LABEL_PLACEMENT_GAP_REDUCTION_FACTORS`
- **AND** the test SHALL pass without invoking the full orchestrator

#### Scenario: Visual regression unchanged

- **GIVEN** the 9 vdiffr snapshots in `tests/testthat/_snaps/visual-regression/`
- **WHEN** the test suite runs after refactor
- **THEN** all snapshots SHALL match byte-for-byte (no `.new.svg` files generated)

#### Scenario: Magic numbers named in globals

- **GIVEN** the post-refactor source
- **WHEN** `grep -nE "0\.5|0\.3|0\.15" R/utils_label_placement.R` is run
- **THEN** no hits SHALL appear within `place_two_labels_npc()` or its helpers (literals replaced by named constants)
