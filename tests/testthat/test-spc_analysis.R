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

  expect_false(fn_args$use_ai)
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
    txt <- BFHcharts:::build_fallback_analysis(ctx, max_chars = mx)
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
  # goal_not_met-tekster udtrykker negation paa flere maader afhaengigt af
  # variant: "opfylder (endnu )?ikke maalet", "endnu ikke naaet", "er ikke
  # naaet", "naar ikke (udviklings)?maalet". Daekker alle nuvaerende formuleringer.
  expect_true(grepl("opfylder (endnu )?ikke målet|endnu ikke nået|er ikke nået|når ikke (udviklings)?målet", txt),
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
  txt <- BFHcharts:::build_fallback_analysis(ctx_no_target, max_chars = 400)
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
  # "1 af de seneste [N] observationer ligger" (flertal i "af de seneste"-konstruktion,
  # muligvis med et vinduesantal indskudt).
  expect_match(txt, "1 observation\\b|1 af de seneste \\d* ?observationer")
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
  # "3 af de seneste [N] observationer" (flertal i "af de seneste"-konstruktion,
  # muligvis med et vinduesantal indskudt).
  expect_match(txt, "3 observationer|3 af de seneste \\d* ?observationer")
  # Må aldrig bruge ental efter tal > 1
  expect_false(grepl("\\b3 observation\\b", txt))
})


# ==============================================================================
# .normalize_percent_target() — unit tests (alle 6 kombinationer fra spec)
# ==============================================================================

test_that(".normalize_percent_target: percent-chart + display med % + value > 1 -> divider med 100", {
  # Fx ">= 90%" -> parsed value=90, display=">= 90%", y_axis_unit="percent"
  result <- BFHcharts:::.normalize_percent_target(90, ">= 90%", "percent")
  expect_equal(result, 0.90, tolerance = 1e-9)
})

test_that(".normalize_percent_target: percent-chart + numeric input value > 1 + tom display -> normaliser", {
  # resolve_target(90) returnerer display="" (numerisk input-sti)
  result <- BFHcharts:::.normalize_percent_target(90, "", "percent")
  expect_equal(result, 0.90, tolerance = 1e-9)
})

test_that(".normalize_percent_target: percent-chart + value <= 1 + tom display -> uændret (allerede proportion)", {
  result <- BFHcharts:::.normalize_percent_target(0.9, "", "percent")
  expect_equal(result, 0.9, tolerance = 1e-9)
})

test_that(".normalize_percent_target: percent-chart + '>= 0.9' display (ingen %) + value <= 1 -> uændret", {
  # Power-user input: proportion-skala direkte angivet
  result <- BFHcharts:::.normalize_percent_target(0.9, ">= 0.9", "percent")
  expect_equal(result, 0.9, tolerance = 1e-9)
})

test_that(".normalize_percent_target: count-chart + value > 1 -> ingen normalisering", {
  result <- BFHcharts:::.normalize_percent_target(90, ">= 90", "count")
  expect_equal(result, 90)
})

test_that(".normalize_percent_target: rate-chart + value > 1 -> ingen normalisering", {
  result <- BFHcharts:::.normalize_percent_target(2.5, "<= 2.5", "rate")
  expect_equal(result, 2.5)
})

test_that(".normalize_percent_target: lower-direction percent target normaliseres korrekt", {
  # "<= 5%" -> value=5, display="<= 5%", unit="percent"
  result <- BFHcharts:::.normalize_percent_target(5, "<= 5%", "percent")
  expect_equal(result, 0.05, tolerance = 1e-9)
})

test_that("E1 regression: percent-chart preserves numeric stretch-target in (1, 1.5]", {
  # Cycle 01 finding E1 (review 2026-05-10):
  # validate_target_for_unit() allows target_value up to multiply*1.5 = 1.5
  # for percent charts (legitimate stretch goals > 100% on proportion scale).
  # Previous 'value > 1' threshold misclassified such targets as percent-scale
  # input and divided by 100, producing wrong narrative text in
  # bfh_generate_analysis(). Threshold is now 'value > 1.5' (validator's max).
  expect_equal(
    BFHcharts:::.normalize_percent_target(1.05, "", "percent"),
    1.05,
    tolerance = 1e-9
  )
  expect_equal(
    BFHcharts:::.normalize_percent_target(1.5, "", "percent"),
    1.5,
    tolerance = 1e-9
  )
  # Boundary: value just above 1.5 IS percent-scale input -> normalize
  expect_equal(
    BFHcharts:::.normalize_percent_target(1.51, "", "percent"),
    0.0151,
    tolerance = 1e-9
  )
})

test_that("E1 regression: percent-chart still normalizes values clearly on 0-100 scale", {
  # Sanity: confirm that values comfortably above 1.5 still normalize.
  # This is the dominant production case and must not regress.
  expect_equal(
    BFHcharts:::.normalize_percent_target(50, "", "percent"),
    0.50,
    tolerance = 1e-9
  )
  expect_equal(
    BFHcharts:::.normalize_percent_target(100, "", "percent"),
    1.00,
    tolerance = 1e-9
  )
})


# ==============================================================================
# Regressions-tests: percent-target skalafejl (bug 2026-04-29)
# ==============================================================================

test_that("REGRESSION: bfh_build_analysis_context normaliserer '>= 90%' til 0.90 på p-chart", {
  # Fejlscenarie: centerline=0.91, target=">= 90%" -> target_value lagret som 90
  # -> 0.91 >= 90 = FALSE -> FORKERT "endnu ikke nået"
  # Forventet: target_value normaliseres til 0.90

  set.seed(7)
  # p-chart kræver n (nævner) og events (tæller)
  p_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    n = rep(100L, 24),
    events = c(rep(91L, 20), rep(88L, 4)) # ~91% de fleste måneder
  )
  result <- bfh_qic(p_data,
    x = date, y = events, n = n, chart_type = "p",
    y_axis_unit = "percent"
  )

  ctx <- bfh_build_analysis_context(result, metadata = list(target = ">= 90%"))

  expect_equal(ctx$target_value, 0.90,
    tolerance = 1e-9,
    label = "target_value skal være 0.90 (normaliseret fra 90)"
  )
  expect_equal(ctx$target_display, ">= 90%",
    label = "target_display bevares uændret"
  )
  expect_equal(ctx$target_direction, "higher")
})

test_that("REGRESSION: build_fallback_analysis producerer 'opfylder målet' for 91% vs >= 90%", {
  # Dette er den direkte kliniske konsekvens-test:
  # Med normaliseret target (0.90) og centerline (0.91) skal goal_met = TRUE
  ctx <- fixture_analysis_context(
    chart_type = "p",
    y_axis_unit = "percent",
    centerline = 0.91,
    target_value = 0.90, # normaliseret (bug: var 90 -> FALSE)
    target_direction = "higher",
    target_display = ">= 90%"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)

  # Teksten bør bekræfte at målet er nået
  expect_match(txt, "opfylder målet|målet.*opfyldt|målet.*nået",
    label = "Skal indeholde positivt målbekræftelse"
  )
  # Og IKKE den fejlagtige negative tekst
  expect_false(grepl("endnu ikke nået|opfylder ikke", txt),
    label = "Må ikke indeholde fejlagtig negation"
  )
})

test_that("REGRESSION: lower-direction 3% vs '<= 5%' -> goal_met via normalisering", {
  set.seed(9)
  p_data <- data.frame(
    date   = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    n      = rep(100L, 20),
    events = rep(3L, 20) # 3% -> centerline ~0.03
  )
  result <- bfh_qic(p_data,
    x = date, y = events, n = n, chart_type = "p",
    y_axis_unit = "percent"
  )

  ctx <- bfh_build_analysis_context(result, metadata = list(target = "<= 5%"))

  expect_equal(ctx$target_value, 0.05,
    tolerance = 1e-9,
    label = "target_value normaliseret fra 5 til 0.05"
  )
  expect_equal(ctx$target_direction, "lower")

  txt <- BFHcharts:::build_fallback_analysis(ctx)
  expect_match(txt, "opfylder målet|målet.*opfyldt",
    label = "3% opfylder <= 5% mål"
  )
})

test_that("bfh_build_analysis_context: numerisk target=90 normaliseres på p-chart", {
  set.seed(11)
  p_data <- data.frame(
    date   = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    n      = rep(100L, 20),
    events = rep(91L, 20)
  )
  result <- bfh_qic(p_data,
    x = date, y = events, n = n, chart_type = "p",
    y_axis_unit = "percent"
  )

  ctx <- bfh_build_analysis_context(result, metadata = list(target = 90))
  expect_equal(ctx$target_value, 0.90, tolerance = 1e-9)
})

test_that("bfh_build_analysis_context: numerisk target=0.9 bevares uændret på p-chart", {
  set.seed(11)
  p_data <- data.frame(
    date   = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    n      = rep(100L, 20),
    events = rep(91L, 20)
  )
  result <- bfh_qic(p_data,
    x = date, y = events, n = n, chart_type = "p",
    y_axis_unit = "percent"
  )

  ctx <- bfh_build_analysis_context(result, metadata = list(target = 0.9))
  expect_equal(ctx$target_value, 0.9, tolerance = 1e-9)
})

test_that("bfh_build_analysis_context: '>= 0.9' på p-chart bevares uændret (ingen % i display)", {
  set.seed(11)
  p_data <- data.frame(
    date   = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    n      = rep(100L, 20),
    events = rep(91L, 20)
  )
  result <- bfh_qic(p_data,
    x = date, y = events, n = n, chart_type = "p",
    y_axis_unit = "percent"
  )

  ctx <- bfh_build_analysis_context(result, metadata = list(target = ">= 0.9"))
  expect_equal(ctx$target_value, 0.9, tolerance = 1e-9)
  expect_equal(ctx$target_display, ">= 0.9")
})

test_that("bfh_build_analysis_context: i-chart target=90 ikke normaliseret (count-skala)", {
  set.seed(42)
  i_data <- data.frame(
    date  = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rnorm(20, mean = 95, sd = 5)
  )
  result <- bfh_qic(i_data, x = date, y = value, chart_type = "i")

  ctx <- bfh_build_analysis_context(result, metadata = list(target = ">= 90"))
  expect_equal(ctx$target_value, 90,
    label = "i-chart count-skala: 90 bevares uændret"
  )
})


# ==============================================================================
# Target fallback chain (metadata -> config$target_text -> config$target_value)
# Issue #1 (Codex 2026-04-30): Chart-target skal flyde til analyse uden
# at caller duplikerer i metadata.
# ==============================================================================

test_that("Target fallback: metadata-only target preserves existing behavior", {
  set.seed(101)
  i_data <- data.frame(
    date  = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rnorm(20, mean = 95, sd = 5)
  )
  result <- bfh_qic(i_data, x = date, y = value, chart_type = "i")
  # Bekræft at chart ikke selv har target (regression-baseline)
  expect_null(result$config$target_text)
  expect_null(result$config$target_value)

  ctx <- bfh_build_analysis_context(result, metadata = list(target = ">= 90"))
  expect_equal(ctx$target_value, 90)
  expect_equal(ctx$target_direction, "higher")
})

test_that("Target fallback: chart target_value (numeric) used when metadata absent", {
  set.seed(102)
  i_data <- data.frame(
    date  = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rnorm(20, mean = 95, sd = 5)
  )
  result <- bfh_qic(i_data, x = date, y = value, chart_type = "i", target_value = 85)
  expect_equal(result$config$target_value, 85)

  ctx <- bfh_build_analysis_context(result, metadata = list())
  expect_equal(ctx$target_value, 85,
    label = "config$target_value bruges som fallback når metadata$target er NULL"
  )
  expect_null(ctx$target_direction,
    label = "Numerisk target har ingen retning (matcher resolve_target-kontrakt)"
  )
})

test_that("Target fallback: chart target_text (character with operator) used when metadata absent", {
  set.seed(103)
  i_data <- data.frame(
    date  = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rnorm(20, mean = 95, sd = 5)
  )
  result <- bfh_qic(i_data,
    x = date, y = value, chart_type = "i",
    target_text = ">= 90"
  )
  expect_equal(result$config$target_text, ">= 90")

  ctx <- bfh_build_analysis_context(result, metadata = list())
  expect_equal(ctx$target_value, 90,
    label = "config$target_text parser-stien bruges som fallback"
  )
  expect_equal(ctx$target_direction, "higher",
    label = "Operator-retning bevares gennem fallback"
  )
})

test_that("Target fallback: metadata overrides chart config when both present", {
  set.seed(104)
  i_data <- data.frame(
    date  = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rnorm(20, mean = 95, sd = 5)
  )
  result <- bfh_qic(i_data,
    x = date, y = value, chart_type = "i",
    target_text = ">= 90"
  )

  ctx <- bfh_build_analysis_context(result, metadata = list(target = "<= 50"))
  expect_equal(ctx$target_value, 50,
    label = "metadata$target overrider config (eksplicit caller wins)"
  )
  expect_equal(ctx$target_direction, "lower")
})

test_that("Target fallback: percent-target via config flows through normalize_percent_target", {
  set.seed(105)
  p_data <- data.frame(
    date   = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    n      = rep(100L, 20),
    events = rep(91L, 20)
  )
  result <- bfh_qic(p_data,
    x = date, y = events, n = n, chart_type = "p",
    y_axis_unit = "percent",
    target_text = ">= 90%"
  )

  ctx <- bfh_build_analysis_context(result, metadata = list())
  expect_equal(ctx$target_value, 0.90,
    tolerance = 1e-9,
    label = "Percent-normalisering virker også når target kommer fra config"
  )
  expect_equal(ctx$target_direction, "higher")
  expect_equal(ctx$target_display, ">= 90%")
})

test_that("Target fallback: no target anywhere yields NA target_value", {
  set.seed(106)
  i_data <- data.frame(
    date  = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rnorm(20, mean = 95, sd = 5)
  )
  result <- bfh_qic(i_data, x = date, y = value, chart_type = "i")

  ctx <- bfh_build_analysis_context(result, metadata = list())
  expect_true(is.na(ctx$target_value),
    label = "resolve_target() returnerer NA_real_ for NULL-input"
  )
  expect_null(ctx$target_direction)
})

# ==============================================================================
# Process-variation-based at_target classification
# (openspec change: at-target-tolerance-process-variation)
# ==============================================================================

test_that("at_target classifies CORRECTLY for tight process with small target (bug reproducer)", {
  # Bug rapporteret af maintainer: target = "<1%" (proportionsskala: 0.01),
  # centerline = 0.019, smalle kontrolgraenser (UCL-LCL ~= 0.01).
  # Under den gamle regel: tolerance = max(0.01*0.05, 0.01) = 0.01 dominerer ->
  # |0.019-0.01| = 0.009 <= 0.01 -> at_target = TRUE (forkert).
  # Under den nye regel: sigma_hat = 0.01/6 ~= 0.0017, 3*sigma_hat ~= 0.005 ->
  # 0.009 > 0.005 -> at_target = FALSE (korrekt).
  # NB: target_direction = NULL, ellers rammer vi goal_not_met-grenen.
  ctx <- fixture_analysis_context(
    target_value = 0.01,
    target_direction = NULL,
    centerline = 0.019,
    sigma_hat = 0.01 / 6, # half-width = 3*sigma => sigma = (UCL-LCL)/6
    sigma_data = 0.002,
    target_display = "0.01"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  expect_true(grepl("over (udviklings)?m.let|over (udviklings)?malet", txt),
    info = paste("Forventede over_target, fik:", txt)
  )
  expect_false(grepl("t.t p. (udviklings)?m.let|naer (udviklings)?m.let", txt))
})

test_that("at_target classifies CORRECTLY when target is inside wide control limits", {
  # Vid process: UCL=12, LCL=2 -> sigma_hat = 10/6 ~= 1.67, 3*sigma_hat = 5.
  # target=5, centerline=7 -> |7-5|=2 <= 5 -> at_target = TRUE.
  ctx <- fixture_analysis_context(
    target_value = 5,
    target_direction = NULL,
    centerline = 7,
    sigma_hat = 10 / 6,
    target_display = "5"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  expect_true(grepl("t.t p. (udviklings)?m.let", txt),
    info = paste("Forventede at_target, fik:", txt)
  )
})

test_that("at_target falls back to sd(y) when sigma_hat is NA (run chart)", {
  # Run chart har ingen UCL/LCL -> sigma_hat = NA, men sigma_data = sd(y).
  # target=10, centerline=11, sd(y)=2 -> |11-10|=1 <= 2 -> at_target = TRUE.
  ctx <- fixture_analysis_context(
    target_value = 10,
    target_direction = NULL,
    centerline = 11,
    sigma_hat = NA_real_,
    sigma_data = 2,
    target_display = "10"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  expect_true(grepl("t.t p. (udviklings)?m.let", txt),
    info = paste("Forventede at_target via sd-fallback, fik:", txt)
  )
})

test_that("at_target falls back to sd(y) and classifies over_target when delta exceeds sd", {
  # Run chart hvor target ligger uden for sd-baeltet.
  ctx <- fixture_analysis_context(
    target_value = 10,
    target_direction = NULL,
    centerline = 15,
    sigma_hat = NA_real_,
    sigma_data = 2,
    target_display = "10"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  expect_true(grepl("over (udviklings)?m.let", txt),
    info = paste("Forventede over_target, fik:", txt)
  )
})

test_that("at_target uses exact-match when both sigma_hat and sigma_data are zero/NA", {
  # Degenereret case: konstant y, ingen variation. CL == target -> at_target.
  ctx <- fixture_analysis_context(
    target_value = 5,
    target_direction = NULL,
    centerline = 5,
    sigma_hat = 0,
    sigma_data = 0,
    target_display = "5"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  expect_true(grepl("t.t p. (udviklings)?m.let", txt),
    info = paste("Forventede at_target via eksakt-match, fik:", txt)
  )
})

test_that("at_target eksakt-match: lille forskel klassificeres som over/under", {
  # CL er minimalt over target med ingen variation -> over_target.
  ctx <- fixture_analysis_context(
    target_value = 5,
    target_direction = NULL,
    centerline = 5.001,
    sigma_hat = 0,
    sigma_data = 0,
    target_display = "5"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  expect_true(grepl("over (udviklings)?m.let", txt))
})

test_that("at_target classifies inclusively at the 3*sigma_hat boundary", {
  # Boundary case: |CL - target| = 3*sigma_hat exactly.
  # Forventning: <=-konvention inkluderer graensen -> at_target.
  sigma <- 1
  ctx <- fixture_analysis_context(
    target_value = 8,
    target_direction = NULL,
    centerline = 5,
    sigma_hat = sigma, # 3*sigma = 3; |5-8| = 3 = 3 -> at_target
    target_display = "8"
  )
  txt <- BFHcharts:::build_fallback_analysis(ctx)
  expect_true(grepl("t.t p. (udviklings)?m.let", txt),
    info = paste("Forventede at_target ved <=-graense, fik:", txt)
  )
})

test_that("bfh_build_analysis_context computes sigma_hat from qic_data (constant limits)", {
  # i-chart med konstante graenser -> sigma_hat = (UCL-LCL)/6 paa hver raekke,
  # mean er ~konstant.
  set.seed(2030)
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 100, sd = 10)
  )
  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
  ctx <- bfh_build_analysis_context(result, metadata = list())

  expect_true(is.numeric(ctx$sigma_hat))
  expect_true(is.finite(ctx$sigma_hat))
  expect_gt(ctx$sigma_hat, 0)
  # Forventning: sigma_hat ~= sd(value) * d4-ish for i-chart. Vi kraever blot
  # konsistens med (UCL-LCL)/6 fra qic_data.
  qd <- result$qic_data
  expected <- mean((qd$ucl - qd$lcl) / 6, na.rm = TRUE)
  expect_equal(ctx$sigma_hat, expected, tolerance = 1e-9)
})

test_that("bfh_build_analysis_context returns NA sigma_hat for run charts", {
  set.seed(2031)
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 100, sd = 10)
  )
  result <- bfh_qic(test_data, x = date, y = value, chart_type = "run")
  ctx <- bfh_build_analysis_context(result, metadata = list())

  # Run charts har ingen ucl/lcl -> sigma_hat = NA, men sigma_data > 0.
  expect_true(is.na(ctx$sigma_hat))
  expect_true(is.finite(ctx$sigma_data))
  expect_gt(ctx$sigma_data, 0)
})

test_that("bfh_build_analysis_context filters qic_data to last phase for sigma", {
  # Multi-phase via freeze (numerisk index): foerste fase har anderledes
  # spredning end anden fase. sigma_hat skal kun afspejle sidste fase.
  set.seed(2032)
  n_per_phase <- 15
  phase1 <- rnorm(n_per_phase, mean = 50, sd = 20) # vid
  phase2 <- rnorm(n_per_phase, mean = 50, sd = 5) # smal
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"),
      by = "month",
      length.out = 2 * n_per_phase
    ),
    value = c(phase1, phase2)
  )

  result <- bfh_qic(test_data,
    x = date, y = value, chart_type = "i",
    freeze = n_per_phase
  )
  ctx <- bfh_build_analysis_context(result, metadata = list())

  # Verificer: sigma_hat fra sidste fase alene.
  qd <- result$qic_data
  if ("part" %in% names(qd)) {
    qd_last <- qd[qd$part == max(qd$part, na.rm = TRUE), ]
    expected <- mean((qd_last$ucl - qd_last$lcl) / 6, na.rm = TRUE)
    expect_equal(ctx$sigma_hat, expected,
      tolerance = 1e-9,
      info = "sigma_hat skal beregnes fra sidste fase alene"
    )
  } else {
    skip("freeze_period ikke supporteret af denne qicharts2-version")
  }
})

# ==============================================================================
# target_tolerance deprecation
# ==============================================================================

test_that("bfh_generate_analysis warns when target_tolerance is passed", {
  set.seed(2040)
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rnorm(20, mean = 50, sd = 5)
  )
  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  # Eksplicit videregivelse af target_tolerance (selv default-vaerdien) skal
  # fyre deprecation-warning. missing()-detektion sondrer paa "blev argumentet
  # angivet", ikke paa "vaerdien er default".
  expect_warning(
    bfh_generate_analysis(result, target_tolerance = 0.1),
    "deprecat"
  )
  expect_warning(
    bfh_generate_analysis(result, target_tolerance = 0.05),
    "deprecat"
  )
})

test_that("bfh_generate_analysis does NOT warn when target_tolerance omitted", {
  set.seed(2041)
  test_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 20),
    value = rnorm(20, mean = 50, sd = 5)
  )
  result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")

  # Default-kald uden argumentet maa ikke fyre advarsel. expect_no_warning
  # filtrerer kun deprecation-klassen for at undgaa falsk-positive paa andre
  # advarsler (fx fra qicharts2 om sparsom data).
  withCallingHandlers(
    {
      bfh_generate_analysis(result)
    },
    warning = function(w) {
      if (inherits(w, "lifecycle_warning_deprecated")) {
        fail("Default-kald maa ikke fyre target_tolerance-deprecation")
      }
      invokeRestart("muffleWarning")
    }
  )
  succeed("Default-kald fyrer ikke target_tolerance-deprecation")
})
