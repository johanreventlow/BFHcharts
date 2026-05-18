# Phase 1.4 parity-tests: bfh_render_analysis(bfh_analyse(x)) vs
# eksisterende bfh_generate_analysis(x) for representativt sub-corpus.
#
# Phase 1 dækker base-path (no modifier-slices active). Sammenligning er
# semantisk-match: whitespace-normaliseret, eksakt-equality. Tegnbudget-
# trim tolerance er trivielt 0 her (samme budget-allokering bruges af
# begge paths).
#
# ##############################################################################
# # Cycle 05 finding (2026-05-18): TESTEN ER TAUTOLOGISK POST CUT-OVER         #
# #                                                                            #
# # Phase 2 cut-over (commit 4a01fef) lod bfh_generate_analysis() delegere    #
# # internt til bfh_analyse() + bfh_render_analysis(). De to "paths" der      #
# # her sammenlignes returnerer derfor identisk output by construction --     #
# # legacy_text er literalt new_text gennem samme code-path.                  #
# #                                                                           #
# # Tests skipperes med rationale-besked indtil snapshot-tests mod gemt       #
# # baseline-corpus er implementeret (Phase 99.1.2 follow-up). Determinism-   #
# # testen nederst bevares som SMALL-meaningful regression-gate (verificerer  #
# # idempotens af pipelinen).                                                 #
# ##############################################################################
#
# Refs: openspec change restructure-spc-analysis-architecture, Phase 1.4
#       docs/reviews/04-structured-spc-analysis-branch-2026-05-18.md (user finding)

# ==========================================================================
# Helper: semantic match efter whitespace-normalisering
# ==========================================================================

normalize_text <- function(s) {
  s <- gsub("\\s+", " ", s)
  trimws(s)
}

expect_semantic_text_equal <- function(actual, expected,
                                       tolerance_chars = 0L,
                                       info = NULL) {
  actual_n <- normalize_text(actual)
  expected_n <- normalize_text(expected)

  if (identical(actual_n, expected_n)) {
    expect_true(TRUE, info = info)
    return(invisible(actual_n))
  }

  # Tolerance: laengde-diff inden for n tegn + prefix match
  len_diff <- abs(nchar(actual_n) - nchar(expected_n))
  prefix_len <- min(nchar(actual_n), nchar(expected_n))
  prefix_match <- substr(actual_n, 1, prefix_len) == substr(expected_n, 1, prefix_len)

  if (tolerance_chars > 0L && len_diff <= tolerance_chars && prefix_match) {
    expect_true(TRUE, info = paste0(info, " (tolerance-match, diff=", len_diff, ")"))
    return(invisible(actual_n))
  }

  # Eksakt fail med informativ besked
  fail(paste0(
    info %||% "Text mismatch",
    "\nActual:   ", actual_n,
    "\nExpected: ", expected_n,
    "\nDiff len: ", len_diff
  ))
}


# ==========================================================================
# Parity-corpus: parametrisk sweep over key-paths
# ==========================================================================

# Hjaelper: parity-runde med pinned analysis_date for determinisme
parity_round <- function(x, metadata = list(), language = "da", max_chars = 375L) {
  metadata$analysis_date <- metadata$analysis_date %||% as.Date("2026-05-17")
  # bfh_generate_analysis kraever min_chars < max_chars; juster min_chars
  # ned for boundary-cases (200, 100)
  min_chars <- pmin(300L, max_chars - 10L)

  new_text <- bfh_render_analysis(
    bfh_analyse(x, metadata = metadata, language = language),
    max_chars = max_chars
  )
  legacy_text <- bfh_generate_analysis(
    x,
    metadata = metadata,
    language = language,
    max_chars = max_chars,
    min_chars = min_chars,
    use_ai = FALSE
  )
  list(new = new_text, legacy = legacy_text)
}


# Test-fixtures: synthetic data for hver dispatch-path
set.seed(42L)
TEST_STABLE_DATA <- data.frame(
  date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
  value = round(rnorm(24L, mean = 50, sd = 5), 1)
)

TEST_CONSTANT_DATA <- data.frame(
  date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
  value = rep(50, 24L)
)

set.seed(43L)
TEST_SHORT_DATA <- data.frame(
  date = seq(as.Date("2024-01-01"), by = "month", length.out = 8L),
  value = round(rnorm(8L, 50, 5), 1)
)

# Data med skift i niveau (forventet runs_only-signal)
TEST_SHIFT_DATA <- data.frame(
  date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
  value = c(rep(45, 12), rep(55, 12)) + rnorm(24L, 0, 0.5)
)


# ==========================================================================
# Sub-corpus 1: stabile data, ingen target, dansk
# ==========================================================================

SKIP_TAUTOLOGICAL <- "Tautological post-cut-over (cycle 05). See file-header for rationale + follow-up plan (snapshot-tests mod gemt baseline)."
skip_tautological <- function() testthat::skip(SKIP_TAUTOLOGICAL)

test_that("parity: stable data, no target, da, max_chars=375", {
  skip_tautological()
  res <- bfh_qic(TEST_STABLE_DATA, x = date, y = value, chart_type = "i")
  texts <- parity_round(res)
  expect_semantic_text_equal(texts$new, texts$legacy)
})

test_that("parity: stable data, no target, da, max_chars=200", {
  skip_tautological()
  res <- bfh_qic(TEST_STABLE_DATA, x = date, y = value, chart_type = "i")
  texts <- parity_round(res, max_chars = 200L)
  expect_semantic_text_equal(texts$new, texts$legacy)
})


# ==========================================================================
# Sub-corpus 2: konstant data (no_variation override)
# ==========================================================================

test_that("parity: constant data, no_variation override", {
  skip_tautological()
  res <- bfh_qic(TEST_CONSTANT_DATA, x = date, y = value, chart_type = "i")
  texts <- parity_round(res)
  expect_semantic_text_equal(texts$new, texts$legacy)
})


# ==========================================================================
# Sub-corpus 3: target operator (direction-aware)
# ==========================================================================

test_that("parity: stable data, target = '<= 100' (direction-aware lower)", {
  skip_tautological()
  res <- bfh_qic(TEST_STABLE_DATA, x = date, y = value, chart_type = "i", target_text = "<= 100")
  texts <- parity_round(res)
  expect_semantic_text_equal(texts$new, texts$legacy)
})

test_that("parity: stable data, target = '>= 40' (direction-aware higher)", {
  skip_tautological()
  res <- bfh_qic(TEST_STABLE_DATA, x = date, y = value, chart_type = "i", target_text = ">= 40")
  texts <- parity_round(res)
  expect_semantic_text_equal(texts$new, texts$legacy)
})


# ==========================================================================
# Sub-corpus 4: target numerisk (value-neutral)
# ==========================================================================

test_that("parity: stable data, target = 50 (value-neutral)", {
  skip_tautological()
  res <- bfh_qic(TEST_STABLE_DATA, x = date, y = value, chart_type = "i")
  texts <- parity_round(res, metadata = list(target = 50))
  expect_semantic_text_equal(texts$new, texts$legacy)
})


# ==========================================================================
# Sub-corpus 5: short data (n=8) -- legacy bruger samme templates trods low confidence
# ==========================================================================

test_that("parity: short data n=8 (legacy: ingen low-tier override endnu)", {
  skip_tautological()
  res <- bfh_qic(TEST_SHORT_DATA, x = date, y = value, chart_type = "i")
  # NB: Phase 1 har confidence_tier-akse men aktiverer IKKE override-
  # dispatch i renderer endnu (Slice 8 INCLUDE faktisk implementeret i
  # Phase 3+ commit). Parity holder fordi begge paths bruger samme
  # signal-baserede stability-key.
  texts <- parity_round(res)
  expect_semantic_text_equal(texts$new, texts$legacy)
})


# ==========================================================================
# Sub-corpus 6: run-chart (sigma_hat = NA by design)
# ==========================================================================

test_that("parity: run-chart, no target", {
  skip_tautological()
  res <- bfh_qic(TEST_STABLE_DATA, x = date, y = value, chart_type = "run")
  texts <- parity_round(res)
  expect_semantic_text_equal(texts$new, texts$legacy)
})


# ==========================================================================
# Sub-corpus 7: cl= specified (cl_user_supplied)
# ==========================================================================

test_that("parity: stable data, cl = 50 (cl_user_supplied) -- Slice 9 caveat aktiv begge veje", {
  skip_tautological()
  suppressWarnings({
    res <- bfh_qic(TEST_STABLE_DATA,
      x = date, y = value, chart_type = "i", cl = 50
    )
  })
  texts <- parity_round(res)
  # Post-Phase-2 cut-over: bfh_generate_analysis() er nu identisk med
  # bfh_render_analysis(bfh_analyse()). Slice 9 INCLUDE betyder begge
  # output indeholder cl_user_supplied-caveat som tail-clause.
  expect_semantic_text_equal(texts$new, texts$legacy)
  expect_match(texts$new, "midtlinje fastsat manuelt",
    ignore.case = TRUE
  )
})


# Cycle 06 M3: cl_user_supplied substring-assertion er IKKE tautologisk
# (verificerer Slice 9 caveat-prose rendres) og lever derfor i separat
# non-skipped test-block. Resterende parity-tests forbliver skipped.
test_that("Slice 9: cl_user_supplied caveat rendres i bfh_generate_analysis output", {
  suppressWarnings({
    res <- bfh_qic(TEST_STABLE_DATA,
      x = date, y = value, chart_type = "i", cl = 50
    )
  })
  text <- bfh_generate_analysis(res,
    metadata = list(analysis_date = as.Date("2026-05-17")),
    max_chars = 375L, min_chars = 300L, use_ai = FALSE
  )
  expect_match(text, "midtlinje fastsat manuelt", ignore.case = TRUE)
})


# ==========================================================================
# Sub-corpus 8: sprog (en)
# ==========================================================================

test_that("parity: stable data, no target, en, max_chars=375", {
  skip_tautological()
  res <- bfh_qic(TEST_STABLE_DATA, x = date, y = value, chart_type = "i")
  texts <- parity_round(res, language = "en")
  expect_semantic_text_equal(texts$new, texts$legacy)
})

test_that("parity: stable data, target = '>= 40', en", {
  skip_tautological()
  res <- bfh_qic(TEST_STABLE_DATA, x = date, y = value, chart_type = "i", target_text = ">= 40")
  texts <- parity_round(res, language = "en")
  expect_semantic_text_equal(texts$new, texts$legacy)
})


# ==========================================================================
# Sub-corpus 9: shift data (forventet runs_only-signal)
# ==========================================================================

test_that("parity: shifted data (runs_only / signal-baseret dispatch)", {
  skip_tautological()
  res <- bfh_qic(TEST_SHIFT_DATA, x = date, y = value, chart_type = "i")
  texts <- parity_round(res)
  expect_semantic_text_equal(texts$new, texts$legacy)
})


# ==========================================================================
# Determinism: parity holder paa tvaers af kald
# ==========================================================================

test_that("parity: deterministisk -- gentaget kald giver samme output", {
  res <- bfh_qic(TEST_STABLE_DATA, x = date, y = value, chart_type = "i")
  texts1 <- parity_round(res)
  texts2 <- parity_round(res)

  expect_identical(texts1$new, texts2$new)
  expect_identical(texts1$legacy, texts2$legacy)
})
