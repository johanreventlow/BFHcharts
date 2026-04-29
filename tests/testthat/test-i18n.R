test_that("alle nøgler i da.yaml findes også i en.yaml (key parity)", {
  da_path <- system.file("i18n", "da.yaml", package = "BFHcharts")
  en_path <- system.file("i18n", "en.yaml", package = "BFHcharts")
  skip_if(da_path == "", "da.yaml ikke fundet")
  skip_if(en_path == "", "en.yaml ikke fundet")

  da <- yaml::read_yaml(da_path)
  en <- yaml::read_yaml(en_path)

  # Rekursiv funktion: alle blade-nøglestier i en nested liste
  leaf_paths <- function(x, prefix = "") {
    if (!is.list(x)) {
      return(prefix)
    }
    paths <- character(0)
    for (nm in names(x)) {
      child_prefix <- if (nchar(prefix) == 0) nm else paste(prefix, nm, sep = ".")
      paths <- c(paths, leaf_paths(x[[nm]], child_prefix))
    }
    paths
  }

  da_keys <- leaf_paths(da)
  en_keys <- leaf_paths(en)

  missing_in_en <- setdiff(da_keys, en_keys)
  expect_equal(
    missing_in_en, character(0),
    info = paste("Nøgler i da.yaml men ikke i en.yaml:", paste(missing_in_en, collapse = ", "))
  )

  # Bidirektionel paritet: EN må ikke have nøgler der mangler i DA
  missing_in_da <- setdiff(en_keys, da_keys)
  expect_equal(
    missing_in_da, character(0),
    info = paste("Nøgler i en.yaml men ikke i da.yaml:", paste(missing_in_da, collapse = ", "))
  )
})

test_that("load_translations returnerer liste for 'da'", {
  BFHcharts:::bfh_reset_caches()
  result <- BFHcharts:::load_translations("da")
  expect_type(result, "list")
  expect_true(length(result) > 0)
})

test_that("load_translations returnerer liste for 'en'", {
  BFHcharts:::bfh_reset_caches()
  result <- BFHcharts:::load_translations("en")
  expect_type(result, "list")
  expect_true(length(result) > 0)
})

test_that("load_translations fejler ved ukendt sprog", {
  expect_error(
    BFHcharts:::load_translations("fr"),
    "language must be one of"
  )
})

test_that("i18n_lookup returnerer dansk streng", {
  BFHcharts:::bfh_reset_caches()
  expect_equal(BFHcharts:::i18n_lookup("labels.interval.monthly", "da"), "måned")
  expect_equal(BFHcharts:::i18n_lookup("labels.chart.development_goal", "da"), "UDVIKLINGSMÅL")
})

test_that("i18n_lookup returnerer engelsk streng", {
  BFHcharts:::bfh_reset_caches()
  expect_equal(BFHcharts:::i18n_lookup("labels.interval.monthly", "en"), "month")
  expect_equal(BFHcharts:::i18n_lookup("labels.chart.development_goal", "en"), "TARGET")
})

test_that("i18n_lookup falder tilbage til dansk ved manglende nøgle i en", {
  BFHcharts:::bfh_reset_caches()
  # Ukendt nøgle → advarsel + returnerer key-strengen
  expect_warning(
    result <- BFHcharts:::i18n_lookup("labels.nonexistent.key", "da"),
    "i18n key not found"
  )
  expect_equal(result, "labels.nonexistent.key")
})

test_that("validate_language fejler ved ukendt sprog", {
  expect_error(
    BFHcharts:::validate_language("fr"),
    "language must be one of"
  )
})

test_that("bfh_generate_details accepterer language = 'da' (default)", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")
  details_da <- bfh_generate_details(result, language = "da")
  expect_true(grepl("Periode", details_da))
  expect_true(grepl("Gns\\.", details_da))
  expect_true(grepl("Seneste", details_da))
  expect_true(grepl("Nuv", details_da))
})

test_that("bfh_generate_details returnerer engelsk tekst med language = 'en'", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")
  details_en <- bfh_generate_details(result, language = "en")
  expect_true(grepl("Period", details_en))
  expect_true(grepl("Avg\\.", details_en))
  expect_true(grepl("Latest", details_en))
})

test_that("bfh_generate_details er bagudkompatibel (ingen language param)", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")
  # Skal virke uden language — default = "da"
  details <- bfh_generate_details(result)
  expect_true(grepl("Periode", details))
})

test_that("bfh_generate_analysis er bagudkompatibel (ingen language param)", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")
  analysis <- bfh_generate_analysis(result, use_ai = FALSE)
  expect_type(analysis, "character")
  expect_true(nchar(analysis) > 0)
})

test_that("bfh_generate_analysis returnerer engelsk tekst med language = 'en'", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")
  analysis_en <- bfh_generate_analysis(result, use_ai = FALSE, language = "en")
  expect_type(analysis_en, "character")
  # Dansk tekst ikke til stede
  expect_false(grepl("stabil og forudsigelig|niveauskift", analysis_en))
})

test_that("bfh_generate_analysis fejler ved ukendt language", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")
  expect_error(
    bfh_generate_analysis(result, use_ai = FALSE, language = "fr"),
    "language must be one of"
  )
})

test_that("texts_loader stadig virker som mock-parameter", {
  set.seed(42)
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 12),
    value = rnorm(12, mean = 50, sd = 5)
  )
  result <- bfh_qic(data, x = date, y = value, chart_type = "i")

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
