# test-utils_label_placement.R
# Tests for label placement kernefunktioner
# Refs: #89, #91, #92, #93, #94

# ==============================================================================
# clamp_to_bounds
# ==============================================================================

test_that("clamp_to_bounds clamps til custom interval", {
  expect_equal(clamp_to_bounds(0.5, 0.1, 0.9), 0.5)
  expect_equal(clamp_to_bounds(0.05, 0.1, 0.9), 0.1)
  expect_equal(clamp_to_bounds(0.95, 0.1, 0.9), 0.9)
})

test_that("clamp_to_bounds håndterer flipped og lige bounds", {
  # Flipped bounds — clamper stadig korrekt
  expect_equal(clamp_to_bounds(0.5, 0.9, 0.1), 0.5)
  # Lige bounds — returnerer værdien
  expect_equal(clamp_to_bounds(0.5, 0.5, 0.5), 0.5)
})

test_that("clamp_to_bounds afviser ikke-numerisk", {
  expect_error(clamp_to_bounds("a", 0, 1), "numeric")
  expect_error(clamp_to_bounds(0.5, "a", 1), "numeric")
})

# ==============================================================================
# propose_single_label
# ==============================================================================

test_that("propose_single_label placerer under når foretrukket og muligt", {
  result <- propose_single_label(
    y_line_npc = 0.5, pref_side = "under",
    label_h = 0.1, gap = 0.02, pad_top = 0.01, pad_bot = 0.01
  )
  expect_equal(result$side, "under")
  # Center skal være under linjen: y_line - gap - half = 0.5 - 0.02 - 0.05 = 0.43
  expect_equal(result$center, 0.43)
})

test_that("propose_single_label placerer over når foretrukket og muligt", {
  result <- propose_single_label(
    y_line_npc = 0.5, pref_side = "over",
    label_h = 0.1, gap = 0.02, pad_top = 0.01, pad_bot = 0.01
  )
  expect_equal(result$side, "over")
  # Center: y_line + gap + half = 0.5 + 0.02 + 0.05 = 0.57
  expect_equal(result$center, 0.57)
})

test_that("propose_single_label flipper når foretrukken side er out-of-bounds", {
  # Linje nær bund, foretrukken under → flip til over

  result <- propose_single_label(
    y_line_npc = 0.05, pref_side = "under",
    label_h = 0.1, gap = 0.02, pad_top = 0.01, pad_bot = 0.01
  )
  expect_equal(result$side, "over")

  # Linje nær top, foretrukken over → flip til under
  result <- propose_single_label(
    y_line_npc = 0.95, pref_side = "over",
    label_h = 0.1, gap = 0.02, pad_top = 0.01, pad_bot = 0.01
  )
  expect_equal(result$side, "under")
})

test_that("propose_single_label respekterer padding ved flip", {
  # Linje helt i bund, flip til over
  result <- propose_single_label(
    y_line_npc = 0.01, pref_side = "under",
    label_h = 0.1, gap = 0.02, pad_top = 0.05, pad_bot = 0.05
  )
  expect_equal(result$side, "over")
  # Clamped: max = 1 - pad_top - half = 1 - 0.05 - 0.05 = 0.90
  expect_true(result$center <= 0.90)
  # Min = pad_bot + half = 0.05 + 0.05 = 0.10
  expect_true(result$center >= 0.10)
})

# ==============================================================================
# place_two_labels_npc - Optimal placement
# ==============================================================================

test_that("optimal placement når labels er langt fra hinanden", {
  result <- place_two_labels_npc(
    yA_npc = 0.3, yB_npc = 0.7,
    label_height_npc = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01
  )
  expect_equal(result$placement_quality, "optimal")
  expect_equal(length(result$warnings), 0)
  expect_false(is.na(result$yA))
  expect_false(is.na(result$yB))
})

test_that("optimal placement returnerer positions inden for bounds", {
  result <- place_two_labels_npc(
    yA_npc = 0.3, yB_npc = 0.7,
    label_height_npc = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.05, pad_bot = 0.05
  )
  half <- 0.10 / 2
  low_bound <- 0.05 + half
  high_bound <- 1 - 0.05 - half

  expect_true(result$yA >= low_bound)
  expect_true(result$yA <= high_bound)
  expect_true(result$yB >= low_bound)
  expect_true(result$yB <= high_bound)
})

# ==============================================================================
# place_two_labels_npc - Coincident lines (CL = Target)
# ==============================================================================

test_that("coincident lines placerer labels over/under", {
  result <- place_two_labels_npc(
    yA_npc = 0.5, yB_npc = 0.5,
    label_height_npc = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01
  )
  # Skal have forskellige sider
  expect_true(result$sideA != result$sideB)
  # Labels skal ikke overlappe
  expect_true(abs(result$yA - result$yB) >= 0.10)
})

test_that("coincident lines nær kant respekterer padding (#91)", {
  # BUG-TEST: Denne test dokumenterer bug #91
  # Med pad=0.1 og coincident lines nær top, skal labels IKKE gå til 1.0
  result <- place_two_labels_npc(
    yA_npc = 0.85, yB_npc = 0.85,
    label_height_npc = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.10, pad_bot = 0.10
  )
  half <- 0.10 / 2
  high_bound <- 1 - 0.10 - half # 0.85
  low_bound <- 0.10 + half # 0.15

  # Labels skal respektere padding
  expect_true(result$yA <= high_bound,
    info = sprintf("yA=%.3f bør være <= high_bound=%.3f", result$yA, high_bound)
  )
  expect_true(result$yB <= high_bound,
    info = sprintf("yB=%.3f bør være <= high_bound=%.3f", result$yB, high_bound)
  )
  expect_true(result$yA >= low_bound,
    info = sprintf("yA=%.3f bør være >= low_bound=%.3f", result$yA, low_bound)
  )
  expect_true(result$yB >= low_bound,
    info = sprintf("yB=%.3f bør være >= low_bound=%.3f", result$yB, low_bound)
  )
})

# ==============================================================================
# place_two_labels_npc - Tight lines (collision avoidance)
# ==============================================================================

test_that("tight lines trigges multi-level collision avoidance", {
  # Labels tæt men med plads til at løse det
  result <- place_two_labels_npc(
    yA_npc = 0.50, yB_npc = 0.52,
    label_height_npc = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01
  )
  # Skal stadig returnere et resultat
  expect_false(is.na(result$yA))
  expect_false(is.na(result$yB))
  # Labels skal ikke overlappe (min center gap = label_height)
  expect_true(abs(result$yA - result$yB) >= 0.10,
    info = sprintf("Labels overlapper: yA=%.3f, yB=%.3f", result$yA, result$yB)
  )
})

test_that("shelf placement (niveau 3) returnerer degraded quality", {
  # Ekstremt tætte linjer med store labels og store paddings
  # Der er ikke plads til begge labels inden for bounds
  result <- place_two_labels_npc(
    yA_npc = 0.5, yB_npc = 0.51,
    label_height_npc = 0.45,
    gap_line = 0.05, gap_labels = 0.15,
    pad_top = 0.05, pad_bot = 0.05
  )
  # Skal ikke crashe, men quality er degraderet
  expect_false(is.na(result$yA))
  expect_false(is.na(result$yB))
  expect_true(result$placement_quality %in% c("acceptable", "suboptimal", "degraded"))
})

# ==============================================================================
# place_two_labels_npc - Edge cases
# ==============================================================================

test_that("én label NA returnerer kun den anden", {
  # Kun A
  result <- place_two_labels_npc(
    yA_npc = 0.5, yB_npc = NA_real_,
    label_height_npc = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01
  )
  expect_false(is.na(result$yA))
  expect_true(is.na(result$yB))

  # Kun B
  result <- place_two_labels_npc(
    yA_npc = NA_real_, yB_npc = 0.5,
    label_height_npc = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01
  )
  expect_true(is.na(result$yA))
  expect_false(is.na(result$yB))
})

test_that("begge labels NA returnerer failed", {
  result <- place_two_labels_npc(
    yA_npc = NA_real_, yB_npc = NA_real_,
    label_height_npc = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01
  )
  expect_true(is.na(result$yA))
  expect_true(is.na(result$yB))
  expect_equal(result$placement_quality, "failed")
})

test_that("out-of-bounds linjer håndteres gracefully", {
  result <- place_two_labels_npc(
    yA_npc = -0.5, yB_npc = 1.5,
    label_height_npc = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01
  )
  # Begge er out-of-bounds → behandles som NA
  expect_true(is.na(result$yA))
  expect_true(is.na(result$yB))
})

test_that("deterministisk: samme input giver altid samme output", {
  args <- list(
    yA_npc = 0.4, yB_npc = 0.6,
    label_height_npc = 0.10,
    gap_line = 0.01, gap_labels = 0.03,
    pad_top = 0.01, pad_bot = 0.01
  )
  result1 <- do.call(place_two_labels_npc, args)
  result2 <- do.call(place_two_labels_npc, args)
  expect_identical(result1$yA, result2$yA)
  expect_identical(result1$yB, result2$yB)
  expect_identical(result1$sideA, result2$sideA)
  expect_identical(result1$sideB, result2$sideB)
})

# ==============================================================================
# place_two_labels_npc - label_height_npc > 0.5 (#92)
# ==============================================================================

test_that("label_height_npc > 0.5 emitterer warning, ikke hard stop (#92)", {
  # BUG #92 fix-kontrakt: store labels (>50% af panel) skal degraderes
  # gracefully via warning() — ikke stop(). Bekraefter at koden ved
  # R/utils_label_placement.R:376-384 emitterer warning og returnerer
  # et gyldigt resultat (best-effort placement).
  #
  # CI-NOTE: tidligere skip_on_ci() pga. options(warn = 2) konverterede
  # warning til error og brød expect_no_error(). Fix: assertér warning'en
  # direkte i stedet — platform-uafhaengigt.
  result <- NULL
  expect_warning(
    result <- place_two_labels_npc(
      yA_npc = 0.5, yB_npc = NA_real_,
      label_height_npc = 0.6,
      gap_line = 0.01, gap_labels = 0.03,
      pad_top = 0.01, pad_bot = 0.01
    ),
    regexp = "degraded placement"
  )
  expect_false(is.null(result))
})

# ==============================================================================
# place_two_labels_npc - Padding respekt i alle fallback-grene (#91)
# ==============================================================================

test_that("NIVEAU 1 (gap reduction) respekterer padding", {
  result <- place_two_labels_npc(
    yA_npc = 0.80, yB_npc = 0.85,
    label_height_npc = 0.12,
    gap_line = 0.02, gap_labels = 0.04,
    pad_top = 0.10, pad_bot = 0.10
  )
  half <- 0.12 / 2
  high_bound <- 1 - 0.10 - half
  low_bound <- 0.10 + half

  expect_true(result$yA >= low_bound,
    info = sprintf("NIVEAU 1: yA=%.3f < low_bound=%.3f", result$yA, low_bound)
  )
  expect_true(result$yA <= high_bound,
    info = sprintf("NIVEAU 1: yA=%.3f > high_bound=%.3f", result$yA, high_bound)
  )
  expect_true(result$yB >= low_bound,
    info = sprintf("NIVEAU 1: yB=%.3f < low_bound=%.3f", result$yB, low_bound)
  )
  expect_true(result$yB <= high_bound,
    info = sprintf("NIVEAU 1: yB=%.3f > high_bound=%.3f", result$yB, high_bound)
  )
})

test_that("NIVEAU 3 (shelf) respekterer padding", {
  result <- place_two_labels_npc(
    yA_npc = 0.5, yB_npc = 0.51,
    label_height_npc = 0.40,
    gap_line = 0.05, gap_labels = 0.15,
    pad_top = 0.10, pad_bot = 0.10
  )
  half <- 0.40 / 2
  high_bound <- 1 - 0.10 - half
  low_bound <- 0.10 + half

  # Shelf placement bør stadig respektere bounds
  expect_true(result$yA >= low_bound || is.na(result$yA),
    info = sprintf("SHELF: yA=%.3f < low_bound=%.3f", result$yA, low_bound)
  )
  expect_true(result$yA <= high_bound || is.na(result$yA),
    info = sprintf("SHELF: yA=%.3f > high_bound=%.3f", result$yA, high_bound)
  )
})

# ==============================================================================
# Input validation
# ==============================================================================

test_that("place_two_labels_npc validerer input korrekt", {
  # Ikke-numerisk
  expect_error(
    place_two_labels_npc(yA_npc = "a", yB_npc = 0.5, label_height_npc = 0.1),
    "numeric"
  )
  # Negativ label height
  expect_error(
    place_two_labels_npc(yA_npc = 0.5, yB_npc = 0.5, label_height_npc = -0.1),
    "positive"
  )
  # Ugyldig priority
  expect_error(
    place_two_labels_npc(yA_npc = 0.5, yB_npc = 0.5, label_height_npc = 0.1, priority = "C"),
    "arg"
  )
  # Ugyldig pref_pos
  expect_error(
    place_two_labels_npc(
      yA_npc = 0.5, yB_npc = 0.5, label_height_npc = 0.1,
      pref_pos = c("left", "right")
    ),
    "under.*over"
  )
})
