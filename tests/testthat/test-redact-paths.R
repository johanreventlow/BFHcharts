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

test_that(".redact_paths also strips the Windows backslash form of tempdir", {
  # file.copy()/system2() report OS-native paths -- on Windows that means
  # "\" separators, even though tempdir()/normalizePath(winslash = "/")
  # always return "/". Simulate a Windows-native warning message on any
  # test platform by backslash-ifying the real tempdir() path.
  td_norm <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
  td_bslash <- gsub("/", "\\", td_norm, fixed = TRUE)
  msg <- paste0(
    "problem copying ", td_bslash, "\\bfh-template\\images\\logo.png",
    " to ", td_bslash, "\\out\\images\\logo.png: No space left on device"
  )
  redacted <- BFHcharts:::.redact_paths(msg)
  expect_match(redacted, "<tmpdir>", fixed = TRUE)
  expect_false(grepl(td_bslash, redacted, fixed = TRUE),
    info = "backslash-form tempdir-prefix must not appear in redacted output"
  )
  expect_match(redacted, "No space left on device", fixed = TRUE)
})

test_that(".file_copy_capture reports success with no warnings for a normal copy", {
  src <- withr::local_tempfile(lines = "hello")
  dest_dir <- withr::local_tempdir()
  result <- BFHcharts:::.file_copy_capture(src, file.path(dest_dir, "out.txt"))
  expect_true(result$success)
  expect_length(result$warnings, 0L)
})

test_that(".file_copy_capture captures the warning and reports failure", {
  src <- withr::local_tempfile(lines = "hello")
  # Destination's parent directory does not exist -> file.copy() fails and
  # emits a "problem copying ..." warning instead of erroring outright.
  bad_dest <- file.path(withr::local_tempdir(), "no_such_subdir", "out.txt")
  result <- BFHcharts:::.file_copy_capture(src, bad_dest)
  expect_false(result$success)
  expect_gt(length(result$warnings), 0L)
  expect_match(result$warnings[[1]], "problem copying", fixed = TRUE)
})

test_that(".format_copy_failure_reason formats and redacts the first warning", {
  td <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
  warnings <- paste0("problem copying ", td, "/a.txt to ", td, "/b.txt: disk full")
  formatted <- BFHcharts:::.format_copy_failure_reason(warnings)
  expect_match(formatted, "^\\n  Reason: ")
  expect_match(formatted, "disk full", fixed = TRUE)
  expect_false(grepl(td, formatted, fixed = TRUE))
})

test_that(".format_copy_failure_reason returns empty string for no warnings", {
  expect_equal(BFHcharts:::.format_copy_failure_reason(character(0)), "")
})

test_that(".stage_packaged_template_dir stop() includes the Reason detail on copy failure", {
  # End-to-end wiring check via a deterministic, cross-platform copy
  # failure: file.copy(src_dir, output_dir, recursive = TRUE) needs to
  # create output_dir/<basename(src_dir)>/ as a directory, but a regular
  # file already occupies that path -- no disk-full or permission tricks
  # needed, and the real file.copy()-warning path (not a hand-crafted
  # message) is what reaches the stop().
  src_dir <- withr::local_tempdir()
  writeLines("x", file.path(src_dir, "a.txt"))

  output_dir <- withr::local_tempdir()
  writeLines("blocker", file.path(output_dir, basename(src_dir)))

  testthat::local_mocked_bindings(
    .get_or_stage_template_cache = function() src_dir,
    .package = "BFHcharts"
  )

  err <- tryCatch(
    BFHcharts:::.stage_packaged_template_dir(output_dir),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "Failed to copy template directory", fixed = TRUE)
  expect_match(conditionMessage(err), "Reason:", fixed = TRUE)
})
