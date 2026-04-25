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
# SHELL METACHARACTERS
# ============================================================================

test_that("validate_export_path afviser shell metacharacters", {
  expect_error(validate_export_path("out; rm -rf /"), "disallowed")
  expect_error(validate_export_path("out | cat /etc/passwd"), "disallowed")
  expect_error(validate_export_path("out & evil"), "disallowed")
  expect_error(validate_export_path("out`cmd`"), "disallowed")
  expect_error(validate_export_path("out$(cmd)"), "disallowed")
  expect_error(validate_export_path("out<in"), "disallowed")
  expect_error(validate_export_path("out>redirect"), "disallowed")
  expect_error(validate_export_path("out\nevil"), "disallowed")
  expect_error(validate_export_path("out\revil"), "disallowed")
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
# BASIC INPUT VALIDATION
# ============================================================================

test_that("validate_export_path fejler ved ikke-character input", {
  expect_error(validate_export_path(NULL), "non-empty character")
  expect_error(validate_export_path(123), "non-empty character")
  expect_error(validate_export_path(""), "non-empty character")
  expect_error(validate_export_path(c("a", "b")), "non-empty character")
})
