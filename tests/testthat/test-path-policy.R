# ============================================================================
# UNIT TESTS FOR validate_export_path() — central path policy helper
# ============================================================================

# ============================================================================
# PATH TRAVERSAL
# ============================================================================

test_that("validate_export_path afviser path traversal med ..", {
  expect_error(
    validate_export_path("../../etc/passwd"),
    "path traversal"
  )
  expect_error(
    validate_export_path("output/../../../etc/cron.d/bad"),
    "path traversal"
  )
  expect_error(
    validate_export_path("charts/../../secret.pdf"),
    "path traversal"
  )
})

# ============================================================================
# OUTPUT PATH POLICY: kun NUL/LF/CR + traversal afvises
# ============================================================================
#
# Output-stier passeres som argv[1+] til system2() i vector-form, som ikke
# invokerer shell. Shell-metacharacters er derfor ufarlige.
# Kontekst: Codex 2026-04-30 finding #10 / change relax-output-path-policy-parens

test_that("validate_export_path afviser stadig shell-pipeline metacharacters + LF/CR", {
  # R's system2(stdout=TRUE, stderr=TRUE) shell-mode -- these characters can
  # break shell parsing or trigger command substitution.
  expect_error(validate_export_path("out; rm -rf /"), "disallowed")
  expect_error(validate_export_path("out | cat /etc/passwd"), "disallowed")
  expect_error(validate_export_path("out`cmd`"), "disallowed")
  expect_error(validate_export_path("out<in"), "disallowed")
  expect_error(validate_export_path("out>redirect"), "disallowed")
  expect_error(validate_export_path("out\nevil"), "disallowed")
  expect_error(validate_export_path("out\revil"), "disallowed")
})

test_that("validate_export_path afviser double-quote i output-sti (M2)", {
  # Double-quote can break shell argument boundaries even inside shQuote'd strings
  # in some edge cases. Rejected as a safety measure.
  expect_error(validate_export_path('a".pdf'), "disallowed")
  expect_error(validate_export_path('out"evil.pdf'), "disallowed")
})

test_that("validate_export_path tillader hospital-relevante karakterer i output-stier", {
  # Codex 2026-04-30 #10 (relaxed): hospital-filnavne inkluderer parens,
  # brackets, braces, ampersand, dollar, single-quote, spaces.
  expect_no_error(validate_export_path("out & evil"))
  expect_no_error(validate_export_path("out$value"))
  expect_no_error(validate_export_path("out's draft"))
})

test_that("validate_export_path accepterer parens/brackets/braces (hospital-filnavne)", {
  expect_no_error(validate_export_path("rapport (final).pdf"))
  expect_no_error(validate_export_path("Q1 [2026].pdf"))
  expect_no_error(validate_export_path("kvalitet {draft}.pdf"))
  expect_no_error(validate_export_path("Indikator & resultat.pdf"))
  expect_no_error(validate_export_path("(((test))).pdf"))
})

test_that("validate_export_path accepterer enkelt-quotes og dollartegn", {
  expect_no_error(validate_export_path("rapport 'draft'.pdf"))
  expect_no_error(validate_export_path("budget $2026.pdf"))
})

test_that(".check_metachars_binary forbliver strikt for binary-stier", {
  # Binary-validator skal stadig afvise shell-metacharacters
  expect_error(.check_metachars_binary("/bin/quarto;evil"), "disallowed")
  expect_error(.check_metachars_binary("/bin/quarto|cat"), "disallowed")
  expect_error(.check_metachars_binary("/bin/quarto`cmd`"), "disallowed")
  expect_error(.check_metachars_binary("/bin/quarto$(cmd)"), "disallowed")
  expect_error(.check_metachars_binary("/bin/quarto<in"), "disallowed")
})

# ============================================================================
# EXTENSION VALIDATION
# ============================================================================

test_that("validate_export_path ext_action=stop fejler ved forkert extension", {
  expect_error(
    validate_export_path("chart.txt", extension = "png", ext_action = "stop"),
    regexp = "\\.png"
  )
  expect_error(
    validate_export_path("chart.pdf", extension = "typ", ext_action = "stop"),
    regexp = "\\.typ"
  )
})

test_that("validate_export_path ext_action=warn advarer ved forkert extension", {
  expect_warning(
    validate_export_path("chart.txt", extension = "png", ext_action = "warn"),
    regexp = "\\.png"
  )
})

test_that("validate_export_path ext_action=none ignorerer extension mismatch", {
  expect_no_error(validate_export_path("chart.txt", extension = "png", ext_action = "none"))
  expect_no_warning(validate_export_path("chart.txt", extension = "png", ext_action = "none"))
})

test_that("validate_export_path accepterer korrekt extension (case-insensitiv)", {
  expect_no_error(validate_export_path("chart.PNG", extension = "png", ext_action = "stop"))
  expect_no_error(validate_export_path("chart.PDF", extension = "pdf", ext_action = "stop"))
})

# ============================================================================
# SYMLINK ESCAPE (normalize = TRUE)
# ============================================================================

test_that("validate_export_path med normalize=TRUE afviser symlink der escaper root", {
  skip_on_os("windows")

  withr::with_tempdir({
    safe_dir <- file.path(getwd(), "safe")
    outside <- file.path(getwd(), "outside")
    dir.create(safe_dir)
    dir.create(outside)

    target_file <- file.path(outside, "secret.typ")
    writeLines("secret", target_file)

    link_path <- file.path(safe_dir, "link.typ")
    file.symlink(target_file, link_path)

    expect_error(
      validate_export_path(link_path, normalize = TRUE, allow_root = safe_dir),
      "outside the allowed root"
    )
  })
})

# ============================================================================
# LEGITIM STI ACCEPTERES
# ============================================================================

test_that("validate_export_path accepterer legitim sti og returnerer den normaliseret", {
  withr::with_tempfile("f", fileext = ".typ", {
    writeLines("", f)
    result <- validate_export_path(f, extension = "typ", ext_action = "stop", normalize = TRUE)
    expect_true(is.character(result))
    expect_false(grepl("..", result, fixed = TRUE))
  })
})

test_that("validate_export_path returnerer path invisibly uden normalize", {
  path <- "charts/output.png"
  result <- withVisible(validate_export_path(path))
  expect_false(result$visible)
  expect_equal(result$value, path)
})

# ============================================================================
# TRAVERSAL: KOMPONENT-BASERET CHECK (regression for #214)
# ============================================================================

test_that(".check_traversal accepterer '..' som del af filnavn (ikke komponent)", {
  # Disse skal IKKE afvises — '..' er del af filnavnet, ikke en path-komponent
  expect_no_error(validate_export_path("report..v2.pdf"))
  expect_no_error(validate_export_path("..hidden.pdf"))
  expect_no_error(validate_export_path("data..backup.csv"))
  expect_no_error(validate_export_path("analyse..final.pdf"))
})

test_that(".check_traversal afviser '..' som selvstændig path-komponent", {
  expect_error(validate_export_path("../etc/passwd"), "traversal")
  expect_error(validate_export_path("output/../secret.pdf"), "traversal")
  expect_error(validate_export_path("../../sensitive.pdf"), "traversal")
  expect_error(validate_export_path("subdir/.."), "traversal")
  expect_error(validate_export_path("subdir/../child.pdf"), "traversal")
})

test_that(".check_traversal håndterer Windows backslash-separator", {
  # strsplit splitter på både / og \ — '\..\' erkendes som traversal-komponent
  # på alle platforme
  expect_error(validate_export_path("subdir\\..\\child.pdf"), "traversal")
})

# ============================================================================
# BASIC INPUT VALIDATION
# ============================================================================

test_that("validate_export_path fejler ved ikke-character input", {
  expect_error(validate_export_path(NULL), "non-empty character")
  expect_error(validate_export_path(123), "non-empty character")
  expect_error(validate_export_path(""), "non-empty character")
  expect_error(validate_export_path(c("a", "b")), "non-empty character")
})

# ============================================================================
# $-SUBSTITUTION: literal dollar sign in paths (mock-based)
# ============================================================================
#
# Verifies that .safe_system2_capture() passes $ as a literal character to
# the shell, not as a variable-expansion trigger. shQuote() on Unix wraps
# the path in single quotes which suppresses $-expansion entirely.
#
# Reference: openspec/changes/2026-05-01-validate-output-paths-against-runtime
# Spec: pdf-export, "$ in output path does not trigger shell substitution"

test_that("$ in output path does not trigger shell substitution (mock)", {
  skip_on_os("windows") # shQuote style differs; substitution semantics differ

  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[dollar test]", typst_file)
  withr::defer(unlink(typst_file))

  # Path contains literal $HOME -- must NOT be expanded to actual home dir
  out_path <- file.path(tempdir(), paste0("test_", "$HOME", "_dummy.pdf"))
  withr::defer(unlink(out_path))

  captured_args <- NULL
  success_mock <- function(command, args, ...) {
    captured_args <<- args
    file.create(out_path)
    character(0)
  }

  expect_no_error(
    BFHcharts:::bfh_compile_typst(
      typst_file, out_path,
      .system2 = success_mock, .quarto_path = "/fake/quarto"
    )
  )

  # The arg sent to system2 must contain the literal "$HOME" string
  output_arg <- captured_args[4]
  expect_true(
    grepl("$HOME", output_arg, fixed = TRUE),
    info = paste("Expected literal $HOME in arg, got:", output_arg)
  )
  # On Unix, shQuote wraps in single quotes which suppresses $ expansion
  expect_true(
    startsWith(output_arg, "'"),
    info = "Unix: shQuote must wrap with single quotes to prevent $-expansion"
  )
})

test_that("${USER} and backtick in filename are handled safely (mock)", {
  skip_on_os("windows")

  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[subst test]", typst_file)
  withr::defer(unlink(typst_file))

  # ${USER} literal path
  out_user <- file.path(tempdir(), paste0("report_", "${USER}", ".pdf"))
  withr::defer(unlink(out_user))

  captured_args <- NULL
  mock_user <- function(command, args, ...) {
    captured_args <<- args
    file.create(out_user)
    character(0)
  }

  expect_no_error(
    BFHcharts:::bfh_compile_typst(
      typst_file, out_user,
      .system2 = mock_user, .quarto_path = "/fake/quarto"
    )
  )
  output_arg_user <- captured_args[4]
  # Literal ${USER} must survive in the quoted arg
  expect_true(
    grepl("${USER}", output_arg_user, fixed = TRUE),
    info = paste("Expected literal ${USER} in arg, got:", output_arg_user)
  )

  # Note: backtick (`) is rejected by validate_export_path() so it never
  # reaches .safe_system2_capture(). Test that the validator blocks it.
  expect_error(
    validate_export_path(paste0(tempdir(), "/report`cmd`.pdf")),
    "disallowed",
    info = "Backtick must be rejected by validator before reaching system2"
  )
})

test_that("$ in output path renders actual PDF with literal filename (live Quarto)", {
  skip_if_not_render_test()
  skip_if_no_quarto()
  skip_on_os("windows")

  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[dollar live test]", typst_file)
  withr::defer(unlink(typst_file))

  out_dollar <- file.path(tempdir(), paste0("data_", "$HOME", "_test.pdf"))
  withr::defer(unlink(out_dollar))

  expect_no_error(BFHcharts:::bfh_compile_typst(typst_file, out_dollar))
  expect_true(file.exists(out_dollar))
  expect_gt(file.size(out_dollar), 0L)

  # Confirm literal $HOME is in the filename (not expanded to actual home path)
  expect_true(
    grepl("$HOME", basename(out_dollar), fixed = TRUE),
    info = "Filename must contain literal $HOME, not expanded home directory"
  )
})

# ============================================================================
# M18: .safe_system2_capture quoting applies uniformly across platforms
# ============================================================================
#
# Historical note: previously the Windows branch in .safe_system2_capture
# returned early without shQuote(), based on the (incorrect) assumption that
# Windows passes argv tokens directly to the child process. In practice,
# system2() on Windows joins args with paste(collapse = " ") just like POSIX,
# so spaces in output paths (e.g. "Behandling og pleje/foo.pdf") would split
# into multiple tokens and typst would reject `unexpected argument 'og'`.
# Quoting is therefore applied on both platforms.

test_that(".safe_system2_capture quotes non-flag args on Windows (mocked)", {
  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[win test]", typst_file)
  withr::defer(unlink(typst_file))

  out_pdf <- tempfile(fileext = ".pdf")
  withr::defer(unlink(out_pdf))

  captured_args <- NULL
  win_mock_system2 <- function(command, args, ...) {
    captured_args <<- args
    file.create(out_pdf)
    character(0)
  }

  with_mocked_bindings(
    .is_windows = function() TRUE,
    code = {
      BFHcharts:::bfh_compile_typst(
        typst_file, out_pdf,
        .system2 = win_mock_system2,
        .quarto_path = "/fake/quarto"
      )
    }
  )

  # Non-flag args must be wrapped in shell quotes so paths with spaces survive
  # system2()'s paste(collapse = " ") concatenation. shQuote() picks the
  # platform-appropriate convention (single-quote on POSIX, double-quote on
  # Windows); accept either since tests may run on either OS.
  path_args <- captured_args[!captured_args %in% c(
    "typst", "compile",
    "--ignore-system-fonts", "--font-path", "--root"
  )]
  expect_true(
    length(path_args) > 0L,
    info = "expected at least one path-like arg in the captured args"
  )
  expect_true(
    all(grepl("^['\"].*['\"]$", path_args)),
    info = "Windows branch must wrap path args via shQuote() to survive system2() concatenation"
  )
  # The raw (unquoted) typst_file path must NOT appear literally.
  expect_false(
    any(captured_args == typst_file),
    info = "raw typst_file path must be quoted, not passed literally"
  )
})

test_that(".safe_system2_capture applies shQuote on non-Windows (mocked)", {
  skip_on_os("windows") # Only meaningful to test POSIX quoting on POSIX

  typst_file <- tempfile(fileext = ".typ")
  writeLines("#text[posix test]", typst_file)
  withr::defer(unlink(typst_file))

  out_pdf <- tempfile(fileext = ".pdf")
  withr::defer(unlink(out_pdf))

  captured_args <- NULL
  posix_mock <- function(command, args, ...) {
    captured_args <<- args
    file.create(out_pdf)
    character(0)
  }

  with_mocked_bindings(
    .is_windows = function() FALSE,
    code = {
      BFHcharts:::bfh_compile_typst(
        typst_file, out_pdf,
        .system2 = posix_mock,
        .quarto_path = "/fake/quarto"
      )
    }
  )

  # On POSIX path, non-flag args must be shQuote'd (single-quote wrapping).
  # `--root` was added to KNOWN_TYPST_FLAGS in 0.16.1; the flag itself is not
  # quoted, but its value (the staged tempdir) IS a path arg that must be
  # quoted -- so it falls through to the path_args bucket below.
  path_args <- captured_args[!captured_args %in% c(
    "typst", "compile",
    "--ignore-system-fonts", "--font-path", "--root"
  )]
  expect_true(
    all(startsWith(path_args, "'")),
    info = "POSIX branch must wrap path args in single-quotes via shQuote"
  )
})
