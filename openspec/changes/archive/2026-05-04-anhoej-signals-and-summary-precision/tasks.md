## 1. Pre-implementation audit

- [x] 1.1 Catalog all references to `loebelaengde_signal` / `øbelængde_signal` (UTF-8 form) in `R/`, `tests/testthat/`, `inst/`, `openspec/specs/`, and `vignettes/` (if any). Save list to scratch file for tracking during slice A.
- [x] 1.2 Catalog all `round()` call-sites in `R/utils_qic_summary.R`. Confirm scope: `centerlinje`, `nedre_kontrolgrænse`, `øvre_kontrolgrænse`, `nedre_kontrolgrænse_min/max`, `øvre_kontrolgrænse_min/max`, `nedre_kontrolgrænse_95`, `øvre_kontrolgrænse_95`. Distinguish from internal `round_prec` constancy check (must remain).
- [x] 1.3 Catalog all consumers of `summary$centerlinje` / `summary$*kontrolgrænse*` in `R/utils_typst.R`, `R/utils_spc_stats.R`, and any print method. Confirm which need post-change rounding helper.
- [x] 1.4 Verify `qicharts2::runs.signal` semantics empirically with a minimal example: crossing-only data should produce `runs.signal = TRUE` with `longest.run < longest.run.max`. Document in scratch.

## 2. Slice A — Anhoej signal semantics

- [x] 2.1 Edit `R/utils_qic_summary.R` `format_qic_summary()`:
    - Rename column write at line 153 from `løbelængde_signal` to `anhoej_signal` (combined, sourced from `raw_summary$runs.signal`).
    - After the existing `ængste_løb` / `antal_kryds` writes, add per-phase derived flags:
        ```r
        formatted$runs_signal <- formatted[["længste_løb"]] >
                                 formatted[["længste_løb_max"]]
        formatted$crossings_signal <- formatted$antal_kryds <
                                      formatted$antal_kryds_min
        ```
    - Update `@return` Roxygen block (lines 22-50): rename `løbelængde_signal` reference to `anhoej_signal`, add `runs_signal` + `crossings_signal` entries with NA-semantics note.
    - Update `@details` Column Translations block (lines 53-60): replace `runs.signal -> løbelængde_signal` with `runs.signal -> anhoej_signal` and add derivation lines for `runs_signal` / `crossings_signal`.
- [x] 2.2 Edit `R/bfh_qic.R` provenance Roxygen table (lines ~92-118):
    - Rename `løbelængde_signal` row to `anhoej_signal` (keep source `runs.signal`, aggregation `any() per phase`, scope `per-phase`).
    - Add two new rows for `runs_signal` and `crossings_signal`: source `(derived)`, aggregation `per-phase comparison`, scope `per-phase`, chart-types `all`.
- [x] 2.3 Run `devtools::document()` to regenerate Rd files. Verify NAMESPACE unchanged.
- [x] 2.4 Update `tests/testthat/test-utils_qic_summary.R`:
    - Replace `expect_true("løbelængde_signal" %in% names(result))` (line 22) with `expect_true(all(c("anhoej_signal", "runs_signal", "crossings_signal") %in% names(result)))`.
    - Replace `expect_type(result$løbelængde_signal, "logical")` (line 33) with three assertions on the new columns.
    - Replace value assertions on lines 81-82 with new column references.
- [x] 2.5 Update `tests/testthat/test-summary-anhoej-consistency.R`:
    - Replace `loebelaengde_signal` references at lines 11, 67-73 with `anhoej_signal`.
    - Add new test block: derived `runs_signal` per phase equals `any(qic_data$longest.run > qic_data$longest.run.max)` per phase.
    - Add new test block: derived `crossings_signal` per phase equals `any(qic_data$n.crossings < qic_data$n.crossings.min)` per phase.
- [x] 2.6 Update `tests/testthat/test-return-data-summary.R` lines 129, 371, 375: replace `løbelængde_signal` with `anhoej_signal`.
- [x] 2.7 Update `tests/testthat/test-anhoej-precision.R` line 275: replace `"løbelængde_signal"` reference with `"anhoej_signal"`.
- [x] 2.8 Update `tests/testthat/test-signal_interpretation.R` line 74: replace `løbelængde_signal` with `anhoej_signal`.
- [x] 2.9 Add new test file `tests/testthat/test-anhoej-decomposed-signals.R` (or extend existing) covering the four scenarios from `specs/public-api/spec.md`:
    - Combined + decomposed columns present and `logical` type for all chart types (i, p, pp, u, up, c, mr, run, xbar where applicable).
    - Crossing-only data: `crossings_signal = TRUE`, `runs_signal = FALSE`, `anhoej_signal = TRUE`.
    - Long-run data: `runs_signal = TRUE`, `anhoej_signal = TRUE`.
    - Random data: all three signals `FALSE`.
    - Multi-phase: signals evaluated per phase.
    - `anhoej_signal[p]` matches `any(qic_data$runs.signal[part == p])` for each phase.
- [x] 2.10 Run `devtools::test()`. Expect green; investigate any new failures.

## 3. Slice C — Summary precision

- [x] 3.1 Edit `R/utils_qic_summary.R` `format_qic_summary()`:
    - Remove `round(..., decimal_places)` from `formatted$centerlinje` (line 179): assign `raw_summary$cl` directly.
    - Remove `round(...)` from scalar `nedre_kontrolgrænse` / `øvre_kontrolgrænse` (lines 208-209).
    - Remove `round(...)` from min/max variable-limit writes (lines 212-223): emit raw `min()`/`max()` results.
    - Remove `round(...)` from 95% limit writes (lines 229-230).
    - Keep `round_prec = decimal_places + 2` constancy-check logic (lines 184-198) — this operates on raw `qic_data` and continues to use the same precision tolerance.
    - Update `@return` Roxygen entry on rounding rules (lines 62-65): replace "Control limits: 2 decimals for percent/rate, 1 decimal for count/time" with "Numeric values are returned at raw qicharts2 precision; consumers SHALL round at display time."
- [-] 3.2 ~~Add `round_for_display()` helper~~ — DROPPED. Audit confirmed no consumer needs it: `R/utils_typst.R` does not receive summary numerics; `format_centerline_for_details()` reads `qic_data$cl` directly with its own `round()`; `format_target_value()` rounds internally. Speculative helper would violate project CLAUDE.md "no features beyond task" rule.
- [-] 3.3 ~~Edit `R/utils_typst.R`~~ — DROPPED. Typst params receive only integer `spc_stats` counts (`runs_*`, `crossings_*`, `outliers_*`). No centerline/control-limit cells.
- [x] 3.4 Verify `R/utils_spc_stats.R` is unaffected: the `data.frame` method reads `længste_løb`/`antal_kryds` (integer) and forwards `forventede_outliers`/`antal_outliers` (integer). No numeric-precision-sensitive reads.
- [x] 3.5 Update `tests/testthat/test-utils_qic_summary.R`:
    - Replace value assertions that compare against rounded values (e.g. `expect_equal(result$centerlinje[1], 0.07)`) with `expect_equal(result$centerlinje[1], qic_data$cl[1])` (raw equality).
    - Update fixture comments noting raw precision is now expected.
- [x] 3.6 Add new test file `tests/testthat/test-summary-precision.R` covering scenarios from `specs/public-api/spec.md`:
    - `summary$centerlinje[p] == qic_data$cl[part == p][1]` for p, i, c, u charts.
    - `summary$nedre_kontrolgrænse[p] == qic_data$lcl[part == p][1]` for constant-limit phases.
    - `summary$nedre_kontrolgrænse_min[p] == min(qic_data$lcl[part == p])` for variable-limit phases.
    - `kontrolgrænser_konstante` correctly identifies near-equal-but-not-exact qicharts2 limits as constant despite raw values now stored unrounded.
- [-] 3.7 ~~test-typst-display-rounding.R~~ — DROPPED. No `round_for_display()` helper to test. Covered indirectly: 5.3 PDF render diff.
- [x] 3.7b Add test in `tests/testthat/test-summary-precision.R` (or extend §3.6 file): `format_target_value()` rendering analysis text from `result$summary$centerlinje[1]` produces same string before and after Slice C (because `format_target_value` rounds internally — verifies the audit-claim that display path is auto-safe).
- [x] 3.8 Update `tests/testthat/test-return-data-summary.R` line 129 (and any other site asserting rounded summary values): replace rounded literals with raw expectations sourced from `qic_data`.
- [x] 3.9 Run `devtools::test()`. Expect green.

## 4. Documentation

- [x] 4.1 Append addendum section to `inst/adr/ADR-002-anhoej-summary-source.md` titled `## Addendum 2026-05-03 (anhoej-signals-and-summary-precision)` describing slices A + C and pointing to this OpenSpec change. ASCII-only (transliterate Danish chars per CLAUDE.md ASCII-policy).
- [x] 4.2 Update `NEWS.md` with new section `# BFHcharts 0.15.0` containing:
    - `## Breaking changes` block with two bullets: (1) `summary$loebelaengde_signal` replaced by `anhoej_signal` + `runs_signal` + `crossings_signal`, with one-line migration snippet; (2) `summary$centerlinje` and control-limit columns now carry raw qicharts2 precision (no rounding), with note that PDF rendering output is byte-identical and that biSPCharts pre-#470 versions need a corresponding update.
    - `## Bug fixes` block noting crossings-only data no longer mis-attributes the signal as a runs-violation.
- [x] 4.3 Bump `DESCRIPTION` `Version:` field from `0.14.5` to `0.15.0`.
- [x] 4.4 Run `devtools::document()` once more after all Roxygen edits. Verify clean diff.

## 5. Validation

- [x] 5.1 Run `devtools::test()` full suite. All tests SHALL pass.
- [x] 5.2 Run `devtools::check()`. SHALL produce no new warnings or errors versus pre-change baseline.
- [x] 5.3 Render one fixed-input p-chart PDF and one fixed-input i-chart PDF. Diff PDF Typst-param strings (or rendered output) against pre-change baseline. Numeric values in cells SHALL match exactly.
- [x] 5.4 Run vdiffr regression check via `testthat::test_dir("tests/testthat")`. Confirm zero `.new.svg` files (no plot regression).
- [x] 5.5 Manual eyeball: render one PDF for a percent-unit P-chart and one for a count-unit I-chart. Confirm cell values are 0.07 (not 0.07195946) and 47.2 (not 47.234).

## 6. Cross-repo coordination (post-merge follow-up)

- [x] 6.1 Tag `v0.15.0` annotated tag after merge to main per `VERSIONING_POLICY.md` §B.
- [-] 6.2 Comment on biSPCharts #468 with migration snippet (column-name mapping table) and link to `v0.15.0` NEWS entry.
    - Note: external biSPCharts repo action; tracked downstream, not blocking BFHcharts archive.
- [-] 6.3 Comment on biSPCharts #290-tracking issue (or close it via this PR's commit ref) noting slices A + C resolved.
    - Note: external biSPCharts repo action; tracked downstream.
- [-] 6.4 (Outside this change scope but flagged) biSPCharts opens follow-up PR bumping `DESCRIPTION` `BFHcharts (>= 0.15.0)` per `VERSIONING_POLICY.md` §E.
    - Note: explicitly outside scope per task description; tracked in biSPCharts.

## 7. Archive change

- [x] 7.1 After merge to main and tag, run `/openspec-archive-change anhoej-signals-and-summary-precision`.
