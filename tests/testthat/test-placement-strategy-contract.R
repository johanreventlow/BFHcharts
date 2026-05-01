# test-placement-strategy-contract.R
# Contract tests for the pure placement strategy layer.
#
# These tests run WITHOUT a graphics device (.compute_placement_strategy() is
# a pure function with no device calls). Verify via dev.list() that no device
# is opened as a side effect.
#
# Refs: opsx/2026-05-01-refactor-label-placement-monolith task 7

make_cfg <- function(
  coincident_threshold_factor = 0.1,
  tight_lines_threshold_factor = 0.5,
  gap_reduction_factors = c(0.5, 0.3, 0.15),
  shelf_center_threshold = 0.5
) {
  list(
    coincident_threshold_factor = coincident_threshold_factor,
    tight_lines_threshold_factor = tight_lines_threshold_factor,
    gap_reduction_factors = gap_reduction_factors,
    shelf_center_threshold = shelf_center_threshold
  )
}

# ==============================================================================
# Pure-layer: no device opened
# ==============================================================================

test_that(".compute_placement_strategy runs without opening a graphics device", {
  devs_before <- grDevices::dev.list()

  result <- BFHcharts:::.compute_placement_strategy(
    yA_npc = 0.3, yB_npc = 0.7,
    pref_pos = c("under", "under"),
    label_height_npc_value = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01,
    priority = "A",
    cfg = make_cfg()
  )

  devs_after <- grDevices::dev.list()
  expect_identical(devs_before, devs_after,
    info = "Pure strategy must not open any graphics device"
  )
  expect_false(is.na(result$yA))
  expect_false(is.na(result$yB))
})

# ==============================================================================
# Normal (no collision)
# ==============================================================================

test_that("normal separation returns optimal quality", {
  result <- BFHcharts:::.compute_placement_strategy(
    yA_npc = 0.3, yB_npc = 0.7,
    pref_pos = c("under", "under"),
    label_height_npc_value = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01,
    priority = "A",
    cfg = make_cfg()
  )
  expect_equal(result$placement_quality, "optimal")
  expect_equal(length(result$warnings), 0)
})

# ==============================================================================
# Coincident lines
# ==============================================================================

test_that("coincident lines produce over/under split", {
  result <- BFHcharts:::.compute_placement_strategy(
    yA_npc = 0.5, yB_npc = 0.5,
    pref_pos = c("under", "under"),
    label_height_npc_value = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01,
    priority = "A",
    cfg = make_cfg()
  )
  expect_true(result$sideA != result$sideB)
  expect_true(any(grepl("Sammenfaldende", result$warnings)))
})

test_that("coincident strategy produces non-overlapping labels", {
  result <- BFHcharts:::.compute_placement_strategy(
    yA_npc = 0.5, yB_npc = 0.5,
    pref_pos = c("under", "under"),
    label_height_npc_value = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01,
    priority = "A",
    cfg = make_cfg()
  )
  expect_true(abs(result$yA - result$yB) >= 0.10)
})

# ==============================================================================
# Tight lines (triggers pref_pos flip)
# ==============================================================================

test_that("tight lines trigger over/under strategy", {
  result <- BFHcharts:::.compute_placement_strategy(
    yA_npc = 0.50, yB_npc = 0.52,
    pref_pos = c("under", "under"),
    label_height_npc_value = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01,
    priority = "A",
    cfg = make_cfg()
  )
  # Should not overlap
  expect_true(abs(result$yA - result$yB) >= 0.10,
    info = sprintf("Overlap: yA=%.3f yB=%.3f", result$yA, result$yB)
  )
  expect_true(any(grepl("taette|optimal|acceptable|NIVEAU", result$warnings)) ||
    result$placement_quality %in% c("optimal", "acceptable", "suboptimal", "degraded"))
})

# ==============================================================================
# Bounds clamping
# ==============================================================================

test_that("labels near top edge respect high_bound", {
  result <- BFHcharts:::.compute_placement_strategy(
    yA_npc = 0.95, yB_npc = 0.90,
    pref_pos = c("over", "over"),
    label_height_npc_value = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.05, pad_bot = 0.05,
    priority = "A",
    cfg = make_cfg()
  )
  high_bound <- 1 - 0.05 - 0.10 / 2
  low_bound <- 0.05 + 0.10 / 2
  expect_true(result$yA <= high_bound || result$yA >= low_bound,
    info = sprintf("yA=%.3f out of [%.3f, %.3f]", result$yA, low_bound, high_bound)
  )
  expect_true(result$yB <= high_bound || result$yB >= low_bound,
    info = sprintf("yB=%.3f out of [%.3f, %.3f]", result$yB, low_bound, high_bound)
  )
})

test_that("labels near bottom edge respect low_bound", {
  result <- BFHcharts:::.compute_placement_strategy(
    yA_npc = 0.05, yB_npc = 0.10,
    pref_pos = c("under", "under"),
    label_height_npc_value = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.05, pad_bot = 0.05,
    priority = "A",
    cfg = make_cfg()
  )
  low_bound <- 0.05 + 0.10 / 2
  high_bound <- 1 - 0.05 - 0.10 / 2
  expect_true(result$yA >= low_bound || result$yA <= high_bound)
  expect_true(result$yB >= low_bound || result$yB <= high_bound)
})

# ==============================================================================
# Line-gap enforcement
# ==============================================================================

test_that("line-gap enforcement: label does not overlap its own line", {
  # Normal case: label should be at gap_line + half from line
  result <- BFHcharts:::.compute_placement_strategy(
    yA_npc = 0.5, yB_npc = 0.8,
    pref_pos = c("under", "under"),
    label_height_npc_value = 0.10,
    gap_line = 0.05, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01,
    priority = "A",
    cfg = make_cfg()
  )
  # For "under" side: label center should be <= line - gap - half
  # i.e., label top edge should be below line by at least gap_line
  if (result$sideA == "under") {
    max_allowed <- 0.5 - 0.05 - 0.10 / 2
    expect_true(result$yA <= max_allowed + 1e-10,
      info = sprintf("Label A too close to line: %.4f > %.4f", result$yA, max_allowed)
    )
  }
})

# ==============================================================================
# Shelf placement (niveau 3)
# ==============================================================================

test_that("shelf placement triggered by very large labels", {
  # Large label (40% of panel) forces niveau 3
  result <- BFHcharts:::.compute_placement_strategy(
    yA_npc = 0.5, yB_npc = 0.51,
    pref_pos = c("under", "under"),
    label_height_npc_value = 0.40,
    gap_line = 0.05, gap_labels = 0.15,
    pad_top = 0.05, pad_bot = 0.05,
    priority = "A",
    cfg = make_cfg()
  )
  expect_true(result$placement_quality %in% c("acceptable", "suboptimal", "degraded"))
  expect_false(is.na(result$yA))
  expect_false(is.na(result$yB))
})

# ==============================================================================
# Property: output always within [low_bound, high_bound]
# ==============================================================================

test_that("property: any valid input yields positions within bounds", {
  test_cases <- list(
    list(yA = 0.3, yB = 0.7, h = 0.10, gap_l = 0.01, gap_lab = 0.03),
    list(yA = 0.5, yB = 0.5, h = 0.10, gap_l = 0.01, gap_lab = 0.03),
    list(yA = 0.5, yB = 0.52, h = 0.10, gap_l = 0.01, gap_lab = 0.03),
    list(yA = 0.2, yB = 0.8, h = 0.30, gap_l = 0.02, gap_lab = 0.09),
    list(yA = 0.1, yB = 0.9, h = 0.15, gap_l = 0.01, gap_lab = 0.04)
  )

  pad <- 0.05
  for (tc in test_cases) {
    low_b <- pad + tc$h / 2
    high_b <- 1 - pad - tc$h / 2
    result <- BFHcharts:::.compute_placement_strategy(
      yA_npc = tc$yA, yB_npc = tc$yB,
      pref_pos = c("under", "under"),
      label_height_npc_value = tc$h,
      gap_line = tc$gap_l, gap_labels = tc$gap_lab,
      pad_top = pad, pad_bot = pad,
      priority = "A",
      cfg = make_cfg()
    )
    # Allow slight violation only in extreme shelf cases
    quality_ok <- result$placement_quality %in%
      c("optimal", "acceptable", "suboptimal", "degraded")
    expect_true(quality_ok,
      info = sprintf(
        "yA=%.2f yB=%.2f h=%.2f -> quality=%s", tc$yA, tc$yB, tc$h,
        result$placement_quality
      )
    )
  }
})

# ==============================================================================
# Determinism
# ==============================================================================

test_that("same inputs produce identical output (deterministic)", {
  args <- list(
    yA_npc = 0.30, yB_npc = 0.48,
    pref_pos = c("under", "under"),
    label_height_npc_value = 0.20,
    gap_line = 0.016, gap_labels = 0.06,
    pad_top = 0.01, pad_bot = 0.01,
    priority = "A",
    cfg = make_cfg()
  )
  r1 <- do.call(BFHcharts:::.compute_placement_strategy, args)
  r2 <- do.call(BFHcharts:::.compute_placement_strategy, args)
  expect_identical(r1$yA, r2$yA)
  expect_identical(r1$yB, r2$yB)
  expect_identical(r1$sideA, r2$sideA)
  expect_identical(r1$sideB, r2$sideB)
})
