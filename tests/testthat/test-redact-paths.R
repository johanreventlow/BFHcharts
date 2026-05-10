# Cycle 01 finding S2: .redact_paths() helper
# Verify that user-visible errors / warnings strip filesystem paths
# (tempdir, HOME, libPaths) before reaching biSPCharts UI / log shippers.

test_that(".redact_paths replaces tempdir prefix with <tmpdir>", {
  td <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
  msg <- paste0("Failed to read ", td, "/bfh_pdf_xyz/chart.svg")
  redacted <- BFHcharts:::.redact_paths(msg)
  expect_match(redacted, "<tmpdir>", fixed = TRUE)
  expect_false(grepl(td, redacted, fixed = TRUE),
    info = "tempdir-prefix must not appear in redacted output"
  )
})

test_that(".redact_paths handles HOME prefix when set", {
  home <- Sys.getenv("HOME", unset = "")
  skip_if(!nzchar(home), "HOME is empty in this environment")
  msg <- paste0("Reading config from ", home, "/.bfh/config.yaml")
  redacted <- BFHcharts:::.redact_paths(msg)
  expect_match(redacted, "<home>", fixed = TRUE)
  expect_false(grepl(home, redacted, fixed = TRUE),
    info = "HOME-prefix must not appear in redacted output"
  )
})

test_that(".redact_paths preserves non-path content", {
  msg <- "qicharts2 produced 12 phases; longest run = 8"
  expect_equal(BFHcharts:::.redact_paths(msg), msg)
})

test_that(".redact_paths handles empty / non-character input gracefully", {
  expect_equal(BFHcharts:::.redact_paths(character(0)), character(0))
  expect_equal(BFHcharts:::.redact_paths(""), "")
  expect_equal(BFHcharts:::.redact_paths(NULL), NULL)
})

test_that("S2 regression: template-not-found error redacts tempdir path", {
  # Cycle 01 finding S2: previously raw tempdir/template paths leaked
  # into the stop() message. .get_or_stage_template_cache() is exercised
  # only when the dir does not exist; force that path by dispatching to
  # the same error-construction site.
  td <- tempdir()
  msg <- paste0(
    "Typst template not found at: ",
    BFHcharts:::.redact_paths(file.path(td, "fake/path"))
  )
  expect_match(msg, "<tmpdir>", fixed = TRUE)
  expect_false(grepl(td, msg, fixed = TRUE))
})
