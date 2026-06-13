# test-label-placement.R
# Unit tests for .compute_pref_pos()
# Refs: #427

# Use identity as y_to_npc so NPC == y, making branches deterministic.
identity_npc <- function(y) y

# ==============================================================================
# .compute_pref_pos: NA inputs
# ==============================================================================

test_that(".compute_pref_pos returns defaults when yA is NA", {
  result <- .compute_pref_pos(NA_real_, 0.5, identity_npc)
  expect_equal(result, c("under", "under"))
})

test_that(".compute_pref_pos returns defaults when yB is NA", {
  result <- .compute_pref_pos(0.5, NA_real_, identity_npc)
  expect_equal(result, c("under", "under"))
})

test_that(".compute_pref_pos returns defaults when both are NA", {
  result <- .compute_pref_pos(NA_real_, NA_real_, identity_npc)
  expect_equal(result, c("under", "under"))
})

# ==============================================================================
# .compute_pref_pos: both lines mid-range (no boundary trigger)
# ==============================================================================

test_that(".compute_pref_pos defaults to under/under when both mid-range", {
  result <- .compute_pref_pos(0.5, 0.55, identity_npc)
  expect_equal(result, c("under", "under"))
})

# ==============================================================================
# .compute_pref_pos: both lines near bottom
# ==============================================================================

test_that(".compute_pref_pos spreads labels when both near bottom, A below B", {
  # npc_A=0.1 <= npc_B=0.2 -> pref_A="under", pref_B="over"
  result <- .compute_pref_pos(0.1, 0.2, identity_npc)
  expect_equal(result, c("under", "over"))
})

test_that(".compute_pref_pos spreads labels when both near bottom, A above B", {
  # npc_A=0.2 > npc_B=0.1 -> pref_A="over", pref_B="under"
  result <- .compute_pref_pos(0.2, 0.1, identity_npc)
  expect_equal(result, c("over", "under"))
})

# ==============================================================================
# .compute_pref_pos: both lines near top
# ==============================================================================

test_that(".compute_pref_pos spreads labels when both near top, A above B", {
  # npc_A=0.9 >= npc_B=0.8 -> pref_A="over", pref_B="under"
  result <- .compute_pref_pos(0.9, 0.8, identity_npc)
  expect_equal(result, c("over", "under"))
})

test_that(".compute_pref_pos spreads labels when both near top, A below B", {
  # npc_A=0.8 < npc_B=0.9 -> pref_A="under", pref_B="over"
  result <- .compute_pref_pos(0.8, 0.9, identity_npc)
  expect_equal(result, c("under", "over"))
})

# ==============================================================================
# .compute_pref_pos: one line near bottom, one mid-range
# ==============================================================================

test_that(".compute_pref_pos: A near bottom, B mid-range -> A under, B over", {
  # npc_A=0.1 < 0.30 triggers: pref_A="under", pref_B="over"
  result <- .compute_pref_pos(0.1, 0.5, identity_npc)
  expect_equal(result, c("under", "over"))
})

test_that(".compute_pref_pos: B near bottom, A mid-range -> B under, A over", {
  # npc_B=0.1 < 0.30 triggers: pref_B="under", pref_A="over"
  result <- .compute_pref_pos(0.5, 0.1, identity_npc)
  expect_equal(result, c("over", "under"))
})

# ==============================================================================
# .compute_pref_pos: one line near top, one mid-range
# ==============================================================================

test_that(".compute_pref_pos: A near top, B mid-range -> A over, B under", {
  # npc_A=0.9 > 0.70 triggers: pref_A="over", pref_B="under"
  result <- .compute_pref_pos(0.9, 0.5, identity_npc)
  expect_equal(result, c("over", "under"))
})

test_that(".compute_pref_pos: B near top, A mid-range -> B over, A under", {
  # npc_B=0.9 > 0.70 triggers: pref_B="over", pref_A="under"
  result <- .compute_pref_pos(0.5, 0.9, identity_npc)
  expect_equal(result, c("under", "over"))
})

# ==============================================================================
# .compute_pref_pos: custom boundary_threshold
# ==============================================================================

test_that(".compute_pref_pos respects custom boundary_threshold", {
  # With threshold=0.60: npc_A=0.5 < 0.60 -> treated as near bottom
  # B at 0.55 also < 0.60 -> both_near_bottom, A<=B -> pref_A="under", pref_B="over"
  result <- .compute_pref_pos(0.5, 0.55, identity_npc, boundary_threshold = 0.60)
  expect_equal(result, c("under", "over"))
})

# ==============================================================================
# .compute_pref_pos: non-identity mapping (scale test)
# ==============================================================================

test_that(".compute_pref_pos works with a non-identity NPC mapper", {
  # Mapper that scales [0, 100] data to [0, 1] NPC
  npc_100 <- function(y) y / 100
  # yA=5, yB=15 -> npc_A=0.05, npc_B=0.15, both < 0.30, A<=B
  result <- .compute_pref_pos(5, 15, npc_100)
  expect_equal(result, c("under", "over"))
})
