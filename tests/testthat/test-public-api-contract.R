# Tests for public API surface contract
# Verificerer at NAMESPACE-exports matcher dokumentation og at
# qic_data-kolonnekontrakt er opfyldt.

# ----------------------------------------------------------------------------
# Export surface: hvert NAMESPACE-export skal have en Rd-side
# og maa ikke have @keywords internal i source
# ----------------------------------------------------------------------------

test_that("all NAMESPACE exports have a corresponding Rd file", {
  pkg_exports <- getNamespaceExports("BFHcharts")

  # Load Rd database: prefer installed package (R CMD check); fall back to
  # in-tree man/ when running via devtools::test() (load_all empties help/).
  rd_db <- tryCatch(tools::Rd_db(package = "BFHcharts"), error = function(e) list())
  if (length(rd_db) == 0) {
    # In-tree fallback: tests/testthat/ is two levels below package root
    pkg_root_candidate <- tryCatch(
      normalizePath(file.path(test_path(), "..", ".."), mustWork = FALSE),
      error = function(e) NULL
    )
    in_tree_man <- if (!is.null(pkg_root_candidate)) {
      file.path(pkg_root_candidate, "man")
    }
    if (!is.null(in_tree_man) && dir.exists(in_tree_man)) {
      rd_db <- tryCatch(
        suppressWarnings(tools::Rd_db(dir = pkg_root_candidate)),
        error = function(e) list()
      )
    }
  }
  if (length(rd_db) == 0) {
    skip("No Rd database available -- run devtools::document() first")
  }

  # Extract \\alias{} values from all Rd pages. Each export must appear as an
  # exact alias in at least one Rd page. Using aliases (not filenames) correctly
  # handles @rdname/@describeIn groups where multiple exports share one .Rd file.
  # Previously used grepl(fn, rd_names) which caused false positives: e.g.
  # "bfh_qic" matched "bfh_qic_result.Rd", hiding undocumented exports (#458).
  alias_tag <- paste0(rawToChar(as.raw(0x5c)), "alias")
  documented <- unique(unlist(lapply(rd_db, function(rd) {
    out <- character(0)
    for (item in rd) {
      if (!is.null(attr(item, "Rd_tag")) && attr(item, "Rd_tag") == alias_tag) {
        val <- item[[1]]
        if (is.character(val)) out <- c(out, val)
      }
    }
    out
  })))

  for (fn in pkg_exports) {
    expect_true(
      fn %in% documented,
      info = paste0("Export '", fn, "' has no \\alias{} in any Rd page")
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

# ----------------------------------------------------------------------------
# Regression: print.summary fully removed (deprecation cycle complete)
# print.summary was removed from public API in v0.11.0 (signature accepted
# print.summary = FALSE silently, errored on TRUE). In v0.14.3 the parameter
# was removed entirely. These tests verify that no trace of the parameter
# remains in the public Rd.
# Bruger in-tree man/ saa testen koerer under baade devtools::test() og R CMD check.
# ----------------------------------------------------------------------------

.rd_path_bfh_qic <- function() {
  # Prioriter installeret pakke; fald tilbage til in-tree man/ (devtools::test)
  installed <- system.file("man", "bfh_qic.Rd", package = "BFHcharts")
  if (nzchar(installed) && file.exists(installed)) {
    return(installed)
  }

  # In-tree: tests/testthat/ er to niveauer under package root
  pkg_root_candidate <- tryCatch(
    normalizePath(file.path(test_path(), "..", ".."), mustWork = FALSE),
    error = function(e) NULL
  )
  if (!is.null(pkg_root_candidate)) {
    candidate <- file.path(pkg_root_candidate, "man", "bfh_qic.Rd")
    if (file.exists(candidate)) {
      return(candidate)
    }
  }
  NULL
}

test_that("bfh_qic signature does not include print.summary (removed)", {
  fmls <- formals(bfh_qic)
  expect_false(
    "print.summary" %in% names(fmls),
    info = "bfh_qic() formals still contain print.summary parameter"
  )
})

test_that("bfh_qic Rd does not mention print.summary at all", {
  rd_path <- .rd_path_bfh_qic()
  skip_if(is.null(rd_path), "Cannot locate man/bfh_qic.Rd")

  rd_content <- readLines(rd_path, warn = FALSE)
  expect_false(
    any(grepl("print.summary", rd_content, fixed = TRUE)),
    info = "Rd still references print.summary (parameter was removed entirely)"
  )
})

# ----------------------------------------------------------------------------
# Regression: chart type documentation completeness (complete-chart-type-public-docs)
# Verificerer at alle typer i CHART_TYPES_EN er dokumenteret i man/bfh_qic.Rd.
# ----------------------------------------------------------------------------

test_that("bfh_qic Rd documents all validated chart types", {
  rd_path <- .rd_path_bfh_qic()
  skip_if(is.null(rd_path), "Cannot locate man/bfh_qic.Rd")

  rd_content <- paste(readLines(rd_path, warn = FALSE), collapse = "\n")

  for (t in BFHcharts:::CHART_TYPES_EN) {
    # Match the quoted chart-type token via fixed-string search; all types
    # appear quoted in the Rd param list, so this is reliable.
    expect_true(
      grepl(paste0("\"", t, "\""), rd_content, fixed = TRUE),
      info = paste("Chart type", t, "missing from bfh_qic.Rd")
    )
  }
})
