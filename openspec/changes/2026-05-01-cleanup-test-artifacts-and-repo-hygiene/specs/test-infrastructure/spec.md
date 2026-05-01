## ADDED Requirements

### Requirement: Tests SHALL leave no filesystem artifacts after run

After running `devtools::test()` on a clean checkout, `git status --porcelain` SHALL show no untracked files in the test directory other than:

- Files explicitly listed in `.gitignore` patterns under `tests/`
- Files inside `tests/testthat/_snaps/` that are tracked snapshot baselines

Specifically, NO test SHALL leave behind:

- Graphics device output files (`Rplots.pdf`)
- Temporary directories created during the test (including those with deliberately malformed names from security tests)
- Cache or scratch files outside of `tempdir()`

**Rationale:**
- Claude review 2026-05-01 K2 found `tests/testthat/output; rm -rf ` mappe efterladt af shell-injection-test
- Codex 2026-05-01 confirmed `Rplots.pdf` device-leak
- Untracked artifacts confuse `git status`, slow CI, and create false security signals

#### Scenario: Clean checkout has no artifacts after test run

- **GIVEN** a fresh `git clone` of the repository
- **WHEN** `devtools::test()` completes
- **THEN** `git status --porcelain tests/` SHALL output empty
- **AND** `ls tests/testthat/Rplots.pdf` SHALL fail with "no such file"
- **AND** no directory matching pattern `tests/testthat/output*` SHALL exist (except tracked snapshots)

### Requirement: Tests SHALL use withr or on.exit for filesystem operations

Tests that create files or directories SHALL use:

- `withr::local_tempfile()` for individual files,
- `withr::local_tempdir()` for working directories,
- `withr::defer(unlink(...))` or `on.exit(unlink(...))` for paths that cannot use the above,

and SHALL NOT use the pattern `if (file.exists(x)) unlink(x)` at the end of a test.

**Rationale:**
- The `if (file.exists())` pattern is race-prone and fails to clean up when the test errors mid-execution
- `withr` patterns guarantee cleanup even on error or interrupt
- Consistent cleanup convention reduces review burden and onboarding time

#### Scenario: Test that errors mid-execution still cleans up

- **GIVEN** a test that uses `withr::local_tempfile()`
- **AND** the test calls `stop()` before reaching its assertions
- **WHEN** `testthat::test_file()` runs the test
- **THEN** the tempfile SHALL be unlinked despite the error
- **AND** the working directory SHALL contain no leftover files from this test

### Requirement: Graphics-device tests SHALL close devices they open

Tests that produce graphics output via `pdf()`, `png()`, `svglite::svglite()`, or implicit device-opening SHALL close all devices they opened before returning.

A `helper-graphics.R` SHALL provide a `with_clean_graphics()` wrapper that asserts no new devices remain open after the test code completes.

#### Scenario: Test using with_clean_graphics closes devices

- **GIVEN** a test wrapped in `with_clean_graphics({...})`
- **WHEN** the test code opens a PDF device but forgets to close it
- **THEN** `with_clean_graphics()` SHALL close the device on exit
- **AND** no `Rplots.pdf` SHALL be created in the working directory
- **AND** the test SHALL emit a warning identifying the leak

### Requirement: Repository SHALL provide a clean target for build artifacts

The repository SHALL provide a documented mechanism (Makefile target `make clean` or `dev/clean_workdir.R`) that removes:

- `BFHcharts.Rcheck/`, `BFHcharts_*.tar.gz`, `doc/`, `Meta/` (R CMD build/check outputs)
- `Rplots.pdf` at any level
- `tests/testthat/_problems/` (testthat parallel-failure artifacts)
- Any directory matching the deliberate-injection-test pattern

Running this target SHALL be idempotent (no-op when already clean).

#### Scenario: Clean target removes all known artifacts

- **GIVEN** a working directory with `Rplots.pdf`, `BFHcharts.Rcheck/`, and `BFHcharts_0.9.0.tar.gz`
- **WHEN** `make clean` (or equivalent) is run
- **THEN** all listed artifacts SHALL be removed
- **AND** no tracked source files SHALL be modified
- **AND** running the command again SHALL complete without error
