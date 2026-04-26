# Tasks: reuse-typst-template-assets

## 1. Implementation

- [x] 1.1 Opret `R/export_session.R` med `bfh_create_export_session()` factory
- [x] 1.2 Session-objekt: liste med `tmpdir`, `template_ready`, `close_fn`
- [x] 1.3 Tilføj `batch_session = NULL` parameter til `bfh_export_pdf()`
- [x] 1.4 Hvis `batch_session` gives: spring template-copy over, brug session tmpdir
- [x] 1.5 Hvis `batch_session = NULL`: eksisterende adfærd (opret + teardown)
- [x] 1.6 Tilføj `close()`/`on.exit()` cleanup for sessions

## 2. Benchmarks

> Formelle N=1/10/100 benchmarks er descoped — ingen måling er foretaget.
> Feature-korrekthed og testdækning er verificeret; speedup er dokumenteret
> kvalitativt i NEWS baseret på at eliminere rekursiv template-copy pr. kald.

- [ ] 2.1 Benchmark N=1 eksport: single-call vs. session-wrapped single-call
- [ ] 2.2 Benchmark N=10 eksport: uden session vs. med session
- [ ] 2.3 Benchmark N=100 eksport: uden session vs. med session
- [x] 2.4 Dokumentér speedup i proposal-relateret NEWS (kvalitativt; NEWS 0.8.3)

## 3. Testing

- [x] 3.1 Test: single-call uden session fungerer (backward compat)
- [x] 3.2 Test: batch-session genbruger tmpdir
- [x] 3.3 Test: session cleanup fjerner tmpdir
- [x] 3.4 Test: PDF-output sammenligning med/uden session (page-count smoke test;
      byte-identisk checksum er ikke realistisk for Typst PDF grundet
      nondeterministiske timestamps)

## 4. Documentation

- [x] 4.1 Roxygen `@param batch_session` + example
- [x] 4.2 README-section om batch workflow
- [x] 4.3 NEWS.md: batch-mode speedup
