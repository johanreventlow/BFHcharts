# Tasks: align-public-api-documentation

## Status: Implemented

**Decisions made:**

- **(a) Low-level API trio** (`spc_plot_config`, `viewport_dims`, `bfh_spc_plot`): Kept internal.
  README "Low-Level API for Fine Control" section removed. `spc_plot_config` and `viewport_dims`
  already had `@keywords internal @noRd` in source. `print.spc_plot_config` and
  `print.viewport_dims` use `@noRd` on print methods (not `@rdname`), since `@rdname` would
  require a target Rd page which cannot exist when the class is `@noRd`.

- **(b) `new_bfh_qic_result`**: Confirmed not internally tagged (only the class topic at line 7
  had `@keywords internal`). Removed `@keywords internal` from class topic.
  Added `@section Stability:` and `@section qic_data columns:` to `new_bfh_qic_result` constructor.
  No lifecycle dependency added.

- **(c) S3 print methods for internal classes**: Applied `@noRd` to `print.spc_plot_config` and
  `print.viewport_dims`. S3 registration preserved in NAMESPACE. Rationale: `@rdname` requires
  an existing target Rd, impossible when class has `@noRd`.

- **(d) Orphan Rd pages**: Added `@noRd` to 16 internal functions across 4 files:
  `utils_typst.R` (8 functions), `utils_quarto.R` (4 functions),
  `utils_bfh_qic_helpers.R` (2 functions: `add_anhoej_signal`, `build_bfh_qic_return`),
  `config_objects.R` (2 print methods).

- **(e) `$qic_data` column contract**: Added `@section qic_data columns:` to `new_bfh_qic_result`
  documenting canonical columns from qicharts2. Actual columns verified via load_all().

- **(f) README update**: Removed "Low-Level API for Fine Control" section (lines 108-137).
  Updated Features bullet from "low-level customization" to "composable ggplot2 objects".

## Checklist

- [x] (a) Low-level API trio kept internal, README section removed
- [x] (b) `new_bfh_qic_result` class topic cleaned, stability + column contract added
- [x] (c) S3 print methods have `@noRd`, NAMESPACE registration preserved
- [x] (d) 16 orphan Rd pages removed via `@noRd` additions
- [x] (e) `$qic_data` column contract documented
- [x] (f) README Low-Level API section removed
- [x] Test file `test-public-api-contract.R` created
- [x] `devtools::document()` run cleanly
- [x] Tests pass
- [x] DESCRIPTION bumped 0.10.5 → 0.11.0
- [x] NEWS.md updated
