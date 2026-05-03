## Context

Issue #290 (open) was partially addressed by `2026-05-01-verify-anhoej-summary-vs-qic-data-consistency` (archived 2026-05-03). That change fixed `sigma.signal` per-phase aggregation and added 22 consistency tests. A follow-up codex code-review on 2026-05-03 reframed the remaining problem space:

- BFHcharts does NOT maintain its own Anhoej algorithm (verified empirically). It calls `qicharts2::qic()` and forwards `longest.run`, `n.crossings`, `runs.signal`, `sigma.signal`. The bug is **semantic mis-mapping** in the summary layer, not algorithmic divergence.
- `qicharts2::runs.signal = crsignal(n.useful, n.crossings, longest.run)` is the **combined** Anhoej signal. BFHcharts maps it to a column named `loebelaengde_signal` ("run-length signal"), which clinicians read as runs-only and mis-attribute crossings-only signals.
- `format_qic_summary()` rounds `cl`/`lcl`/`ucl` to 1-2 decimals as a presentation convenience. Downstream consumers (biSPCharts) doing logical comparisons (`target >= centerlinje`) hit round-off boundaries and get clinically wrong answers. biSPCharts already has a workaround (#470) — but the architecture is fundamentally inverted.

Stakeholders:
- BFHcharts maintainer (Johan Reventlow) — owns API contract.
- biSPCharts (downstream) — primary consumer, has open issue #468 (signal semantics) and merged #470 (rounding workaround).
- Healthcare clinicians — read `summary` indirectly via PDF + biSPCharts UI.

Constraints:
- Pre-1.0 (`0.14.5`). Per `VERSIONING_POLICY.md` §A, breaking changes allowed in MINOR with `## Breaking changes` NEWS marking.
- ASCII-only in `R/*.R` source (per project CLAUDE.md). Danish characters via `\u00xx` escapes.
- Must not regress 1800+ existing tests.

## Goals / Non-Goals

**Goals:**
- Make `summary` semantics match qicharts2's signal model (combined + decomposed).
- Make `summary` numeric values authoritative (raw qicharts2 precision) and confine rounding to display layer.
- Document the model in NEWS, Roxygen, ADR addendum so downstream knows the contract.
- Single MINOR release covers slices A + C; biSPCharts coordinates lower-bound bump.

**Non-Goals:**
- Slice B (`forventede_outliers`): explicitly retained as-is per maintainer decision. Document rationale in design but do not change runtime.
- Algorithmic changes to Anhoej rules (BFHcharts already delegates to qicharts2).
- Deprecation cycle for `loebelaengde_signal` rename. Pre-1.0 allows direct breaking change with NEWS entry; deprecation aliases would bloat the summary surface.
- Migrating biSPCharts. Cross-repo coordination is a follow-up PR in biSPCharts repo (BFHcharts only ships its side).

## Decisions

### D1 — Slice A: Replace `loebelaengde_signal` with three columns (combined + decomposed)

`format_qic_summary()` will write three logical columns:

```r
formatted$anhoej_signal     <- as.logical(raw_summary$runs.signal)         # combined (qicharts2 source)
formatted$runs_signal       <- formatted[["længste_løb"]] >
                                formatted[["længste_løb_max"]]   # derived per-phase
formatted$crossings_signal  <- formatted$antal_kryds <
                                formatted$antal_kryds_min                  # derived per-phase
```

`anhoej_signal` is the canonical primary flag (matches qicharts2's combined logic, what `runs.signal` actually represents). `runs_signal` and `crossings_signal` decompose the combined flag for diagnostic clarity.

NA handling: when `laengste_loeb` or `antal_kryds` are NA (degenerate phase, e.g., all-equal values), the comparison yields NA. Wrap derivations with `isTRUE`-style coercion if desired, but default `NA` reflects qicharts2's own NA semantics for those phases — consistent.

**Alternatives considered:**

- *A1 — Rename only* (`loebelaengde_signal` → `anhoej_signal`, no decomposed flags): rejected. Clinicians reading `anhoej_signal=TRUE` still cannot tell whether runs or crossings tripped without inspecting raw fields. The decomposed flags are derivable for free from existing summary columns; not exposing them duplicates work for every consumer.
- *A2 — Add only `runs_signal`+`crossings_signal`, keep `loebelaengde_signal`*: rejected. Three signal columns where `loebelaengde_signal == runs_signal | crossings_signal` would mislead — the legacy name still claims to be runs-only. Rename is the fix.
- *A3 — chosen* (rename + add decomposed): one breaking rename, two additive columns, matches qicharts2 semantics exactly.

### D2 — Slice B: Retain `forventede_outliers = 0` literal

Maintainer (Johan Reventlow) decided 2026-05-03 to keep the existing PDF "FORVENTET 0" cell unchanged. Rationale captured here so future contributors do not re-litigate:

- Klinisk read of "FORVENTET 0" is "any outlier is a signal" — operational SPC interpretation. Mathematically loose (true expected = ~0.0027 × n_useful), but pragmatically consistent with how SPC charts are read in this clinical context.
- Replacing with `round(0.0027 × n_useful, 1)` introduces decimals (e.g., "FORVENTET 0.1") that clinicians find confusing.
- Removing the cell breaks visual consistency with the runs/crossings rows above it.
- The literal is BFH convention, not qicharts2 output. Documented in `bfh_qic()` provenance table as `(constant 0)` source. That documentation suffices.

**Action in this change:** none (status quo). Design.md preserves rationale.

### D3 — Slice C: `summary` carries raw precision; existing display formatters already round at their own boundary

`format_qic_summary()` will stop calling `round()` on numeric columns:

```r
# BEFORE
formatted$centerlinje <- round(raw_summary$cl, decimal_places)
formatted[["nedre_kontrolgrænse"]] <- round(raw_summary$lcl, decimal_places)

# AFTER
formatted$centerlinje <- raw_summary$cl
formatted[["nedre_kontrolgrænse"]] <- raw_summary$lcl
```

**Display path is already safe.** Pre-implementation audit (tasks.md §1.3) found:
- `R/utils_typst.R` builds Typst params from `spc_stats` containing only integer SPC counts (`runs_expected/actual`, `crossings_expected/actual`, `outliers_expected/actual`). It does NOT receive `summary$centerlinje` or control-limit values. No Typst-layer rounding required.
- `R/export_details.R::format_centerline_for_details()` reads `qic_data$cl` (not `summary$centerlinje`) and applies its own `round()` per `y_axis_unit`. Untouched by this change.
- `R/spc_analysis.R::format_target_value()` calls `round(x, 2)` / `round(x * 100)` internally when emitting analysis-text strings. Untouched.

**Logic path is auto-fixed.** `R/spc_analysis.R::.evaluate_target_arm()` compares `centerline >= target_value` (lines 748-760). With raw values flowing through, the round-off boundary bug (analogous to biSPCharts #470) is fixed without code change.

No new `round_for_display()` helper is added. If a future code path needs to render summary numerics directly to Typst, that future change can introduce the helper. Adding it speculatively now violates "do not add features beyond what task requires" (project CLAUDE.md).

**Alternatives considered:**

- *C2 — `raw_summary` parallel data frame*: rejected. Duplicates structure; consumers face "which is canonical" confusion.
- *C3 — Accessors only* (`bfh_get_centerline()`): rejected. Most consumers reach into `summary` directly; an accessor doesn't redirect existing call-sites and adds API surface.
- *C4 — `*_raw` suffix columns alongside rounded*: rejected. Backward-compat by column-bloat; defers the cleanup. Pre-1.0 should not bake half-fixes into the API.
- *C1 — chosen* (raw in summary, round at display): single source of truth. biSPCharts already paid the migration price (#470) — formalizing it costs nothing for the existing downstream and prevents future round-off bugs.

**Internal logic that MUST stay using rounded values:**

`format_qic_summary()` lines 190-198 use `round_prec = decimal_places + 2` to detect "are control limits constant within a phase?" This logic operates on **raw `qic_data$lcl/ucl` columns** (not on `summary`), so it is unaffected. The +2-precision tolerance for floating-point drift is preserved.

### D4 — Constancy detection precision (`round_prec`) unchanged

The `kontrolgraenser_konstante` flag uses `round_prec = decimal_places + 2` to absorb qicharts2 float drift when checking limit constancy. This is internal computation and stays. The flag itself remains accurate to higher precision than the display, which is correct: a phase where limits differ in the 4th decimal but agree in the 2nd is rendered with constant scalar columns (correct visual presentation) while still being flagged via the constancy check that operates on raw values.

### D5 — `bfh_extract_spc_stats()` reads `anhoej_signal`

`R/utils_spc_stats.R` currently does not directly reference `loebelaengde_signal` (verified via grep), but the `data.frame` method reads `forventede_outliers` and `antal_outliers`. Slice A does not impact `bfh_extract_spc_stats()` directly. However:

- Tests in `test-utils_qic_summary.R` and `test-return-data-summary.R` assert `loebelaengde_signal` column presence — these MUST be updated.
- `R/bfh_qic.R` provenance Roxygen table references the old column name — update to new names.

## Risks / Trade-offs

**[Test churn]** ~10+ test sites reference `loebelaengde_signal` / hardcoded summary column names → Mitigation: catalog all sites in tasks.md before implementing; do all rename-touches in a single commit so test failures during the migration are obvious.

**[Visual regression in PDF]** Moving rounding to Typst layer could change rendered cell values if the helper is mis-implemented → Mitigation: regression test asserts PDF Typst params equal `round(summary$centerlinje, dp)` exactly. Existing vdiffr snapshots cover plot rendering but not Typst params; add explicit unit test on `R/utils_typst.R` rounding helper.

**[Consumer regression in biSPCharts UI]** biSPCharts may display `summary$centerlinje` directly without rounding → user-facing UI suddenly shows `0.07195946` instead of `0.07` → Mitigation: NEWS entry calls this out explicitly; biSPCharts maintainer notified via #468 cross-link. biSPCharts can either (a) apply its own rounding in the display layer (preferred — matches BFHcharts pattern) or (b) reach into `result$qic_data` for raw values and format independently.

**[NA-handling in derived signals]** When `laengste_loeb` is NA (degenerate phase), `runs_signal = NA > NA` yields NA, not FALSE → Mitigation: document NA semantics in Roxygen `@return`. Test `test-summary-anhoej-consistency.R` asserts NA propagates correctly. Consumers checking `if (runs_signal)` will need to wrap with `isTRUE()`; this is consistent with how they should handle qicharts2's NA semantics for empty/degenerate phases anyway.

**[`anhoej_signal` semantic clash with future]** If qicharts2 adds new Anhoej-style rules (e.g., "8 consecutive trending"), `anhoej_signal` may become ambiguous as the model evolves → Mitigation: scope `anhoej_signal` documentation to "matches `qicharts2::runs.signal` as of qicharts2 v0.7.x". Future expansion handled by additional decomposed flags if needed.

**[ASCII-policy in test files]** Tests assert `summary$løbelængde_signal` (UTF-8 column name) — when renamed to `anhoej_signal` (ASCII), the `ø`/`æ`-escaped column-name strings drop out of test files → Mitigation: net reduction in non-ASCII cleverness; aligns with project ASCII-policy without regression.

## Migration Plan

1. **Pre-implementation audit** (tasks.md §1):
   - Catalog all references to `loebelaengde_signal` / `løbelængde_signal` across `R/`, `tests/`, `inst/`, `openspec/`.
   - Catalog all references to `summary$centerlinje` / `summary$nedre_kontrolgrænse` etc. that read for *logic* (vs. display).
   - Catalog all `round()` call-sites in `R/utils_qic_summary.R` (must move to display).

2. **Implementation order** (each commit independently testable):
   1. Slice A: rename + add decomposed flags. Update provenance Roxygen. Update tests.
   2. Slice C: remove `round()` in `format_qic_summary()`. Add `round_for_display()` helper. Update `R/utils_typst.R` to call helper. Update tests.
   3. Final: NEWS, ADR-002 addendum, version bump.

3. **Validation:**
   - `devtools::test()` — full suite green.
   - `devtools::check()` — no new warnings.
   - PDF render test: render fixed-input PDF, diff against pre-change baseline at byte level. Expected diff is zero (rounding ends at same numeric values, just at different layer).
   - Manual: render one P-chart + one I-chart PDF, eyeball precision/layout against previous.

4. **Rollback:**
   - Revert at PR level if visual regression detected. Slice A and Slice C can be reverted independently if commits remain atomic.

5. **Cross-repo:**
   - After 0.15.0 tag: comment on biSPCharts #468 with migration snippet (`loebelaengde_signal` → `anhoej_signal`).
   - biSPCharts opens follow-up PR to bump `BFHcharts (>= 0.15.0)` in DESCRIPTION + update column references.

## Open Questions

1. **`anhoej_signal` for run-charts** (chart_type = "run"): qicharts2 produces `runs.signal` for run-charts (uses runs + crossings, no sigma). Should `summary$anhoej_signal` be present for run-charts? Currently `loebelaengde_signal` IS present for run-charts (via `format_qic_summary()` unconditional add) — preserve symmetry. **Resolved:** yes, `anhoej_signal` present for all chart types including run; tests cover this.

2. **Should `runs_signal` / `crossings_signal` exist for chart types where qicharts2 returns NA for `longest.run`?** Edge case: phase with all-equal values produces NA. Derived flags inherit NA. **Resolved:** yes, NA propagates correctly. Document and test.

3. **Display-layer helper location** (`utils_typst.R` vs new `utils_format.R`): `round_for_display()` is currently only used by Typst, but print methods may want it too. **Resolution deferred to implementation:** start in `utils_typst.R`; extract to `utils_format.R` if a second consumer materializes during slice C.

4. **NEWS entry phrasing:** "Breaking changes" header is required. Should we also note that biSPCharts pre-#470 versions break with 0.15.0? **Resolution:** yes, mention biSPCharts coordination explicitly in migration note.
