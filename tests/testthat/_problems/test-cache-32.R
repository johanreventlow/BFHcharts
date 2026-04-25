# Extracted from test-cache.R:32

# test -------------------------------------------------------------------------
BFHcharts:::.resolve_font_family("sans")
BFHcharts:::get_right_aligned_marquee_style(0.9)
bfh_reset_caches()
expect_equal(length(ls(envir = BFHcharts:::.font_cache)), 0L)
expect_equal(length(ls(envir = BFHcharts:::.marquee_style_cache)), 0L)
expect_equal(length(ls(envir = BFHcharts:::.quarto_cache)), 0L)
expect_equal(length(ls(envir = BFHcharts:::.spc_text_cache)), 0L)
