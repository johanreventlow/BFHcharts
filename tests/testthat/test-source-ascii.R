# ============================================================================
# Source code ASCII-cleanliness guard
# ============================================================================
# Enforces openspec change "ascii-clean-source-files":
# All R/*.R files SHALL contain only ASCII bytes (0x00-0x7F). Non-ASCII
# Danish content belongs in roxygen string-literals (\\u escapes), i18n YAML,
# NEWS.md, vignettes, or README -- not in .R source.
#
# Failure output identifies file path, line number, and character position so
# offenders can be remediated quickly.

test_that("R/*.R sources contain only ASCII bytes", {
  pkg_root <- testthat::test_path("..", "..")
  r_dir <- file.path(pkg_root, "R")

  # When tests run from an installed package, R/ may not exist; skip gracefully.
  skip_if_not(dir.exists(r_dir), "R/ source directory not present")

  r_files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
  expect_gt(length(r_files), 0L)

  offenders <- list()
  for (f in r_files) {
    lines <- readLines(f, warn = FALSE, encoding = "UTF-8")
    for (i in seq_along(lines)) {
      line <- lines[[i]]
      bytes <- charToRaw(line)
      idx <- which(as.integer(bytes) > 127L)
      if (length(idx) > 0L) {
        offenders[[length(offenders) + 1L]] <- sprintf(
          "%s:%d: non-ASCII byte at column %s (line: %s)",
          basename(f), i, paste(idx, collapse = ","), line
        )
      }
    }
  }

  if (length(offenders) > 0L) {
    fail(paste0(
      "Non-ASCII bytes detected in R/*.R sources. ",
      "Move Danish prose to roxygen \\u escapes, i18n YAML, NEWS.md or vignettes:\n",
      paste(unlist(offenders), collapse = "\n")
    ))
  } else {
    succeed("All R/*.R files are ASCII-clean")
  }
})
