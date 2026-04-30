## 1. Audit

- [x] 1.1 Confirm only callsite for `place_two_labels_npc()` is `add_spc_labels()` (`grep -rn "place_two_labels_npc" R/`)
- [x] 1.2 Confirm legacy NPC-only API path is unreachable from public API (BFHcharts: 8 internal test calls; biSPCharts: also internal `:::` test calls)
- [x] 1.3 Audit biSPCharts for `BFHcharts:::place_two_labels_npc` references (FOUND in `tests/testthat/test-label-placement-core.R` -- legacy signature in active use; option 3 chosen: keep legacy signature, defer removal)

## 2. Constants extraction

- [x] 2.1 Add to `R/globals.R`:
  - `LABEL_PLACEMENT_GAP_REDUCTION_FACTORS` (replaces 0.5, 0.3, 0.15)
  - `LABEL_PLACEMENT_TIGHT_LINES_THRESHOLD_FACTOR` (replaces 0.5)
  - `LABEL_PLACEMENT_COINCIDENT_THRESHOLD_FACTOR` (replaces 0.1)
  - `LABEL_PLACEMENT_SHELF_CENTER_THRESHOLD` (replaces 0.5)
- [x] 2.2 Replace literal numbers in `utils_label_placement.R` with named constants

## 3. Function decomposition

(Adapted from spec sketch to match actual code shape: NIVEAU cascade is a sub-branch, not the main path. Decomposed only the cascade.)

- [x] 3.1 Extract `.verify_line_gap_npc()` -- standalone version of inline closure
- [x] 3.2 Extract `.try_niveau_1_gap_reduction()` -- gap-reduction collision resolution
- [x] 3.3 Extract `.try_niveau_2_flip()` -- 3-strategy label-flip
- [x] 3.4 Extract `.apply_niveau_3_shelf()` -- last-resort shelf placement
- [x] 3.7 Rewrite NIVEAU cascade in `place_two_labels_npc()` to orchestrate via helpers

## 4. Legacy API removal (DEFERRED)

- [ ] 4.1 Delete legacy NPC-only signature path (DEFERRED -- biSPCharts depends on it via `BFHcharts:::place_two_labels_npc(yA_npc=, yB_npc=, label_height_npc=)`. Legacy signature retained; removal requires separate cross-repo coordination change.)
- [ ] 4.2 N/A (legacy still supported)
- [ ] 4.3 N/A (no removal happened)

## 5. Documentation

- [x] 5.1 Top-of-file algorithm block in `R/utils_label_placement.R` (NIVEAU 1/2/3 summary + invocation context)
- [x] 5.2 Per-niveau roxygen with trigger/transformation/exit semantics
- [x] 5.3 NPC math implicit in helper docs (low-NPC = bottom of panel, high-NPC = top)

## 6. Tests

- [x] 6.1 New `tests/testthat/test-niveau-resolvers.R` (14 tests, 30 assertions): 3 verify_line_gap, 3 niveau_1, 3 niveau_2, 4 niveau_3, 1 sanity
- [x] 6.2 Byte-equivalence regression: directly compared `.new.svg` output between inline and helper-decomposed orchestrator -- 9/9 visual snapshots IDENTICAL
- [x] 6.3 vdiffr full-suite run: all 9 visual snapshots pass after the refactor. (Initial filtered-test run failures observed earlier traced to test-ordering / vdiffr `.new.svg` retention; full-suite ordering is the canonical CI pathway.)

## 7. Verification

- [x] 7.1 `devtools::test()` full suite: 2847 PASS / 0 FAIL / 47 SKIP / 11 WARN (all warnings pre-existing)
- [x] 7.2 `devtools::check()` (2026-04-30): 0 errors, 0 warnings, 1 unrelated NOTE ("unable to verify current time")
- [x] 7.3 vdiffr 9 visual snapshots passed in full suite (filtered run failures observed earlier resolved by full-suite test ordering / vdiffr snapshot behavior)
- [x] 7.4 Profile skipped (pure code-motion refactor, helper invocation overhead negligible)

## 8. Release

- [x] 8.1 Rolled into 0.12.0 development cycle
- [x] 8.2 NEWS entry under `## Interne ændringer`

Tracking: GitHub Issue #TBD
