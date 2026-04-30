# ============================================================================
# Per-niveau collision-resolver tests
# ============================================================================
# Verifies the three NIVEAU resolvers extracted from `place_two_labels_npc()`
# in R/utils_label_placement.R per openspec change
# "refactor-utils-label-placement". Each resolver is a pure function operating
# on a subset of placement state; these tests pin their contracts so future
# tweaks cannot regress silently.

# ----------------------------------------------------------------------------
# .verify_line_gap_npc()
# ----------------------------------------------------------------------------

test_that(".verify_line_gap_npc detects under-side violation", {
  # Label at y_center = 0.50, line at 0.55, side "under". Required max =
  # 0.55 - gap_line - half_height. With gap_line = 0.02 and label_h = 0.10:
  #   half = 0.05, required_max = 0.55 - 0.02 - 0.05 = 0.48.
  # 0.50 > 0.48 -> violated.
  res <- BFHcharts:::.verify_line_gap_npc(
    y_center = 0.50, y_line = 0.55, side = "under",
    label_h = 0.10, gap_line = 0.02
  )
  expect_true(res$violated)
  expect_equal(res$y, 0.48, tolerance = 1e-9)
})

test_that(".verify_line_gap_npc passes compliant under-side label", {
  res <- BFHcharts:::.verify_line_gap_npc(
    y_center = 0.30, y_line = 0.55, side = "under",
    label_h = 0.10, gap_line = 0.02
  )
  expect_false(res$violated)
  expect_equal(res$y, 0.30)
})

test_that(".verify_line_gap_npc detects over-side violation", {
  # Label at 0.50, line at 0.45, side "over". Required min = 0.45 + 0.02 +
  # 0.05 = 0.52. 0.50 < 0.52 -> violated.
  res <- BFHcharts:::.verify_line_gap_npc(
    y_center = 0.50, y_line = 0.45, side = "over",
    label_h = 0.10, gap_line = 0.02
  )
  expect_true(res$violated)
  expect_equal(res$y, 0.52, tolerance = 1e-9)
})

# ----------------------------------------------------------------------------
# .try_niveau_1_gap_reduction()
# ----------------------------------------------------------------------------

test_that(".try_niveau_1_gap_reduction succeeds with first applicable factor", {
  # Distance 0.13 between proposed positions, label_h = 0.10, gap_labels = 0.06.
  # min_gap at factor=0.5 = 0.10 + 0.06 * 0.5 = 0.13 -> succeeds at first factor.
  res <- BFHcharts:::.try_niveau_1_gap_reduction(
    proposed_yA = 0.30, proposed_yB = 0.43,
    label_height_npc_value = 0.10, gap_labels = 0.06,
    low_bound = 0.05, high_bound = 0.95,
    reduction_factors = c(0.5, 0.3, 0.15)
  )
  expect_true(res$success)
  expect_equal(res$placement_quality, "acceptable")
  expect_match(res$warning, "NIVEAU 1: Reduceret label gap til 50%")
  expect_equal(res$yA, 0.30)
  expect_equal(res$yB, 0.43)
})

test_that(".try_niveau_1_gap_reduction tries smaller factors when needed", {
  # Distance 0.108: factor 0.5 needs 0.13 (fail), factor 0.3 needs 0.118 (fail),
  # factor 0.15 needs 0.109 (fail since 0.108 < 0.109) -> fall through.
  # Adjust to test fallthrough: distance 0.105, factors 0.5/0.3/0.15:
  #   0.5 -> 0.13 (fail), 0.3 -> 0.118 (fail), 0.15 -> 0.109 (fail).
  res <- BFHcharts:::.try_niveau_1_gap_reduction(
    proposed_yA = 0.30, proposed_yB = 0.405,
    label_height_npc_value = 0.10, gap_labels = 0.06,
    low_bound = 0.05, high_bound = 0.95,
    reduction_factors = c(0.5, 0.3, 0.15)
  )
  expect_false(res$success)
})

test_that(".try_niveau_1_gap_reduction clamps to bounds", {
  # Position 0.99 -> clamped to high_bound = 0.95.
  res <- BFHcharts:::.try_niveau_1_gap_reduction(
    proposed_yA = 0.20, proposed_yB = 0.99,
    label_height_npc_value = 0.10, gap_labels = 0.06,
    low_bound = 0.05, high_bound = 0.95,
    reduction_factors = c(0.5, 0.3, 0.15)
  )
  expect_true(res$success)
  expect_equal(res$yB, 0.95)
})

# ----------------------------------------------------------------------------
# .try_niveau_2_flip()
# ----------------------------------------------------------------------------

test_that(".try_niveau_2_flip flips A when 2a strategy succeeds", {
  # Construct: A under at line 0.30, B under at line 0.50. Flipping A to
  # "over" places A at 0.30 + gap + half_h (above its line). Distance to B
  # (around 0.45) should exceed label_height (0.10).
  res <- BFHcharts:::.try_niveau_2_flip(
    proposed_yA = 0.40, proposed_yB = 0.45,
    yA_npc = 0.30, yB_npc = 0.50,
    sideA = "under", sideB = "under",
    label_height_npc_value = 0.10,
    gap_line = 0.02, pad_top = 0.01, pad_bot = 0.01,
    low_bound = 0.06, high_bound = 0.94
  )
  expect_true(res$success)
  expect_match(res$warning, "NIVEAU 2[abc]:")
  expect_true(res$placement_quality %in% c("acceptable", "suboptimal"))
})

test_that(".try_niveau_2_flip returns FALSE when no flip resolves", {
  # Lines overlap heavily -> no flip strategy gives sufficient separation.
  res <- BFHcharts:::.try_niveau_2_flip(
    proposed_yA = 0.50, proposed_yB = 0.50,
    yA_npc = 0.50, yB_npc = 0.50,
    sideA = "under", sideB = "under",
    label_height_npc_value = 0.30, # very tall labels
    gap_line = 0.02, pad_top = 0.01, pad_bot = 0.01,
    low_bound = 0.16, high_bound = 0.84
  )
  expect_false(res$success)
})

test_that(".try_niveau_2_flip returns side info on success", {
  res <- BFHcharts:::.try_niveau_2_flip(
    proposed_yA = 0.40, proposed_yB = 0.45,
    yA_npc = 0.30, yB_npc = 0.50,
    sideA = "under", sideB = "under",
    label_height_npc_value = 0.10,
    gap_line = 0.02, pad_top = 0.01, pad_bot = 0.01,
    low_bound = 0.06, high_bound = 0.94
  )
  expect_true(res$success)
  expect_true(res$sideA %in% c("under", "over"))
  expect_true(res$sideB %in% c("under", "over"))
})

# ----------------------------------------------------------------------------
# .apply_niveau_3_shelf()
# ----------------------------------------------------------------------------

test_that(".apply_niveau_3_shelf pins priority A and shelves B", {
  res <- BFHcharts:::.apply_niveau_3_shelf(
    proposed_yA = 0.30, proposed_yB = 0.50,
    low_bound = 0.05, high_bound = 0.95,
    priority = "A", shelf_threshold = 0.5
  )
  expect_equal(res$yA, 0.30) # priority A near proposed (already in bounds)
  expect_equal(res$yB, 0.95) # yA < threshold -> B to high_bound
  expect_equal(res$placement_quality, "degraded")
})

test_that(".apply_niveau_3_shelf flips shelf when priority above threshold", {
  res <- BFHcharts:::.apply_niveau_3_shelf(
    proposed_yA = 0.80, proposed_yB = 0.20,
    low_bound = 0.05, high_bound = 0.95,
    priority = "A", shelf_threshold = 0.5
  )
  expect_equal(res$yA, 0.80)
  expect_equal(res$yB, 0.05) # yA >= threshold -> B to low_bound
})

test_that(".apply_niveau_3_shelf honours priority B", {
  res <- BFHcharts:::.apply_niveau_3_shelf(
    proposed_yA = 0.50, proposed_yB = 0.20,
    low_bound = 0.05, high_bound = 0.95,
    priority = "B", shelf_threshold = 0.5
  )
  expect_equal(res$yB, 0.20) # priority B near proposed
  expect_equal(res$yA, 0.95) # yB < threshold -> A to high_bound
})

test_that(".apply_niveau_3_shelf clamps priority to bounds", {
  res <- BFHcharts:::.apply_niveau_3_shelf(
    proposed_yA = 1.5, proposed_yB = 0.20,
    low_bound = 0.05, high_bound = 0.95,
    priority = "A", shelf_threshold = 0.5
  )
  expect_equal(res$yA, 0.95) # clamped
  expect_equal(res$yB, 0.05) # 0.95 >= threshold -> low_bound
})
