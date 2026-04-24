# Tasks: reuse-typst-template-assets

## 1. Implementation

- [ ] 1.1 Opret `R/export_session.R` med `bfh_create_export_session()` factory
- [ ] 1.2 Session-objekt: liste med `tmpdir`, `template_ready`, `close_fn`
- [ ] 1.3 Tilføj `batch_session = NULL` parameter til `bfh_export_pdf()`
- [ ] 1.4 Hvis `batch_session` gives: spring template-copy over, brug session tmpdir
- [ ] 1.5 Hvis `batch_session = NULL`: eksisterende adfærd (opret + teardown)
- [ ] 1.6 Tilføj `close()`/`on.exit()` cleanup for sessions

## 2. Benchmarks

- [ ] 2.1 Benchmark N=1 eksport: single-call vs. session-wrapped single-call
- [ ] 2.2 Benchmark N=10 eksport: uden session vs. med session
- [ ] 2.3 Benchmark N=100 eksport: uden session vs. med session
- [ ] 2.4 Dokumentér speedup i proposal-relateret NEWS

## 3. Testing

- [ ] 3.1 Test: single-call uden session fungerer (backward compat)
- [ ] 3.2 Test: batch-session genbruger tmpdir
- [ ] 3.3 Test: session cleanup fjerner tmpdir
- [ ] 3.4 Test: PDF-output er byte-identisk (eller identisk checksum) med/uden session

## 4. Documentation

- [ ] 4.1 Roxygen `@param batch_session` + example
- [ ] 4.2 Vignette eller README-section om batch workflow
- [ ] 4.3 NEWS.md: batch-mode speedup
