# Proposal: align-public-api-documentation

**Status:** Approved  
**Date:** 2026-04-29  
**Author:** Johan Reventlow  

## Problem

The BFHcharts package has inconsistencies between what is exported in NAMESPACE,
what is documented in man/, and what the package contract claims:

1. **Internal functions have man/ Rd pages** — 16 internal functions have `@keywords internal`
   but are missing `@noRd`, causing roxygen2 to generate orphan Rd pages. These are
   not in NAMESPACE but appear in `man/` (e.g., `bfh_compile_typst.Rd`,
   `validate_export_path.Rd`, `add_anhoej_signal.Rd`).

2. **README documents internal API** — The "Low-Level API" section at line 108 shows
   `spc_plot_config()`, `viewport_dims()`, and `bfh_spc_plot()` as user-facing. These
   are internal-only (`@keywords internal @noRd` in source). The README contradicts the
   package's "1 function bfh_qic()" contract.

3. **`bfh_qic_result` class topic has `@keywords internal`** — The class is public
   (returned by every `bfh_qic()` call), but its topic has `@keywords internal`.
   Remove it, and add a `$qic_data` column contract section.

4. **`new_bfh_qic_result` is exported but the class is marked internal** — Constructor
   is exported and usable; the internal flag is only on the class topic.

## Solution

- Add `@noRd` to all internal functions missing it (removes 16 orphan Rd pages)
- Remove the "Low-Level API" section from README
- Remove `@keywords internal` from the `bfh_qic_result` class topic
- Add `@section qic_data columns:` Roxygen documentation to `new_bfh_qic_result`
- Add `@section Stability:` to `new_bfh_qic_result`
- Create `tests/testthat/test-public-api-contract.R` verifying the API surface
- MINOR version bump 0.10.5 → 0.11.0 (potentially breaking via Rd removal)

## Impact

- No behavior change
- No function signature change
- Rd files removed for internal functions (not a breaking change, they were never in NAMESPACE)
- README improved (docs change only)
