# Label Placement Architecture

Refactored in v0.12.2 (opsx/2026-05-01-refactor-label-placement-monolith).

## 3-Layer Architecture

### Layer 1 — Pure (no side effects)

| Function | File | Responsibility |
|---|---|---|
| `.validate_placement_inputs()` | `utils_label_placement.R` | Parse `label_height_npc` (numeric or list API), validate all NPC params, normalize `pref_pos` |
| `.resolve_placement_config()` | `utils_label_placement.R` | Load config, compute `gap_line` / `gap_labels` / `pad_top` / `pad_bot` from absolute or NPC dimensions |
| `.compute_placement_strategy()` | `utils_label_placement.R` | Pure collision-avoidance algorithm: coincident → tight → normal → cascade |

`.compute_placement_strategy()` has **no device calls, no file IO, no global state mutation**.
It is fully testable without a graphics device (`dev.list()` unchanged after call).

### Layer 2 — Effectful orchestrator

`place_two_labels_npc()` (~90 lines) sequences the pure layer:

```
parse/validate  →  resolve config  →  handle NA/OOB  →  strategy  →  return
```

Public wrapper; backward-compatible signature preserved.

### Layer 3 — Device management

`add_right_labels_marquee()` is the rendering layer. It:

1. Calls `ggplot_build()` + `ggplot_gtable()`.
2. Opens a temporary Cairo PDF device (via `with_temporary_device()` pattern)
   for grob height measurements.
3. Calls `measure_panel_height_from_gtable()` + `estimate_label_heights_npc()`.
4. Delegates NPC positioning to `place_two_labels_npc()` (layer 2).
5. Renders labels via `marquee::geom_marquee()`.

Device cleanup uses a single `on.exit` block registered immediately after
device open — covers both normal return and error paths.

## Key Files

| File | Role |
|---|---|
| `R/utils_label_placement.R` | Pure helpers + orchestrator |
| `R/utils_npc_mapping.R` | NPC↔data-unit mapper, `clamp_to_bounds()` |
| `R/utils_panel_measurement.R` | `with_temporary_device()`, `measure_panel_height_from_gtable()`, `.estimate_label_height_npc_internal()` |
| `R/utils_add_right_labels_marquee.R` | Rendering layer |
| `R/config_label_placement.R` | Config constants + accessors |

## Collision Cascade (in `.compute_placement_strategy()`)

```
1. Coincident check  (lines within 10% of label_height)
   → one over, one under same line

2. Tight check  (gap < 50% of min_center_gap)
   → flip pref_pos so labels go on opposite sides

3. Initial proposal  (propose_single_label each)
   → early exit if no collision

4. Push apart  (push upper up or lower down)
   → early exit if succeeds

5. Line-gap enforcement  (.verify_line_gap_npc)
   → if enforcement would cause collision:
     NIVEAU 1: shrink gap_labels (50% → 30% → 15%)
     NIVEAU 2: flip A, flip B, flip both
     NIVEAU 3: shelf placement (last resort)
```

## Device Management Pattern

```r
# CORRECT: single on.exit, covers error path
temp_pdf <- tempfile(fileext = ".pdf")
grDevices::cairo_pdf(filename = temp_pdf, width = w, height = h)
temp_dev <- grDevices::dev.cur()
on.exit(
  {
    if (temp_dev %in% grDevices::dev.list()) {
      tryCatch(grDevices::dev.off(temp_dev), error = function(e) NULL)
    }
    unlink(temp_pdf, force = TRUE)
  },
  add = TRUE, after = FALSE
)
# ... use device ...
# on.exit fires automatically — no manual cleanup block needed
```

## Testing

- `tests/testthat/test-placement-strategy-contract.R`: 27 pure-layer tests,
  no device required, property-based.
- `tests/testthat/test-utils_label_placement.R`: integration tests for
  `place_two_labels_npc()` and `propose_single_label()`.
- `tests/testthat/test-niveau-resolvers.R`: unit tests for cascade helpers.
