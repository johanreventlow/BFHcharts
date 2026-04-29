## Why

`devtools::test()` currently shows 9 vdiffr failures and 12 warnings (Codex review 2026-04, finding #1). Visual regression tests are file-scoped skipped in CI via `skip_if_fonts_unavailable()` (`tests/testthat/test-visual-regression.R:28-31`), which gates on the `CI` env var rather than actual font detection — the entire vdiffr suite is unconditionally skipped in every automated pipeline run.

The dedicated render-tests workflow (`.github/workflows/render-tests.yaml`) exists but is **not PR-blocking** — it runs on a weekly cron and `workflow_dispatch` only (commit `306204d`, 2026-04). PR-check (`.github/workflows/R-CMD-check.yaml`) does not install Quarto.

**Consequence:** PDF/Typst regressions can merge to `main` between weekly render runs. Theme-level visual regressions (label placement, control limits, color mapping) are invisible until a developer happens to run vdiffr locally with Mari fonts installed.

Both reviews flagged this:
- Codex finding #3: "PR-check installerer ikke Quarto, og render-tests er ikke PR-blocking"
- Claude finding D1+D2: "Visual regression suite has zero CI value"

## What Changes

- Add a PR-blocking smoke-render job to `.github/workflows/R-CMD-check.yaml` (or a new `.github/workflows/pdf-smoke.yaml`)
- The smoke job SHALL:
  - Install Quarto (>= 1.4.0) via `quarto-dev/quarto-actions/setup`
  - Install Typst via the Typst official action (or use Quarto's bundled Typst)
  - Use a fallback font stack (Liberation Sans / DejaVu) registered as Mari/Arial/Roboto aliases via `setup.R`
  - Render 1-3 representative SPC charts to PDF via `bfh_export_pdf()`
  - Verify each PDF: exists, is non-empty, has expected page count via `pdftools::pdf_info()`
  - Optionally: run a content text-presence check via `pdftools::pdf_text()`
- Address the 9 existing vdiffr failures: review snapshots, accept legitimate intentional changes, fix unintentional regressions
- Re-enable vdiffr suite in CI: replace file-scope `skip_if_fonts_unavailable()` with per-test `skip_if_no_mari_font()` and provide a fallback-font path that satisfies the test
- Add release-check: `devtools::test()` MUST NOT have any vdiffr failure before tag

## Impact

**Affected specs:**
- `test-infrastructure` — ADDED requirements: PR-blocking PDF smoke-render; vdiffr CI execution; release-test-gate

**Affected code:**
- `.github/workflows/R-CMD-check.yaml` (or new `.github/workflows/pdf-smoke.yaml`) — new job
- `tests/testthat/test-visual-regression.R:28-31` — replace file-scope skip with per-test fallback-aware gating
- `tests/testthat/_snaps/visual-regression/` — accept/fix 9 failing snapshots
- `tests/testthat/setup.R` — fallback-font registration path for CI
- `tests/testthat/helper-skips.R` — add `skip_if_no_pdf_render_deps()` helper checking Quarto availability
- NEWS under `## CI`

**Not breaking:** Pure tooling addition.

## Cross-repo impact

None.

## Related

- Codex findings #1, #3
- Claude findings D1, D2
- Existing CI setup: `.github/workflows/R-CMD-check.yaml`, `.github/workflows/render-tests.yaml`
- Recent commit `306āčd6` (limited render-tests to cron)
