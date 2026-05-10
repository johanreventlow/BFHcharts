# Edge case tests for bfh_qic()
# Verificerer at pipelinen håndterer grænsetilfælde korrekt

test_that("bfh_qic håndterer minimum data (3 punkter)", {
  data <- data.frame(
    date = as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")),
    value = c(10, 15, 12)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "run")

  expect_s3_class(result, "bfh_qic_result")
  expect_equal(nrow(result$qic_data), 3)
})

test_that("bfh_qic håndterer alle identiske værdier (zero variance)", {
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rep(50, 12)
  )

  # Skal ikke crashe — qicharts2 håndterer zero variance
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")

  expect_s3_class(result, "bfh_qic_result")
  # Centerlinje skal være 50
  expect_true(all(result$qic_data$cl == 50))
})

test_that("bfh_qic håndterer data med alle nul-værdier", {
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rep(0, 12)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "run")

  expect_s3_class(result, "bfh_qic_result")
})

test_that("bfh_qic håndterer negative værdier", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = -10, sd = 5)
  )

  # i-chart accepterer negative værdier (continuous metric, fx temperaturer)
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")

  expect_s3_class(result, "bfh_qic_result")
  # Y-værdier skal afspejle de negative inputdata
  expect_true(any(result$qic_data$y < 0))
})

test_that("E8 regression: count-style charts reject negative y values", {
  # Cycle 01 finding E8 (review 2026-05-10):
  # qicharts2 silently rendered negative counts on c/g/t/p/u-charts,
  # producing statistically meaningless charts that appeared valid to
  # clinicians. Now caught at validation time with chart-type-aware error.
  data <- data.frame(
    date = as.Date("2024-01-01") + 0:9,
    val = c(5, 3, 8, -1, 4, 6, 2, 7, 5, 3)
  )

  for (ct in c("c", "g", "t", "u")) {
    expect_error(
      bfh_qic(data, x = date, y = val, chart_type = ct),
      "non-negative",
      info = paste0("chart_type='", ct, "' should reject negative y")
    )
  }

  # i-chart (and run-chart) still accept negative values
  expect_no_error(
    bfh_qic(data, x = date, y = val, chart_type = "i")
  )
})

test_that("bfh_qic håndterer stor dataset (200 punkter)", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2010-01-01"), by = "month", length.out = 200),
    value = rpois(200, lambda = 50)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i")

  expect_s3_class(result, "bfh_qic_result")
  expect_equal(nrow(result$qic_data), 200)
})

test_that("bfh_qic returnerer summary med korrekte danske kolonner", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rpois(24, lambda = 50)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i")

  # Summary skal have danske kolonner fra format_qic_summary
  expect_true("fase" %in% names(result$summary))
  expect_true("centerlinje" %in% names(result$summary))
  expect_true("antal_observationer" %in% names(result$summary))
})

test_that("bfh_qic med multiply parameter skalerer korrekt", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 0.5, sd = 0.1)
  )

  result <- bfh_qic(data,
    x = date, y = value, chart_type = "i",
    multiply = 100
  )

  # Multiplicerede y-værdier skal være ~50 (0.5 * 100)
  expect_true(mean(result$qic_data$y) > 30)
})

test_that("bfh_qic med cl parameter sætter custom centerlinje", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rpois(12, lambda = 50)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = date, y = value, chart_type = "run", cl = 42)
  )

  # Centerlinje skal være 42 (custom)
  expect_true(all(result$qic_data$cl == 42))
})

test_that("E2 regression: bfh_qic rejects non-finite cl with clear error", {
  # Cycle 01 finding E2 (review 2026-05-10):
  # validate_numeric_parameter() admitted Inf because is.na(Inf)=FALSE and
  # bounds checks Inf < Inf / Inf > Inf both return FALSE. Inf flowed to
  # qicharts2 / yA_npc machinery where it failed with cryptic
  # "yA_npc must be finite" -- AFTER the user-supplied-cl warning had
  # already been emitted, masking the actual root cause.
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rpois(12, lambda = 50)
  )

  expect_error(
    bfh_qic(data, x = date, y = value, chart_type = "run", cl = Inf),
    "cl must be finite"
  )
  expect_error(
    bfh_qic(data, x = date, y = value, chart_type = "run", cl = -Inf),
    "cl must be finite"
  )
})

test_that("bfh_qic med part parameter opretter faser", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rpois(24, lambda = 50)
  )

  result <- bfh_qic(data,
    x = date, y = value, chart_type = "i",
    part = 12
  )

  expect_equal(length(unique(result$qic_data$part)), 2)
  expect_equal(nrow(result$summary), 2)
})

test_that("bfh_qic med freeze parameter fryser baseline", {
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rpois(24, lambda = 50)
  )

  result <- bfh_qic(data,
    x = date, y = value, chart_type = "i",
    freeze = 12
  )

  expect_s3_class(result, "bfh_qic_result")
  # Centerlinje skal være konstant (frozen fra de første 12 obs)
  cl_values <- unique(round(result$qic_data$cl, 2))
  expect_equal(length(cl_values), 1)
})

test_that("bfh_qic med part-vektor og freeze fungerer (regressiontest)", {
  set.seed(1)

  # Reproduktion af kombination: part=c(6,9) + freeze=6
  # Sikrer at dette ikke crasher (regression mod evt. fremtidige brud)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 15),
    value = rpois(15, lambda = 50)
  )

  result <- suppressWarnings(
    bfh_qic(data,
      x = date, y = value, chart_type = "i",
      part = c(6, 9), freeze = 6
    )
  )

  expect_s3_class(result, "bfh_qic_result")
  # 3 faser: obs 1-6, 7-9, 10-15
  expect_equal(length(unique(result$qic_data$part)), 3)
  expect_equal(nrow(result$summary), 3)
})

test_that("bfh_qic med tomt data.frame giver fejl", {
  # Empty data.frame (0 rows) must produce an explicit error, not a crash.
  # Validation: utils_bfh_qic_helpers.R:306 raises
  # "'data' is empty; bfh_qic() requires at least one row".
  expect_error(
    bfh_qic(
      data.frame(date = as.Date(character(0)), value = numeric(0)),
      x = date, y = value, chart_type = "i"
    )
  )
})

test_that("bfh_qic med enkelt-række data returnerer objekt (ingen crash)", {
  # Single observation: qicharts2 håndterer dette — returnerer result med NA limits.
  data <- data.frame(
    date = as.Date("2024-01-01"),
    value = 42
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "run")

  expect_s3_class(result, "bfh_qic_result")
  expect_equal(nrow(result$qic_data), 1)
})

# ============================================================================
# BASELINE MINIMUM ADVARSEL TESTS (enforce-baseline-minimum-and-cl-warnings)
# ============================================================================

test_that("bfh_qic giver advarsel når freeze < MIN_BASELINE_N (8)", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rpois(20, lambda = 50)
  )

  expect_warning(
    bfh_qic(data, x = date, y = value, chart_type = "i", freeze = 3),
    regexp = "freeze = 3"
  )
})

test_that("bfh_qic giver advarsel ved freeze = 7 (< 8)", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rpois(20, lambda = 50)
  )

  expect_warning(
    bfh_qic(data, x = date, y = value, chart_type = "i", freeze = 7),
    regexp = "baseline has fewer than 8"
  )
})

test_that("bfh_qic giver IKKE advarsel når freeze = 8 (lig MIN_BASELINE_N)", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rpois(20, lambda = 50)
  )

  expect_no_warning(
    bfh_qic(data, x = date, y = value, chart_type = "i", freeze = 8)
  )
})

test_that("bfh_qic giver IKKE advarsel når freeze = NULL", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rpois(12, lambda = 50)
  )

  # Ingen freeze — ingen advarsel fra freeze-check
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")
  expect_s3_class(result, "bfh_qic_result")
})

test_that("bfh_qic giver advarsel når en part-fase er for kort", {
  set.seed(42)
  # n=18: part=3 → fase 1 har 3 obs (< 8), fase 2 har 15 obs
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 18),
    value = rpois(18, lambda = 50)
  )

  expect_warning(
    bfh_qic(data, x = date, y = value, chart_type = "i", part = 3),
    regexp = "Phase\\(s\\) 1"
  )
})

test_that("bfh_qic giver IKKE advarsel når alle part-faser har >= 8 obs", {
  set.seed(42)
  # n=24: part=12 → fase 1 har 12 obs, fase 2 har 12 obs
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rpois(24, lambda = 50)
  )

  expect_no_warning(
    bfh_qic(data, x = date, y = value, chart_type = "i", part = 12)
  )
})

test_that("bfh_qic giver cl-override advarsel ved custom cl med tilstrækkelige data", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rpois(20, lambda = 50)
  )

  expect_warning(
    bfh_qic(data, x = date, y = value, chart_type = "i", cl = 50),
    regexp = "Custom cl supplied"
  )
})

test_that("bfh_qic giver IKKE cl-override advarsel ved cl = NULL", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rpois(20, lambda = 50)
  )

  # Ingen cl — ingen advarsel fra cl-check
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")
  expect_s3_class(result, "bfh_qic_result")
})

# ============================================================================
# Tightened input validation (Codex 2026-04-30 / change tighten-bfh_qic-input-validation)
# ============================================================================

test_that("bfh_qic afviser tomt data.frame med klar 'empty'-fejl", {
  expect_error(
    bfh_qic(
      data.frame(period = integer(0), value = numeric(0)),
      x = period, y = value, chart_type = "i"
    ),
    "empty"
  )
})

test_that("bfh_qic afviser non-numerisk y-kolonne før qic-kald", {
  data <- data.frame(
    period = 1:5,
    value = c("a", "b", "c", "d", "e"),
    stringsAsFactors = FALSE
  )
  expect_error(
    bfh_qic(data, x = period, y = value, chart_type = "i"),
    "must be numeric"
  )
})

test_that("bfh_qic afviser non-integer part med 'integer'-besked", {
  data <- data.frame(month = 1:24, value = rnorm(24))
  expect_error(
    bfh_qic(data, x = month, y = value, part = 3.5, chart_type = "i"),
    "integer"
  )
})

test_that("bfh_qic afviser duplikerede part-positioner med 'unique'-besked", {
  data <- data.frame(month = 1:24, value = rnorm(24))
  expect_error(
    bfh_qic(data, x = month, y = value, part = c(12, 12), chart_type = "i"),
    "unique"
  )
})

test_that("bfh_qic afviser unsorted part med 'increasing'-besked", {
  data <- data.frame(month = 1:24, value = rnorm(24))
  expect_error(
    bfh_qic(data, x = month, y = value, part = c(12, 6), chart_type = "i"),
    "increasing"
  )
})

test_that("bfh_qic afviser non-integer freeze med 'integer'-besked", {
  data <- data.frame(month = 1:24, value = rnorm(24))
  expect_error(
    bfh_qic(data, x = month, y = value, freeze = 5.5, chart_type = "i"),
    "integer"
  )
})

test_that("bfh_qic afviser duplikerede exclude-positioner med 'unique'-besked", {
  data <- data.frame(month = 1:24, value = rnorm(24))
  expect_error(
    bfh_qic(data, x = month, y = value, exclude = c(2, 2, 5), chart_type = "i"),
    "unique"
  )
})

test_that("bfh_export_pdf afviser non-scalar metadata$target", {
  chart <- fixture_test_chart()
  expect_error(
    bfh_export_pdf(chart, tempfile(fileext = ".pdf"),
      metadata = list(target = c(1, 2))
    ),
    "scalar|length 1"
  )
})

test_that("bfh_generate_analysis afviser Inf metadata$target", {
  chart <- fixture_test_chart()
  expect_error(
    bfh_generate_analysis(chart, metadata = list(target = Inf)),
    "finite"
  )
})

test_that("bfh_build_analysis_context afviser NA character metadata$target", {
  chart <- fixture_test_chart()
  expect_error(
    bfh_build_analysis_context(chart, metadata = list(target = NA_character_)),
    "NA"
  )
})


test_that("anhoej.signal kan være NA for en kort serie (n=6)", {
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 6),
    value = c(10, 15, 12, 14, 11, 13)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i")

  expect_s3_class(result, "bfh_qic_result")
  # Kort serie → qicharts2 returnerer NA for Anhøj-signaler
  # anhoej.signal må godt indeholde NA (bevaret fra qicharts2)
  anhoej_vals <- result$qic_data$anhoej.signal
  # Enten er alle NA (for meget kort serie) eller logisk — ikke tvunget til FALSE
  expect_true(is.logical(anhoej_vals))
})
