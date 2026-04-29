# Tests for public API surface contract
# Verificerer at NAMESPACE-exports matcher dokumentation og at
# qic_data-kolonnekontrakt er opfyldt.

# ----------------------------------------------------------------------------
# Export surface: hvert NAMESPACE-export skal have en Rd-side
# og maa ikke have @keywords internal i source
# ----------------------------------------------------------------------------

test_that("all NAMESPACE exports have a corresponding Rd file", {
  pkg_exports <- getNamespaceExports("BFHcharts")
  man_dir <- system.file("help", package = "BFHcharts")

  # Alternativt: brug devtools::load_all-stiknown man/ i package root
  # Fallback naar pakken er loadet via load_all (help-dir er tomt)
  if (!nzchar(man_dir) || !dir.exists(man_dir)) {
    skip("Package not installed — run devtools::install() to test Rd coverage")
  }

  # Rd filnavne (uden .Rd extension)
  rd_names <- tools::Rd_db(package = "BFHcharts")
  documented <- names(rd_names)

  for (fn in pkg_exports) {
    expect_true(
      any(grepl(fn, documented, fixed = TRUE)),
      info = paste0("Export '", fn, "' has no Rd page")
    )
  }
})

test_that("exported functions are not tagged @keywords internal in source", {
  # Brug roxygen2 til at inspicere tags — simpel tilgang: scan R/ kildefiler
  pkg_exports <- getNamespaceExports("BFHcharts")

  # Find R/ directory: tests/testthat/ er to niveauer under package root
  pkg_root_candidate <- tryCatch(
    normalizePath(file.path(test_path(), "..", ".."), mustWork = FALSE),
    error = function(e) NULL
  )

  has_desc <- !is.null(pkg_root_candidate) &&
    file.exists(file.path(pkg_root_candidate, "DESCRIPTION"))
  has_r_dir <- !is.null(pkg_root_candidate) &&
    dir.exists(file.path(pkg_root_candidate, "R"))

  pkg_root <- NULL
  if (has_desc && has_r_dir) {
    pkg_root <- file.path(pkg_root_candidate, "R")
  }

  if (is.null(pkg_root)) {
    skip("Cannot locate R/ source directory — run tests via devtools::test()")
  }

  r_files <- list.files(pkg_root, pattern = "\\.R$", full.names = TRUE)

  for (fn in pkg_exports) {
    for (rfile in r_files) {
      content <- readLines(rfile, warn = FALSE)
      # Find roxygen blocks that define this function
      fn_lines <- grep(paste0("^", fn, "\\s*<-\\s*function"), content)
      if (length(fn_lines) == 0) next

      # Look back at the preceding roxygen block (up to 100 lines)
      for (fn_line in fn_lines) {
        block_start <- max(1, fn_line - 100)
        block <- content[block_start:fn_line]
        # Check for @keywords internal WITHOUT also having @noRd
        # (which would suppress Rd page generation)
        has_keywords_internal <- any(grepl("@keywords internal", block))
        has_no_rd <- any(grepl("@noRd", block))

        if (has_keywords_internal && !has_no_rd) {
          fail(paste0(
            "Export '", fn, "' in ", basename(rfile),
            " has @keywords internal without @noRd.",
            " Either remove @keywords internal or add @noRd."
          ))
        }
      }
    }
  }
  succeed("All checked exports pass @keywords internal check")
})

# ----------------------------------------------------------------------------
# qic_data column contract smoke test
# ----------------------------------------------------------------------------

test_that("bfh_qic() result$qic_data contains canonical columns", {
  d <- fixture_minimal_chart_data(n = 15)
  result <- bfh_qic(d, x = month, y = infections, chart_type = "i")

  expect_s3_class(result, "bfh_qic_result")
  qd <- result$qic_data
  expect_true(is.data.frame(qd))

  # Kanoniske kolonner fra qic_data-kontrakten i new_bfh_qic_result()
  canonical_cols <- c("x", "y", "cl", "ucl", "lcl")
  for (col in canonical_cols) {
    expect_true(
      col %in% names(qd),
      info = paste0("qic_data missing canonical column: '", col, "'")
    )
  }
})

test_that("bfh_qic() result$qic_data contains signal columns", {
  d <- fixture_minimal_chart_data(n = 20)
  result <- bfh_qic(d, x = month, y = infections, chart_type = "i")

  qd <- result$qic_data
  expect_true("sigma.signal" %in% names(qd), info = "Missing sigma.signal")
  expect_true("runs.signal" %in% names(qd), info = "Missing runs.signal")
  expect_true("anhoej.signal" %in% names(qd), info = "Missing anhoej.signal")

  # Signal-kolonner er logiske vektorer
  expect_type(qd$sigma.signal, "logical")
  expect_type(qd$anhoej.signal, "logical")
})

test_that("bfh_qic() result$qic_data anhoej.signal is never NA", {
  d <- fixture_minimal_chart_data(n = 12)
  result <- bfh_qic(d, x = month, y = infections, chart_type = "i")

  expect_false(
    any(is.na(result$qic_data$anhoej.signal)),
    info = "anhoej.signal contains NA values (should always be TRUE/FALSE)"
  )
})
