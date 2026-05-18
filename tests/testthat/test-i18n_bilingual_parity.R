# Tests: Phase 99.3 -- Bilingual parity CI-gate
#
# Sikrer at inst/i18n/da.yaml + en.yaml er strukturelt synkrone:
#  - Samme nøgle-saet
#  - Samme placeholders ({...}) i hver template
#  - Magnitude-formatering respekterer sprog-specifik decimal-separator
#
# Refs: openspec change restructure-spc-analysis-architecture, Phase 99.3

library(yaml)


# Helper: flatten nested YAML-list til dotted paths (a.b.c.short, ...)
.flatten_yaml_paths <- function(x, prefix = "") {
  if (!is.list(x)) {
    return(prefix)
  }
  if (length(x) == 0L) {
    return(character(0L))
  }
  child_paths <- lapply(names(x), function(name) {
    new_prefix <- if (nzchar(prefix)) paste0(prefix, ".", name) else name
    .flatten_yaml_paths(x[[name]], new_prefix)
  })
  unlist(child_paths)
}


# Helper: extract {...}-placeholders fra streng
.extract_placeholders <- function(s) {
  if (is.null(s) || !is.character(s) || length(s) == 0L) {
    return(character(0L))
  }
  matches <- regmatches(s, gregexpr("\\{[^}]+\\}", s))[[1]]
  sort(unique(matches))
}


# Helper: get value at dotted path via traversal
.path_get <- function(x, path) {
  parts <- strsplit(path, ".", fixed = TRUE)[[1]]
  v <- x
  for (p in parts) {
    if (is.null(v) || !is.list(v) || !p %in% names(v)) {
      return(NULL)
    }
    v <- v[[p]]
  }
  v
}


.load_yaml <- function(lang) {
  path <- system.file("i18n", paste0(lang, ".yaml"), package = "BFHcharts")
  if (!nzchar(path)) {
    # Fallback til worktree-pad ved load_all-context
    pkg_root <- normalizePath(file.path(getwd(), ".."), mustWork = FALSE)
    path <- file.path(pkg_root, "inst", "i18n", paste0(lang, ".yaml"))
  }
  yaml::read_yaml(path)
}


# ==========================================================================
# Phase 99.3.1: key-paritet -- alle paths i da har modstykke i en og omvendt
# ==========================================================================

test_that("Phase 99.3: alle YAML-paths har modstykke i begge sprog", {
  da <- .load_yaml("da")
  en <- .load_yaml("en")

  da_paths <- .flatten_yaml_paths(da)
  en_paths <- .flatten_yaml_paths(en)

  expect_setequal(da_paths, en_paths)
})


# ==========================================================================
# Phase 99.3.2: placeholder-paritet -- {target}, {centerline} etc samme set
# ==========================================================================

test_that("Phase 99.3: placeholders matches mellem da og en per nøgle", {
  da <- .load_yaml("da")
  en <- .load_yaml("en")

  # Whitelist af pre-existing placeholder-divergens i legacy-templates
  # (en.yaml udelader {centerline}-substitution i nogle detailed-varianter
  # for at producere kortere prose). Disse bevares for backward-compat
  # men ingen NYE divergenser tillades.
  KNOWN_DIVERGENCES <- c(
    "analysis.stability.outliers_only.standard",
    "analysis.stability.outliers_only.detailed",
    "analysis.target.at_target.detailed",
    "analysis.target.over_target.detailed",
    "analysis.target.under_target.detailed",
    "analysis.target.goal_met.detailed",
    "analysis.target.goal_not_met.detailed",
    "analysis.action.stable_goal_not_met.detailed",
    "analysis.action.stable_near_target.short",
    "analysis.action.stable_near_target.detailed",
    "analysis.action.unstable_near_target.detailed"
  )

  da_paths <- .flatten_yaml_paths(da)
  new_mismatches <- list()

  for (path in da_paths) {
    if (path %in% KNOWN_DIVERGENCES) next
    da_value <- .path_get(da, path)
    en_value <- .path_get(en, path)
    if (!is.character(da_value) || !is.character(en_value)) next
    da_ph <- .extract_placeholders(da_value)
    en_ph <- .extract_placeholders(en_value)
    if (!setequal(da_ph, en_ph)) {
      new_mismatches[[path]] <- list(da = da_ph, en = en_ph)
    }
  }

  if (length(new_mismatches) > 0L) {
    msg <- paste0(
      "NEW placeholder-mismatch i ", length(new_mismatches), " nøgle(r) ",
      "(ej i KNOWN_DIVERGENCES-whitelist):\n  ",
      paste(names(new_mismatches), collapse = "\n  ")
    )
    fail(msg)
  } else {
    expect_true(TRUE)
  }
})


# ==========================================================================
# Phase 99.3.3: format_target_value respekterer sprog
# ==========================================================================

test_that("Phase 99.3: format_target_value bruger korrekt decimal-separator", {
  # da: komma
  expect_equal(
    BFHcharts:::format_target_value(1.5, y_axis_unit = "count", language = "da"),
    "1,5"
  )
  expect_equal(
    BFHcharts:::format_target_value(50.59, y_axis_unit = "count", language = "da"),
    "50,59"
  )

  # en: punktum
  expect_equal(
    BFHcharts:::format_target_value(1.5, y_axis_unit = "count", language = "en"),
    "1.5"
  )
  expect_equal(
    BFHcharts:::format_target_value(50.59, y_axis_unit = "count", language = "en"),
    "50.59"
  )
})


test_that("Phase 99.3: format_target_value percent rendres ens (% er sprog-neutralt)", {
  # x in [0,1] -> percent conversion. Hele tal -> ingen decimal-separator
  expect_equal(
    BFHcharts:::format_target_value(0.9, y_axis_unit = "percent", language = "da"),
    "90%"
  )
  expect_equal(
    BFHcharts:::format_target_value(0.9, y_axis_unit = "percent", language = "en"),
    "90%"
  )
})


# ==========================================================================
# Phase 99.3.4: regression -- gentaget kald giver samme output (cache stable)
# ==========================================================================

test_that("Phase 99.3: load_spc_texts() er deterministisk pa tvaers af kald", {
  texts1 <- BFHcharts:::load_spc_texts("da")
  texts2 <- BFHcharts:::load_spc_texts("da")
  expect_identical(texts1, texts2)
})


# ==========================================================================
# Phase 99.3.5: Slice-specifikke modifier-keys er tilstede i begge sprog
# ==========================================================================

test_that("Phase 99.3: Slice 3 magnitude-keys i begge sprog", {
  da <- .load_yaml("da")
  en <- .load_yaml("en")

  for (tier in c("small", "medium", "large")) {
    for (variant in c("short", "standard", "detailed")) {
      path <- paste0("analysis.modifier.magnitude.", tier, ".", variant)
      expect_false(is.null(.path_get(da, path)), info = paste("da missing:", path))
      expect_false(is.null(.path_get(en, path)), info = paste("en missing:", path))
    }
  }
})


test_that("Phase 99.3: Slice 4 direction-keys i begge sprog", {
  da <- .load_yaml("da")
  en <- .load_yaml("en")

  for (dir in c("favorable", "unfavorable")) {
    for (variant in c("short", "standard", "detailed")) {
      path <- paste0("analysis.modifier.direction.", dir, ".", variant)
      expect_false(is.null(.path_get(da, path)), info = paste("da missing:", path))
      expect_false(is.null(.path_get(en, path)), info = paste("en missing:", path))
    }
  }
})


test_that("Phase 99.3: Slice 5 baseline_delta-keys i begge sprog", {
  da <- .load_yaml("da")
  en <- .load_yaml("en")

  for (variant in c("short", "standard", "detailed")) {
    path <- paste0("analysis.modifier.baseline_delta.", variant)
    expect_false(is.null(.path_get(da, path)), info = paste("da missing:", path))
    expect_false(is.null(.path_get(en, path)), info = paste("en missing:", path))
  }
})


test_that("Phase 99.3: Slice 7 + 14 + 9 caveats-keys i begge sprog", {
  da <- .load_yaml("da")
  en <- .load_yaml("en")

  caveats <- c(
    "cl_user_supplied", "cl_auto_mean",
    "discrete_scale_mild", "discrete_scale_moderate",
    "variable_cl"
  )
  for (k in caveats) {
    path <- paste0("labels.caveats.", k)
    expect_false(is.null(.path_get(da, path)), info = paste("da missing:", path))
    expect_false(is.null(.path_get(en, path)), info = paste("en missing:", path))
  }
})


test_that("Phase 99.3: Slice 8 not_evaluable-keys i begge sprog", {
  da <- .load_yaml("da")
  en <- .load_yaml("en")

  for (variant in c("short", "standard", "detailed")) {
    path <- paste0("analysis.base.not_evaluable.", variant)
    expect_false(is.null(.path_get(da, path)), info = paste("da missing:", path))
    expect_false(is.null(.path_get(en, path)), info = paste("en missing:", path))
  }
})
