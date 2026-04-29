## 1. Resolve existing vdiffr failures

- [ ] 1.1 Run `devtools::test(filter = "visual-regression")` locally with Mari fonts installed
- [ ] 1.2 For each of the 9 failures: inspect snapshot diff
- [ ] 1.3 Categorize: intentional change (accept) vs unintentional regression (fix)
- [ ] 1.4 Update snapshots via `testthat::snapshot_accept()` or fix code
- [ ] 1.5 Re-run; verify 0 failures

## 2. CI fallback-font path

- [ ] 2.1 In `tests/testthat/setup.R`, add CI-aware font registration: when `Sys.getenv("CI") == "true"`, register Liberation Sans / DejaVu Sans as Mari/Arial/Roboto aliases
- [ ] 2.2 Add `skip_if_no_pdf_render_deps()` helper in `tests/testthat/helper-skips.R` that checks `quarto_available()` instead of font availability
- [ ] 2.3 In `test-visual-regression.R:28-31`, remove file-scope skip; per-test, use fallback-aware skipping

## 3. PR-blocking smoke-render job

- [ ] 3.1 Create or update `.github/workflows/pdf-smoke.yaml` (or add job to `R-CMD-check.yaml`)
- [ ] 3.2 Use `quarto-dev/quarto-actions/setup@v2` to install Quarto >= 1.4.0
- [ ] 3.3 Verify Typst is available (Quarto bundles >= 1.4)
- [ ] 3.4 Install BFHcharts + Suggests (pdftools, withr)
- [ ] 3.5 Run a smoke-render script (e.g. `tests/smoke/render_smoke.R`) that produces 1-3 PDFs from canned data
- [ ] 3.6 Assert each PDF exists, is non-empty, has expected page count via `pdftools::pdf_info()`
- [ ] 3.7 Mark the job `required` in branch protection

## 4. Smoke-render fixtures

- [ ] 4.1 Create `tests/smoke/render_smoke.R` with 1-3 representative `bfh_export_pdf()` calls
- [ ] 4.2 Use `inst/extdata/spc_exampledata.csv` as input
- [ ] 4.3 Output to a temp directory; clean up after assertions

## 5. Release-test gate

- [ ] 5.1 Add release-checklist item in `openspec/changes/.../tasks.md` template: "devtools::test() must have 0 vdiffr failures"
- [ ] 5.2 Document in CONTRIBUTING.md (or equivalent) that visual changes require updated snapshots in PR

## 6. Documentation

- [ ] 6.1 Update `tests/testthat/README.md` documenting the CI font fallback strategy
- [ ] 6.2 NEWS entry under `## CI`

## 7. Verify

- [ ] 7.1 Open a draft PR with a deliberate-regression to verify the gate fails the PR
- [ ] 7.2 Verify the gate passes on a clean PR
