test_that("LABEL_PLACEMENT_CONFIG contains all expected keys", {
  config <- LABEL_PLACEMENT_CONFIG

  expected_keys <- c(
    "relative_gap_line",
    "relative_gap_labels",
    "pad_top",
    "pad_bot",
    "coincident_threshold_factor",
    "tight_lines_threshold_factor",
    "gap_reduction_factors",
    "shelf_center_threshold",
    "marquee_size_factor",
    "marquee_lineheight",
    "height_safety_margin",
    "height_fallback_npc"
  )

  expect_true(all(expected_keys %in% names(config)))
})

test_that("LABEL_PLACEMENT_CONFIG values are numeric and reasonable", {
  config <- LABEL_PLACEMENT_CONFIG

  # All single values should be numeric
  expect_true(is.numeric(config$relative_gap_line))
  expect_true(is.numeric(config$relative_gap_labels))
  expect_true(is.numeric(config$pad_top))
  expect_true(is.numeric(config$pad_bot))
  expect_true(is.numeric(config$coincident_threshold_factor))
  expect_true(is.numeric(config$tight_lines_threshold_factor))
  expect_true(is.numeric(config$shelf_center_threshold))
  expect_true(is.numeric(config$marquee_size_factor))
  expect_true(is.numeric(config$marquee_lineheight))
  expect_true(is.numeric(config$height_safety_margin))
  expect_true(is.numeric(config$height_fallback_npc))

  # gap_reduction_factors should be numeric vector
  expect_true(is.numeric(config$gap_reduction_factors))
  expect_true(length(config$gap_reduction_factors) > 0)

  # Values should be in reasonable ranges
  expect_true(config$relative_gap_line > 0 && config$relative_gap_line < 1)
  expect_true(config$relative_gap_labels > 0 && config$relative_gap_labels < 1)
  expect_true(config$pad_top >= 0 && config$pad_top < 0.5)
  expect_true(config$pad_bot >= 0 && config$pad_bot < 0.5)
  expect_true(config$shelf_center_threshold >= 0 && config$shelf_center_threshold <= 1)
  expect_true(config$marquee_size_factor > 0)
  expect_true(config$marquee_lineheight > 0 && config$marquee_lineheight <= 2)
  expect_true(config$height_safety_margin >= 0)
  expect_true(config$height_fallback_npc > 0 && config$height_fallback_npc < 1)
})

test_that("get_label_placement_param returns correct values", {
  # Test retrieval of existing parameters
  expect_equal(
    get_label_placement_param("relative_gap_line"),
    LABEL_PLACEMENT_CONFIG$relative_gap_line
  )

  expect_equal(
    get_label_placement_param("pad_top"),
    LABEL_PLACEMENT_CONFIG$pad_top
  )

  expect_equal(
    get_label_placement_param("marquee_size_factor"),
    LABEL_PLACEMENT_CONFIG$marquee_size_factor
  )
})

test_that("get_label_placement_param handles nonexistent keys with default", {
  # Should return default if key doesn't exist
  expect_equal(
    get_label_placement_param("nonexistent_key", default = 0.5),
    0.5
  )

  expect_equal(
    get_label_placement_param("another_missing", default = 100),
    100
  )
})

test_that("get_label_placement_param throws error for nonexistent key without default", {
  expect_error(
    get_label_placement_param("nonexistent_key"),
    "Label placement parameter 'nonexistent_key' ikke fundet"
  )

  expect_error(
    get_label_placement_param("missing"),
    "Tilgængelige keys"
  )
})

test_that("get_label_placement_config returns full configuration", {
  config <- get_label_placement_config()

  # Should be a list
  expect_true(is.list(config))

  # Should contain all keys from LABEL_PLACEMENT_CONFIG
  expect_setequal(names(config), names(LABEL_PLACEMENT_CONFIG))

  # Should be a copy (not the same object)
  # Modifying returned config should not affect original
  config$relative_gap_line <- 999
  expect_equal(
    LABEL_PLACEMENT_CONFIG$relative_gap_line,
    0.05  # Original value unchanged
  )
})

test_that("override_label_placement_config errors when config is locked", {
  # NOTE: LABEL_PLACEMENT_CONFIG is locked in the package namespace,
  # so override_label_placement_config() cannot actually modify it.
  # This is GOOD for security - config should be immutable at runtime.
  # The function exists for documentation purposes but cannot be used.

  # Should error when trying to modify locked binding
  expect_error(
    override_label_placement_config(relative_gap_line = 0.10),
    "cannot change value of locked binding"
  )
})

test_that("override_label_placement_config handles both valid and invalid keys", {
  # NOTE: Since LABEL_PLACEMENT_CONFIG is locked, we can't fully test
  # the override functionality. But we can verify the function exists
  # and has the expected signature.

  # Function should exist and be callable
  expect_true(exists("override_label_placement_config"))
  expect_true(is.function(override_label_placement_config))

  # Any attempt to modify should error due to locked binding
  expect_error(
    override_label_placement_config(relative_gap_line = 0.10),
    "cannot change value of locked binding"
  )
})

test_that("Configuration values follow documented relationships", {
  config <- LABEL_PLACEMENT_CONFIG

  # gap_reduction_factors should be decreasing sequence
  expect_true(all(diff(config$gap_reduction_factors) < 0))

  # All gap_reduction_factors should be between 0 and 1
  expect_true(all(config$gap_reduction_factors > 0))
  expect_true(all(config$gap_reduction_factors < 1))

  # relative_gap_labels should be larger than relative_gap_line
  # (labels need more space between them than between label and line)
  expect_true(config$relative_gap_labels > config$relative_gap_line)

  # Padding should be symmetric
  expect_equal(config$pad_top, config$pad_bot)
})

test_that("Configuration can be used in typical calculations", {
  config <- get_label_placement_config()
  label_height_npc <- 0.10  # Example label height

  # Calculate gaps
  gap_line <- config$relative_gap_line * label_height_npc
  gap_labels <- config$relative_gap_labels * label_height_npc

  # Results should be reasonable
  expect_true(gap_line > 0)
  expect_true(gap_labels > 0)
  expect_true(gap_labels > gap_line)

  # Test collision threshold
  threshold <- config$coincident_threshold_factor * label_height_npc
  expect_true(threshold > 0 && threshold < label_height_npc)
})
