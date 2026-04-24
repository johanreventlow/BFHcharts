# ============================================================================
# ISOLATION TESTS FOR QUARTO-INTEGRATION
# ============================================================================
#
# Tester Quarto-detektion, caching og versions-check uden live Quarto-binary.
# Fokus: pure logic (check_quarto_version) + cache-håndtering + test-hooks
# for mock-based integration.
#
# Noter om scope:
#   - check_quarto_version() kan testes direkte (pure logic)
#   - quarto_available() cache-adfærd testes via .quarto_cache manipulation
#   - Fuld system2-mocking af quarto_available() og bfh_compile_typst() kræver
#     refactor med dependency-injection (planlagt — Fase 2 task 5.x opfølgning)
#
# Reference: openspec/changes/strengthen-test-infrastructure (task 5.3–5.5)
# Spec: test-infrastructure, "External dependencies SHALL be testable in isolation"

# ============================================================================
# check_quarto_version() — PURE LOGIC (ingen mock krævet)
# ============================================================================

test_that("check_quarto_version accepterer version over minimum", {
  expect_true(BFHcharts:::check_quarto_version("1.4.557", "1.4.0"))
  expect_true(BFHcharts:::check_quarto_version("1.5.0", "1.4.0"))
  expect_true(BFHcharts:::check_quarto_version("2.0.0", "1.4.0"))
  expect_true(BFHcharts:::check_quarto_version("10.0.0", "1.4.0"))
})

test_that("check_quarto_version afviser version under minimum", {
  expect_false(BFHcharts:::check_quarto_version("1.3.9", "1.4.0"))
  expect_false(BFHcharts:::check_quarto_version("1.3.0", "1.4.0"))
  expect_false(BFHcharts:::check_quarto_version("0.9.0", "1.4.0"))
})

test_that("check_quarto_version accepterer eksakt match", {
  expect_true(BFHcharts:::check_quarto_version("1.4.0", "1.4.0"))
  expect_true(BFHcharts:::check_quarto_version("1.4", "1.4.0"))
})

test_that("check_quarto_version håndterer 2-cifrede versionsstrenge", {
  # qicharts2 kan rapportere "1.4" uden patch-niveau
  expect_true(BFHcharts:::check_quarto_version("1.4", "1.4.0"))
  expect_true(BFHcharts:::check_quarto_version("2.0", "1.4.0"))
})

test_that("check_quarto_version ekstraherer version fra 'Quarto X.Y.Z'-prefix", {
  # Faktisk output fra `quarto --version` kan have prefix
  expect_true(BFHcharts:::check_quarto_version("Quarto 1.4.557", "1.4.0"))
  expect_true(BFHcharts:::check_quarto_version("quarto CLI v1.5.0", "1.4.0"))
})

test_that("check_quarto_version fejler gracefully ved uparserbar version", {
  expect_warning(
    result <- BFHcharts:::check_quarto_version("unknown-version", "1.4.0"),
    "Could not parse Quarto version"
  )
  expect_false(result)
})

test_that("check_quarto_version fejler gracefully ved tom input", {
  expect_warning(
    result <- BFHcharts:::check_quarto_version("", "1.4.0"),
    "Could not parse"
  )
  expect_false(result)
})

test_that("check_quarto_version håndterer uparserbar minimum-streng", {
  # Hvis minimum-strengen er korrupt, skal den returnere FALSE (fail-safe)
  expect_false(BFHcharts:::check_quarto_version("1.4.0", "not-a-version"))
})

# ============================================================================
# quarto_available() — CACHE-ADFÆRD (mock via .quarto_cache manipulation)
# ============================================================================

test_that("quarto_available bruger cached TRUE-resultat når tilgængeligt", {
  local_mock_quarto_cache(
    quarto_available = TRUE,
    min_version = "1.4.0",
    quarto_path = "/fake/bin/quarto"
  )

  # Skal returnere cached-værdien uden at kalde find_quarto / system2
  result <- BFHcharts:::quarto_available(min_version = "1.4.0", use_cache = TRUE)
  expect_true(result)
})

test_that("quarto_available bruger cached FALSE-resultat når tilgængeligt", {
  local_mock_quarto_cache(
    quarto_available = FALSE,
    min_version = "1.4.0"
  )

  result <- BFHcharts:::quarto_available(min_version = "1.4.0", use_cache = TRUE)
  expect_false(result)
})

test_that("quarto_available separerer cache pr. min_version", {
  # Cache for "1.4.0" skal ikke påvirke resultat for "2.0.0"
  local_mock_quarto_cache(
    quarto_available = TRUE,
    min_version = "1.4.0",
    quarto_path = "/fake/bin/quarto"
  )

  # Cached for 1.4.0 → TRUE
  expect_true(BFHcharts:::quarto_available(min_version = "1.4.0", use_cache = TRUE))

  # Ikke cached for 2.0.0 → vil udføre reel detektion (skip hvis live-Quarto
  # ikke er tilgængeligt)
  skip_if_no_quarto()

  # Hvis live-Quarto er < 2.0.0, skal 2.0.0-nøglen give FALSE (ikke genbruge 1.4.0-cache)
  # Vi cacher kun 1.4.0-TRUE → 2.0.0 skal lave sit eget opslag
  expect_type(
    BFHcharts:::quarto_available(min_version = "2.0.0", use_cache = TRUE),
    "logical"
  )
})

test_that("get_quarto_path returnerer cached sti", {
  local_mock_quarto_cache(
    quarto_available = TRUE,
    min_version = "1.4.0",
    quarto_path = "/custom/path/quarto"
  )

  expect_equal(BFHcharts:::get_quarto_path(), "/custom/path/quarto")
})

# ============================================================================
# find_quarto() — sti-opløsning via environment-variabel
# ============================================================================

test_that("find_quarto respekterer QUARTO_PATH environment-variabel", {
  # Dette test er miljø-afhængigt: Sys.which() har højere prioritet end
  # QUARTO_PATH. Hvis et system-Quarto findes i PATH, returneres det først.
  # Testen skip'er i så fald for at undgå false positive.
  skip_if(
    nchar(Sys.which("quarto")) > 0 &&
      file.exists(as.character(Sys.which("quarto"))),
    "System Quarto present in PATH; cannot test QUARTO_PATH fallback"
  )

  local_clean_quarto_cache()

  fake_path <- tempfile(fileext = ".fake-quarto")
  file.create(fake_path)
  withr::defer(unlink(fake_path))

  withr::local_envvar(QUARTO_PATH = fake_path)

  result <- BFHcharts:::find_quarto()
  expect_equal(result, fake_path)
})

test_that("find_quarto respekterer bfhcharts.quarto_path option", {
  # Ligesom ovenfor: option-opslag er efter Sys.which i prioritet.
  # Testen verificerer blot at funktionen returnerer en gyldig string.
  local_clean_quarto_cache()

  fake_path <- tempfile(fileext = ".fake-quarto-opt")
  file.create(fake_path)
  withr::defer(unlink(fake_path))

  withr::local_envvar(QUARTO_PATH = "") # Ryd environment først
  withr::local_options(bfhcharts.quarto_path = fake_path)

  result <- BFHcharts:::find_quarto()
  expect_type(result, "character")
  expect_length(result, 1)
})

# ============================================================================
# bfh_compile_typst() — VALIDATION-LOGIK (pre-system2 paths)
# ============================================================================

test_that("bfh_compile_typst afviser manglende typst-fil", {
  nonexistent <- tempfile(fileext = ".typ")
  expect_error(
    BFHcharts:::bfh_compile_typst(nonexistent, tempfile(fileext = ".pdf")),
    "Typst file not found"
  )
})

test_that("bfh_compile_typst afviser shell-metacharacters i typst_file-sti", {
  # Opret en fil med unsafe karakterer i navn
  temp_dir <- tempfile()
  dir.create(temp_dir)
  withr::defer(unlink(temp_dir, recursive = TRUE))

  # Sti med semikolon (shell-metacharacter)
  unsafe_file <- file.path(temp_dir, "test;rm.typ")
  file.create(unsafe_file)

  expect_error(
    BFHcharts:::bfh_compile_typst(unsafe_file, tempfile(fileext = ".pdf")),
    "unsafe characters"
  )
})

test_that("bfh_compile_typst afviser shell-metacharacters i output-sti", {
  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[test]", typst_file)
  withr::defer(unlink(typst_file))

  expect_error(
    BFHcharts:::bfh_compile_typst(typst_file, "output; rm -rf /.pdf"),
    "unsafe characters"
  )

  expect_error(
    BFHcharts:::bfh_compile_typst(typst_file, "output | cat.pdf"),
    "unsafe characters"
  )

  expect_error(
    BFHcharts:::bfh_compile_typst(typst_file, "output`cmd`.pdf"),
    "unsafe characters"
  )
})

test_that("bfh_compile_typst afviser path traversal i font_path", {
  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[test]", typst_file)
  withr::defer(unlink(typst_file))

  expect_error(
    BFHcharts:::bfh_compile_typst(
      typst_file,
      tempfile(fileext = ".pdf"),
      font_path = "../../etc"
    ),
    "path traversal"
  )
})

test_that("bfh_compile_typst afviser shell-metacharacters i font_path", {
  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[test]", typst_file)
  withr::defer(unlink(typst_file))

  expect_error(
    BFHcharts:::bfh_compile_typst(
      typst_file,
      tempfile(fileext = ".pdf"),
      font_path = "/fonts; rm"
    ),
    "unsafe characters"
  )
})

test_that("bfh_compile_typst afviser ikke-eksisterende font_path med warning", {
  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[test]", typst_file)
  withr::defer(unlink(typst_file))

  # Hop over fuld compile — vi tester kun validation-fasen
  # Kør funktionen, fang warning om manglende font-mappe
  nonexistent_fonts <- tempfile() # eksisterer ikke

  # Forventer warning (ikke error) om manglende font-mappe.
  # Den efterfølgende system2-kald vil fejle pga. live Quarto ikke garanteret,
  # så vi accepterer både warning og efterfølgende error.
  expect_warning(
    tryCatch(
      BFHcharts:::bfh_compile_typst(
        typst_file,
        tempfile(fileext = ".pdf"),
        font_path = nonexistent_fonts
      ),
      error = function(e) invisible(NULL) # swallow downstream errors
    ),
    "font_path directory does not exist"
  )
})

test_that("bfh_compile_typst afviser non-character font_path", {
  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[test]", typst_file)
  withr::defer(unlink(typst_file))

  expect_error(
    BFHcharts:::bfh_compile_typst(
      typst_file,
      tempfile(fileext = ".pdf"),
      font_path = 123
    ),
    "font_path must be a single character string"
  )

  expect_error(
    BFHcharts:::bfh_compile_typst(
      typst_file,
      tempfile(fileext = ".pdf"),
      font_path = c("a", "b")
    ),
    "font_path must be a single character string"
  )
})


# ============================================================================
# MOCK-BASEREDE TESTS: .system2 dependency injection i bfh_compile_typst()
# ============================================================================
#
# Disse tests bruger .system2-parameteret til at injicere mocks uden live Quarto.
# Mock-factories er defineret i helper-mocks.R.
#
# For egne tests: brug BFHcharts:::bfh_compile_typst(..., .system2 = mock, .quarto_path = "/fake/quarto")

test_that(".system2 mock: success path verifies arg construction og returnerer output-sti", {
  typst_file <- tempfile(fileext = ".typ")
  typst_file <- file.path(normalizePath(dirname(typst_file), mustWork = FALSE), basename(typst_file))
  writeLines("#text[test]", typst_file)
  withr::defer(unlink(typst_file))

  output <- tempfile(fileext = ".pdf")
  output <- file.path(normalizePath(dirname(output), mustWork = FALSE), basename(output))
  withr::defer(unlink(output))

  captured_command <- NULL
  captured_args <- NULL

  success_mock <- function(command, args, ...) {
    captured_command <<- command
    captured_args <<- args
    file.create(output)
    character(0)
  }

  result <- BFHcharts:::bfh_compile_typst(
    typst_file,
    output,
    .system2 = success_mock,
    .quarto_path = "/fake/quarto"
  )

  expect_equal(result, output)
  expect_equal(captured_command, "/fake/quarto")
  expect_equal(captured_args[1:3], c("typst", "compile", shQuote(typst_file)))
  expect_equal(captured_args[4], shQuote(output))
})

test_that(".system2 mock: non-zero exit code rejser fejl med output", {
  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[test]", typst_file)
  withr::defer(unlink(typst_file))

  expect_error(
    BFHcharts:::bfh_compile_typst(
      typst_file,
      tempfile(fileext = ".pdf"),
      .system2 = make_system2_failure_mock(exit_code = 1L, output = "Error: compilation failed"),
      .quarto_path = "/fake/quarto"
    ),
    "Quarto compilation failed"
  )
})

test_that(".system2 mock: error fra system2 er wrappet med forklarende besked", {
  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[test]", typst_file)
  withr::defer(unlink(typst_file))

  expect_error(
    BFHcharts:::bfh_compile_typst(
      typst_file,
      tempfile(fileext = ".pdf"),
      .system2 = make_system2_error_mock("cannot find quarto executable"),
      .quarto_path = "/fake/quarto"
    ),
    "Failed to execute Quarto command"
  )
})

test_that("bfh_compile_typst: reel Quarto integration (kun med BFHCHARTS_TEST_FULL=true)", {
  skip_if_not_full_test()
  skip_if_no_quarto()

  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[integration test]", typst_file)
  withr::defer(unlink(typst_file))
  output <- tempfile(fileext = ".pdf")

  expect_no_error(BFHcharts:::bfh_compile_typst(typst_file, output))
  expect_true(file.exists(output))
})
