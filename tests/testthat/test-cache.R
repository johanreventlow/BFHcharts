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

test_that("bfh_reset_caches() tømmer alle caches", {
  # Fyld caches
  BFHcharts:::.resolve_font_family("sans")
  BFHcharts:::get_right_aligned_marquee_style(0.9)

  bfh_reset_caches()

  expect_equal(length(ls(envir = BFHcharts:::.font_cache)), 0L)
  expect_equal(length(ls(envir = BFHcharts:::.marquee_style_cache)), 0L)
  expect_equal(length(ls(envir = BFHcharts:::.quarto_cache)), 0L)
  expect_equal(length(ls(envir = BFHcharts:::.i18n_cache)), 0L)
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
