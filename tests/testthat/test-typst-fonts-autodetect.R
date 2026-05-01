# Tests for auto-detect of staged template fonts in bfh_compile_typst().
# Covers: ADR-001 Option A -- companion-injected fonts detected without explicit
# font_path argument.
#
# All tests use .system2 mock injection to avoid spawning live Quarto processes.

test_that("auto-detect: fonts/ dir with .ttf file sets font_path", {
  # Arrange: minimal .typ file + staged fonts/ dir with a .ttf file
  tmp <- withr::local_tempdir()
  bfh_dir <- file.path(tmp, "bfh-template")
  fonts_dir <- file.path(bfh_dir, "fonts")
  dir.create(fonts_dir, recursive = TRUE)
  writeLines("", file.path(fonts_dir, "DejaVuSans.ttf"))

  typst_file <- file.path(tmp, "doc.typ")
  writeLines("#show: doc", typst_file)

  output_pdf <- file.path(tmp, "out.pdf")

  # Capture args passed to mock system2
  captured <- list()
  mock_system2 <- function(cmd, args, stdout, stderr) {
    captured[[length(captured) + 1]] <<- args
    # Simulate successful compile: create output file
    writeLines("", output_pdf)
    structure(character(0), status = 0L)
  }

  bfh_compile_typst(
    typst_file = typst_file,
    output = output_pdf,
    font_path = NULL,
    ignore_system_fonts = FALSE,
    .system2 = mock_system2,
    .quarto_path = "/fake/quarto"
  )

  args <- captured[[1]]
  expect_true(
    any(args == "--font-path"),
    label = "--font-path flag present in compile args"
  )
  fp_idx <- which(args == "--font-path")
  # Strip shQuote wrapping (single-quotes on POSIX, double-quotes on Windows)
  # added by .safe_system2_capture() before path comparison.
  raw_path <- gsub('^["\']|["\']$', "", args[[fp_idx + 1]])
  expect_equal(
    normalizePath(raw_path, mustWork = FALSE),
    normalizePath(fonts_dir, mustWork = FALSE),
    label = "auto-detected font_path matches staged fonts dir"
  )
})

test_that("auto-detect: fonts/ dir with .otf file sets font_path", {
  tmp <- withr::local_tempdir()
  bfh_dir <- file.path(tmp, "bfh-template")
  fonts_dir <- file.path(bfh_dir, "fonts")
  dir.create(fonts_dir, recursive = TRUE)
  writeLines("", file.path(fonts_dir, "Roboto-Regular.otf"))

  typst_file <- file.path(tmp, "doc.typ")
  writeLines("#show: doc", typst_file)
  output_pdf <- file.path(tmp, "out.pdf")

  captured <- list()
  mock_system2 <- function(cmd, args, stdout, stderr) {
    captured[[length(captured) + 1]] <<- args
    writeLines("", output_pdf)
    structure(character(0), status = 0L)
  }

  bfh_compile_typst(
    typst_file = typst_file,
    output = output_pdf,
    font_path = NULL,
    ignore_system_fonts = FALSE,
    .system2 = mock_system2,
    .quarto_path = "/fake/quarto"
  )

  args <- captured[[1]]
  expect_true(any(args == "--font-path"))
})

test_that("auto-detect: empty fonts/ dir does NOT set font_path", {
  tmp <- withr::local_tempdir()
  bfh_dir <- file.path(tmp, "bfh-template")
  fonts_dir <- file.path(bfh_dir, "fonts")
  dir.create(fonts_dir, recursive = TRUE)
  # No font files -- only an unrelated file
  writeLines("", file.path(fonts_dir, "README.txt"))

  typst_file <- file.path(tmp, "doc.typ")
  writeLines("#show: doc", typst_file)
  output_pdf <- file.path(tmp, "out.pdf")

  captured <- list()
  mock_system2 <- function(cmd, args, stdout, stderr) {
    captured[[length(captured) + 1]] <<- args
    writeLines("", output_pdf)
    structure(character(0), status = 0L)
  }

  bfh_compile_typst(
    typst_file = typst_file,
    output = output_pdf,
    font_path = NULL,
    ignore_system_fonts = FALSE,
    .system2 = mock_system2,
    .quarto_path = "/fake/quarto"
  )

  args <- captured[[1]]
  expect_false(
    any(args == "--font-path"),
    label = "--font-path flag absent when fonts/ dir has no font files"
  )
})

test_that("auto-detect: missing fonts/ dir does NOT set font_path", {
  tmp <- withr::local_tempdir()
  # No bfh-template/fonts/ dir at all

  typst_file <- file.path(tmp, "doc.typ")
  writeLines("#show: doc", typst_file)
  output_pdf <- file.path(tmp, "out.pdf")

  captured <- list()
  mock_system2 <- function(cmd, args, stdout, stderr) {
    captured[[length(captured) + 1]] <<- args
    writeLines("", output_pdf)
    structure(character(0), status = 0L)
  }

  bfh_compile_typst(
    typst_file = typst_file,
    output = output_pdf,
    font_path = NULL,
    ignore_system_fonts = FALSE,
    .system2 = mock_system2,
    .quarto_path = "/fake/quarto"
  )

  args <- captured[[1]]
  expect_false(any(args == "--font-path"))
})

test_that("explicit font_path overrides auto-detect", {
  tmp <- withr::local_tempdir()
  bfh_dir <- file.path(tmp, "bfh-template")
  auto_fonts_dir <- file.path(bfh_dir, "fonts")
  dir.create(auto_fonts_dir, recursive = TRUE)
  writeLines("", file.path(auto_fonts_dir, "DejaVuSans.ttf"))

  # Create a separate explicit font path
  explicit_fonts_dir <- file.path(tmp, "my-custom-fonts")
  dir.create(explicit_fonts_dir)
  writeLines("", file.path(explicit_fonts_dir, "CustomFont.ttf"))

  typst_file <- file.path(tmp, "doc.typ")
  writeLines("#show: doc", typst_file)
  output_pdf <- file.path(tmp, "out.pdf")

  captured <- list()
  mock_system2 <- function(cmd, args, stdout, stderr) {
    captured[[length(captured) + 1]] <<- args
    writeLines("", output_pdf)
    structure(character(0), status = 0L)
  }

  bfh_compile_typst(
    typst_file = typst_file,
    output = output_pdf,
    font_path = explicit_fonts_dir,
    ignore_system_fonts = FALSE,
    .system2 = mock_system2,
    .quarto_path = "/fake/quarto"
  )

  args <- captured[[1]]
  fp_idx <- which(args == "--font-path")
  expect_true(length(fp_idx) > 0, label = "--font-path present")
  raw_path <- gsub('^["\']|["\']$', "", args[[fp_idx + 1]])
  expect_equal(
    normalizePath(raw_path, mustWork = FALSE),
    normalizePath(explicit_fonts_dir, mustWork = FALSE),
    label = "explicit font_path used, not auto-detected"
  )
})

test_that("auto-detect: .woff and .woff2 files are recognized", {
  tmp <- withr::local_tempdir()
  bfh_dir <- file.path(tmp, "bfh-template")
  fonts_dir <- file.path(bfh_dir, "fonts")
  dir.create(fonts_dir, recursive = TRUE)
  writeLines("", file.path(fonts_dir, "Roboto.woff2"))

  typst_file <- file.path(tmp, "doc.typ")
  writeLines("#show: doc", typst_file)
  output_pdf <- file.path(tmp, "out.pdf")

  captured <- list()
  mock_system2 <- function(cmd, args, stdout, stderr) {
    captured[[length(captured) + 1]] <<- args
    writeLines("", output_pdf)
    structure(character(0), status = 0L)
  }

  bfh_compile_typst(
    typst_file = typst_file,
    output = output_pdf,
    font_path = NULL,
    ignore_system_fonts = FALSE,
    .system2 = mock_system2,
    .quarto_path = "/fake/quarto"
  )

  args <- captured[[1]]
  expect_true(any(args == "--font-path"))
})
