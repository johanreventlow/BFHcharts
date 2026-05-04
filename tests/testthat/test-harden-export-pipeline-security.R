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

test_that("find_quarto afviser forgiftet options(BFHcharts.quarto_path) og falder tilbage", {
  skip_on_cran()
  reset_quarto_cache()

  withr::with_options(
    list(BFHcharts.quarto_path = "/tmp/poisoned;rm -rf /"),
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
    list(BFHcharts.quarto_path = "/this/path/definitely/does/not/exist/quarto"),
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

test_that(".truncate_compile_output redacter tempdir-stier", {
  td <- normalizePath(tempdir(), winslash = "/", mustWork = FALSE)
  output_with_path <- paste0("error at: ", td, "/bfh_pdf_abc/document.typ")
  result <- BFHcharts:::.truncate_compile_output(output_with_path)
  expect_false(grepl(td, result, fixed = TRUE))
  expect_true(grepl("<tmpdir>", result, fixed = TRUE))
})

test_that("bfh_create_typst_document afviser output med path-traversal", {
  tmp <- withr::local_tempfile(fileext = ".png")
  writeLines("", tmp)
  expect_error(
    BFHcharts:::bfh_create_typst_document(
      chart_image = tmp,
      output = "../../../etc/evil.typ",
      metadata = list(),
      spc_stats = list()
    ),
    "path traversal"
  )
})

test_that("bfh_create_typst_document afviser chart_image med path-traversal", {
  expect_error(
    BFHcharts:::bfh_create_typst_document(
      chart_image = "../../../etc/passwd",
      output = withr::local_tempfile(fileext = ".typ"),
      metadata = list(),
      spc_stats = list()
    ),
    "path traversal"
  )
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

test_that("escape_typst_string lader < og > passere uaendret (string-literal kontekst)", {
  # < og > er almindelige tegn i Typst string literals - de kan ikke terminere
  # strengen, og tidligere `\<` / `\>` escapes var invalide Typst-escapes som
  # blev gengivet med literal backslash i PDF (fx "p \< 0.05").
  expect_equal(BFHcharts:::escape_typst_string("a<b>c"), "a<b>c")
})

test_that("escape_typst_string bevarer realistisk klinisk tekst med < og >", {
  # Regression: sikrer at indholdsfelter (hospital, department, details, author,
  # data_definition, chart_title) ikke faar literal backslash i PDF-output.
  expect_equal(
    BFHcharts:::escape_typst_string("p < 0.05 og n > 30"),
    "p < 0.05 og n > 30"
  )
})

test_that("escape_typst_string bevarer kombineret < > og quote-escaping", {
  # Kombineret realistisk input: backslash + quote skal stadig escapes,
  # men < og > skal ikke faa literal backslash.
  expect_equal(
    BFHcharts:::escape_typst_string("p < 0.05 (\"primary\")"),
    "p < 0.05 (\\\"primary\\\")"
  )
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

# ============================================================================
# 5. cleanup-temp-dir-ownership-check — temp dir isolation via tempfile + 0700
# ============================================================================

test_that("prepare_temp_workspace opretter 0700-tilladelsesmappe paa Unix", {
  skip_on_os("windows")
  ws <- BFHcharts:::prepare_temp_workspace(NULL)
  on.exit(unlink(ws$temp_dir, recursive = TRUE), add = TRUE)
  mode_octal <- as.integer(file.info(ws$temp_dir)$mode) %% (8^3)
  expect_equal(mode_octal, as.integer(strtoi("700", 8L)),
    info = "temp dir skal have 0700 tilladelser for at forhindre anden-bruger-adgang"
  )
})

test_that("prepare_temp_workspace returnerer temp_dir under tempdir()", {
  ws <- BFHcharts:::prepare_temp_workspace(NULL)
  on.exit(unlink(ws$temp_dir, recursive = TRUE), add = TRUE)
  expect_true(startsWith(
    normalizePath(ws$temp_dir, mustWork = FALSE),
    normalizePath(tempdir(), mustWork = TRUE)
  ))
})

test_that("prepare_temp_workspace bruger ikke Sys.getenv UID-check", {
  src_path <- system.file("R", "utils_export_helpers.R", package = "BFHcharts")
  if (nchar(src_path) == 0) {
    skip("kildekode ikke installeret")
  }
  src <- readLines(src_path)
  expect_false(any(grepl('Sys\\.getenv\\("UID"\\)', src)))
})

# ============================================================================
# 6. M1: KNOWN_TYPST_FLAGS allowlist in .safe_system2_capture
# ============================================================================

test_that(".safe_system2_capture quotes --rce flag (not in allowlist)", {
  skip_on_os("windows")

  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[rce test]", typst_file)
  withr::defer(unlink(typst_file))
  out_pdf <- tempfile(fileext = ".pdf")
  withr::defer(unlink(out_pdf))

  captured_args <- NULL
  mock_s2 <- function(command, args, ...) {
    captured_args <<- args
    file.create(out_pdf)
    character(0)
  }

  # Inject a rogue flag-like arg by temporarily appending to compile_args via
  # a custom .system2 that intercepts before quoting.
  # Verify via the KNOWN_TYPST_FLAGS constant: --rce is not in it.
  expect_false("--rce" %in% BFHcharts:::KNOWN_TYPST_FLAGS)

  # Direct unit test of .safe_system2_capture: --rce must be quoted.
  BFHcharts:::.safe_system2_capture(
    "/fake/cmd", c("--rce", typst_file),
    stdout = FALSE, stderr = FALSE,
    .system2 = function(command, args, ...) {
      captured_args <<- args
      character(0)
    }
  )

  # --rce should be wrapped in single quotes (shQuote) since it is not allowlisted
  rce_arg <- captured_args[1]
  expect_true(
    startsWith(rce_arg, "'"),
    info = paste("--rce must be shell-quoted, got:", rce_arg)
  )
})

test_that("KNOWN_TYPST_FLAGS contains exactly the expected flags", {
  flags <- BFHcharts:::KNOWN_TYPST_FLAGS
  # `--root` added in 0.16.1 as defense-in-depth: confines Typst's
  # image()/read()/include access to the staged template tempdir.
  expect_setequal(flags, c("--ignore-system-fonts", "--font-path", "--root"))
})

# ============================================================================
# 7. H2: restrict_template parameter on bfh_export_pdf()
# ============================================================================

test_that("bfh_export_pdf with restrict_template=TRUE rejects custom template_path", {
  # We need a valid bfh_qic_result to get past the first input validation.
  # Create a minimal one using the public API.
  skip_on_cran()

  data <- data.frame(
    x = seq.Date(as.Date("2022-01-01"), by = "month", length.out = 20),
    y = rpois(20, 10)
  )
  result <- bfh_qic(data,
    x = x, y = y, chart_type = "i",
    chart_title = "Test"
  )

  expect_error(
    bfh_export_pdf(
      result,
      output = tempfile(fileext = ".pdf"),
      template_path = "/some/custom/template.typ",
      restrict_template = TRUE
    ),
    regexp = "restrict_template"
  )
})

# ============================================================================
# 8. M3: bad font_path warns then auto-detects packaged fonts
# ============================================================================

test_that("bad font_path warns then auto-detects packaged fonts in bfh-template/fonts", {
  skip_on_cran()

  # Set up a tempdir that mimics the staged workspace layout:
  #   <tmp>/document.typ          <- typst source file
  #   <tmp>/bfh-template/fonts/   <- directory .detect_packaged_fonts() scans
  #   <tmp>/bfh-template/fonts/BFHFont.ttf  <- sentinel font file
  tmp_dir <- withr::local_tempdir("m3_font_fallback")
  typst_file <- file.path(tmp_dir, "document.typ")
  writeLines("#text[m3 test]", typst_file)

  fonts_dir <- file.path(tmp_dir, "bfh-template", "fonts")
  dir.create(fonts_dir, recursive = TRUE)
  file.create(file.path(fonts_dir, "BFHFont.ttf"))

  output_pdf <- file.path(tmp_dir, "output.pdf")
  captured_args <- NULL

  mock_s2 <- function(command, args, ...) {
    captured_args <<- args
    # Simulate successful compile by creating the output file
    file.create(output_pdf)
    character(0)
  }

  # Call with a non-existent font_path; should warn AND fall back to packaged fonts
  expect_warning(
    BFHcharts:::bfh_compile_typst(
      typst_file, output_pdf,
      font_path = "/nonexistent/fonts/dir",
      .system2 = mock_s2,
      .quarto_path = "/fake/quarto"
    ),
    regexp = "font_path directory does not exist"
  )

  # --font-path should point to the staged packaged fonts dir, not the bad path
  expect_true(!is.null(captured_args), info = "mock_s2 must have been called")
  font_path_idx <- which(captured_args == "--font-path")
  expect_true(
    length(font_path_idx) > 0,
    info = "Compiled args should include --font-path after auto-detect"
  )
  if (length(font_path_idx) > 0) {
    raw_arg <- captured_args[font_path_idx + 1L]
    # .safe_system2_capture wraps non-flag args with shQuote() on Unix.
    # Strip outer single or double quotes before comparing paths.
    actual_font_path <- gsub("^'(.*)'$", "\\1", raw_arg)
    actual_font_path <- gsub('^"(.*)"$', "\\1", actual_font_path)
    expect_equal(
      normalizePath(actual_font_path, mustWork = FALSE),
      normalizePath(fonts_dir, mustWork = FALSE),
      info = paste("Expected packaged fonts dir, got:", raw_arg)
    )
  }
})

test_that("bfh_export_pdf with restrict_template=FALSE allows custom template_path (explicit opt-out)", {
  # restrict_template=TRUE is the default since 0.16.0; restrict_template=FALSE
  # is the power-user opt-out. We test that the restrict_template guard does NOT
  # fire when explicit FALSE is passed.
  # (The actual export may fail due to missing template file -- that is unrelated.)
  skip_on_cran()

  data <- data.frame(
    x = seq.Date(as.Date("2022-01-01"), by = "month", length.out = 20),
    y = rpois(20, 10)
  )
  result <- bfh_qic(data,
    x = x, y = y, chart_type = "i",
    chart_title = "Test"
  )

  err <- tryCatch(
    bfh_export_pdf(
      result,
      output = tempfile(fileext = ".pdf"),
      template_path = "/nonexistent/custom.typ",
      restrict_template = FALSE
    ),
    error = function(e) e
  )

  # Error should NOT mention restrict_template -- it should be about the missing file
  if (inherits(err, "error")) {
    expect_false(
      grepl("restrict_template", conditionMessage(err)),
      info = "Error should be about missing template, not restrict_template guard"
    )
  }
})
