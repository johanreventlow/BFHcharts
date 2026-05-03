## Context

`add_right_labels_marquee()` (R/utils_add_right_labels_marquee.R, ~510 lines) is the largest single function in the package. It is the heart of the labeling pipeline that ships with every PDF/PNG export and every `bfh_qic()` invocation. The function is invoked from two places:

1. `apply_spc_labels_to_export()` — render path (export pipeline)
2. `add_spc_labels()` — interactive/preview path

The function has accumulated 11 distinct responsibilities over time as the labeling system evolved through:

- v0.10.x: initial marquee-based label rendering
- v0.12.0: NIVEAU-cascade collision avoidance
- v0.13.0: 3-layer split of `place_two_labels_npc()` (sister function)
- v0.14.x: device-leak hardening + viewport-vs-fallback strategy

The 3-layer split that succeeded for `place_two_labels_npc()` (validate -> resolve -> strategy) is the proven template. The existing inline comments in `add_right_labels_marquee()` already partition the function into the three layers we want; the comments document the seams. Verbose-logging blocks (9 `if (verbose) message(...)` calls) currently spread across the function will follow each helper into its new home.

Constraints:

- **Behavior must not change.** Visual regression baselines (PR #279, freshly refreshed in v0.14.2) are the authoritative correctness gate. Any pixel diff from refactor = regression.
- **biSPCharts is a `:::` consumer** of `add_spc_labels()`, not of `add_right_labels_marquee()` directly. Internal helper signature changes are allowed; public-facing path through `add_spc_labels()` must remain stable.
- **Pre-push hook (`PREPUSH_MODE=full`) runs visual regression** with `NOT_CRAN=true`. Refactor cannot be merged unless the hook passes without baseline updates.

## Goals / Non-Goals

**Goals:**

- Decompose `add_right_labels_marquee()` into orchestrator (≤120 lines) + 3 named helpers along existing comment-partition lines.
- Each helper has a single responsibility: geometry resolution, device acquisition, label-height measurement.
- Each helper accepts injected dependencies (config, device, style) for unit-testability without device side effects.
- Verbose-logging messages remain (gated by `verbose = FALSE` default per Fase 1B work) and travel with their helper.
- Zero behavioral change. Same output bytes for every test scenario. Visual regression: zero diff.

**Non-Goals:**

- Restructuring the NIVEAU-cascade in `place_two_labels_npc()` (already done in v0.13.0).
- Replacing the marquee rendering library (out of scope; would be a separate proposal).
- Performance optimization (M10/M11 from review remain in Fase 5 backlog).
- Public API changes. `add_spc_labels()` signature stays.
- Adding new features (target arrows, multi-line labels, etc).
- Splitting `add_right_labels_marquee()` into a separate file. Helpers live in the same file under shared header comment.

## Decisions

### Decision 1: 3-layer split mirroring `place_two_labels_npc()`

**Choice:** Three private helpers prefixed `.`:

1. `.resolve_label_geometry(label_size, lineheight_factor, marquee_size_factor, header_pt, value_pt, gap_line, gap_labels, pad_top, pad_bot)` → returns named list `(scale_factor, header_size, value_size, lineheight, gap_line, gap_labels, pad_top, pad_bot, cfg)`. Pure function. Replaces lines ~137-170. Reuses the `resolve_label_size()` helper extracted in v0.14.3.

2. `.acquire_device_for_measurement(viewport_width, viewport_height, panel_width_inches, fallback_width = 10, fallback_height = 7.5, verbose = FALSE)` → returns list `(device_size, panel_height_inches, temp_device_opened, cleanup_fn)`. Side-effect at this layer: opens fallback device when viewport unavailable. Returns `cleanup_fn` so orchestrator can `withr::defer(cleanup_fn())`. Replaces lines ~200-315.

3. `.measure_label_heights(textA, textB, style, panel_height_inches, device_size, marquee_height_estimator = estimate_label_heights_npc)` → returns named list `(height_A, height_B, label_height_npc)`. Pure given inputs (estimator is injected for tests). Handles empty-label fallback selection. Replaces lines ~320-410.

**Rationale:** Mirrors the proven `place_two_labels_npc()` decomposition. Each helper's name reads as a complete sentence. Each is testable without a real graphics device thanks to injectable seams (`cleanup_fn`, `marquee_height_estimator`). Returning a single `list` per layer matches existing style elsewhere in the file (`device_info`, `placement` results).

**Alternative considered:** S3 class for "label geometry" + methods. Rejected: too heavy for an internal pipeline. The codebase has only one S3 class (`bfh_qic_result`) and that is for public API data. Internal pipelines use plain lists.

### Decision 2: Device-leak cleanup uses `withr::defer()` at orchestrator boundary

**Choice:** `.acquire_device_for_measurement()` returns a `cleanup_fn` closure that the orchestrator binds via `withr::defer(cleanup_fn(), envir = parent.frame())`. The closure encapsulates the `dev.off()` call(s) needed to balance any device opened during measurement.

**Rationale:** `withr::defer()` is testthat-aware and unwinds correctly on early return or error. Existing `tryCatch` + manual `dev.off()` patterns in the function are race-prone. The package already uses `withr::defer()` extensively in test files (PR #284 standardized this in test-export-session.R).

**Alternative considered:** R6 RAII-style "Device" class. Rejected: same heaviness argument as Decision 1; closures are idiomatic R for this.

### Decision 3: Verbose-message blocks stay with their helper

**Choice:** Each helper gets its own `verbose` parameter (defaults to `FALSE`). The `if (verbose) message(sprintf(...))` blocks travel with the code that produces the value being logged. Component-tag prefixes preserved verbatim (`[VIEWPORT_STRATEGY]`, `[DEVICE_FALLBACK]`, `[DEVICE_SIZE]`, `[PANEL_HEIGHT]`, `[LABEL_HEIGHT]`).

**Rationale:** Logging colocated with the logic it diagnoses. Defaults stay quiet (consistent with PR #281's i18n cleanup). No behavioral change in default code path.

**Alternative considered:** Centralized logging facade. Rejected: opens a separate refactor scope (would require touching many other files); not aligned with this proposal's "pure decomposition" goal.

### Decision 4: Helpers stay in the same file

**Choice:** All four functions (orchestrator + 3 helpers) live in `R/utils_add_right_labels_marquee.R`. Helpers are `@keywords internal @noRd` private, prefixed `.`.

**Rationale:** Co-location matches the existing pattern in `R/utils_label_placement.R` (orchestrator `place_two_labels_npc()` + helpers `.try_niveau_1_gap_reduction()`, `.try_niveau_2_flip()`, `.apply_niveau_3_shelf()`). Splitting into 4 files would fragment the labeling pipeline without grep-friendly benefit.

**Alternative considered:** Move to new files (`R/label_geometry.R`, `R/label_device.R`, etc.). Rejected: makes navigation worse for the same logical unit.

## Risks / Trade-offs

- **[Risk] Visual regression diff after refactor.** → Mitigation: run pre-push hook (`PREPUSH_MODE=full`) before opening PR; require zero `.new.svg` files in `tests/testthat/_snaps/visual-regression/`. Decompose in small commits per helper so a regression bisects to a single helper.

- **[Risk] Device-leak regression on test-runner with parallel workers.** → Mitigation: `withr::defer()` is parallel-safe per testthat 3.x docs. Each test process opens/closes its own device. Verify with `Rscript -e 'devtools::test()'` in fresh R session.

- **[Risk] Verbose-output diff in tests grepping log lines.** → Mitigation: pre-flight grep `tests/testthat/` for the 5 verbose-tag prefixes; if any test asserts log content, update them in the same commit that moves the message.

- **[Trade-off] Helper count grows from 1 to 4.** → Acceptable: each helper has a clear single responsibility and earns its name. Discoverability via grep is better, not worse.

- **[Trade-off] Some duplication in helper signatures (passing `verbose` through 3 layers).** → Acceptable: explicit > implicit. Alternative would be a thread-local logger which adds infrastructure for marginal benefit.

## Migration Plan

This is a pure refactor. No deployment migration needed.

**Implementation sequence:**

1. Branch: `refactor/decompose-marquee-labels` from current develop (post-v0.14.3).
2. Commit 1: Extract `.resolve_label_geometry()`. Keep call site in orchestrator. Run targeted unit tests.
3. Commit 2: Extract `.measure_label_heights()` (independent of device acquisition order; pure given inputs). Run unit tests.
4. Commit 3: Extract `.acquire_device_for_measurement()` with `cleanup_fn` closure. Run device-isolation tests + visual regression. **Critical commit** — device-leak risk concentrates here.
5. Commit 4: Final orchestrator simplification (remove dead inline comments; verify ≤120 lines). Run full pre-push.
6. Open PR. CI runs vdiffr in `NOT_CRAN=true` mode. Review.

**Rollback strategy:** `git revert <merge-sha>`. No persistent state, no migration. Safe to revert at any time.

## Open Questions

- Should the `verbose` parameter on the orchestrator default from `FALSE` (current) or be derived from `getOption("BFHcharts.debug.label_placement")`? Current proposal preserves `verbose = FALSE` default. Discussion can happen at PR review.

- Should the 3-layer split also be applied to `add_spc_labels()` (the caller) in a follow-up? `add_spc_labels()` is shorter (~250 lines) and less critical, but has similar structure. Out of scope for this proposal; flagged for review.
