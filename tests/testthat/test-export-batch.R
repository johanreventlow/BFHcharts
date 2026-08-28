# ============================================================================
# TESTS FOR BATCH PDF EXPORT (page-bundle cache)
#
# Spec: batch-pdf-export. Covers staging (bfh_stage_pdf_page), batch
# compile (bfh_export_batch_pdf) incl. manifest + chunking, and pruning
# (bfh_prune_page_cache). Compile-path tests use synthetic bundles plus a
# mocked Typst compiler so they run without Quarto; end-to-end smoke tests
# live in test-export-batch-render.R.
# ============================================================================

# ---- helpers ----------------------------------------------------------------

local_cache_dir <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  dir
}

# Write a synthetic-but-valid page bundle directly (no chart rendering),
# for compile-path tests that do not need a real bfh_qic_result.
write_fake_bundle <- function(cache_dir, id, order = 1,
                              template = "bfh-diagram",
                              format_version = BFHcharts:::BATCH_CACHE_FORMAT_VERSION,
                              created_at = Sys.time(),
                              title = paste("Titel", id),
                              mutate = identity) {
  bundle_dir <- file.path(cache_dir, id)
  dir.create(bundle_dir)
  writeLines("<svg xmlns='http://www.w3.org/2000/svg'></svg>",
    file.path(bundle_dir, "chart.svg")
  )
  bundle <- list(
    format_version = format_version,
    id = id,
    order = order,
    metadata = list(
      hospital = "Testhospital",
      title = title,
      date = Sys.Date()
    ),
    spc_stats = list(
      runs_expected = 7, runs_actual = 5,
      crossings_expected = 4, crossings_actual = 6,
      is_run_chart = FALSE
    ),
    template = template,
    created_at = created_at,
    bfhcharts_version = "0.0.0"
  )
  bundle <- mutate(bundle)
  saveRDS(bundle, file.path(bundle_dir, "page.rds"))
  invisible(bundle_dir)
}

# Run bfh_export_batch_pdf with the Typst compiler mocked out. Captures each
# generated .typ document's content and writes a dummy PDF per compile call.
# Returns list(result, docs, workspaces).
with_mocked_compile <- function(expr_fn) {
  captured <- new.env(parent = emptyenv())
  captured$docs <- list()
  captured$workspaces <- character(0)
  testthat::local_mocked_bindings(
    bfh_compile_typst = function(typst_file, output, ...) {
      captured$docs[[length(captured$docs) + 1L]] <- readLines(typst_file)
      captured$workspaces <- unique(c(captured$workspaces, dirname(typst_file)))
      writeLines("%PDF-fake", output)
      invisible(output)
    },
    quarto_available = function(...) TRUE,
    .package = "BFHcharts"
  )
  result <- expr_fn()
  list(result = result, docs = captured$docs, workspaces = captured$workspaces)
}

# ---- bfh_stage_pdf_page: input validation -----------------------------------

test_that("bfh_stage_pdf_page rejects non-result x with classed error", {
  cache <- local_cache_dir()
  expect_error(
    bfh_stage_pdf_page(list(), cache),
    "bfh_qic_result",
    class = "bfhcharts_export_error"
  )
})

test_that("bfh_stage_pdf_page rejects missing cache_dir with classed error", {
  x <- fixture_test_chart()
  expect_error(
    bfh_stage_pdf_page(x, file.path(tempdir(), "does-not-exist-xyz")),
    "cache_dir",
    class = "bfhcharts_export_error"
  )
})

test_that("bfh_stage_pdf_page rejects traversal and metachar ids", {
  cache <- local_cache_dir()
  x <- fixture_test_chart()
  for (bad_id in c("../evil", "a/b", "a\\b", "a;b", ".hidden", "", "a b")) {
    expect_error(
      bfh_stage_pdf_page(x, cache, id = bad_id),
      class = "bfhcharts_export_error"
    )
  }
  # Nothing may have been written by rejected ids
  expect_length(list.files(cache, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("bfh_stage_pdf_page rejects invalid template/overwrite/strict_baseline/order", {
  cache <- local_cache_dir()
  x <- fixture_test_chart()
  expect_error(
    bfh_stage_pdf_page(x, cache, template = "1bad; import"),
    "template",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_stage_pdf_page(x, cache, overwrite = NA),
    "overwrite",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_stage_pdf_page(x, cache, strict_baseline = "yes"),
    "strict_baseline",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_stage_pdf_page(x, cache, order = "first"),
    "order",
    class = "bfhcharts_export_error"
  )
})

test_that("staging resolves centerline caveat text into the bundle", {
  cache <- local_cache_dir()
  data <- fixture_minimal_chart_data()
  # Custom cl intentionally triggers the interpret-with-caution warning;
  # the staged caveat text is the subject under test, not the warning.
  x <- suppressWarnings(bfh_qic(data,
    x = month, y = infections, chart_type = "run",
    cl = 15, chart_title = "Manuel CL"
  ))
  bfh_stage_pdf_page(x, cache, id = "cl-caveat")
  bundle <- readRDS(file.path(cache, "cl-caveat", "page.rds"))
  expect_true(isTRUE(bundle$spc_stats$cl_user_supplied))
  expect_true(is.character(bundle$metadata$cl_caveat_text))
  expect_true(nzchar(bundle$metadata$cl_caveat_text))
})

test_that("print method on bfh_staged_page shows id, order and path", {
  cache <- local_cache_dir()
  x <- fixture_test_chart()
  staged <- bfh_stage_pdf_page(x, cache, id = "vis", order = 7)
  out <- capture.output(print(staged))
  expect_match(out[1], "vis")
  expect_match(out[1], "7")
})

test_that("bfh_stage_pdf_page rejects non-list metadata and bad dpi", {
  cache <- local_cache_dir()
  x <- fixture_test_chart()
  expect_error(
    bfh_stage_pdf_page(x, cache, metadata = "not-a-list"),
    "metadata",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_stage_pdf_page(x, cache, dpi = -1),
    "dpi",
    class = "bfhcharts_export_error"
  )
})

# ---- bfh_stage_pdf_page: staging behavior -----------------------------------

test_that("staging writes a bundle with chart.svg and round-trippable page.rds", {
  cache <- local_cache_dir()
  x <- fixture_test_chart(title = "Infektioner")

  staged <- bfh_stage_pdf_page(x, cache,
    id = "afd-a",
    metadata = list(department = "Afdeling A")
  )

  expect_s3_class(staged, "bfh_staged_page")
  expect_identical(staged$id, "afd-a")
  bundle_dir <- file.path(cache, "afd-a")
  expect_true(dir.exists(bundle_dir))
  expect_true(file.exists(file.path(bundle_dir, "chart.svg")))
  expect_true(file.exists(file.path(bundle_dir, "page.rds")))

  bundle <- readRDS(file.path(bundle_dir, "page.rds"))
  expect_identical(bundle$format_version, BFHcharts:::BATCH_CACHE_FORMAT_VERSION)
  expect_identical(bundle$id, "afd-a")
  expect_identical(bundle$template, "bfh-diagram")
  expect_identical(bundle$metadata$department, "Afdeling A")
  expect_identical(bundle$metadata$title, "Infektioner")
  expect_true(is.list(bundle$spc_stats))
  expect_true(inherits(bundle$created_at, "POSIXct"))

  # No PDF and no leftover staging dirs
  expect_length(list.files(cache, pattern = "\\.pdf$", recursive = TRUE), 0L)
  expect_length(list.files(cache, pattern = "^\\.staging-", all.files = TRUE), 0L)
})

test_that("staging returns invisibly", {
  cache <- local_cache_dir()
  x <- fixture_test_chart()
  expect_invisible(bfh_stage_pdf_page(x, cache, id = "inv"))
})

test_that("default id and order follow the staging sequence", {
  cache <- local_cache_dir()
  x <- fixture_test_chart()

  s1 <- bfh_stage_pdf_page(x, cache)
  s2 <- bfh_stage_pdf_page(x, cache)

  expect_identical(s1$id, "page-0001")
  expect_identical(s2$id, "page-0002")
  expect_identical(s1$order, 1)
  expect_identical(s2$order, 2)
})

test_that("overwrite = FALSE errors on duplicate id; TRUE replaces cleanly", {
  cache <- local_cache_dir()
  x <- fixture_test_chart(title = "Foer")

  bfh_stage_pdf_page(x, cache, id = "dup")
  expect_error(
    bfh_stage_pdf_page(x, cache, id = "dup", overwrite = FALSE),
    "already exists",
    class = "bfhcharts_export_error"
  )

  x2 <- fixture_test_chart(title = "Efter")
  bfh_stage_pdf_page(x2, cache, id = "dup")
  bundle <- readRDS(file.path(cache, "dup", "page.rds"))
  expect_identical(bundle$metadata$title, "Efter")
  # No backup/staging residue after overwrite
  expect_length(
    list.files(cache, pattern = "^\\.(staging|replaced)-", all.files = TRUE), 0L
  )
})

test_that("interrupted staging leaves no visible bundle", {
  cache <- local_cache_dir()
  x <- fixture_test_chart()

  testthat::local_mocked_bindings(
    export_chart_svg = function(...) stop("simulated render failure"),
    .package = "BFHcharts"
  )
  expect_error(bfh_stage_pdf_page(x, cache, id = "boom"))
  expect_false(dir.exists(file.path(cache, "boom")))
  expect_length(list.files(cache, pattern = "^\\.staging-", all.files = TRUE), 0L)
})

# ---- bfh_export_batch_pdf: discovery + validation ---------------------------

test_that("empty cache directory aborts with classed error and writes no PDF", {
  cache <- local_cache_dir()
  out <- file.path(withr::local_tempdir(), "out.pdf")
  expect_error(
    bfh_export_batch_pdf(cache, out),
    "No staged page bundles",
    class = "bfhcharts_export_error"
  )
  expect_false(file.exists(out))
})

test_that("corrupt bundle aborts naming the bundle before any PDF is written", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "good", order = 1)
  dir.create(file.path(cache, "broken"))
  writeLines("not rds", file.path(cache, "broken", "page.rds"))
  writeLines("<svg/>", file.path(cache, "broken", "chart.svg"))
  out <- file.path(withr::local_tempdir(), "out.pdf")

  expect_error(
    bfh_export_batch_pdf(cache, out),
    "broken",
    class = "bfhcharts_export_error"
  )
  expect_false(file.exists(out))
})

test_that("bundle missing chart.svg is invalid", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "nosvg")
  unlink(file.path(cache, "nosvg", "chart.svg"))
  out <- file.path(withr::local_tempdir(), "out.pdf")
  expect_error(
    bfh_export_batch_pdf(cache, out),
    "missing chart.svg",
    class = "bfhcharts_export_error"
  )
})

test_that("unsupported format version errors name version and remedy", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "old", format_version = 999L)
  out <- file.path(withr::local_tempdir(), "out.pdf")
  err <- expect_error(
    bfh_export_batch_pdf(cache, out),
    class = "bfhcharts_export_error"
  )
  expect_match(conditionMessage(err), "999")
  expect_match(conditionMessage(err), "re-stage")
  expect_match(conditionMessage(err), "old")
})

test_that("skip_invalid = TRUE warns listing skipped ids and compiles the rest", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "ok1", order = 1)
  write_fake_bundle(cache, "bad1", format_version = 999L)
  out <- file.path(withr::local_tempdir(), "out.pdf")

  res <- with_mocked_compile(function() {
    expect_warning(
      bfh_export_batch_pdf(cache, out, skip_invalid = TRUE),
      "bad1"
    )
  })
  expect_true(file.exists(out))
  doc <- res$docs[[1]]
  expect_true(any(grepl("charts/ok1.svg", doc, fixed = TRUE)))
  expect_false(any(grepl("bad1", doc, fixed = TRUE)))
})

test_that("non-numeric spc stats in a bundle are rejected", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "inj", mutate = function(b) {
    b$spc_stats$runs_actual <- "7); #import \"evil.typ\""
    b
  })
  out <- file.path(withr::local_tempdir(), "out.pdf")
  expect_error(
    bfh_export_batch_pdf(cache, out),
    "runs_actual",
    class = "bfhcharts_export_error"
  )
})

test_that("non-scalar metadata strings in a bundle are rejected", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "meta", mutate = function(b) {
    b$metadata$department <- list(a = 1)
    b
  })
  out <- file.path(withr::local_tempdir(), "out.pdf")
  expect_error(
    bfh_export_batch_pdf(cache, out),
    "department",
    class = "bfhcharts_export_error"
  )
})

test_that("mixed templates across bundles are rejected", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a", template = "bfh-diagram")
  write_fake_bundle(cache, "b", template = "other-template")
  out <- file.path(withr::local_tempdir(), "out.pdf")
  expect_error(
    bfh_export_batch_pdf(cache, out),
    "different templates",
    class = "bfhcharts_export_error"
  )
})

test_that("custom template_path under restrict_template = TRUE is rejected", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  out <- file.path(withr::local_tempdir(), "out.pdf")
  expect_error(
    bfh_export_batch_pdf(cache, out, template_path = "custom.typ"),
    "restrict_template",
    class = "bfhcharts_export_error"
  )
})

test_that("batch compile validates argument types", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  out <- file.path(withr::local_tempdir(), "out.pdf")
  expect_error(
    bfh_export_batch_pdf(cache, out, ids = 1:3),
    "ids",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_export_batch_pdf(cache, out, restrict_template = NA),
    "restrict_template",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_export_batch_pdf(42, out),
    "cache_dir",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_export_batch_pdf(file.path(tempdir(), "no-such-dir-xyz"), out),
    "cache_dir",
    class = "bfhcharts_export_error"
  )
})

test_that("batch compile without Quarto aborts with install guidance", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  out <- file.path(withr::local_tempdir(), "out.pdf")
  testthat::local_mocked_bindings(
    quarto_available = function(...) FALSE,
    .package = "BFHcharts"
  )
  expect_error(
    bfh_export_batch_pdf(cache, out),
    "Quarto",
    class = "bfhcharts_export_error"
  )
})

# ---- bfh_export_batch_pdf: composition + ordering ---------------------------

test_that("batch document contains one page call per bundle in staged order", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "zzz", order = 1)
  write_fake_bundle(cache, "aaa", order = 2)
  write_fake_bundle(cache, "mmm", order = 3)
  out <- file.path(withr::local_tempdir(), "out.pdf")

  res <- with_mocked_compile(function() {
    bfh_export_batch_pdf(cache, out)
  })

  expect_true(file.exists(out))
  expect_length(res$docs, 1L)
  doc <- res$docs[[1]]

  expect_identical(
    doc[[1]],
    '#import "bfh-template/bfh-template.typ": bfh-diagram'
  )
  chart_lines <- grep("charts/.*\\.svg", doc, value = TRUE)
  expect_length(chart_lines, 3L)
  # Sorted by order key, not alphabetically or by filesystem enumeration
  expect_match(chart_lines[[1]], "charts/zzz.svg", fixed = TRUE)
  expect_match(chart_lines[[2]], "charts/aaa.svg", fixed = TRUE)
  expect_match(chart_lines[[3]], "charts/mmm.svg", fixed = TRUE)
  # Pagebreaks between pages: exactly n - 1
  expect_length(grep("#pagebreak(weak: true)", doc, fixed = TRUE), 2L)
  # Escaping applied to metadata strings via the shared param builder
  expect_true(any(grepl("hospital: \"Testhospital\"", doc, fixed = TRUE)))
})

test_that("order ties break deterministically by id", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "b-page", order = 1)
  write_fake_bundle(cache, "a-page", order = 1)
  out <- file.path(withr::local_tempdir(), "out.pdf")

  res <- with_mocked_compile(function() bfh_export_batch_pdf(cache, out))
  chart_lines <- grep("charts/.*\\.svg", res$docs[[1]], value = TRUE)
  expect_match(chart_lines[[1]], "charts/a-page.svg", fixed = TRUE)
  expect_match(chart_lines[[2]], "charts/b-page.svg", fixed = TRUE)
})

test_that("workspace with generated documents is cleaned up after compile", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  out <- file.path(withr::local_tempdir(), "out.pdf")

  res <- with_mocked_compile(function() bfh_export_batch_pdf(cache, out))
  for (ws in res$workspaces) {
    expect_false(dir.exists(ws))
  }
})

# ---- bfh_export_batch_pdf: manifest (ids) -----------------------------------

test_that("manifest excludes unlisted (retired) bundles silently", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a", order = 1)
  write_fake_bundle(cache, "b", order = 2)
  write_fake_bundle(cache, "retired", order = 3)
  out <- file.path(withr::local_tempdir(), "out.pdf")

  res <- with_mocked_compile(function() {
    expect_no_warning(bfh_export_batch_pdf(cache, out, ids = c("a", "b")))
  })
  doc <- res$docs[[1]]
  expect_true(any(grepl("charts/a.svg", doc, fixed = TRUE)))
  expect_true(any(grepl("charts/b.svg", doc, fixed = TRUE)))
  expect_false(any(grepl("retired", doc, fixed = TRUE)))
  # The retired bundle stays untouched in the cache
  expect_true(dir.exists(file.path(cache, "retired")))
})

test_that("manifest naming missing pages aborts listing every missing id", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  out <- file.path(withr::local_tempdir(), "out.pdf")

  err <- expect_error(
    bfh_export_batch_pdf(cache, out, ids = c("a", "d", "e")),
    class = "bfhcharts_export_error"
  )
  expect_match(conditionMessage(err), "d")
  expect_match(conditionMessage(err), "e")
  expect_match(conditionMessage(err), "bfh_stage_pdf_page")
  expect_false(file.exists(out))
})

test_that("re-staged corrected page appears with updated content", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a", title = "Original A")
  write_fake_bundle(cache, "b", title = "Original B")
  # Correct bundle b under the same id (simulates re-staging)
  unlink(file.path(cache, "b"), recursive = TRUE)
  write_fake_bundle(cache, "b", title = "Rettet B")
  out <- file.path(withr::local_tempdir(), "out.pdf")

  res <- with_mocked_compile(function() {
    bfh_export_batch_pdf(cache, out, ids = c("a", "b"))
  })
  doc <- paste(res$docs[[1]], collapse = "\n")
  expect_match(doc, "Original A", fixed = TRUE)
  expect_match(doc, "Rettet B", fixed = TRUE)
  expect_false(grepl("Original B", doc, fixed = TRUE))
})

test_that("order_by = ids orders pages by manifest position", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a", order = 1)
  write_fake_bundle(cache, "b", order = 2)
  out <- file.path(withr::local_tempdir(), "out.pdf")

  res <- with_mocked_compile(function() {
    bfh_export_batch_pdf(cache, out, ids = c("b", "a"), order_by = "ids")
  })
  chart_lines <- grep("charts/.*\\.svg", res$docs[[1]], value = TRUE)
  expect_match(chart_lines[[1]], "charts/b.svg", fixed = TRUE)
  expect_match(chart_lines[[2]], "charts/a.svg", fixed = TRUE)
})

test_that("order_by = ids without a manifest is rejected", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  out <- file.path(withr::local_tempdir(), "out.pdf")
  expect_error(
    bfh_export_batch_pdf(cache, out, order_by = "ids"),
    "manifest",
    class = "bfhcharts_export_error"
  )
})

test_that("invalid manifest ids are rejected before filesystem access", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  out <- file.path(withr::local_tempdir(), "out.pdf")
  expect_error(
    bfh_export_batch_pdf(cache, out, ids = c("a", "../evil")),
    class = "bfhcharts_export_error"
  )
})

# ---- bfh_export_batch_pdf: chunking -----------------------------------------

test_that("chunked compile splits pages and concatenates in order", {
  skip_if_not_installed("qpdf")
  cache <- local_cache_dir()
  for (i in 1:5) {
    write_fake_bundle(cache, sprintf("p%02d", i), order = i)
  }
  out <- file.path(withr::local_tempdir(), "out.pdf")

  combined <- new.env(parent = emptyenv())
  testthat::local_mocked_bindings(
    pdf_combine = function(input, output, ...) {
      combined$input <- input
      writeLines("%PDF-fake-combined", output)
      output
    },
    .package = "qpdf"
  )

  res <- with_mocked_compile(function() {
    bfh_export_batch_pdf(cache, out, pages_per_chunk = 2)
  })

  # ceil(5 / 2) = 3 chunk documents compiled
  expect_length(res$docs, 3L)
  pages_per_doc <- vapply(
    res$docs, function(d) length(grep("charts/.*\\.svg", d)), integer(1)
  )
  expect_identical(pages_per_doc, c(2L, 2L, 1L))
  # Page order preserved across chunk boundaries
  all_charts <- unlist(lapply(res$docs, function(d) {
    grep("charts/.*\\.svg", d, value = TRUE)
  }))
  expect_match(all_charts[[1]], "p01", fixed = TRUE)
  expect_match(all_charts[[5]], "p05", fixed = TRUE)
  # Concatenation received the chunk PDFs in order and intermediates are gone
  expect_length(combined$input, 3L)
  expect_true(file.exists(out))
  for (chunk_pdf in combined$input) expect_false(file.exists(chunk_pdf))
})

test_that("chunk intermediates are removed when a compile fails midway", {
  skip_if_not_installed("qpdf")
  cache <- local_cache_dir()
  for (i in 1:4) write_fake_bundle(cache, sprintf("p%d", i), order = i)
  out <- file.path(withr::local_tempdir(), "out.pdf")

  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  calls$dirs <- character(0)
  testthat::local_mocked_bindings(
    bfh_compile_typst = function(typst_file, output, ...) {
      calls$n <- calls$n + 1L
      calls$dirs <- unique(c(calls$dirs, dirname(typst_file)))
      if (calls$n == 2L) stop("simulated compile failure")
      writeLines("%PDF-fake", output)
      invisible(output)
    },
    quarto_available = function(...) TRUE,
    .package = "BFHcharts"
  )

  expect_error(
    bfh_export_batch_pdf(cache, out, pages_per_chunk = 2),
    "simulated compile failure"
  )
  expect_false(file.exists(out))
  for (ws in calls$dirs) expect_false(dir.exists(ws))
})

test_that("no chunking argument compiles everything in a single document", {
  cache <- local_cache_dir()
  for (i in 1:4) write_fake_bundle(cache, sprintf("p%d", i), order = i)
  out <- file.path(withr::local_tempdir(), "out.pdf")

  res <- with_mocked_compile(function() bfh_export_batch_pdf(cache, out))
  expect_length(res$docs, 1L)
  expect_length(grep("charts/.*\\.svg", res$docs[[1]]), 4L)
})

test_that("invalid pages_per_chunk is rejected", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  out <- file.path(withr::local_tempdir(), "out.pdf")
  expect_error(
    bfh_export_batch_pdf(cache, out, pages_per_chunk = 0),
    "pages_per_chunk",
    class = "bfhcharts_export_error"
  )
})

# ---- bfh_prune_page_cache ---------------------------------------------------

test_that("prune with keep-list removes exactly the unlisted bundles", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  write_fake_bundle(cache, "b")
  write_fake_bundle(cache, "c")

  removed <- bfh_prune_page_cache(cache, keep = c("a", "b"))

  expect_identical(removed, "c")
  expect_true(dir.exists(file.path(cache, "a")))
  expect_true(dir.exists(file.path(cache, "b")))
  expect_false(dir.exists(file.path(cache, "c")))
})

test_that("prune dry_run deletes nothing and lists candidates", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  write_fake_bundle(cache, "b")
  write_fake_bundle(cache, "c")

  candidates <- bfh_prune_page_cache(cache, keep = "a", dry_run = TRUE)

  expect_identical(candidates, c("b", "c"))
  for (id in c("a", "b", "c")) {
    expect_true(dir.exists(file.path(cache, id)))
  }
})

test_that("prune by age removes only bundles staged before the cutoff", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "old",
    created_at = as.POSIXct("2020-01-01 00:00:00", tz = "UTC")
  )
  write_fake_bundle(cache, "fresh", created_at = Sys.time())

  removed <- bfh_prune_page_cache(cache, older_than = Sys.time() - 3600)

  expect_identical(removed, "old")
  expect_true(dir.exists(file.path(cache, "fresh")))
})

test_that("prune by age skips unreadable bundles with a warning", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "old",
    created_at = as.POSIXct("2020-01-01 00:00:00", tz = "UTC")
  )
  dir.create(file.path(cache, "corrupt"))
  writeLines("junk", file.path(cache, "corrupt", "page.rds"))

  expect_warning(
    removed <- bfh_prune_page_cache(cache, older_than = Sys.time()),
    "corrupt"
  )
  expect_identical(removed, "old")
  expect_true(dir.exists(file.path(cache, "corrupt")))
})

test_that("prune never touches foreign files in the cache directory", {
  cache <- local_cache_dir()
  write_fake_bundle(cache, "a")
  writeLines("notes", file.path(cache, "README.txt"))
  dir.create(file.path(cache, "not-a-bundle"))

  removed <- bfh_prune_page_cache(cache, keep = character(0))

  expect_identical(removed, "a")
  expect_true(file.exists(file.path(cache, "README.txt")))
  expect_true(dir.exists(file.path(cache, "not-a-bundle")))
})

test_that("prune requires exactly one selector", {
  cache <- local_cache_dir()
  expect_error(
    bfh_prune_page_cache(cache),
    "exactly one",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_prune_page_cache(cache, keep = "a", older_than = Sys.time()),
    "exactly one",
    class = "bfhcharts_export_error"
  )
})

test_that("prune validates keep-list ids", {
  cache <- local_cache_dir()
  expect_error(
    bfh_prune_page_cache(cache, keep = "../evil"),
    class = "bfhcharts_export_error"
  )
})
