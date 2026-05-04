## Why

Codex code-review (issue #290, 2026-05-03) identified two semantic defects in `bfh_qic()$summary` that survived the prior fix (`2026-05-01-verify-anhoej-summary-vs-qic-data-consistency`):

1. **`loebelaengde_signal` is mis-named.** It maps `qicharts2::runs.signal`, which is the *combined* Anhoej signal (`crsignal(n.useful, n.crossings, longest.run)` — TRUE on either runs OR crossings violation). Clinicians read the Danish name literally as "long-run signal only" and mis-attribute crossings-only signals as level-shifts. Reproduces with crossing-only data: 4 alternating phases trip `loebelaengde_signal=TRUE` despite `longest.run=5 < longest.run.max=7`.

2. **Rounded summary values mis-feed downstream logic.** `format_qic_summary()` rounds `cl`/`lcl`/`ucl` to 1-2 decimals (presentation format). Consumers using `summary$centerlinje` for target-comparison logic (e.g. biSPCharts target-evaluation) hit the wrong side of the round-off boundary. biSPCharts already paid this price downstream (#470). BFHcharts must move rounding to the display layer so `summary` carries raw qicharts2 precision.

## What Changes

**Slice A — Anhoej signal semantics (BREAKING):**
- **BREAKING** Rename `summary$loebelaengde_signal` → `summary$anhoej_signal` (combined runs-or-crossings signal, matching `qicharts2::runs.signal` semantics).
- Add `summary$runs_signal` (per-phase, derived: `laengste_loeb > laengste_loeb_max`).
- Add `summary$crossings_signal` (per-phase, derived: `antal_kryds < antal_kryds_min`).
- Update `bfh_extract_spc_stats()` to read `anhoej_signal` (with backward-compat fallback removed).
- Update `bfh_qic()` provenance Roxygen table.

**Slice B — `forventede_outliers` (no change):**
- Retain `summary$forventede_outliers = 0` and PDF "FORVENTET 0" cell unchanged. Decision documented in design.md so future contributors do not re-litigate.

**Slice C — Summary precision (BREAKING):**
- **BREAKING** Stop rounding in `format_qic_summary()`. `summary$centerlinje`, `summary$nedre_kontrolgraense`, `summary$oevre_kontrolgraense`, `summary$nedre_kontrolgraense_min/max`, `summary$oevre_kontrolgraense_min/max`, and `summary$nedre_kontrolgraense_95`/`oevre_kontrolgraense_95` carry raw `qicharts2::qic()` precision.
- Existing display consumers already round at their own boundary: `format_centerline_for_details()` (`R/export_details.R`) reads `qic_data$cl` directly with its own `round()` for unit-specific formatting; `format_target_value()` (`R/spc_analysis.R`) calls `round(x, 2)` / `round(x*100)` internally. PDF Typst params (`R/utils_typst.R`) emit only integer SPC counts (runs, crossings, outliers) — they never receive `summary$centerlinje` — so no Typst-layer rounding is required.
- Logic consumer that benefits: `R/spc_analysis.R:748-760` (`.evaluate_target_arm()`) compares `centerline >= target_value`. Round-off bugs here are auto-fixed by raw values flowing through.
- Constancy check (`kontrolgraenser_konstante`) continues to use `round_prec` internally — that logic is unchanged because it operates on raw `qic_data` columns directly.
- Add migration note in NEWS + `bfh_qic()` Roxygen.

**Cross-cutting:**
- Version bump 0.14.5 → 0.15.0 (MINOR, pre-1.0 breaking allowed per `VERSIONING_POLICY.md` §A).
- NEWS entry under `## Breaking changes` for slices A + C.
- Regression tests for slice A (crossing-only, runs-only, both, neither) and slice C (raw precision preserved through summary).

## Capabilities

### New Capabilities
None. All changes modify existing behaviour.

### Modified Capabilities
- `public-api`: Summary column names and types change (rename `loebelaengde_signal` → `anhoej_signal`, add `runs_signal` + `crossings_signal`, drop rounding on numeric columns). `bfh_extract_spc_stats()` reads new column.

## Impact

**Code:**
- `R/utils_qic_summary.R` — primary site. Add signal derivation, remove `round()` calls on `cl`/`lcl`/`ucl`/`*_95`, update Roxygen `@return`.
- `R/utils_spc_stats.R` — verify no direct `loebelaengde_signal` reference; no functional change required (data.frame method reads from `længste_løb`/`antal_kryds` which are unchanged).
- `R/bfh_qic.R` — provenance table in Roxygen `@details`.
- `inst/adr/ADR-002-anhoej-summary-source.md` — append addendum referencing this change.
- No changes required in `R/utils_typst.R` (Typst params do not include centerline) or `R/export_details.R` / `R/spc_analysis.R::format_target_value()` (existing display formatters already apply their own rounding when reading `qic_data` or `summary` numerics).

**Tests:**
- `tests/testthat/test-utils_qic_summary.R` — update column-name assertions.
- `tests/testthat/test-summary-anhoej-consistency.R` — add `runs_signal`/`crossings_signal`/`anhoej_signal` cases incl. crossing-only regression.
- `tests/testthat/test-return-data-summary.R` — update column-name assertions.
- `tests/testthat/test-anhoej-precision.R` — update column reference.
- `tests/testthat/test-signal_interpretation.R` — update column reference.
- `tests/testthat/test-export_pdf.R` — verify PDF cells receive rounded values; raw-precision values propagate from summary.
- New: `tests/testthat/test-summary-precision.R` — assert `summary$centerlinje` matches `qic_data$cl[1]` exactly per phase.

**Public API surface:**
- `bfh_qic()$summary` — column names + numeric precision change.
- `bfh_extract_spc_stats()` — internal column-name dependency updated; output struct unchanged.

**Cross-repo (biSPCharts):**
- biSPCharts #468: signal-name reference must update (`loebelaengde_signal` → `anhoej_signal`). Provides clearer crossing-only diagnostics via new `crossings_signal` field.
- biSPCharts #470: already migrated target-evaluation off `summary$centerlinje` (uses `qic_data$cl`). Slice C makes that workaround unnecessary — biSPCharts may revert to summary-based logic with raw values, but no forced action required.
- DESCRIPTION lower-bound bump in biSPCharts: `BFHcharts (>= 0.15.0)` once released.

**Statistical validation:**
- Slice A: signal derivation is purely arithmetic from existing fields (no new statistical computation). qicharts2's `runs.signal` semantics verified empirically (codex review 2026-05-03 + crsignal source).
- Slice C: removes rounding only — no calculation change. Raw values always existed in `qic_data`.

**Dependencies:**
- No new package dependencies.
- qicharts2 semantics relied upon: `runs.signal = crsignal(n.useful, n.crossings, longest.run)` (verified in qicharts2 source `runs.analysis()`).
