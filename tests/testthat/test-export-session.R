# ============================================================================
# TESTS FOR BATCH EXPORT SESSION
# ============================================================================

# ---- bfh_create_export_session: basic construction -------------------------

test_that("bfh_create_export_session returns bfh_export_session object", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  session <- bfh_create_export_session()
  on.exit(close(session))

  expect_s3_class(session, "bfh_export_session")
  expect_true(dir.exists(session$tmpdir))
  expect_true(session$template_ready)
  expect_false(session$closed())
})

test_that("bfh_create_export_session stages template in tmpdir", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  session <- bfh_create_export_session()
  on.exit(close(session))

  template_dir <- file.path(session$tmpdir, "bfh-template")
  expect_true(dir.exists(template_dir))
  expect_true(file.exists(file.path(template_dir, "bfh-template.typ")))
})

test_that("close() removes tmpdir and marks session closed", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  session <- bfh_create_export_session()
  tmpdir <- session$tmpdir
  expect_true(dir.exists(tmpdir))
  expect_false(session$closed())

  close(session)

  expect_false(dir.exists(tmpdir))
  expect_true(session$closed())
})

test_that("close() is idempotent", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  session <- bfh_create_export_session()
  close(session)
  expect_silent(close(session))
  expect_true(session$closed())
})

test_that("print.bfh_export_session shows open/closed status", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  session <- bfh_create_export_session()
  on.exit(close(session))

  out <- capture.output(print(session))
  expect_true(any(grepl("open", out)))

  close(session)
  out2 <- capture.output(print(session))
  expect_true(any(grepl("closed", out2)))
})

# ---- inject_assets and font_path -------------------------------------------

test_that("inject_assets callback is called with template dir", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  called_with <- NULL
  session <- bfh_create_export_session(inject_assets = function(path) {
    called_with <<- path
  })
  on.exit(close(session))

  expect_equal(called_with, file.path(session$tmpdir, "bfh-template"))
})

test_that("inject_assets auto-sets font_path from injected fonts/", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  session <- bfh_create_export_session(inject_assets = function(path) {
    dir.create(file.path(path, "fonts"), showWarnings = FALSE)
  })
  on.exit(close(session))

  expect_equal(session$font_path, file.path(session$tmpdir, "bfh-template", "fonts"))
})

test_that("explicit font_path takes precedence over inject_assets auto-detect", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  explicit_path <- tempdir()
  session <- bfh_create_export_session(
    font_path = explicit_path,
    inject_assets = function(path) {
      dir.create(file.path(path, "fonts"), showWarnings = FALSE)
    }
  )
  on.exit(close(session))

  expect_equal(session$font_path, explicit_path)
})

# ---- bfh_create_export_session: validation ---------------------------------

test_that("bfh_create_export_session rejects non-function inject_assets", {
  expect_error(
    bfh_create_export_session(inject_assets = "not a function"),
    "inject_assets must be a function"
  )
})

test_that("bfh_create_export_session rejects invalid font_path", {
  expect_error(
    bfh_create_export_session(font_path = 42),
    "font_path must be a single character string"
  )
  expect_error(
    bfh_create_export_session(font_path = c("a", "b")),
    "font_path must be a single character string"
  )
})

# ---- bfh_export_pdf: batch_session validation ------------------------------

test_that("bfh_export_pdf rejects non-session batch_session", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )
  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )
  expect_error(
    bfh_export_pdf(result, tempfile(fileext = ".pdf"), batch_session = "not a session"),
    "bfh_export_session"
  )
})

test_that("bfh_export_pdf rejects closed session", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )
  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )
  session <- bfh_create_export_session()
  close(session)

  expect_error(
    bfh_export_pdf(result, tempfile(fileext = ".pdf"), batch_session = session),
    "already closed"
  )
})

test_that("bfh_export_pdf rejects batch_session + template_path", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )
  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )
  session <- bfh_create_export_session()
  on.exit(close(session))

  fake_template <- tempfile(fileext = ".typ")
  writeLines("#let x = 1", fake_template)
  on.exit(unlink(fake_template), add = TRUE)

  expect_error(
    bfh_export_pdf(result, tempfile(fileext = ".pdf"),
      batch_session = session, template_path = fake_template
    ),
    "template_path"
  )
})

test_that("bfh_export_pdf rejects batch_session + inject_assets", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )
  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )
  session <- bfh_create_export_session()
  on.exit(close(session))

  expect_error(
    bfh_export_pdf(result, tempfile(fileext = ".pdf"),
      batch_session = session, inject_assets = function(p) NULL
    ),
    "inject_assets"
  )
})

# ---- render tests (require Quarto) -----------------------------------------

test_that("bfh_export_pdf single-call works (backward compat)", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_if_not(
    Sys.getenv("BFHCHARTS_TEST_RENDER") == "true",
    "Set BFHCHARTS_TEST_RENDER=true to run render tests"
  )

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 15)
  )
  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )
  out <- tempfile(fileext = ".pdf")
  on.exit(unlink(out))

  expect_silent(bfh_export_pdf(result, out))
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0)
})

test_that("batch session reuses tmpdir across multiple exports", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_if_not(
    Sys.getenv("BFHCHARTS_TEST_RENDER") == "true",
    "Set BFHCHARTS_TEST_RENDER=true to run render tests"
  )
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 15)
  )

  session <- bfh_create_export_session()
  on.exit(close(session))
  session_tmpdir <- session$tmpdir

  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Test")
  )

  out1 <- tempfile(fileext = ".pdf")
  out2 <- tempfile(fileext = ".pdf")
  on.exit(unlink(c(out1, out2)), add = TRUE)

  bfh_export_pdf(result, out1, batch_session = session)
  bfh_export_pdf(result, out2, batch_session = session)

  # Session tmpdir is shared and still alive after both exports
  expect_true(dir.exists(session_tmpdir))
  expect_true(file.exists(out1))
  expect_true(file.exists(out2))
  # Template directory still present (not cleaned up per-export)
  expect_true(dir.exists(file.path(session_tmpdir, "bfh-template")))
})

test_that("batch export produces same page count as single-call export", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_if_not(
    Sys.getenv("BFHCHARTS_TEST_RENDER") == "true",
    "Set BFHCHARTS_TEST_RENDER=true to run render tests"
  )
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")
  skip_if_not(
    requireNamespace("pdftools", quietly = TRUE),
    "pdftools not available for page count check"
  )

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 15)
  )
  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Page count test")
  )

  out_single <- tempfile(fileext = ".pdf")
  out_batch <- tempfile(fileext = ".pdf")
  on.exit(unlink(c(out_single, out_batch)))

  bfh_export_pdf(result, out_single)

  session <- bfh_create_export_session()
  on.exit(close(session), add = TRUE)
  bfh_export_pdf(result, out_batch, batch_session = session)

  pages_single <- pdftools::pdf_length(out_single)
  pages_batch <- pdftools::pdf_length(out_batch)
  expect_equal(pages_single, pages_batch)
})

# ============================================================================
# HARDENING TESTS - race-safety (Issue #213)
# ============================================================================

test_that("bfh_create_export_session returns environment (not list)", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  session <- bfh_create_export_session()
  on.exit(close(session))

  # Environment, ikke list — nødvendigt for reg.finalizer()
  expect_true(is.environment(session))
  expect_s3_class(session, "bfh_export_session")
})

test_that("bfh_create_export_session accesses fields via $ som forventet", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  session <- bfh_create_export_session()
  on.exit(close(session))

  # Alle felter tilgængelige via $ (som med liste)
  expect_true(is.character(session$tmpdir))
  expect_true(session$template_ready)
  expect_false(session$closed())
})

test_that("prepare_temp_workspace returnerer unikke SVG-filnavne per eksport", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  session <- bfh_create_export_session()
  on.exit(close(session))

  # To på hinanden følgende workspace-kald skal give UNIKKE filnavne
  ws1 <- BFHcharts:::prepare_temp_workspace(session)
  ws2 <- BFHcharts:::prepare_temp_workspace(session)

  expect_false(ws1$chart_svg == ws2$chart_svg)
  expect_false(ws1$typst_file == ws2$typst_file)

  # Begge SVG-filnavne skal matche tempfile-mønsteret
  expect_match(basename(ws1$chart_svg), "^chart-")
  expect_match(basename(ws2$chart_svg), "^chart-")

  # Begge .typ-filnavne skal matche tempfile-mønsteret
  expect_match(basename(ws1$typst_file), "^document-")
  expect_match(basename(ws2$typst_file), "^document-")
})

test_that("prepare_temp_workspace i single-call mode giver unikke navne", {
  # Kald uden batch_session: ny temp-mappe per kald og unikke filnavne
  ws1 <- BFHcharts:::prepare_temp_workspace(NULL)
  ws2 <- BFHcharts:::prepare_temp_workspace(NULL)

  on.exit({
    unlink(ws1$temp_dir, recursive = TRUE)
    unlink(ws2$temp_dir, recursive = TRUE)
  })

  # Temp-mapper er unikke
  expect_false(ws1$temp_dir == ws2$temp_dir)

  # Filnavne er unikke
  expect_false(ws1$chart_svg == ws2$chart_svg)
  expect_false(ws1$typst_file == ws2$typst_file)
})

test_that("on.exit cleanup rydder per-eksport filer op ved fejl (crash recovery)", {
  skip_if(!dir.exists(
    system.file("templates/typst/bfh-template", package = "BFHcharts")
  ), "template not installed")

  session <- bfh_create_export_session()
  on.exit(close(session))

  # Simuler et mislykkedes export ved at sende et ugyldigt plot-objekt
  # bfh_export_pdf() bør fejle og on.exit bør køre cleanup
  bad_result <- list(
    plot = NULL,
    config = list(chart_title = "Test"),
    summary = NULL
  )
  class(bad_result) <- "bfh_qic_result"

  # Tæl filer i session-tmpdir inden forsøget
  files_before <- length(list.files(session$tmpdir, recursive = TRUE))

  tryCatch(
    bfh_export_pdf(bad_result, tempfile(fileext = ".pdf"), batch_session = session),
    error = function(e) NULL
  )

  # Per-eksport SVG/typ filer skal være ryddet op (ikke ophobet i tmpdir)
  files_after <- length(list.files(session$tmpdir, recursive = TRUE))
  expect_lte(files_after, files_before)

  # Template-mappen skal stadig eksistere (ikke slettet som per-eksport fil)
  expect_true(dir.exists(file.path(session$tmpdir, "bfh-template")))
})
