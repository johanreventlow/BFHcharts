# Contributing to BFHcharts

Thank you for contributing to BFHcharts. This document covers the CI pipeline,
branch protection setup, and development workflow.

---

## CI Pipeline

BFHcharts uses GitHub Actions for continuous integration. The following jobs run
on every pull request to `main` or `develop`:

| Job | File | PR-blocking | Purpose |
|-----|------|-------------|---------|
| `R-CMD-check` | `R-CMD-check.yaml` | Yes (ubuntu-latest/release) | R CMD check + full test suite incl. render tests |
| `pdf-smoke` | `pdf-smoke.yaml` | Yes | Smoke-render production PDF template |
| `git-archive-render` | `git-archive-render.yaml` | Yes | Render from git-tracked source only (catches untracked asset deps) |
| `test-coverage` | `test-coverage.yml` | No (advisory) | Coverage via covr + Codecov upload |
| `render-tests` | `render-tests.yaml` | No (weekly cron) | Full render integration tests |
| `lint` | `lint.yaml` | No | Linting via lintr |

### Which jobs gate merges

A PR must pass:
1. `R-CMD-check / ubuntu-latest (release)` — primary R CMD check + tests
2. `PDF smoke render / pdf-smoke (ubuntu-latest)` — production template renders
3. `git-archive-render / git-archive-render (ubuntu-latest)` — tracked-source-only render

### Key CI design decisions

- **Quarto installed in R-CMD-check**: `skip_if_no_quarto()` tests now execute
  rather than silently skip. DejaVu/Liberation fonts substitute for proprietary
  Mari fonts on CI runners.
- **pdf-smoke uses production template**: `inst/templates/typst/bfh-template/bfh-template.typ`
  is rendered directly. The `continue-on-error: true` guard on the render step is
  temporary until `fix-pdf-template-asset-contract` is merged.
- **git-archive-render**: Installs from `git archive HEAD` output, not the working
  tree. Fails if rendering depends on untracked files.
- **Coverage**: `test-coverage.yml` uploads to Codecov in advisory (non-blocking)
  mode. Threshold enforcement may be added after baseline is established.

---

## Branch Protection Setup

**[MANUELT TRIN]** Branch protection must be configured manually in the GitHub UI.
It cannot be set automatically without a GitHub API token with admin scope.

### How to configure (GitHub UI)

1. Go to the repository on GitHub.
2. Navigate to **Settings** → **Branches**.
3. Under **Branch protection rules**, click **Add rule** (or edit the existing
   rule for `main`).
4. Set **Branch name pattern** to `main`.
5. Enable **Require status checks to pass before merging**.
6. Enable **Require branches to be up to date before merging**.
7. In the status checks search box, add:
   - `R-CMD-check / ubuntu-latest (release)` (or the exact job name shown in GitHub)
   - `PDF smoke render / pdf-smoke (ubuntu-latest)`
   - `git-archive-render / git-archive-render (ubuntu-latest)`
8. Enable **Include administrators** (recommended).
9. Click **Save changes**.

Repeat for `develop` if needed.

> **Note:** Status check names in the search box must match the `name:` field of
> the job exactly as GitHub records it after the first run. If a job has not run
> yet on a PR, it will not appear in the search. Trigger the workflow via
> `workflow_dispatch` or a test PR first.

### Reproduce if accidentally reset

If branch protection settings are lost, re-apply the steps above. The canonical
list of required checks is documented in this file (section above).

---

## Development Workflow

### Setup

```r
# Install dependencies
pak::pak("local::.")

# Load package for interactive development
devtools::load_all()

# Run tests
devtools::test()

# Full check (as CRAN)
devtools::check(args = c("--no-manual", "--as-cran"))
```

### Before submitting a PR

- [ ] Tests pass: `devtools::test()`
- [ ] R CMD check clean: `devtools::check()`
- [ ] No new unhandled warnings in test output
- [ ] NAMESPACE updated if exports changed: `devtools::document()`
- [ ] NEWS.md entry added
- [ ] Version bumped in DESCRIPTION (PATCH for fixes, MINOR for features)
- [ ] ASCII-only in `R/*.R` files (enforced by `test-source-ascii.R`)

### Commit message format

```
type(scope): short description

Longer explanation (why, not how).
- Bullet points
- Reference: #123
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `style`

---

## Smoke Tests

Run the PDF smoke render locally:

```bash
Rscript tests/smoke/render_smoke.R
```

This uses the production template by default locally (CI=false). On CI,
set `BFHCHARTS_SMOKE_USE_PRODUCTION_TEMPLATE=true` to use the production template,
or leave unset to use the open-font test-template.

---

*See also: `openspec/` for change management and architecture decision records.*
