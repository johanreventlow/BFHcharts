# Tests for SPC Analysis Functions

# ==============================================================================
# bfh_build_analysis_context() tests
# ==============================================================================

test_that("bfh_build_analysis_context rejects invalid input", {
  expect_error(
    bfh_build_analysis_context(data.frame()),
    "bfh_qic_result"
  )

  expect_error(
    bfh_build_analysis_context(list(a = 1)),
    "bfh_qic_result"
  )
})

test_that("bfh_build_analysis_context extracts context from bfh_qic_result", {
  # Create test data
  set.seed(123)
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 100, sd = 10)
  )

  result <- bfh_qic(
    test_data,
    x = date,
    y = value,
    chart_type = "i",
    chart_title = "Test Chart"
  )

  ctx <- bfh_build_analysis_context(result)

  # Check required fields
  expect_true("chart_title" %in% names(ctx))
  expect_true("chart_type" %in% names(ctx))
  expect_true("n_points" %in% names(ctx))
  expect_true("spc_stats" %in% names(ctx))
  expect_true("has_signals" %in% names(ctx))
  expect_false("signal_interpretations" %in% names(ctx))

  # Check values
  expect_equal(ctx$chart_title, "Test Chart")
  expect_equal(ctx$chart_type, "i")
  expect_equal(ctx$n_points, 24)
  expect_type(ctx$has_signals, "logical")
})

test_that("bfh_build_analysis_context merges user metadata", {
  set.seed(42)

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  ctx <- bfh_build_analysis_context(
    result,
    metadata = list(
      data_definition = "Test definition",
      target = 45,
      hospital = "BFH",
      department = "Quality"
    )
  )

  expect_equal(ctx$data_definition, "Test definition")
  expect_equal(ctx$target_value, 45)
  expect_equal(ctx$hospital, "BFH")
  expect_equal(ctx$department, "Quality")
})


# ==============================================================================
# bfh_generate_analysis() tests
# ==============================================================================

test_that("bfh_generate_analysis rejects invalid input", {
  expect_error(
    bfh_generate_analysis(data.frame()),
    "bfh_qic_result"
  )
})

test_that("bfh_generate_analysis returns standard text when use_ai = FALSE", {
  set.seed(42)

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 100, sd = 10)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
  analysis <- bfh_generate_analysis(result, use_ai = FALSE)

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis returns valid text with chart title set", {
  set.seed(42)

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(
    test_data,
    x = date,
    y = value,
    chart_type = "i",
    chart_title = "Månedlige Infektioner"
  )

  analysis <- bfh_generate_analysis(result, use_ai = FALSE)

  # Fallback-analyse genererer stabilitetstekst, ikke nødvendigvis med titel
  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis works with metadata", {
  set.seed(42)

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  analysis <- bfh_generate_analysis(
    result,
    metadata = list(
      data_definition = "Infektioner pr. 1000 patientdage",
      hospital = "BFH"
    ),
    use_ai = FALSE
  )

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis errors informatively when use_ai = TRUE and BFHllm missing", {
  skip_if(
    requireNamespace("BFHllm", quietly = TRUE),
    "BFHllm is installed — this test only applies when BFHllm is absent"
  )

  set.seed(42)
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  # use_ai = TRUE without BFHllm must raise an informative error (not silently fall back)
  expect_error(
    bfh_generate_analysis(result, use_ai = TRUE),
    "BFHllm"
  )
})

test_that("bfh_generate_analysis accepts min_chars and max_chars parameters", {
  set.seed(42)

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  # Test with custom min/max chars (should not error)
  analysis <- bfh_generate_analysis(
    result,
    use_ai = FALSE,
    min_chars = 200,
    max_chars = 500
  )

  expect_type(analysis, "character")
  expect_gt(nchar(analysis), 0)
})

test_that("bfh_generate_analysis has correct default values", {
  fn_args <- formals(bfh_generate_analysis)

  # Security: use_ai default is FALSE (explicit opt-in required)
  expect_equal(as.character(fn_args$use_ai), "FALSE")
  expect_equal(fn_args$min_chars, 300)
  expect_equal(fn_args$max_chars, 375)
  expect_null(fn_args$texts_loader)
  expect_equal(as.character(fn_args$language), "da")
})

test_that("bfh_generate_analysis validates min_chars < max_chars", {
  set.seed(42)

  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )

  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  # min_chars equal to max_chars should error
  expect_error(
    bfh_generate_analysis(result, min_chars = 300, max_chars = 300),
    "min_chars must be less than max_chars"
  )

  # min_chars greater than max_chars should error
  expect_error(
    bfh_generate_analysis(result, min_chars = 500, max_chars = 300),
    "min_chars must be less than max_chars"
  )
})

test_that("bfh_generate_analysis threads texts_loader to fallback pipeline", {
  set.seed(42)
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  custom_texts <- list(
    stability = list(
      no_variation = list(short = "CUSTOM_STABILITY"),
      no_signals = list(short = "CUSTOM_STABILITY"),
      runs_only = list(short = "CUSTOM_STABILITY"),
      crossings_only = list(short = "CUSTOM_STABILITY"),
      outliers_only = list(short = "CUSTOM_STABILITY"),
      runs_crossings = list(short = "CUSTOM_STABILITY"),
      runs_outliers = list(short = "CUSTOM_STABILITY"),
      crossings_outliers = list(short = "CUSTOM_STABILITY"),
      all_signals = list(short = "CUSTOM_STABILITY")
    ),
    target = list(
      at_target = list(short = "CUSTOM_TARGET"),
      over_target = list(short = "CUSTOM_TARGET"),
      under_target = list(short = "CUSTOM_TARGET"),
      goal_met = list(short = "CUSTOM_TARGET"),
      goal_not_met = list(short = "CUSTOM_TARGET")
    ),
    action = list(
      stable_at_target = list(short = "CUSTOM_ACTION"),
      stable_not_at_target = list(short = "CUSTOM_ACTION"),
      unstable_at_target = list(short = "CUSTOM_ACTION"),
      unstable_not_at_target = list(short = "CUSTOM_ACTION"),
      stable_no_target = list(short = "CUSTOM_ACTION"),
      unstable_no_target = list(short = "CUSTOM_ACTION"),
      stable_goal_met = list(short = "CUSTOM_ACTION"),
      stable_goal_not_met = list(short = "CUSTOM_ACTION"),
      unstable_goal_met = list(short = "CUSTOM_ACTION"),
      unstable_goal_not_met = list(short = "CUSTOM_ACTION")
    ),
    padding = list(
      data_points = list(short = ""),
      generic = list(short = "")
    )
  )

  analysis <- bfh_generate_analysis(
    result,
    use_ai = FALSE,
    min_chars = 10,
    max_chars = 100,
    texts_loader = function() custom_texts
  )

  expect_match(analysis, "CUSTOM_STABILITY")
  expect_match(analysis, "CUSTOM_ACTION")
})

test_that("build_fallback_analysis validates texts_loader", {
  expect_error(
    BFHcharts:::build_fallback_analysis(list(), texts_loader = "bad"),
    "texts_loader must be a function"
  )
})

# ==============================================================================
# pick_text() tests (intern funktion)
# ==============================================================================

test_that("pick_text vælger detailed variant når budget tillader det", {
  variants <- list(
    short = "Kort tekst.",
    standard = "Standard tekst med lidt mere.",
    detailed = "Detaljeret tekst med meget mere indhold og forklaring."
  )
  result <- BFHcharts:::pick_text(variants, budget = 200)
  expect_equal(result, "Detaljeret tekst med meget mere indhold og forklaring.")
})

test_that("pick_text vælger standard variant ved mellemstort budget", {
  variants <- list(
    short = "Kort tekst.",
    standard = "Standard tekst med lidt mere.",
    detailed = "Detaljeret tekst med meget mere indhold og forklaring."
  )
  budget <- nchar("Standard tekst med lidt mere.") + 1
  result <- BFHcharts:::pick_text(variants, budget = budget)
  expect_equal(result, "Standard tekst med lidt mere.")
})

test_that("pick_text vælger short variant ved lille budget", {
  variants <- list(
    short = "Kort tekst.",
    standard = "Standard tekst med lidt mere.",
    detailed = "Detaljeret tekst med meget mere indhold og forklaring."
  )
  result <- BFHcharts:::pick_text(variants, budget = 15)
  expect_equal(result, "Kort tekst.")
})

test_that("pick_text returnerer short selv når budget er for lille", {
  variants <- list(
    short = "Kort tekst.",
    standard = "Standard tekst med lidt mere."
  )
  result <- BFHcharts:::pick_text(variants, budget = 3)
  expect_equal(result, "Kort tekst.")
})

test_that("pick_text erstatter placeholders i valgt variant", {
  variants <- list(
    short = "Serie: {runs_actual}.",
    standard = "Serie ({runs_actual}) over forventet ({runs_expected}).",
    detailed = "Længste serie ({runs_actual}) overstiger forventet maksimum ({runs_expected}). Skift."
  )
  result <- BFHcharts:::pick_text(
    variants,
    data = list(runs_actual = 9, runs_expected = 7),
    budget = 200
  )
  expect_true(grepl("9", result))
  expect_true(grepl("7", result))
  expect_false(grepl("\\{runs_actual\\}", result))
})

test_that("pick_text håndterer varianter med kun short og standard", {
  variants <- list(
    short = "Kort.",
    standard = "Standard tekst."
  )
  result <- BFHcharts:::pick_text(variants, budget = 200)
  expect_equal(result, "Standard tekst.")
})

test_that("pick_text håndterer gammel YAML-format (bagudkompatibilitet)", {
  variants <- list("Processen er stabil.")
  result <- BFHcharts:::pick_text(variants, budget = 200)
  expect_equal(result, "Processen er stabil.")
})

test_that("pick_text med budget = Inf vælger detailed", {
  variants <- list(
    short = "Kort.",
    standard = "Standard.",
    detailed = "Detaljeret."
  )
  result <- BFHcharts:::pick_text(variants)
  expect_equal(result, "Detaljeret.")
})


# ==============================================================================
# resolve_target() tests (E: retningsfølsomhed)
# ==============================================================================

test_that("resolve_target returnerer tom liste for NULL input", {
  r <- BFHcharts:::resolve_target(NULL)
  expect_true(is.na(r$value))
  expect_null(r$direction)
  expect_equal(r$display, "")
})

test_that("resolve_target bevarer numerisk input uændret (bagudkompatibelt)", {
  r <- BFHcharts:::resolve_target(2.5)
  expect_equal(r$value, 2.5)
  expect_null(r$direction)
})

test_that("resolve_target parser <= til 'lower' direction", {
  r <- BFHcharts:::resolve_target("<= 2,5")
  expect_equal(r$value, 2.5)
  expect_equal(r$direction, "lower")
  expect_equal(r$display, "<= 2,5")
})

test_that("resolve_target parser >= til 'higher' direction", {
  r <- BFHcharts:::resolve_target(">= 90")
  expect_equal(r$value, 90)
  expect_equal(r$direction, "higher")
})

test_that("resolve_target parser Unicode ≤ til 'lower'", {
  r <- BFHcharts:::resolve_target("\U2264 5")
  expect_equal(r$value, 5)
  expect_equal(r$direction, "lower")
})

test_that("resolve_target parser Unicode ≥ til 'higher'", {
  r <- BFHcharts:::resolve_target("\U2265 90%")
  expect_equal(r$value, 90)
  expect_equal(r$direction, "higher")
})

test_that("resolve_target parser < med tal til 'lower'", {
  r <- BFHcharts:::resolve_target("< 3")
  expect_equal(r$value, 3)
  expect_equal(r$direction, "lower")
})

test_that("resolve_target parser > med tal til 'higher'", {
  r <- BFHcharts:::resolve_target("> 80")
  expect_equal(r$value, 80)
  expect_equal(r$direction, "higher")
})

test_that("resolve_target uden operator har ingen retning", {
  r <- BFHcharts:::resolve_target("2,5")
  expect_equal(r$value, 2.5)
  expect_null(r$direction)
})

test_that("resolve_target håndterer dansk decimalkomma og engelsk punktum", {
  r1 <- BFHcharts:::resolve_target("<= 2,5")
  r2 <- BFHcharts:::resolve_target("<= 2.5")
  expect_equal(r1$value, r2$value)
  expect_equal(r1$direction, r2$direction)
})

test_that("resolve_target returnerer NA_real_ for ikke-numerisk streng", {
  r <- BFHcharts:::resolve_target("ikke et tal")
  expect_true(is.na(r$value))
})


# ==============================================================================
# pluralize_da() tests (B: ental/flertal)
# ==============================================================================

test_that("pluralize_da returnerer ental når n == 1", {
  expect_equal(BFHcharts:::pluralize_da(1, "observation", "observationer"), "observation")
})

test_that("pluralize_da returnerer flertal når n != 1", {
  expect_equal(BFHcharts:::pluralize_da(0, "observation", "observationer"), "observationer")
  expect_equal(BFHcharts:::pluralize_da(2, "observation", "observationer"), "observationer")
  expect_equal(BFHcharts:::pluralize_da(5, "observation", "observationer"), "observationer")
})

test_that("pluralize_da håndterer NA og NULL gracefult", {
  expect_equal(BFHcharts:::pluralize_da(NA, "observation", "observationer"), "observationer")
  expect_equal(BFHcharts:::pluralize_da(NULL, "observation", "observationer"), "observationer")
})


# ==============================================================================
# ensure_within_max() tests (B: trim)
# ==============================================================================

test_that("ensure_within_max returnerer tekst uændret under grænsen", {
  text <- "Kort tekst."
  expect_equal(BFHcharts:::ensure_within_max(text, 100), text)
})

test_that("ensure_within_max trimmer ved sidste punktum", {
  text <- "Første sætning. Anden sætning. Tredje sætning der er meget lang."
  result <- BFHcharts:::ensure_within_max(text, 30)
  expect_lte(nchar(result), 30)
  expect_match(result, "\\.$") # ender på punktum
})

test_that("ensure_within_max trimmer ved komma hvis intet punktum findes", {
  text <- "Første del, anden del, tredje del der fortsætter og fortsætter"
  result <- BFHcharts:::ensure_within_max(text, 20)
  expect_lte(nchar(result), 20)
})

test_that("ensure_within_max aldrig klipper midt i et ord", {
  text <- "første sætning her. Anden sætning er også lang nok til at mærke klippet"
  result <- BFHcharts:::ensure_within_max(text, 25)
  expect_lte(nchar(result), 25)
  # Resultat skal være enten tom, slutte på punktuation/space, eller være et
  # helt ord-præfiks fra originalen — aldrig en afbrudt halv-stavelse.
  trimmed <- trimws(result)
  if (nchar(trimmed) > 0) {
    ends_on_punct <- grepl("[.!?,]$", trimmed)
    # Tjek at resultatet findes som prefix i originalen ved et ordskel
    orig_words <- strsplit(text, "\\s+")[[1]]
    valid_prefixes <- sapply(seq_along(orig_words), function(i) {
      paste(orig_words[seq_len(i)], collapse = " ")
    })
    # Fjern trailing punktuation for match mod original
    clean_trimmed <- gsub("[.!?,]+$", "", trimmed)
    is_prefix <- any(sapply(valid_prefixes, function(p) {
      gsub("[.!?,]+$", "", p) == clean_trimmed
    }))
    expect_true(ends_on_punct || is_prefix,
      label = sprintf(
        "Resultat '%s' bør slutte på punktuation eller være et ord-præfiks",
        trimmed
      )
    )
  }
})


# ==============================================================================
# bfh_build_analysis_context() — target_direction (E)
# ==============================================================================

test_that("bfh_build_analysis_context afleder target_direction fra operator-streng", {
  set.seed(42)
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  ctx <- bfh_build_analysis_context(result, metadata = list(target = "<= 45"))

  expect_equal(ctx$target_value, 45)
  expect_equal(ctx$target_direction, "lower")
  expect_equal(ctx$target_display, "<= 45")
})

test_that("bfh_build_analysis_context bevarer numerisk target uden retning", {
  set.seed(42)
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  ctx <- bfh_build_analysis_context(result, metadata = list(target = 45))

  expect_equal(ctx$target_value, 45)
  expect_null(ctx$target_direction)
})


# ==============================================================================
# build_fallback_analysis() — goal_met/goal_not_met + constraints
# ==============================================================================

# Hjælpefunktion: fixture_analysis_context() er tilgængelig via helper-fixtures.R.

test_that("build_fallback_analysis overstiger aldrig max_chars", {
  for (mx in c(200L, 275L, 375L, 500L)) {
    ctx <- fixture_analysis_context(target_value = 50, target_direction = "lower", centerline = 45)
    txt <- BFHcharts:::build_fallback_analysis(ctx, min_chars = 50, max_chars = mx)
    expect_lte(nchar(txt), mx,
      label = sprintf("max_chars=%d giver %d tegn", mx, nchar(txt))
    )
  }
})

test_that("build_fallback_analysis bruger goal_met-tekst når target_direction er 'lower' og CL <= target", {
  ctx <- fixture_analysis_context(
    target_value = 2.5, target_direction = "lower", centerline = 2.0,
    target_display = "<= 2,5"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  # Skal INDEHOLDE "opfylder målet" eller "målet ... nået"
  expect_true(grepl("opfylder målet|målet.*nået", txt),
    info = paste("Forventede goal_met-sprog, fik:", txt)
  )
  # Må IKKE indeholde den værdineutrale "ligger under målet"
  expect_false(grepl("ligger under målet", txt))
})

test_that("build_fallback_analysis bruger goal_not_met når CL overstiger 'lower'-target", {
  ctx <- fixture_analysis_context(
    target_value = 2.5, target_direction = "lower", centerline = 4.0,
    target_display = "<= 2,5"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  expect_true(grepl("opfylder (endnu )?ikke målet|endnu ikke nået", txt),
    info = paste("Forventede goal_not_met-sprog, fik:", txt)
  )
})

test_that("build_fallback_analysis bruger goal_met for 'higher'-target når CL >= target", {
  ctx <- fixture_analysis_context(
    target_value = 90, target_direction = "higher", centerline = 95,
    target_display = ">= 90"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  expect_true(grepl("opfylder målet|målet.*nået", txt),
    info = paste("Forventede goal_met, fik:", txt)
  )
})

test_that("build_fallback_analysis bruger værdineutral tekst når target_direction er NULL", {
  ctx <- fixture_analysis_context(target_value = 2.5, target_direction = NULL, centerline = 3.0)
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  # Den værdineutrale sti bruger "over" / "under" / "tæt på"
  expect_true(grepl("over|under|tæt på", txt))
})

test_that("build_fallback_analysis reallokerer budget når target mangler", {
  ctx_no_target <- fixture_analysis_context(target_value = NA_real_, target_direction = NULL)
  txt <- BFHcharts:::build_fallback_analysis(ctx_no_target, min_chars = 300, max_chars = 400)
  # Uden target skal stability+action fylde meste af max_chars
  expect_gte(nchar(txt), 250)
  expect_lte(nchar(txt), 400)
})

test_that("build_fallback_analysis bruger ental ved 1 outlier", {
  stats <- list(
    runs_actual = 5, runs_expected = 7,
    crossings_actual = 8, crossings_expected = 5,
    outliers_recent_count = 1
  )
  ctx <- fixture_analysis_context(spc_stats = stats)
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  # Grammatisk korrekt dansk: enten "1 observation ligger" (direkte) eller
  # "1 af de seneste observationer ligger" (flertal i "af de seneste"-konstruktion).
  expect_match(txt, "1 observation\\b|1 af de seneste observationer")
  # Må ikke indeholde "1 observationer" som direkte konstruktion
  expect_false(grepl("\\b1 observationer\\b", txt))
})

test_that("build_fallback_analysis bruger flertal ved 3 outliers", {
  stats <- list(
    runs_actual = 5, runs_expected = 7,
    crossings_actual = 8, crossings_expected = 5,
    outliers_recent_count = 3
  )
  ctx <- fixture_analysis_context(spc_stats = stats)
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  # Grammatisk korrekt dansk: enten "3 observationer" (direkte) eller
  # "3 af de seneste observationer" (flertal i "af de seneste"-konstruktion).
  expect_match(txt, "3 observationer|3 af de seneste observationer")
  # Må aldrig bruge ental efter tal > 1
  expect_false(grepl("\\b3 observation\\b", txt))
})
