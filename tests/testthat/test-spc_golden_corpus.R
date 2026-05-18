# Tests: Phase 99.1 (lite) -- Expanded golden-corpus snapshot
#
# Parametric snapshot-tests over representative dispatch-rum. Faar
# regression-gate naar render-output aendrer sig uintenderet.
# Snapshot-filer lever i tests/testthat/_snaps/.
#
# Klinisk-validerede 10-15 cases er DEFERRED (kraever ekstern reviewer)
# -- denne corpus er kun strukturel sweep.
#
# Refs: openspec change restructure-spc-analysis-architecture, Phase 99.1


# ==========================================================================
# Stable test-fixtures (pinned seeds + analysis_date)
# ==========================================================================

ANALYSIS_DATE <- as.Date("2026-05-18")

# Fixture-fabrikker hentes fra helper-fixtures.R:
#   fixture_phase_stable, fixture_phase_constant, fixture_phase_short,
#   fixture_phase_shifted, fixture_phase_phased
# (set.seed scoped via withr::with_seed -- ej test-order-afhaengigt)
fixture_stable <- function() fixture_phase_stable(seed = 991L, sd = 3)
fixture_constant <- function() fixture_phase_constant()
fixture_short <- function() fixture_phase_short(seed = 992L)
fixture_shifted <- function() fixture_phase_shifted(seed = 993L)
fixture_phased <- function() fixture_phase_phased(seed = 994L, current_mean = 55)


# Helper: kor full pipeline + return text (deterministisk via pinned date)
render_for_snapshot <- function(data, target_text = NULL, language = "da",
                                max_chars = 375L, part = NULL, ...) {
  args <- list(
    data = data, x = quote(date), y = quote(value),
    chart_type = "i", target_text = target_text
  )
  if (!is.null(part)) args$part <- part
  res <- do.call(bfh_qic, c(args, list(...)))

  metadata <- list(analysis_date = ANALYSIS_DATE)
  bfh_render_analysis(
    bfh_analyse(res, metadata = metadata, language = language),
    max_chars = max_chars
  )
}


# ==========================================================================
# Stability-paths sweep
# ==========================================================================

test_that("golden: stable data, no target, da, max=375", {
  text <- render_for_snapshot(fixture_stable())
  expect_snapshot(cat(text))
})

test_that("golden: stable data, no target, en, max=375", {
  text <- render_for_snapshot(fixture_stable(), language = "en")
  expect_snapshot(cat(text))
})

test_that("golden: constant data (no_variation override)", {
  text <- render_for_snapshot(fixture_constant())
  expect_snapshot(cat(text))
})

test_that("golden: short data (low confidence -> not_evaluable)", {
  text <- render_for_snapshot(fixture_short())
  expect_snapshot(cat(text))
})

test_that("golden: shifted data (runs_only signal)", {
  text <- render_for_snapshot(fixture_shifted())
  expect_snapshot(cat(text))
})


# ==========================================================================
# Target-paths sweep
# ==========================================================================

test_that("golden: stable + target='<= 100' (direction-aware lower)", {
  text <- render_for_snapshot(fixture_stable(), target_text = "<= 100")
  expect_snapshot(cat(text))
})

test_that("golden: stable + target='>= 40' (direction-aware higher)", {
  text <- render_for_snapshot(fixture_stable(), target_text = ">= 40")
  expect_snapshot(cat(text))
})


# ==========================================================================
# Multi-phase paths (Slice 3 + 4 + 5)
# ==========================================================================

test_that("golden: phased data + higher_better direction (full modifier-cascade)", {
  res <- bfh_qic(fixture_phased(),
    x = date, y = value, chart_type = "i", part = 12L
  )
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = ANALYSIS_DATE,
      direction = "higher_better"
    )
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)
  expect_snapshot(cat(text))
})


test_that("golden: phased data + lower_better direction (unfavorable cascade)", {
  res <- bfh_qic(fixture_phased(),
    x = date, y = value, chart_type = "i", part = 12L
  )
  analysis <- bfh_analyse(res,
    metadata = list(
      analysis_date = ANALYSIS_DATE,
      direction = "lower_better"
    )
  )
  text <- bfh_render_analysis(analysis, max_chars = 800L)
  expect_snapshot(cat(text))
})


# ==========================================================================
# Caveat-paths (Slice 9, 14)
# ==========================================================================

test_that("golden: cl=specified (cl_user_supplied caveat)", {
  suppressWarnings({
    res <- bfh_qic(fixture_stable(),
      x = date, y = value, chart_type = "i", cl = 50
    )
  })
  analysis <- bfh_analyse(res, metadata = list(analysis_date = ANALYSIS_DATE))
  text <- bfh_render_analysis(analysis, max_chars = 800L)
  expect_snapshot(cat(text))
})


# ==========================================================================
# Budget-boundary sweep
# ==========================================================================

test_that("golden: max_chars=200 (kortere trim-boundary)", {
  text <- render_for_snapshot(fixture_stable(),
    target_text = ">= 40", max_chars = 200L
  )
  expect_snapshot(cat(text))
})

test_that("golden: max_chars=100 (aggressiv trim-boundary)", {
  text <- render_for_snapshot(fixture_stable(),
    target_text = ">= 40", max_chars = 100L
  )
  expect_snapshot(cat(text))
})


# ==========================================================================
# Determinism: snapshot-tests SKAL vaere reproducerbare paa tvaers af kald
# ==========================================================================

test_that("golden: deterministic -- gentaget kald giver samme text", {
  data <- fixture_stable()
  t1 <- render_for_snapshot(data, target_text = ">= 40")
  t2 <- render_for_snapshot(data, target_text = ">= 40")
  expect_identical(t1, t2)
})
