## Why

`bfh_qic()` and the auto-analysis pipeline accept several malformed inputs without early errors, causing downstream qicharts2/plot fails or silently misleading charts. Codex code review 2026-04-30 flagged three findings:

- **C4** (`R/utils_export_helpers.R:49`, `R/spc_analysis.R:27`) — `metadata$target` accepts numeric vectors of any length and non-finite values. `target = c(1, 2)` produces unclear downstream warnings.
- **C5** (`R/utils_bfh_qic_helpers.R:214`) — empty `data.frame()` is accepted; failure surfaces only as a secondary qicharts2 error rather than a clean "data cannot be empty" message.
- **C6** (`R/utils_bfh_qic_helpers.R:233`) — `part`, `freeze`, `exclude` are validated as numeric and bounds-checked, but not as integer position indices, not for sorting, not for uniqueness. `part = 3.5` or `part = c(12, 12)` is accepted.

In clinical use, kryptisk fejl midt i qicharts2-kæden skader brugeroplevelsen og kan skjule data-kvalitetsproblemer. Tidlig, klar validering på public API matcher pakkens etablerede mønster (jf. denominator-validator i v0.9.0).

## What Changes

### 1. metadata$target scalar/finite validation

`R/utils_export_helpers.R` — new internal helper `.validate_metadata_target(x)`:
- If `NULL`: pass through (no target)
- If numeric: SHALL be `length(x) == 1` and `is.finite(x)`. Reject `c(1, 2)`, `NA`, `Inf`, `NaN`.
- If character: SHALL be `length(x) == 1` and not `NA`. Empty string allowed (treated as no target).
- Otherwise: error with informative message.

Called from `bfh_export_pdf()`, `bfh_generate_analysis()`, `bfh_build_analysis_context()`.

### 2. Empty data early error

`R/utils_bfh_qic_helpers.R` — `validate_bfh_qic_inputs()` SHALL check `nrow(data) > 0` immediately after `is.data.frame(data)` (line ~214). Error message: `"'data' is empty; bfh_qic() requires at least one row"`.

### 3. Integer/sorted/unique part/freeze/exclude

`R/utils_bfh_qic_helpers.R` — `validate_part_indices()`, `validate_freeze_index()`, `validate_exclude_indices()`:
- `part`: SHALL be positive integers (`x == floor(x)` after numeric coercion), strictly increasing (sorted), unique. Bounds: `1 < part[i] <= nrow(data)` for non-trailing, last allowed equal to nrow.
- `freeze`: SHALL be a single positive integer in `[MIN_BASELINE_N, nrow(data) - 1]`. Same integer-ness check.
- `exclude`: SHALL be positive integers in `[1, nrow(data)]`, unique. Sorting not required (positions can be non-contiguous).

### 4. y non-numeric early error

`R/utils_bfh_qic_helpers.R` — after column-name validation, SHALL coerce-test `y_data <- data[[y_col]]` and reject if not numeric (allowing integer). Error: `"column 'y' must be numeric, got <class>"`.

### Tests added (8 new):

- `metadata$target = c(1, 2)` → error
- `metadata$target = Inf` → error
- `metadata$target = NA_character_` → error
- `data = data.frame()` → error mentions "empty"
- `part = 3.5` → error mentions "integer"
- `part = c(12, 12)` → error mentions "unique"
- `part = c(12, 6)` → error mentions "increasing"
- `y_col` selecting a character column → error before qic call

## Impact

**Affected specs:**
- `public-api` — MODIFIED requirement: bfh_qic input validation contract

**Affected code:**
- `R/utils_export_helpers.R` — new `.validate_metadata_target()`
- `R/utils_bfh_qic_helpers.R` — new index validators, empty-data check, y-numeric check, wired into `validate_bfh_qic_inputs()`
- `R/spc_analysis.R:27` — call `.validate_metadata_target()` from `bfh_generate_analysis()` entry
- `tests/testthat/test-bfh_qic_edge_cases.R` — 8 new tests
- `NEWS.md` — entry under `## Breaking changes` (if any callers passed previously-accepted malformed input)

**Breaking change scope:** Pre-1.0 → MINOR. Callers that previously passed:
- Multi-element `metadata$target` → must use single value
- Non-integer `part` → must use integers
- Duplicated/unsorted `part` → must deduplicate and sort
- Non-numeric y column → must convert

Each error message identifies the violation precisely so migration is clear.

## Cross-repo impact (biSPCharts)

**Verification:**
```bash
# In biSPCharts:
grep -rn "metadata\$target\|target = " R/ | head -30
grep -rn "part = \|freeze = " R/ | head -30
```

**Likely affected:**
- biSPCharts UI inputs that build metadata$target — confirm scalar
- Phase splitter UI — confirm integer-only inputs

**biSPCharts version bump:** PATCH (input cleaning at app boundary, no UI change).

**Lower-bound:** `BFHcharts (>= 0.12.0)`.

## Related

- Source: Codex code review 2026-04-30 (findings #4, #5, #6)
- Combine with `2026-04-30-fix-chart-target-fallback-in-auto-analysis` for v0.12.0 release
