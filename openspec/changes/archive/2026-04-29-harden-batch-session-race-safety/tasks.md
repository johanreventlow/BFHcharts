## 1. Per-export unique filenames

- [ ] 1.1 Replace `file.path(temp_dir, "chart.svg")` with `tempfile(pattern = "chart-", tmpdir = temp_dir, fileext = ".svg")`
- [ ] 1.2 Same for `document.typ` → `tempfile(pattern = "document-", tmpdir = temp_dir, fileext = ".typ")`
- [ ] 1.3 Track generated filenames in local variables; update cleanup `on.exit` to reference these
- [ ] 1.4 Verify Typst document references chart by relative basename (already does)

## 2. Session finalizer

- [ ] 2.1 Add `reg.finalizer(session, function(s) s$close())` in `bfh_create_export_session()`
- [ ] 2.2 Verify finalizer runs on session GC even without explicit close()
- [ ] 2.3 Test: create session, drop reference, force `gc()` → tmpdir cleaned

## 3. Concurrency tests

- [ ] 3.1 Extend `tests/testthat/test-export-session.R`
- [ ] 3.2 Sequential test: 5 exports back-to-back, verify all PDFs unique + valid
- [ ] 3.3 Crash recovery: simulate error mid-export, verify orphan files cleaned
- [ ] 3.4 (Optional) Parallel test using `parallel::mclapply` (skip on Windows): verify either success with isolation OR clear error
- [ ] 3.5 Stress test: 100 sequential exports → no leftover files in tempdir

## 4. Documentation

- [ ] 4.1 Update `bfh_create_export_session()` Roxygen with explicit safety guarantees
- [ ] 4.2 Document the per-export filename pattern for advanced users
- [ ] 4.3 NEWS entry

## 5. Release

- [ ] 5.1 PATCH bump
- [ ] 5.2 Tests pass
- [ ] 5.3 No new WARN/ERROR in `devtools::check()`

Tracking: GitHub Issue #213
