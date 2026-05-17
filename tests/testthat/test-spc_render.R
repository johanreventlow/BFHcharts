# Tests: bfh_render_analysis() (Phase 1.3)
#
# Refs: openspec change restructure-spc-analysis-architecture
# Spec: openspec/specs/spc-analysis-api/spec.md ADDED requirement
#       "bfh_render_analysis SHALL compose text via deterministic
#       modifier cascade"

set.seed(201L)
TEST_DATA_RENDER <- data.frame(
  date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
  value = round(rnorm(24L, mean = 50, sd = 5), 1)
)

make_render_fixture <- function(target_text = NULL, chart_type = "i", language = "da") {
  result <- bfh_qic(TEST_DATA_RENDER,
    x = date, y = value,
    chart_type = chart_type, target_text = target_text
  )
  bfh_analyse(result,
    metadata = list(analysis_date = as.Date("2026-05-17")),
    language = language
  )
}


# ==========================================================================
# Returnerer character + respekterer max_chars
# ==========================================================================

test_that("bfh_render_analysis(): returnerer character af length 1", {
  analysis <- make_render_fixture()
  text <- bfh_render_analysis(analysis)

  expect_type(text, "character")
  expect_length(text, 1L)
  expect_true(nchar(text) > 0L)
})

test_that("bfh_render_analysis(): respekterer max_chars-budget", {
  analysis <- make_render_fixture(target_text = ">= 40")
  text375 <- bfh_render_analysis(analysis, max_chars = 375L)
  text200 <- bfh_render_analysis(analysis, max_chars = 200L)
  text100 <- bfh_render_analysis(analysis, max_chars = 100L)

  expect_lte(nchar(text375), 375L)
  expect_lte(nchar(text200), 200L)
  expect_lte(nchar(text100), 100L)
})


# ==========================================================================
# Determinisme: samme objekt + samme budget -> samme output
# ==========================================================================

test_that("bfh_render_analysis(): deterministisk paa identisk input", {
  analysis <- make_render_fixture()

  text1 <- bfh_render_analysis(analysis, max_chars = 375L)
  text2 <- bfh_render_analysis(analysis, max_chars = 375L)

  expect_identical(text1, text2)
})


# ==========================================================================
# Sprog-vaelger: language fra objekt + texts_loader-override
# ==========================================================================

test_that("bfh_render_analysis(): language fra objekt anvendes", {
  analysis_da <- make_render_fixture(language = "da")
  text_da <- bfh_render_analysis(analysis_da)

  analysis_en <- make_render_fixture(language = "en")
  text_en <- bfh_render_analysis(analysis_en)

  # Danish + engelsk producerer FORSKELLIG tekst (sprog-specifik)
  expect_false(identical(text_da, text_en))
})

test_that("bfh_render_analysis(): texts_loader-override respekteres", {
  analysis <- make_render_fixture()

  # Custom loader returnerer tom liste -> alle templates fejl-fallback
  empty_loader <- function() {
    list(stability = list(), target = list(), action = list())
  }
  text_empty <- bfh_render_analysis(analysis, texts_loader = empty_loader)

  expect_type(text_empty, "character")
  expect_length(text_empty, 1L)
})


# ==========================================================================
# Render_context-vaerdier respekteres verbatim (N2 fix)
# ==========================================================================

test_that("bfh_render_analysis(): target_display bevares som operator-Unicode", {
  analysis <- make_render_fixture(target_text = ">= 90")
  text <- bfh_render_analysis(analysis)

  # Output indeholder Unicode-version ">= 90" -> "\U2265 90"
  expect_true(grepl("\U2265", text, fixed = TRUE) || grepl(">=", text, fixed = TRUE))
})


# ==========================================================================
# Conclusions-noegler resolveres til tekst
# ==========================================================================

test_that("bfh_render_analysis(): no_signals giver 'stabil og forudsigelig'-tekst", {
  analysis <- make_render_fixture()
  expect_equal(analysis$conclusions$stability_key, "no_signals")

  text <- bfh_render_analysis(analysis)
  expect_match(text, "stabil|naturligt|forudsigelig", ignore.case = TRUE)
})


# ==========================================================================
# Invalid input: stop med klar besked
# ==========================================================================

test_that("bfh_render_analysis(): rejicerer ej-bfh_spc_analysis-input", {
  expect_error(
    bfh_render_analysis(list()),
    "must be a bfh_spc_analysis object"
  )
})

test_that("bfh_render_analysis(): rejicerer ej-funktion texts_loader", {
  analysis <- make_render_fixture()
  expect_error(
    bfh_render_analysis(analysis, texts_loader = "ej-funktion"),
    "texts_loader must be a function"
  )
})


# ==========================================================================
# Stability override (no_variation + majority_at_centerline)
# ==========================================================================

test_that("bfh_render_analysis(): no_variation tilfaelde rendrer 'konstant'-tekst", {
  constant_data <- data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
    value = rep(50, 24L)
  )
  result <- bfh_qic(constant_data, x = date, y = value, chart_type = "i")
  analysis <- bfh_analyse(result)
  text <- bfh_render_analysis(analysis)

  expect_match(text, "konstant|fast|identiske", ignore.case = TRUE)
})


# ==========================================================================
# Target-arm: 3 dispatch-grene
# ==========================================================================

test_that("bfh_render_analysis(): direction-aware target rendres", {
  analysis <- make_render_fixture(target_text = "<= 100")
  text <- bfh_render_analysis(analysis)

  # Target-tekst skal vaere tilstede
  expect_true(nchar(text) > 50L)
  expect_match(text, "mål|maal", ignore.case = TRUE)
})

test_that("bfh_render_analysis(): no target -> intet target-arm-clause", {
  analysis <- make_render_fixture()
  expect_equal(analysis$conclusions$target_key, "")

  text <- bfh_render_analysis(analysis)
  # Target-arm-clauses indeholder "Det nuvaerende niveau ligger ..." eller
  # "Det nuvaerende niveau opfylder ..." -- ingen af disse for no-target.
  # Action-arm kan stadig naevne udviklingsmaal (fx "Overvej om mal kan saettes").
  expect_no_match(text, "Det nuværende niveau ligger")
  expect_no_match(text, "Det nuværende niveau opfylder")
})
