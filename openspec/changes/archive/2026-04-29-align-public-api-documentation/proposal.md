## Why

Code review 2026-04 surfaced four documentation/API-contract mismatches that mislead users about which symbols are stable:

1. **README documents low-level API that is not exported.** `README.md:124` shows `spc_plot_config()`, `viewport_dims()`, and `bfh_spc_plot()` under "Low-Level API". `NAMESPACE` does not export any of them. Copy-paste from README fails with `Error: object 'spc_plot_config' not found`. Users can work around with `BFHcharts:::spc_plot_config()` but the package promises a low-level surface that does not exist (Codex finding #2).

2. **`new_bfh_qic_result` exported but marked `@keywords internal`.** `NAMESPACE:23` exports the symbol; `R/bfh_qic_result.R:7` declares the family `@keywords internal`. The contradiction means the constructor is callable by users with no documented stability contract. biSPCharts could depend on it and break silently (Claude finding A2).

3. **S3 method registrations for non-documented classes.** `NAMESPACE:10-11` registers `print.spc_plot_config` and `print.viewport_dims`; `R/config_objects.R:39-42` marks the classes `@keywords internal @noRd`. roxygen2 will not generate Rd pages for `@noRd` classes, but the S3 methods are still on the public S3 dispatch table.

4. **Rd pages exist for non-exported internals.** `man/bfh_compile_typst.Rd` and similar pages exist for functions not in `NAMESPACE`. Reference-docs render them as if they were part of the public API without a stability label (Codex finding #10).

5. **`$qic_data` exposes qicharts2 column schema as part of the stable `bfh_qic_result` S3 contract.** Downstream consumers (biSPCharts) read `qic_data$cl`, `qic_data$ucl`, `qic_data$runs.signal` etc. — an implicit hard dependency on qicharts2's internal column names. A qicharts2 minor-version rename of any column silently breaks all consumers (Claude finding A7).

**Consequence:** Misleading documentation; broken examples; unclear stability contracts; silent breakage on upstream qicharts2 minor bumps.

## What Changes

For each non-exported symbol referenced from public docs, choose one of:
- **Export** with explicit `@lifecycle` (stable / experimental / deprecated)
- **Hide** by removing the README/Rd reference and adding `@noRd` (no Rd page generated)

Specific decisions to make in this change:

- `spc_plot_config()`, `viewport_dims()`, `bfh_spc_plot()` — either export with `@lifecycle experimental` (matches README low-level intent) or remove the README section
- `new_bfh_qic_result()` — remove `@keywords internal` (since it's exported) and write a stability contract, OR unexport and protect the constructor behind `bfh_qic()`
- `bfh_compile_typst`, `bfh_create_typst_document`, `validate_export_path` and similar Rd pages — either export with lifecycle annotation or add `@noRd` to suppress Rd generation
- `bfh_reset_caches` — exported or not? Used in tests. Decide and document.
- `print.spc_plot_config` / `print.viewport_dims` — keep S3 method registration but add roxygen `@rdname` linking to the (decided-public-or-internal) class doc

Document `$qic_data` column contract:
- Add a `bfh_qic_result` Roxygen section listing the canonical columns the package guarantees to expose (mirror, freeze, pre/post, cl, ucl, lcl, runs.signal, crossings.signal, sigma.signal, anhoej.signal)
- Add a "qicharts2 contract" note documenting the qicharts2 lower-bound version where these columns exist
- Optionally: introduce accessor functions (`bfh_qic_cl()`, `bfh_qic_signals()`) that wrap column access with a single point of update on qicharts2 schema changes

## Impact

**Affected specs:**
- `public-api` — MODIFIED: clarify which symbols are exported with what lifecycle; ADDED: `$qic_data` column contract

**Affected code:**
- `R/bfh_qic_result.R:7` — remove or rewrite `@keywords internal` for the exported constructor
- `R/config_objects.R:39-42` — align Roxygen with NAMESPACE
- `R/bfh_qic.R` low-level helpers — add `@lifecycle experimental` if exporting, else `@noRd`
- `README.md:124` — fix snippet to match decision
- `man/*.Rd` — regenerate via `devtools::document()` after Roxygen fixes
- `tests/testthat/test-public-api-contract.R` — new test that walks NAMESPACE and verifies each export has matching Roxygen
- NEWS under `## API`

**Potentially breaking:** If functions are unexported, callers using them via package name fail. Pre-1.0 + lifecycle annotation makes this acceptable; document migration in NEWS.

## Cross-repo impact (biSPCharts)

biSPCharts likely uses some of these via `BFHcharts:::function_name()` (which works regardless). Verify; if used via `BFHcharts::function_name()`, coordinate.

biSPCharts version bump: PATCH if any usages need updates.

## Related

- Codex findings #2, #10
- Claude findings A2, A7
- Existing OpenSpec capability `public-api`
