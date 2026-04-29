## Why

Both review passes flagged accumulated deprecation lifecycle and dependency hygiene debt:

1. **`print.summary = TRUE` deprecated since v0.3.0; current version is v0.10.5** — 7 minor versions later, the legacy code path lives in `R/utils_bfh_qic_helpers.R:85-109`. The deprecation message says "will be removed in a future version" with no scheduled version.

2. **`lemon` in `Imports` with no confirmed usage.** `DESCRIPTION:36` makes lemon a hard dependency. Both reviews recommend grepping for `lemon::` calls; if zero, move to `Suggests` or remove. Hard deps inflate install time and add transitive risk.

3. **`BFHllm` in `Suggests` AND `Remotes`.** `DESCRIPTION:43` lists `BFHllm` as Suggests (correct: AI is opt-in); `Remotes:` declares the GitHub source. `R CMD check --as-cran` flags non-CRAN Remotes. For a Suggests-only package, the Remotes entry adds noise without functional benefit — manual install instructions in function docs would be cleaner.

4. **Config duplication: `cl/freeze/part` in two places.** `R/utils_bfh_qic_helpers.R:616-637` (`build_bfh_qic_config()`) stores `cl`, `freeze`, `part` at top-level AND mirrors them as `label_config$centerline_value`, `label_config$has_frys_column`, `label_config$has_skift_column`. Mutation after construction can desync the two. Single source of truth needed.

5. **`base_size` ceiling inconsistency.** `R/utils_bfh_qic_helpers.R:238-241` validates user-supplied `base_size` up to 100; `R/config_font_scaling.R:63` clamps auto-scaling at 48. Explicit `base_size = 72` bypasses the cap and produces visually broken layouts.

6. **Auto-detect units silent flip.** `R/bfh_qic.R:111-115` interprets `width = 10` as inches and `width = 11` as cm — a 10% input change produces a 2.54x physical-size flip with no message. Auto-detection should at minimum emit a `message()` naming the inferred unit.

## What Changes

- **Schedule `print.summary` removal:** Add `lifecycle::deprecate_warn()` (or hard `stop()`) targeting v0.11.0; document migration in NEWS; remove the legacy code path
- **Verify and adjust `lemon`:** Run `grep -r "lemon::" R/`. If zero hits → remove from `Imports`. If used in tests/vignettes only → move to `Suggests`. Otherwise document
- **Remove `BFHllm` from `Remotes`** since it's Suggests-only; add manual-install hint to `bfh_generate_analysis()` Roxygen
- **Consolidate `cl/freeze/part` config:** Keep top-level as canonical; derive `label_config` sub-keys lazily via accessor functions
- **Align `base_size` ceiling** to `FONT_SCALING_CONFIG$max_size` (48) for consistency, OR document the larger ceiling for explicit user input
- **Surface auto-detected units:** Add `message()` when width/height auto-detection happens, naming the inferred unit. Document `units` parameter as recommended

## Impact

**Affected specs:**
- `package-config` — MODIFIED requirements: lifecycle annotations, dependency placement, config-canonicalization, auto-detection feedback

**Affected code:**
- `R/utils_bfh_qic_helpers.R:85-109` — remove or `lifecycle::deprecate_stop()` print.summary
- `R/utils_bfh_qic_helpers.R:616-637` — single canonical config source
- `R/utils_bfh_qic_helpers.R:238-241` — base_size ceiling alignment
- `R/bfh_qic.R:111-115` — emit auto-detection message
- `DESCRIPTION:36, 43, 53-54` — adjust Imports / Suggests / Remotes
- `tests/testthat/test-bfh_qic_helpers.R` — assert deprecation, config canonicalization
- NEWS under `## Breaking changes` (print.summary removal) and `## Forbedringer`

**Breaking:**
- `print.summary = TRUE` removal is breaking for any caller still using it (none expected; deprecated for 7 versions). Pre-1.0 MINOR bump acceptable per VERSIONING_POLICY §A.
- `lemon` removal from `Imports` is breaking only if a downstream package depends on BFHcharts re-exporting lemon (unlikely).

## Cross-repo impact (biSPCharts)

- biSPCharts SHALL be grep'd for `print.summary` usage; if found, migrated to new return-format API
- biSPCharts SHALL update its own install instructions if the BFHllm Remotes entry is removed

biSPCharts version bump: PATCH if any usage updates needed.

## Related

- Claude findings A1, A4, A6, B2, B5
- Codex findings #4, #8
- Existing OpenSpec capability `package-config`
- VERSIONING_POLICY.md §A (semver), §F (pre-1.0)
