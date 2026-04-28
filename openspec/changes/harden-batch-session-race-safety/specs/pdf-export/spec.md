## ADDED Requirements

### Requirement: Batch session SHALL use per-export unique intermediate filenames

The package SHALL generate per-export unique filenames for intermediate artifacts (`chart.svg`, `document.typ`) within a shared `batch_session` tmpdir to eliminate filename collisions between exports and to make race conditions impossible by construction.

**Rationale:**
- Fixed filenames create a guaranteed collision if any caller violates the documented sequential-only contract (e.g., calling from `future_lapply()`)
- Even sequential semantics benefit: a crashed export leaves orphan files only for its own filenames, preventing pollution of subsequent exports
- Unique names cost only one `tempfile()` call per export — negligible overhead

**Filename pattern:**
```r
chart_svg <- tempfile(pattern = "chart-", tmpdir = temp_dir, fileext = ".svg")
typst_file <- tempfile(pattern = "document-", tmpdir = temp_dir, fileext = ".typ")
```

The Typst document SHALL reference the chart by relative basename (already the case in `build_typst_content()`), so unique filenames cause no document-content changes.

#### Scenario: sequential batch produces unique intermediates per export

- **GIVEN** a batch session and 10 sequential `bfh_export_pdf()` calls
- **WHEN** all calls complete
- **THEN** no two intermediate filenames SHALL have collided
- **AND** all 10 final PDFs SHALL be valid

```r
session <- bfh_create_export_session()
on.exit(close(session))
for (i in 1:10) {
  out <- tempfile(fileext = ".pdf")
  bfh_export_pdf(result, out, batch_session = session)
  expect_true(file.exists(out))
}
```

#### Scenario: crash mid-export leaves only its own intermediates

- **GIVEN** an export that crashes after writing `chart-XYZ.svg` but before completing
- **WHEN** the next export runs in the same session
- **THEN** the next export SHALL use a different chart filename (`chart-ABC.svg`)
- **AND** the crashed export's orphan SHALL be removable independently

#### Scenario: parallel batch isolation by construction

- **GIVEN** two `bfh_export_pdf()` calls run concurrently against the same session (violating documented contract)
- **WHEN** both write intermediates
- **THEN** unique filenames SHALL prevent overwrite
- **AND** both PDFs SHALL be valid OR fail with clear error (not silently corrupted)

> Note: Parallel use is still not officially supported. This requirement removes a class of failure modes but does not promote parallel as a recommended pattern.

### Requirement: Batch session SHALL register a finalizer for orphan tmpdir cleanup

`bfh_create_export_session()` SHALL register a finalizer on the returned session object that calls `close()` if the user drops the reference without explicitly closing.

**Rationale:**
- R has no implicit RAII; users frequently forget `close()` in dashboards or scripts
- Without finalizer, abandoned sessions leave tmpdirs until R session ends
- Finalizer is a backup, not a substitute for `close()` — explicit cleanup is still preferred

#### Scenario: dropped session reference triggers cleanup on GC

- **GIVEN** a session created and reference dropped without `close()`
- **WHEN** garbage collection runs
- **THEN** the session tmpdir SHALL be removed
- **AND** no error SHALL be raised even if `close()` was never called

```r
local({
  session <- bfh_create_export_session()
  tmpdir_path <- session$tmpdir
  rm(session)
  gc()
  expect_false(dir.exists(tmpdir_path))
})
```
