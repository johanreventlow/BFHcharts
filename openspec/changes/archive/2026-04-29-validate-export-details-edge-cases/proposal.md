## Why

`bfh_generate_details()` (`R/export_details.R:51`) calls `min(..., na.rm = TRUE)` and `max(..., na.rm = TRUE)` on `qic_data$x` (or the equivalent date column) without first verifying that any finite, parseable values exist. Codex review 2026-04 surfaced warnings during cleanup-scenario test runs:

> `bfh_generate_details()` calls min/max(..., na.rm=TRUE) uden først at validere gyldige x-værdier. Testkørslen viser warnings ved tom/ugyldig export-data i cleanup-scenarier.

When `qic_data$x` is empty or contains only `NA`/non-finite values, `min(c(NA, NA), na.rm = TRUE)` returns `Inf` with a warning ("no non-missing arguments to min; returning Inf"). The detail string downstream then renders `"Inf - -Inf"` or similar nonsense in the PDF metadata, or fails when formatted as a date.

**Consequence:** Noisy or misleading details in PDF edge cases (e.g. all-NA filter result, empty session-batch reuse, partially-failed export). The chart and PDF still render, but the metadata band shows garbage.

## What Changes

- In `bfh_generate_details()`, validate that at least one finite/non-NA value exists in the x-column before calling `min`/`max`
- Fail early with a clear error if no valid x-values exist (rather than silently returning `Inf`/`-Inf`)
- Add explicit handling for date/POSIXct columns: ensure values are parseable before range computation
- Add tests for: empty x, all-NA x, single non-NA x, mixed NA + non-finite values
- Document the contract in Roxygen `@details`

## Impact

**Affected specs:**
- `pdf-export` — ADDED requirement: `bfh_generate_details()` SHALL fail-early on inevaluable x-range

**Affected code:**
- `R/export_details.R:51` — input validation gate before `min`/`max`
- `tests/testthat/test-generate_details.R` — add edge-case tests
- NEWS entry under `## Bug fixes`

**Not breaking:** Calls with valid data unchanged. Calls with previously-Inf-producing data now error explicitly. Callers must provide valid x or handle the error.

## Cross-repo impact (biSPCharts)

biSPCharts batch-export logic may produce empty/all-NA frames in cleanup scenarios. Verify error-handling around `bfh_export_pdf()` catches the new error type cleanly. Coordinate with maintainer to ensure UI surfaces a user-readable message rather than crashing.

biSPCharts version bump: PATCH if error-handler updates needed.

## Related

- Codex review 2026-04 (finding #6)
- Source: `tests/testthat/test-generate_details.R` cleanup-scenario warnings
