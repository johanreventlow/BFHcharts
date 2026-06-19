test_that("font-cache: forskellige fontfamilies giver separate cache-entries", {
  bfh_reset_caches()

  # Resultater kan begge falde tilbage til "sans", men nøglerne skal være SEPARATE
  BFHcharts:::.resolve_font_family("sans")
  BFHcharts:::.resolve_font_family("serif")

  cache_keys <- ls(envir = BFHcharts:::.font_cache)
  expect_equal(length(cache_keys), 2L)
})

test_that("font-cache: samme fontfamily giver cache hit (kun 1 entry)", {
  bfh_reset_caches()

  BFHcharts:::.resolve_font_family("sans")
  BFHcharts:::.resolve_font_family("sans")

  cache_keys <- ls(envir = BFHcharts:::.font_cache)
  expect_equal(length(cache_keys), 1L)
})

test_that("bfh_reset_caches() tommer alle caches (#439)", {
  # Fyld samtlige 6 caches foer reset.
  # Caches er environments (reference semantics); hold en lokal reference
  # og tildel via assign() saa testmiljoejet kan mutere package-state.
  BFHcharts:::.resolve_font_family("sans")
  BFHcharts:::get_right_aligned_marquee_style(0.9)
  BFHcharts:::i18n_lookup("labels.misc.ukendt", "da")

  dep_env <- BFHcharts:::.dep_guard_cache
  assign("testkey", TRUE, envir = dep_env)

  tpl_env <- BFHcharts:::.bfh_template_cache
  assign("dir", "/tmp", envir = tpl_env)

  bfh_reset_caches()

  expect_equal(length(ls(envir = BFHcharts:::.font_cache)), 0L)
  expect_equal(length(ls(envir = BFHcharts:::.marquee_style_cache)), 0L)
  expect_equal(length(ls(envir = BFHcharts:::.quarto_cache)), 0L)
  expect_equal(length(ls(envir = BFHcharts:::.i18n_cache)), 0L)
  # Previously missing from bfh_reset_caches():
  expect_equal(length(ls(envir = BFHcharts:::.bfh_template_cache)), 0L)
  expect_equal(length(ls(envir = BFHcharts:::.dep_guard_cache)), 0L)
})

test_that("marquee style-cache: identiske lineheights giver kun 1 entry", {
  bfh_reset_caches()

  BFHcharts:::get_right_aligned_marquee_style(0.9)
  BFHcharts:::get_right_aligned_marquee_style(0.9)

  cache_keys <- ls(envir = BFHcharts:::.marquee_style_cache)
  expect_equal(length(cache_keys), 1L)
})

test_that("marquee style-cache: forskellige lineheights giver separate entries", {
  bfh_reset_caches()

  BFHcharts:::get_right_aligned_marquee_style(0.9)
  BFHcharts:::get_right_aligned_marquee_style(1.2)

  cache_keys <- ls(envir = BFHcharts:::.marquee_style_cache)
  expect_equal(length(cache_keys), 2L)
})

test_that("font-cache: sekventielle kald med samme font giver identisk resultat", {
  bfh_reset_caches()

  result1 <- BFHcharts:::.resolve_font_family("sans")
  result2 <- BFHcharts:::.resolve_font_family("sans")

  expect_identical(result1, result2)
})
