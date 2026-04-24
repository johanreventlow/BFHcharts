# ============================================================================
# TESTS FOR validate_export_path() — CENTRAL PATH POLICY HELPER
# ============================================================================
#
# Reference: openspec/changes/central-export-path-policy (tasks 2.1–2.5)
# Spec: "External path inputs SHALL be validated centrally before any
#        file system operation"

# ============================================================================
# 2.1 — Path traversal rejection
# ============================================================================

test_that("validate_export_path afviser '..' segment i relativ sti", {
  expect_error(
    BFHcharts:::validate_export_path("../../etc/passwd"),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser '..' segment i absolut sti", {
  expect_error(
    BFHcharts:::validate_export_path("/safe/../unsafe/file.pdf"),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path accepterer filnavne der indeholder '..' som del-streng", {
  # '..' som del-streng af et segmentnavn er ikke traversal
  path <- file.path(tempdir(), "my..report.pdf")
  expect_no_error(BFHcharts:::validate_export_path(path, extension = "pdf"))
})

# ============================================================================
# 2.2 — Shell metacharacter rejection
# ============================================================================

test_that("validate_export_path afviser semikolon i sti", {
  expect_error(
    BFHcharts:::validate_export_path(file.path(tempdir(), "file;rm.pdf")),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser pipe i sti", {
  expect_error(
    BFHcharts:::validate_export_path("output|cat.pdf"),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser ampersand i sti", {
  expect_error(
    BFHcharts:::validate_export_path("output&cmd.pdf"),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser backtick i sti", {
  expect_error(
    BFHcharts:::validate_export_path("output`cmd`.pdf"),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser dollar-parentes i sti", {
  expect_error(
    BFHcharts:::validate_export_path("output$(cmd).pdf"),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser newline i sti", {
  expect_error(
    BFHcharts:::validate_export_path("output\ncmd.pdf"),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser angle-brackets i sti", {
  expect_error(
    BFHcharts:::validate_export_path("output; rm -rf /.pdf"),
    class = "bfhcharts_path_policy_error"
  )
  expect_error(
    BFHcharts:::validate_export_path("output > /etc/hosts.pdf"),
    class = "bfhcharts_path_policy_error"
  )
})

# ============================================================================
# 2.3 — Wrong extension rejection
# ============================================================================

test_that("validate_export_path afviser forkert extension (txt vs pdf)", {
  expect_error(
    BFHcharts:::validate_export_path(file.path(tempdir(), "output.txt"), extension = "pdf"),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser forkert extension med informativ besked", {
  err <- tryCatch(
    BFHcharts:::validate_export_path(file.path(tempdir(), "output.txt"), extension = "pdf"),
    bfhcharts_path_policy_error = function(e) e
  )
  expect_match(conditionMessage(err), "pdf")
  expect_match(conditionMessage(err), "txt")
})

test_that("validate_export_path accepterer korrekt extension case-insensitivt", {
  expect_no_error(
    BFHcharts:::validate_export_path(file.path(tempdir(), "output.PDF"), extension = "pdf")
  )
  expect_no_error(
    BFHcharts:::validate_export_path(file.path(tempdir(), "output.PNG"), extension = "png")
  )
})

# ============================================================================
# 2.4 — allow_root: symlink-escape / directory-escape rejection
# ============================================================================

test_that("validate_export_path afviser sti uden for allow_root", {
  tmp_root <- tempfile()
  dir.create(tmp_root)
  withr::defer(unlink(tmp_root, recursive = TRUE))

  outside_path <- file.path(dirname(tmp_root), "outside.pdf")

  expect_error(
    BFHcharts:::validate_export_path(outside_path, allow_root = tmp_root),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path accepterer sti inde i allow_root", {
  tmp_root <- tempfile()
  dir.create(tmp_root)
  withr::defer(unlink(tmp_root, recursive = TRUE))

  inside_path <- file.path(tmp_root, "output.pdf")

  expect_no_error(
    BFHcharts:::validate_export_path(inside_path, allow_root = tmp_root)
  )
})

test_that("validate_export_path allow_root prefix-angreb afvises", {
  # /tmp og /tmp-attack: /tmp-attack starter med /tmp men er ikke inde i /tmp
  tmp_root <- tempfile()
  dir.create(tmp_root)
  withr::defer(unlink(tmp_root, recursive = TRUE))

  attack_root <- paste0(tmp_root, "-attack")
  dir.create(attack_root)
  withr::defer(unlink(attack_root, recursive = TRUE))

  attack_path <- file.path(attack_root, "output.pdf")

  expect_error(
    BFHcharts:::validate_export_path(attack_path, allow_root = tmp_root),
    class = "bfhcharts_path_policy_error"
  )
})

# ============================================================================
# 2.5 — Legitim sti: normaliseret absolut sti returneres
# ============================================================================

test_that("validate_export_path returnerer normaliseret absolut sti", {
  path <- file.path(tempdir(), "output.pdf")
  result <- BFHcharts:::validate_export_path(path, extension = "pdf")

  expect_type(result, "character")
  expect_length(result, 1L)
  expect_true(startsWith(result, "/") || grepl("^[A-Za-z]:[/\\\\]", result))
})

test_that("validate_export_path returnerer samme sti for allerede-absolut input", {
  path <- file.path(tempdir(), "my_chart.png")
  result <- BFHcharts:::validate_export_path(path, extension = "png")

  # Basename bevaret
  expect_equal(basename(result), "my_chart.png")
})

# ============================================================================
# Fejlhåndtering for ugyldige path-typer
# ============================================================================

test_that("validate_export_path afviser tom streng", {
  expect_error(
    BFHcharts:::validate_export_path(""),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser NULL", {
  expect_error(
    BFHcharts:::validate_export_path(NULL),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser numerisk input", {
  expect_error(
    BFHcharts:::validate_export_path(123),
    class = "bfhcharts_path_policy_error"
  )
})

test_that("validate_export_path afviser vektor med flere stier", {
  expect_error(
    BFHcharts:::validate_export_path(c("a.pdf", "b.pdf")),
    class = "bfhcharts_path_policy_error"
  )
})
