# dev/clean_workdir.R
# ============================================================================
# Remove known build/test artifacts from the working directory.
#
# Run from the package root:
#   Rscript dev/clean_workdir.R
#
# Removes:
#   - R CMD check output (BFHcharts.Rcheck/)
#   - Source tarballs (BFHcharts_*.tar.gz)
#   - Vignette build artifacts (doc/, Meta/)
#   - Default R plot output (Rplots.pdf at any level)
#   - Testthat parallel-failure artifacts (tests/testthat/_problems/)
#   - Shell-injection test directory (tests/testthat/output; rm -rf )
#
# Idempotent: safe to run when already clean.
# ============================================================================

pkg_root <- normalizePath(
  if (nzchar(getwd())) getwd() else ".",
  mustWork = TRUE
)

# Helper: remove path with confirmation message
remove_path <- function(path, recursive = FALSE) {
  full <- file.path(pkg_root, path)
  exists <- if (recursive) dir.exists(full) else file.exists(full)
  if (exists) {
    unlink(full, recursive = recursive, force = TRUE)
    message("Removed: ", path)
  }
}

# R CMD check output
remove_path("BFHcharts.Rcheck", recursive = TRUE)

# Source tarballs (find by pattern)
tarballs <- list.files(pkg_root, pattern = "^BFHcharts_.*\\.tar\\.gz$", full.names = FALSE)
for (tb in tarballs) remove_path(tb)

# Vignette build artifacts
remove_path("doc", recursive = TRUE)
remove_path("Meta", recursive = TRUE)

# Root-level Rplots.pdf
remove_path("Rplots.pdf")

# Testthat Rplots.pdf
remove_path("tests/testthat/Rplots.pdf")

# Testthat parallel-failure artifacts
remove_path("tests/testthat/_problems", recursive = TRUE)

# Shell-injection test directory (deliberate malformed name)
injection_dir <- file.path(pkg_root, "tests", "testthat", "output; rm -rf ")
if (dir.exists(injection_dir)) {
  unlink(injection_dir, recursive = TRUE, force = TRUE)
  message("Removed: tests/testthat/output; rm -rf ")
}

message("Clean done.")
