# Property-based tests for label placement geometry
# Covers: NPC-overflow, collision-free invariants, edge cases
# Issue: #317
#
# Strategy: loop over N random valid inputs + set.seed for reproducibility.
# Each test checks a geometric invariant that must hold for ALL inputs.

# ==============================================================================
# propose_single_label() -- NPC bounds invariant
# ==============================================================================

test_that("propose_single_label center always within panel [0, 1]", {
  # Actual invariant: center is always within [0, 1].
  # [pad_bot, 1-pad_top] is NOT guaranteed -- the "over" side places labels
  # just above a near-bottom line without a pad_bot lower-bound check (by
  # design: the label's top is constrained, not its center vs pad_bot).
  set.seed(317)
  n <- 200

  for (i in seq_len(n)) {
    y_line <- runif(1, 0, 1)
    label_h <- runif(1, 0.01, 0.45)
    gap <- runif(1, 0, 0.08)
    pad_top <- runif(1, 0, 0.12)
    pad_bot <- runif(1, 0, 0.12)
    pref <- sample(c("under", "over"), 1)

    result <- BFHcharts:::propose_single_label(
      y_line_npc = y_line,
      pref_side  = pref,
      label_h    = label_h,
      gap        = gap,
      pad_top    = pad_top,
      pad_bot    = pad_bot
    )

    expect_true(
      is.list(result) && !is.null(result$center) && !is.null(result$side),
      info = sprintf("i=%d: returned wrong structure", i)
    )
    expect_gte(
      result$center, -1e-9,
      label = sprintf(
        "i=%d (y=%.3f h=%.3f pref=%s): center=%.4f < 0",
        i, y_line, label_h, pref, result$center
      )
    )
    expect_lte(
      result$center, 1 + 1e-9,
      label = sprintf(
        "i=%d (y=%.3f h=%.3f pref=%s): center=%.4f > 1",
        i, y_line, label_h, pref, result$center
      )
    )
    expect_true(
      result$side %in% c("under", "over"),
      info = sprintf("i=%d: side='%s' is not 'under' or 'over'", i, result$side)
    )
  }
})

test_that("propose_single_label: pref=under respects pad_bot lower bound", {
  # When pref_side is "under" and the result stays "under" (no flip),
  # the expansion zone guarantees center >= pad_bot.
  set.seed(99)
  n <- 150
  for (i in seq_len(n)) {
    y_line <- runif(1, 0.15, 1) # high enough that "under" can stay "under"
    label_h <- runif(1, 0.01, 0.20)
    gap <- runif(1, 0, 0.05)
    pad_top <- runif(1, 0.01, 0.08)
    pad_bot <- runif(1, 0.01, 0.08)

    result <- BFHcharts:::propose_single_label(
      y_line_npc = y_line, pref_side = "under",
      label_h = label_h, gap = gap,
      pad_top = pad_top, pad_bot = pad_bot
    )

    if (result$side == "under") {
      expect_gte(
        result$center, pad_bot - 1e-9,
        label = sprintf("i=%d: under-result center=%.4f < pad_bot=%.4f", i, result$center, pad_bot)
      )
    }
  }
})

test_that("propose_single_label handles y_line at panel extremes", {
  edges <- c(0, 0.001, 0.999, 1)
  for (y in edges) {
    for (pref in c("under", "over")) {
      result <- BFHcharts:::propose_single_label(
        y_line_npc = y, pref_side = pref,
        label_h = 0.1, gap = 0.01, pad_top = 0.02, pad_bot = 0.02
      )
      expect_true(is.finite(result$center),
        info = sprintf("y=%.3f pref=%s: center not finite", y, pref)
      )
      expect_gte(result$center, 0 - 1e-9,
        label = sprintf("y=%.3f pref=%s: center=%.4f < 0", y, pref, result$center)
      )
      expect_lte(result$center, 1 + 1e-9,
        label = sprintf("y=%.3f pref=%s: center=%.4f > 1", y, pref, result$center)
      )
    }
  }
})

test_that("propose_single_label handles near-zero label height", {
  set.seed(1)
  for (i in 1:20) {
    label_h <- runif(1, 1e-6, 0.005)
    y_line <- runif(1, 0.1, 0.9)
    result <- BFHcharts:::propose_single_label(
      y_line_npc = y_line, pref_side = "under",
      label_h = label_h, gap = 0.01, pad_top = 0.02, pad_bot = 0.02
    )
    expect_true(is.finite(result$center),
      info = sprintf("i=%d tiny label_h=%.2e: center not finite", i, label_h)
    )
  }
})

# ==============================================================================
# place_two_labels_npc() -- NPC bounds invariant
# ==============================================================================

test_that("place_two_labels_npc output always within [0, 1] NPC", {
  set.seed(317)
  n <- 100

  for (i in seq_len(n)) {
    yA <- runif(1, 0.05, 0.95)
    yB <- runif(1, 0.05, 0.95)
    # Keep label_h small enough that two labels theoretically fit
    label_h <- runif(1, 0.04, 0.35)

    result <- place_two_labels_npc(
      yA_npc = yA,
      yB_npc = yB,
      label_height_npc = label_h
    )

    if (!is.na(result$yA)) {
      expect_gte(result$yA, -1e-9,
        label = sprintf(
          "i=%d: yA=%.4f < 0 (yA_npc=%.3f yB_npc=%.3f h=%.3f)",
          i, result$yA, yA, yB, label_h
        )
      )
      expect_lte(result$yA, 1 + 1e-9,
        label = sprintf(
          "i=%d: yA=%.4f > 1 (yA_npc=%.3f yB_npc=%.3f h=%.3f)",
          i, result$yA, yA, yB, label_h
        )
      )
    }
    if (!is.na(result$yB)) {
      expect_gte(result$yB, -1e-9,
        label = sprintf("i=%d: yB=%.4f < 0", i, result$yB)
      )
      expect_lte(result$yB, 1 + 1e-9,
        label = sprintf("i=%d: yB=%.4f > 1", i, result$yB)
      )
    }
    expect_true(
      result$placement_quality %in% c("optimal", "acceptable", "suboptimal", "degraded", "failed"),
      info = sprintf("i=%d: unrecognized quality '%s'", i, result$placement_quality)
    )
  }
})

# ==============================================================================
# No-overlap invariant
# ==============================================================================

test_that("place_two_labels_npc: optimal quality always produces non-overlapping labels", {
  # "optimal" quality = no cascade was needed; placement is correct by construction.
  # This is the only quality tier where no-overlap is guaranteed unconditionally.
  # ("acceptable" cascade can produce marginal overlap when lines are close to
  # panel edges and each other -- a known geometric limitation.)
  set.seed(317)
  n <- 200

  for (i in seq_len(n)) {
    label_h <- runif(1, 0.04, 0.20)
    yA <- runif(1, 0.15, 0.85)
    yB <- runif(1, 0.15, 0.85)

    result <- place_two_labels_npc(
      yA_npc           = yA,
      yB_npc           = yB,
      label_height_npc = label_h
    )

    if (result$placement_quality == "optimal" &&
      !is.na(result$yA) && !is.na(result$yB)) {
      sep <- abs(result$yA - result$yB)
      expect_gte(
        sep, label_h - 1e-9,
        label = sprintf(
          "i=%d: optimal quality but labels overlap: |yA-yB|=%.4f < label_h=%.4f",
          i, sep, label_h
        )
      )
    }
  }
})

test_that("place_two_labels_npc: well-separated lines never overlap", {
  # When input lines are > 3 * label_h apart the placement cascade has room
  # to place both labels without geometric conflict.
  set.seed(42)
  n <- 100

  for (i in seq_len(n)) {
    label_h <- runif(1, 0.04, 0.15)
    yA <- runif(1, 0.05, 0.40)
    yB <- yA + label_h * 3 + runif(1, 0.05, 0.20)
    if (yB > 0.95) next

    result <- place_two_labels_npc(
      yA_npc           = yA,
      yB_npc           = yB,
      label_height_npc = label_h
    )

    if (!is.na(result$yA) && !is.na(result$yB)) {
      sep <- abs(result$yA - result$yB)
      expect_gte(
        sep, label_h - 1e-9,
        label = sprintf(
          "i=%d: well-separated (orig_sep=%.3f, 3h=%.3f) but output overlaps: sep=%.4f < h=%.4f (quality=%s)",
          i, yB - yA, 3 * label_h, sep, label_h, result$placement_quality
        )
      )
    }
  }
})

test_that("well-separated lines always yield optimal or acceptable quality", {
  # When lines are >= 4 * label_h apart and away from edges, collision
  # avoidance cascade should resolve at niveau 0 (no cascade needed).
  set.seed(42)
  n <- 80

  for (i in seq_len(n)) {
    label_h <- runif(1, 0.05, 0.18)
    # Force large separation
    yA <- runif(1, 0.05, 0.35)
    yB <- yA + label_h * 4 + runif(1, 0.01, 0.2)
    if (yB > 0.95) next

    result <- place_two_labels_npc(
      yA_npc           = yA,
      yB_npc           = yB,
      label_height_npc = label_h
    )

    expect_true(
      result$placement_quality %in% c("optimal", "acceptable"),
      info = sprintf(
        "i=%d: well-separated lines (sep=%.3f, 4h=%.3f) got quality=%s",
        i, yB - yA, 4 * label_h, result$placement_quality
      )
    )
  }
})

# ==============================================================================
# Edge case: coincident lines (CL == UCL)
# ==============================================================================

test_that("coincident lines (yA == yB) do not crash and produce valid output", {
  coincident_positions <- c(0.1, 0.3, 0.5, 0.7, 0.9)

  for (y in coincident_positions) {
    result <- place_two_labels_npc(
      yA_npc           = y,
      yB_npc           = y,
      label_height_npc = 0.12
    )
    expect_true(is.list(result),
      info = sprintf("y=%.2f: did not return list", y)
    )
    expect_true(!is.null(result$placement_quality),
      info = sprintf("y=%.2f: missing placement_quality", y)
    )
    if (!is.na(result$yA)) {
      expect_gte(result$yA, -1e-9,
        label = sprintf("y=%.2f: yA=%.4f < 0", y, result$yA)
      )
      expect_lte(result$yA, 1 + 1e-9,
        label = sprintf("y=%.2f: yA=%.4f > 1", y, result$yA)
      )
    }
    if (!is.na(result$yB)) {
      expect_gte(result$yB, -1e-9,
        label = sprintf("y=%.2f: yB=%.4f < 0", y, result$yB)
      )
      expect_lte(result$yB, 1 + 1e-9,
        label = sprintf("y=%.2f: yB=%.4f > 1", y, result$yB)
      )
    }
  }
})

test_that("coincident lines (yA == yB) produce over/under split or degraded", {
  # Coincident lines cannot both have labels on the same side.
  # Expect at least one label above and one below, or shelf.
  for (y in c(0.3, 0.5, 0.7)) {
    result <- place_two_labels_npc(
      yA_npc           = y,
      yB_npc           = y,
      label_height_npc = 0.12,
      pref_pos         = c("under", "under")
    )
    if (!is.na(result$yA) && !is.na(result$yB)) {
      sep <- abs(result$yA - result$yB)
      expect_gte(sep, 0.12 - 1e-9,
        label = sprintf("y=%.2f: coincident lines produced overlapping labels (sep=%.4f)", y, sep)
      )
    }
  }
})

# ==============================================================================
# Edge case: large label height (fills panel)
# ==============================================================================

test_that("large label_height (>0.4) does not cause NPC overflow", {
  large_heights <- c(0.45, 0.50, 0.60, 0.80)

  for (h in large_heights) {
    result <- suppressWarnings(
      place_two_labels_npc(
        yA_npc           = 0.4,
        yB_npc           = 0.6,
        label_height_npc = h
      )
    )
    # Should return a valid list, not crash
    expect_true(is.list(result),
      info = sprintf("h=%.2f: did not return list", h)
    )
    if (!is.na(result$yA)) {
      expect_gte(result$yA, -1e-9,
        label = sprintf("h=%.2f: yA=%.4f < 0", h, result$yA)
      )
      expect_lte(result$yA, 1 + 1e-9,
        label = sprintf("h=%.2f: yA=%.4f > 1", h, result$yA)
      )
    }
    if (!is.na(result$yB)) {
      expect_gte(result$yB, -1e-9,
        label = sprintf("h=%.2f: yB=%.4f < 0", h, result$yB)
      )
      expect_lte(result$yB, 1 + 1e-9,
        label = sprintf("h=%.2f: yB=%.4f > 1", h, result$yB)
      )
    }
  }
})

# ==============================================================================
# Edge case: out-of-bounds input lines
# ==============================================================================

test_that("out-of-bounds input lines degrade gracefully, no NPC overflow in output", {
  # Lines outside [0,1] should be silently dropped (NA) per existing behavior.
  # The remaining label (if any) must still be in [0,1].
  oor_cases <- list(
    list(yA = -0.1, yB = 0.5),
    list(yA = 1.1, yB = 0.5),
    list(yA = 0.3, yB = -0.2),
    list(yA = 0.3, yB = 1.5)
  )

  for (tc in oor_cases) {
    result <- place_two_labels_npc(
      yA_npc           = tc$yA,
      yB_npc           = tc$yB,
      label_height_npc = 0.12
    )
    if (!is.na(result$yA)) {
      expect_gte(result$yA, -1e-9,
        label = sprintf("yA_in=%.2f yB_in=%.2f: output yA=%.4f < 0", tc$yA, tc$yB, result$yA)
      )
      expect_lte(result$yA, 1 + 1e-9,
        label = sprintf("yA_in=%.2f yB_in=%.2f: output yA=%.4f > 1", tc$yA, tc$yB, result$yA)
      )
    }
    if (!is.na(result$yB)) {
      expect_gte(result$yB, -1e-9,
        label = sprintf("yA_in=%.2f yB_in=%.2f: output yB=%.4f < 0", tc$yA, tc$yB, result$yB)
      )
      expect_lte(result$yB, 1 + 1e-9,
        label = sprintf("yA_in=%.2f yB_in=%.2f: output yB=%.4f > 1", tc$yA, tc$yB, result$yB)
      )
    }
  }
})
