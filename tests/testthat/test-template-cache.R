# ============================================================================
# TESTS FOR SESSION-LEVEL TYPST TEMPLATE CACHE
# ============================================================================
# Verifies .get_or_stage_template_cache() and the cache-aware code path in
# .stage_packaged_template_dir(). These are performance-critical helpers
# introduced in K2 (perf/typst-template-stamp-file) to avoid repeated
# cross-filesystem template copies on single-call bfh_export_pdf().

skip_if_no_template <- function() {
  skip_if(
    !dir.exists(system.file("templates/typst/bfh-template", package = "BFHcharts")),
    "Typst template not installed"
  )
}

# ---- .get_or_stage_template_cache -------------------------------------------

test_that(".get_or_stage_template_cache returns valid bfh-template path", {
  skip_if_no_template()

  path <- BFHcharts:::.get_or_stage_template_cache()

  expect_true(dir.exists(path))
  expect_equal(basename(path), "bfh-template")
  # Cached dir must live inside tempdir() (same filesystem as per-call dirs)
  expect_true(startsWith(
    normalizePath(path, mustWork = TRUE),
    normalizePath(tempdir(), mustWork = TRUE)
  ))
})

test_that(".get_or_stage_template_cache returns same path on repeated calls", {
  skip_if_no_template()

  path1 <- BFHcharts:::.get_or_stage_template_cache()
  path2 <- BFHcharts:::.get_or_stage_template_cache()

  expect_equal(path1, path2)
})

test_that(".get_or_stage_template_cache contains bfh-template.typ", {
  skip_if_no_template()

  path <- BFHcharts:::.get_or_stage_template_cache()
  typ_file <- file.path(path, "bfh-template.typ")

  expect_true(file.exists(typ_file))
})

# ---- .stage_packaged_template_dir uses cache --------------------------------

test_that(".stage_packaged_template_dir copies from tempdir (cache) not library", {
  skip_if_no_template()

  out_dir <- tempfile("bfh_k2test_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  BFHcharts:::.stage_packaged_template_dir(out_dir, skip_copy = FALSE)

  staged <- file.path(out_dir, "bfh-template")
  expect_true(dir.exists(staged))
  expect_true(file.exists(file.path(staged, "bfh-template.typ")))
})

test_that(".stage_packaged_template_dir removes pre-existing dir before copy", {
  skip_if_no_template()

  out_dir <- tempfile("bfh_k2test_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  # Create stale dir with sentinel file
  stale <- file.path(out_dir, "bfh-template")
  dir.create(stale)
  writeLines("stale", file.path(stale, "stale.txt"))

  BFHcharts:::.stage_packaged_template_dir(out_dir, skip_copy = FALSE)

  # Sentinel must be gone (fresh copy)
  expect_false(file.exists(file.path(stale, "stale.txt")))
  expect_true(file.exists(file.path(stale, "bfh-template.typ")))
})

test_that(".stage_packaged_template_dir skip_copy=TRUE asserts dir exists", {
  out_dir <- tempfile("bfh_k2test_")
  dir.create(out_dir)
  on.exit(unlink(out_dir, recursive = TRUE))

  expect_error(
    BFHcharts:::.stage_packaged_template_dir(out_dir, skip_copy = TRUE),
    "Template directory not found in session tmpdir"
  )
})
