## Why

`R/utils_label_placement.R` is the package's largest source file (860 lines) and contains a single 565-line function `place_two_labels_npc()` (lines 295–860). The function implements three-level collision resolution (NIVEAU 1: gap reduction, NIVEAU 2: label flip, NIVEAU 3: shelf placement) with no inline algorithm documentation, no extracted sub-functions, and unexplained magic numbers (`0.5`, `0.3`, `0.15` at line 423).

Specifically:
- The roxygen header (~50 lines) documents *trigger conditions* but the implementation body has minimal explanatory comments
- Line-gap enforcement fallback (lines 731–839) contains 100 lines of nested branching
- The function supports both a legacy NPC-only API and a newer list-based API (lines 312–335, 443–475) — dual-path complexity
- All three NIVEAU resolutions share collision detection logic but no extracted predicate

Consequence: the function is effectively untouchable without breaking something. Tests cover behavior end-to-end but cannot isolate which niveau resolved a given placement, making regression diagnosis costly. Future label-placement features (e.g., user-configurable shelf positions) cannot be added cleanly.

## What Changes

This is a **non-behavioral refactor**. No public-API change. No spec change for label placement *behavior*. Changes target maintainability and testability.

### 1. Extract NIVEAU resolvers as named functions

In `R/utils_label_placement.R`, replace the monolith with:

```r
place_two_labels_npc <- function(...) {
  proposal <- .build_label_proposal(top_label, bottom_label, params)
  if (.has_collision(proposal, params)) {
    proposal <- .resolve_niveau_1_gap_reduction(proposal, params)
  }
  if (.has_collision(proposal, params)) {
    proposal <- .resolve_niveau_2_flip(proposal, params)
  }
  if (.has_collision(proposal, params)) {
    proposal <- .resolve_niveau_3_shelf(proposal, params)
  }
  .finalize_placement(proposal, params)
}
```

Each `.resolve_niveau_*()` function is independently testable.

### 2. Remove legacy NPC-only API path

The legacy parameter signature (NPC-only, lines 312–335) is no longer reachable from `bfh_qic()` callers (audit confirms only `add_spc_labels()` calls into it, and `add_spc_labels()` always uses the list-based API).

Delete the legacy code path. If any downstream code (biSPCharts) reaches into `:::place_two_labels_npc()` with the legacy signature, document the breakage in NEWS as an internal-API change (`@keywords internal` was set).

### 3. Name magic numbers in `R/globals.R`

```r
LABEL_PLACEMENT_GAP_REDUCTION_FACTORS <- c(
  initial = 0.5,
  retry_1 = 0.3,
  retry_2 = 0.15
)
LABEL_PLACEMENT_FLIP_THRESHOLD_NPC <- 0.05
LABEL_PLACEMENT_SHELF_OFFSET_NPC <- 0.02
```

Reference from `utils_label_placement.R` instead of literal values.

### 4. Document algorithm

Add a top-of-file roxygen-style block (not a roxygen export — internal block comment) with:

- One-paragraph algorithm overview (proposal → 3-niveau resolution → finalize)
- One paragraph per niveau: trigger condition, transformation, exit criterion
- Brief NPC math explanation (mapping plot units to normalized panel coords)

### 5. Tests

Refactor `tests/testthat/test-fct_add_spc_labels.R` to add per-niveau tests:

- Test that `.resolve_niveau_1_gap_reduction()` returns proposal with reduced gap
- Test that `.resolve_niveau_2_flip()` returns flipped placement
- Test that `.resolve_niveau_3_shelf()` returns shelf-positioned labels
- Test that the orchestrator `place_two_labels_npc()` produces identical output as before refactor for ~10 representative inputs (regression suite)

### 6. Visual regression

Run `vdiffr::manage_cases()` against the existing 9 visual snapshots — none should change. Refactor SHALL be byte-equivalent in chart output.

## Impact

**Affected specs:**
- `code-organization` — ADDED requirement: label-placement modular structure

**Affected code:**
- `R/utils_label_placement.R` — major restructure, no API change
- `R/globals.R` — new constants
- `tests/testthat/test-fct_add_spc_labels.R` — new per-niveau tests added (existing tests unchanged)
- `tests/testthat/_snaps/visual-regression/` — must be byte-equivalent
- `NEWS.md` — entry under `## Interne ændringer`

**Breaking change scope:** None for documented public API. Internal-API users calling `BFHcharts:::place_two_labels_npc()` with the legacy NPC-only signature SHALL see an error; the new signature is the list-based form already used by `add_spc_labels()`.

## Cross-repo impact (biSPCharts)

**Verification:**
```bash
# In biSPCharts:
grep -rn "BFHcharts:::" R/ | grep -i label
```

**Likely affected:** None expected. `place_two_labels_npc()` is `@keywords internal` and not exported.

**biSPCharts version bump:** None.

## Related

- Source: BFHcharts code review 2026-04-30 (Claude finding #1)
- This is preparation for future label-placement features (configurable shelf, user-specified label positions)
