# ============================================================================
# TESTS: harden-export-pipeline-security
# ============================================================================
#
# Dækker de fire sikkerhedsfix fra openspec/changes/harden-export-pipeline-security:
#   1. Quarto binary discovery validation (find_quarto, .validate_binary_path)
#   2. Compile-error truncation parity (.truncate_compile_output)
#   3. Control-char escaping i escape_typst_string()
#   4. Ingen shQuote på argv-vector (smoke test med mellemrum i sti)
#
# Alle tests er unit-level og kræver ikke live Quarto.

# Hjælper: nulstil quarto-cache før hvert test der manipulerer options/env
reset_quarto_cache <- function() {
  bfh_reset_caches()
}

# ============================================================================
# 1. Quarto binary discovery validation
# ============================================================================

test_that(".validate_binary_path afviser sti med shell-metachar (semikolon)", {
  reset_quarto_cache()
  result <- withCallingHandlers(
    BFHcharts:::.validate_binary_path("/tmp/poisoned;rm -rf /", source = "test"),
    warning = function(w) {
      expect_match(conditionMessage(w), "disallowed")
      invokeRestart("muffleWarning")
    }
  )
  expect_null(result)
})

test_that(".validate_binary_path afviser sti med pipe-metachar", {
  reset_quarto_cache()
  warned <- FALSE
  result <- withCallingHandlers(
    BFHcharts:::.validate_binary_path("/tmp/x|evil", source = "test"),
    warning = function(w) {
      warned <<- TRUE
      invokeRestart("muffleWarning")
    }
  )
  expect_null(result)
  expect_true(warned)
})

test_that(".validate_binary_path afviser ikke-eksisterende sti", {
  reset_quarto_cache()
  warned <- FALSE
  result <- withCallingHandlers(
    BFHcharts:::.validate_binary_path("/nonexistent/quarto", source = "test"),
    warning = function(w) {
      warned <<- TRUE
      expect_match(conditionMessage(w), "does not exist")
      invokeRestart("muffleWarning")
    }
  )
  expect_null(result)
  expect_true(warned)
})

test_that("find_quarto afviser forgiftet options(bfhcharts.quarto_path) og falder tilbage", {
  skip_on_cran()
  reset_quarto_cache()

  withr::with_options(
    list(bfhcharts.quarto_path = "/tmp/poisoned;rm -rf /"),
    {
      # Skal udstede warning om disallowed chars og IKKE cache den ugyldige sti
      expect_warning(
        result <- BFHcharts:::find_quarto(),
        regexp = "disallowed"
      )
      # Cache maa ikke indeholde den forgiftede sti
      if (exists("quarto_path", envir = BFHcharts:::.quarto_cache)) {
        cached <- get("quarto_path", envir = BFHcharts:::.quarto_cache)
        expect_false(grepl(";", cached, fixed = TRUE))
      }
    }
  )
  reset_quarto_cache()
})

test_that("find_quarto afviser ikke-eksisterende options-sti og falder tilbage", {
  skip_on_cran()
  reset_quarto_cache()

  withr::with_options(
    list(bfhcharts.quarto_path = "/this/path/definitely/does/not/exist/quarto"),
    {
      expect_warning(
        BFHcharts:::find_quarto(),
        regexp = "does not exist"
      )
      # Cache maa ikke indeholde den ugyldige sti
      if (exists("quarto_path", envir = BFHcharts:::.quarto_cache)) {
        cached <- get("quarto_path", envir = BFHcharts:::.quarto_cache)
        expect_false(grepl("definitely/does/not/exist", cached, fixed = TRUE))
      }
    }
  )
  reset_quarto_cache()
})

test_that(".validate_binary_path tillader stier med parens (Windows Program Files)", {
  reset_quarto_cache()

  # Opret undermappe med parens i stien (simulerer C:/Program Files (x86)/Quarto)
  tmp_dir <- withr::local_tempdir("quarto_binary_test")
  parens_dir <- file.path(tmp_dir, "Program Files (x86)")
  dir.create(parens_dir)
  fake_quarto <- file.path(parens_dir, "quarto.exe")
  writeLines("#!/bin/sh\necho quarto", fake_quarto)
  if (.Platform$OS.type != "windows") {
    Sys.chmod(fake_quarto, mode = "755")
  }

  # Verificer at stien faktisk indeholder parens
  expect_true(grepl("(", fake_quarto, fixed = TRUE))

  result <- suppressWarnings(
    BFHcharts:::.validate_binary_path(fake_quarto, source = "test")
  )
  # Parens er IKKE i SHELL_METACHARS_BINARY -> accepteret
  expect_false(is.null(result))
  expect_equal(result, fake_quarto)
})

test_that(".validate_binary_path afviser stadig semikolon selv med binary-mode check", {
  reset_quarto_cache()
  warned <- FALSE
  result <- withCallingHandlers(
    BFHcharts:::.validate_binary_path("/tmp/quarto;evil", source = "test"),
    warning = function(w) {
      warned <<- TRUE
      expect_match(conditionMessage(w), "disallowed")
      invokeRestart("muffleWarning")
    }
  )
  expect_null(result)
  expect_true(warned)
})

# ============================================================================
# 2. Compile-error truncation parity
# ============================================================================

test_that(".truncate_compile_output afkorter output til 500 tegn", {
  long_output <- paste(rep("x", 1000), collapse = "")
  result <- BFHcharts:::.truncate_compile_output(long_output)
  expect_equal(nchar(result), 500L)
})

test_that(".truncate_compile_output bevarer kort output intakt", {
  short <- "kort fejlbesked"
  result <- BFHcharts:::.truncate_compile_output(short)
  expect_equal(result, short)
})

test_that(".truncate_compile_output sammenhaenger vector med newline foer afkorte", {
  vec <- c("linje1", "linje2", "linje3")
  result <- BFHcharts:::.truncate_compile_output(vec)
  expect_true(grepl("\n", result, fixed = TRUE))
})

test_that("bfh_compile_typst truncerer output i PDF-not-created-branch til <= 500 tegn", {
  # Mock system2 der returnerer exit 0 men en lang output-streng
  long_output_vec <- rep(paste(rep("z", 100), collapse = ""), 20)
  attr(long_output_vec, "status") <- 0L

  mock_system2 <- function(...) long_output_vec

  typst_file <- withr::local_tempfile(fileext = ".typ")
  writeLines("#text[test]", typst_file)
  output_pdf <- tempfile(fileext = ".pdf")
  # output_pdf eksisterer ikke -> PDF-not-created branch

  err <- tryCatch(
    BFHcharts:::bfh_compile_typst(
      typst_file, output_pdf,
      .system2 = mock_system2,
      .quarto_path = "/fake/quarto"
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  # Error-meddelelsen maa max indeholde 500 tegn fra output (+ prefix-tekst)
  output_portion <- sub("^.*Quarto output: ", "", conditionMessage(err))
  expect_lte(nchar(output_portion), 500L)
})

test_that("bfh_compile_typst truncerer output i non-zero-exit-branch til <= 500 tegn", {
  long_output_vec <- rep(paste(rep("y", 100), collapse = ""), 20)
  attr(long_output_vec, "status") <- 1L

  mock_system2 <- function(...) long_output_vec

  typst_file <- withr::local_tempfile(fileext = ".typ")
  writeLines("#text[test]", typst_file)
  output_pdf <- tempfile(fileext = ".pdf")

  err <- tryCatch(
    BFHcharts:::bfh_compile_typst(
      typst_file, output_pdf,
      .system2 = mock_system2,
      .quarto_path = "/fake/quarto"
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  output_portion <- sub("^.*Output: ", "", conditionMessage(err))
  expect_lte(nchar(output_portion), 500L)
})

# ============================================================================
# 3. Control-character escaping i escape_typst_string()
# ============================================================================

test_that("escape_typst_string erstatter newline med mellemrum", {
  result <- BFHcharts:::escape_typst_string("linje1\nlinje2")
  expect_false(grepl("\n", result, fixed = TRUE))
  expect_true(grepl("linje1 linje2", result, fixed = TRUE))
})

test_that("escape_typst_string erstatter carriage return med mellemrum", {
  result <- BFHcharts:::escape_typst_string("linje1\rlinje2")
  expect_false(grepl("\r", result, fixed = TRUE))
})

test_that("escape_typst_string erstatter CRLF med mellemrum (Windows copy-paste)", {
  result <- BFHcharts:::escape_typst_string("Afdeling A\r\nUndergruppe B")
  expect_false(grepl("[\r\n]", result))
  # Begge mellemrum kan flyde sammen, men output er gyldigt Typst
  expect_true(grepl("Afdeling A", result, fixed = TRUE))
  expect_true(grepl("Undergruppe B", result, fixed = TRUE))
})

test_that("escape_typst_string erstatter tab med mellemrum", {
  result <- BFHcharts:::escape_typst_string("ord1\tord2")
  expect_false(grepl("\t", result, fixed = TRUE))
})

test_that("escape_typst_string NUL-beskyttelse: guard-kode eksekverer uden fejl", {
  # R character-strenge kan ikke indeholde NUL-bytes (rawToChar raises error).
  # Vi tester at escape_typst_string ikke fejler paa normale strenge og at
  # gsub("\\x00", ..., perl=TRUE) er syntaktisk korrekt og ufarlig.
  result <- BFHcharts:::escape_typst_string("abcdef")
  expect_equal(result, "abcdef")
  # Dobbelttjek med streng der ligner NUL-output men ikke er det
  result2 <- BFHcharts:::escape_typst_string("abc def")
  expect_true(grepl("abc def", result2, fixed = TRUE))
})

test_that("escape_typst_string bevarer eksisterende escaping af backslash og anforselstegn", {
  result <- BFHcharts:::escape_typst_string('test\\quote"end')
  expect_true(grepl("\\\\", result, fixed = TRUE))
  expect_true(grepl('\\"', result, fixed = TRUE))
})

test_that("escape_typst_string bevarer eksisterende escaping af < og >", {
  result <- BFHcharts:::escape_typst_string("a<b>c")
  expect_true(grepl("\\<", result, fixed = TRUE))
  expect_true(grepl("\\>", result, fixed = TRUE))
})

test_that("escape_typst_string haandterer NULL og tom streng", {
  expect_equal(BFHcharts:::escape_typst_string(NULL), "")
  expect_equal(BFHcharts:::escape_typst_string(character(0)), "")
})

# ============================================================================
# 4. shQuote fjernet — argv-token sti med mellemrum (smoke test)
# ============================================================================

test_that("bfh_compile_typst sender sti MED mellemrum som raet argv-token", {
  skip_on_cran()

  # Opret midlertidig mappe med mellemrum i stien
  base_tmp <- tempdir()
  space_dir <- file.path(base_tmp, "with spaces test dir")
  if (!dir.exists(space_dir)) dir.create(space_dir)
  on.exit(unlink(space_dir, recursive = TRUE), add = TRUE)

  typst_file <- file.path(space_dir, "document.typ")
  output_pdf <- file.path(space_dir, "output.pdf")
  writeLines("#text[test]", typst_file)

  # Verificer at stien faktisk indeholder mellemrum
  expect_true(grepl(" ", typst_file, fixed = TRUE))

  # Mock system2: fang de faktiske args der sendes
  captured_args <- NULL
  mock_system2 <- function(command, args, ...) {
    captured_args <<- args
    # Simul: skriv output-PDF saa PDF-not-created-check ikke trigger
    file.create(output_pdf)
    character(0)
  }

  suppressWarnings(
    BFHcharts:::bfh_compile_typst(
      typst_file, output_pdf,
      .system2 = mock_system2,
      .quarto_path = "/fake/quarto"
    )
  )

  # Args skal vaere en character vector, ikke en shell-streng med shQuote
  expect_true(!is.null(captured_args))
  # Typst-fil-argumentet maa IKKE indeholde literale anforselstegn
  typst_arg <- captured_args[captured_args == typst_file]
  if (length(typst_arg) == 0) {
    # Find via grep
    typst_arg <- grep(space_dir, captured_args, fixed = TRUE, value = TRUE)
  }
  expect_true(length(typst_arg) >= 1)
  expect_false(any(grepl('^".*"$', typst_arg)))
})
