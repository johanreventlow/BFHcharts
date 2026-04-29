## ADDED Requirements

### Requirement: Temp directory protection SHALL rely on tempfile() + Sys.chmod(0700)

The temp directory created by `prepare_temp_workspace()` for PDF export SHALL be protected against other-user access by:

1. Use of `tempfile()` for path generation, which produces a path under per-user `tempdir()` (OS-isolated)
2. `Sys.chmod(temp_dir, mode = "0700", use_umask = FALSE)` to remove group/other read/write/execute permissions

The implementation SHALL NOT rely on `Sys.getenv("UID")`-based ownership validation, because `UID` is a shell-internal environment variable that is typically not exported to non-interactive R sessions (Rscript, RStudio Server, knitr, Shiny apps, GitHub Actions runners). Such checks evaluate as `integer(0)` or `NA_integer_` and silently skip without ever firing the protective error branch — providing misleading defense-in-depth without actual protection.

**Rationale:**

- `tempfile()` + `Sys.chmod(0700)` is the canonical and sufficient mechanism in R for per-user temp directory isolation
- Adding an unreliable check creates a false sense of security and increases maintenance burden
- This requirement aligns `prepare_temp_workspace()` with the simpler implementation already in `bfh_create_export_session()` (which uses only `Sys.chmod(0700)`)

#### Scenario: Temp directory has 0700 mode on Unix

- **GIVEN** `prepare_temp_workspace(NULL)` is called on a Unix system
- **WHEN** the function returns
- **THEN** `file.info(temp_dir)$mode` SHALL have permission bits `0700`
- **AND** group/other SHALL have no read/write/execute permission

```r
test_that("prepare_temp_workspace creates 0700 directory on Unix", {
  skip_on_os(c("windows"))
  ws <- prepare_temp_workspace(NULL)
  on.exit(unlink(ws$temp_dir, recursive = TRUE))
  mode_octal <- as.integer(file.info(ws$temp_dir)$mode) %% (8^3)
  expect_equal(mode_octal, strtoi("700", 8L))
})
```

#### Scenario: Temp directory path is under tempdir()

- **GIVEN** `prepare_temp_workspace(NULL)` is called
- **WHEN** the function returns
- **THEN** `temp_dir` SHALL start with `tempdir()` (per-user isolated parent)

```r
test_that("temp_dir is under tempdir()", {
  ws <- prepare_temp_workspace(NULL)
  on.exit(unlink(ws$temp_dir, recursive = TRUE))
  expect_true(startsWith(
    normalizePath(ws$temp_dir, mustWork = FALSE),
    normalizePath(tempdir(), mustWork = TRUE)
  ))
})
```

#### Scenario: Implementation does not rely on Sys.getenv("UID")

- **GIVEN** the source of `R/utils_export_helpers.R`
- **WHEN** the file is read
- **THEN** the implementation SHALL NOT contain `Sys.getenv("UID")` calls or UID-based ownership comparisons in `prepare_temp_workspace()` or any related helper
- **AND** any prior ownership-check code SHALL be replaced with an inline comment documenting why `tempfile()` + `Sys.chmod(0700)` is sufficient

```r
# Verification (regression test):
test_that("prepare_temp_workspace does not use Sys.getenv UID check", {
  src_path <- system.file("R", "utils_export_helpers.R", package = "BFHcharts")
  if (nchar(src_path) == 0) skip("source not installed")
  src <- readLines(src_path)
  expect_false(any(grepl('Sys.getenv\\("UID"\\)', src)))
})
```
