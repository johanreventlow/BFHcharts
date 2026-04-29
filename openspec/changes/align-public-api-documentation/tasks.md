## 1. Decision: low-level API export status

- [ ] 1.1 Decide: export `spc_plot_config`, `viewport_dims`, `bfh_spc_plot` (with `@lifecycle experimental`) OR remove from README
- [ ] 1.2 Apply decision: update Roxygen + NAMESPACE OR rewrite README "Low-Level API" section
- [ ] 1.3 If exporting: write Roxygen `@examples` that actually run

## 2. Decision: new_bfh_qic_result lifecycle

- [ ] 2.1 Decide: keep exported with stability contract OR unexport
- [ ] 2.2 If keeping: remove `@keywords internal`, write stability description
- [ ] 2.3 If unexporting: remove from `@export`, run `devtools::document()`, add to internal-only Rd documentation

## 3. Internal Rd page audit

- [ ] 3.1 List all Rd files in `man/` whose corresponding function is NOT in `NAMESPACE` (`grep -L 'export(' R/<src>.R` cross-referenced)
- [ ] 3.2 For each: decide export-with-lifecycle OR add `@noRd` to source roxygen
- [ ] 3.3 Run `devtools::document()` to remove suppressed Rd pages
- [ ] 3.4 Verify `R CMD check` clean (no NOTE about undocumented exports / orphan Rd)

## 4. S3 method documentation

- [ ] 4.1 Add `@rdname` linking `print.spc_plot_config` and `print.viewport_dims` to their class documentation
- [ ] 4.2 Verify NAMESPACE registrations match the decided export status

## 5. $qic_data column contract

- [ ] 5.1 Document canonical columns in `bfh_qic_result` Roxygen `@section qic_data columns`:
  - cl, ucl, lcl, sigma.signal, runs.signal, crossings.signal, anhoej.signal, x, y, n
- [ ] 5.2 Document qicharts2 lower-bound version (`>= 0.7.0` in DESCRIPTION) and contract guarantee
- [ ] 5.3 Optional: introduce `bfh_qic_cl()`, `bfh_qic_signals()` accessor wrappers
- [ ] 5.4 Add test: `test-public-api-contract.R` asserts each named column exists in `bfh_qic_result()$qic_data` for a smoke fixture

## 6. README cleanup

- [ ] 6.1 Update README "Low-Level API" section to match decision
- [ ] 6.2 If keeping low-level API: add a runnable example, not a snippet
- [ ] 6.3 Add a "Stability" subsection naming each export's lifecycle status

## 7. CI guard

- [ ] 7.1 Add test that walks `getNamespaceExports("BFHcharts")` and asserts each has a non-internal Rd page
- [ ] 7.2 Add test that verifies critical `$qic_data` columns are present (smoke test)

## 8. Release

- [ ] 8.1 Pre-1.0 MINOR bump (potentially breaking via unexports)
- [ ] 8.2 NEWS under `## API` lists each export decision
- [ ] 8.3 Coordinate biSPCharts: grep usage, bump if needed
- [ ] 8.4 `devtools::check()` clean
