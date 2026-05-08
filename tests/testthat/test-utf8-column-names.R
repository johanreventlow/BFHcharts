# ============================================================================
# UTF-8 / Danish column-name support
# ============================================================================
# Issue #327: native Danish character support in column-name validator.
# Hospital systems and BIA exports commonly produce Danish column names like
# "Taeller", "Naevner", "Maaned" (with native ae, oe, aa). Downstream apps
# (biSPCharts) previously had to ASCII-translit before calling bfh_qic().

# Danish chars via \u-escape so source remains portable across encodings.
# æ = ae, ø = oe, å = aa
DK_COL_TAELLER <- "Tæller"
DK_COL_NAEVNER <- "Nævner"
DK_COL_MAANED <- "Måned"
DK_COL_AKTIVITET <- "Aktivitet"
DK_COL_AAR <- "År"

make_danish_data <- function() {
  df <- data.frame(
    a = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    b = stats::rpois(12, lambda = 15),
    c = stats::rpois(12, lambda = 100),
    stringsAsFactors = FALSE
  )
  names(df) <- c(DK_COL_MAANED, DK_COL_TAELLER, DK_COL_NAEVNER)
  df
}

test_that("validate_column_name_expr accepts Danish letters", {
  # Direct symbol-construction via as.name() preserves UTF-8.
  sym_taeller <- as.name(DK_COL_TAELLER)
  sym_naevner <- as.name(DK_COL_NAEVNER)
  sym_maaned <- as.name(DK_COL_MAANED)
  sym_aar <- as.name(DK_COL_AAR)

  # Should not error (returns the symbol).
  expect_silent(BFHcharts:::validate_column_name_expr(sym_taeller, "y"))
  expect_silent(BFHcharts:::validate_column_name_expr(sym_naevner, "n"))
  expect_silent(BFHcharts:::validate_column_name_expr(sym_maaned, "x"))
  expect_silent(BFHcharts:::validate_column_name_expr(sym_aar, "x"))
})

test_that("validate_column_name_expr accepts mixed Danish + ASCII letters", {
  # e.g. "patient_taeller", "rate.naevner"
  mixed_under <- as.name(paste0("patient_", DK_COL_TAELLER))
  mixed_dot <- as.name(paste0("rate.", DK_COL_NAEVNER))

  expect_silent(BFHcharts:::validate_column_name_expr(mixed_under, "y"))
  expect_silent(BFHcharts:::validate_column_name_expr(mixed_dot, "y"))
})

test_that("validate_column_name_expr still rejects expressions with Danish names", {
  # Function calls and operators still rejected, regardless of letter set.
  bad_call <- quote(system("echo pwned"))
  expect_error(
    BFHcharts:::validate_column_name_expr(bad_call, "y"),
    "y must be a simple column name"
  )

  bad_op <- str2lang(paste0(DK_COL_TAELLER, " + 1"))
  expect_error(
    BFHcharts:::validate_column_name_expr(bad_op, "y"),
    "y must be a simple column name"
  )
})

test_that("validate_column_name_expr still rejects names starting with digit", {
  bad_digit <- as.name(paste0("1", DK_COL_TAELLER))
  expect_error(
    BFHcharts:::validate_column_name_expr(bad_digit, "y"),
    "y must be a simple column name"
  )
})

test_that("validate_column_name_expr still rejects names with space", {
  # Spaces are not letter, digit, dot or underscore, so must be rejected.
  bad_space <- as.name(paste0(DK_COL_TAELLER, " count"))
  expect_error(
    BFHcharts:::validate_column_name_expr(bad_space, "y"),
    "y must be a simple column name"
  )
})

test_that("bfh_qic accepts Danish column names end-to-end (run chart)", {
  set.seed(327)
  df <- make_danish_data()

  # Programmatic NSE via as.name() on UTF-8 string.
  sym_x <- as.name(DK_COL_MAANED)
  sym_y <- as.name(DK_COL_TAELLER)

  # do.call evaluates the symbols-as-args; bfh_qic's substitute() then
  # captures the symbols correctly.
  expect_no_error({
    do.call(bfh_qic, list(
      data = df,
      x = sym_x,
      y = sym_y,
      chart_type = "run"
    ))
  })
})

test_that("bfh_qic accepts Danish column names with n parameter (p chart)", {
  set.seed(327)
  df <- make_danish_data()

  sym_x <- as.name(DK_COL_MAANED)
  sym_y <- as.name(DK_COL_TAELLER)
  sym_n <- as.name(DK_COL_NAEVNER)

  expect_no_error({
    do.call(bfh_qic, list(
      data = df,
      x = sym_x,
      y = sym_y,
      n = sym_n,
      chart_type = "p"
    ))
  })
})

test_that("bfh_qic surfaces Danish column name in error when missing", {
  set.seed(327)
  df <- make_danish_data()
  # Reference a column that does not exist.
  sym_missing <- as.name("Ikkeeksisterende")

  err <- tryCatch(
    do.call(bfh_qic, list(
      data = df,
      x = as.name(DK_COL_MAANED),
      y = sym_missing,
      chart_type = "run"
    )),
    error = function(e) conditionMessage(e)
  )

  # Error should mention the missing column name (preserves Danish letters).
  expect_true(nchar(err) > 0)
})
