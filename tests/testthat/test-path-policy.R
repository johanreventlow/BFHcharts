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
  # R's system2(stdout=TRUE, stderr=TRUE) shell-mode — disse karakterer kan
  # bryde shell-parsing eller udfoere kommando-substitution.
  expect_error(validate_export_path("out; rm -rf /"), "disallowed")
  expect_error(validate_export_path("out | cat /etc/passwd"), "disallowed")
  expect_error(validate_export_path("out`cmd`"), "disallowed")
  expect_error(validate_export_path("out<in"), "disallowed")
  expect_error(validate_export_path("out>redirect"), "disallowed")
  expect_error(validate_export_path("out\nevil"), "disallowed")
  expect_error(validate_export_path("out\revil"), "disallowed")
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
