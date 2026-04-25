# reuse-typst-template-assets

## Why

`bfh_create_typst_document()` kopierer hele `bfh`-template-mappen
rekursivt til en temp-dir ved hver PDF-eksport. Ved batch-generering
(fx 100+ afdelingsrapporter) skaber det unødig disk-I/O og forsinker
eksportpipelinen.

Gemini performance-review anbefaler: check om assets allerede findes,
eller tillad batch-kald at genbruge temp-dirs.

## What Changes

- Tilføj opt-in batch-mode til `bfh_export_pdf()`: `batch_session = NULL` parameter
- Introducer `bfh_create_export_session()` factory der opretter én template-kopi og returnerer handle
- Enkelt-kald: uændret adfærd (opret + cleanup)
- Batch-kald: genbrug samme session på tværs af eksports, cleanup ved session-close
- Benchmark: mål før/efter for N=1, 10, 100 eksporter

## Impact

**Affected specs:**
- `pdf-export`

**Affected code:**
- `R/utils_typst.R` (asset-reuse logic)
- `R/export_pdf.R` (batch_session parameter)
- `R/export_session.R` (ny: session factory)
- `tests/testthat/test-export-batch.R` (ny)

**User-visible changes:**
- Ny opt-in parameter `batch_session` (default NULL preserves eksisterende adfærd)
- Ingen breaking changes

## Related

- Gemini review (Performance-flaskehals i batch-eksport)
