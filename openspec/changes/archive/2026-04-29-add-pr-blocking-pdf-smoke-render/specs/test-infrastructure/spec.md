## ADDED Requirements

### Requirement: PRs SHALL be blocked by a PDF smoke-render job

Pull requests targeting `main` or `develop` SHALL be required to pass a CI job that:
- installs Quarto (>= 1.4.0) and Typst
- renders at least one representative SPC chart to PDF via `bfh_export_pdf()`
- verifies the resulting PDF exists, is non-empty, and has the expected page count

The job SHALL be marked `required` in branch protection so a failing render blocks merge.

**Rationale:** PDF/Typst regressions otherwise reach `main` between weekly render-tests runs. The smoke job runs the actual export pipeline against actual Quarto/Typst, catching environment-specific failures before merge.

#### Scenario: smoke-render job runs on every PR

- **GIVEN** a pull request opened against `main` or `develop`
- **WHEN** CI runs
- **THEN** a job named `pdf-smoke` (or equivalent) SHALL execute
- **AND** the job SHALL be required for merge

#### Scenario: smoke-render fails on broken Typst output

- **GIVEN** a code change that breaks `bfh_compile_typst()`
- **WHEN** the smoke-render job runs
- **THEN** the job SHALL fail with a non-zero exit code
- **AND** the PR SHALL be blocked from merge

### Requirement: vdiffr suite SHALL execute in CI with fallback fonts

Visual regression tests SHALL run in CI using a fallback font stack (e.g. Liberation Sans, DejaVu Sans) registered as `Mari` / `Arial` / `Roboto` aliases when the production fonts are unavailable. File-scope `skip_if_fonts_unavailable()` calls that gate solely on the `CI` env var SHALL be removed.

#### Scenario: vdiffr tests run in CI

- **GIVEN** a CI environment where Mari fonts are unavailable
- **WHEN** the test suite runs
- **THEN** vdiffr tests SHALL execute against fallback-font snapshots
- **AND** tests SHALL fail when visual output deviates from the accepted snapshots

#### Scenario: vdiffr regression blocks PR

- **GIVEN** a code change that alters chart visuals (e.g. label placement)
- **WHEN** CI runs vdiffr tests
- **THEN** the relevant vdiffr test SHALL fail until the snapshot is reviewed and accepted

### Requirement: Release SHALL require zero vdiffr failures

Pre-release checklists SHALL include the assertion that `devtools::test()` produces zero vdiffr failures and zero unaddressed warnings. This SHALL be enforced via the release-process documentation (CONTRIBUTING / openspec change template).

#### Scenario: release-tag aborts on vdiffr failure

- **GIVEN** a developer attempting to tag a release with outstanding vdiffr failures
- **WHEN** the pre-release checklist is evaluated
- **THEN** the checklist SHALL flag the failures and block tag creation
