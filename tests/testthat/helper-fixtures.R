# ============================================================================
# Test Fixtures — centraliserede factories
# ============================================================================
#
# Fælles test data-factories. Erstatter duplikerede lokale make_* funktioner
# fra flere testfiler.
#
# Navngivning: fixture_* prefix for at tydeliggøre at det er testfactories
# (ikke produktions-API). Undgår navnekollision med eksisterende lokale
# make_qic_data()-funktioner med forskellige signaturer.
#
# Reference: openspec/changes/strengthen-test-infrastructure (Fase 2 task 6.2)
# Spec: test-infrastructure, "Test fixtures SHALL be centralized and deterministic"

# ----------------------------------------------------------------------------
# Minimal chart-input (erstatter inline data.frame()-konstruktioner)
# ----------------------------------------------------------------------------

#' Minimal canonical chart input dataset
#'
#' Deterministisk data.frame med `month` og `infections` kolonner til at
#' teste bfh_qic()-pipeline. Erstatter 40+ inline-konstruktioner.
#'
#' @param n Antal måneder (default 12)
#' @param lambda Poisson-lambda for infections (default 15)
#' @param seed RNG-seed (default 42)
#' @return data.frame med month (Date), infections (integer)
#' @keywords internal
fixture_minimal_chart_data <- function(n = 12, lambda = 15, seed = 42) {
  set.seed(seed)
  data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = n),
    infections = rpois(n, lambda = lambda)
  )
}

#' Deterministisk chart-data uden RNG
#'
#' Håndlavet vektor — robust over R-versioner og RNGkind-skift.
#' Bruges når tests verificerer specifikke numeriske værdier.
#'
#' @param n Antal punkter (default 12; tages modulo fra 12-punkts pattern)
#' @return data.frame med month (Date), infections (integer)
#' @keywords internal
fixture_deterministic_chart_data <- function(n = 12) {
  values <- c(14, 16, 13, 15, 18, 12, 17, 14, 19, 13, 15, 16)
  data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = n),
    infections = rep_len(values, n)
  )
}

# ----------------------------------------------------------------------------
# Plot-niveau qic_data (bfh_spc_plot input)
# ----------------------------------------------------------------------------

#' Minimal qic_data-struktur til bfh_spc_plot() tests
#'
#' Konsoliderer den version der tidligere eksisterede som lokal
#' `make_qic_data()` i test-plot_core.R. Bruges til at teste den low-level
#' plot-rendering uden at involvere hele qicharts2-pipelinen.
#'
#' @param n Antal punkter
#' @param x_dates TRUE → Date x-akse; FALSE → integer
#' @param has_cl_limits TRUE → ucl/lcl kolonner tilføjet
#' @param sigma_signals Vector af logical (eller NULL for alle FALSE)
#' @param anhoej_signals Vector af logical (eller NULL for alle FALSE)
#' @param target_val Numerisk target-værdi (NA for ingen target)
#' @param parts Vector af part-integers (eller NULL for part=1 overalt)
#' @return data.frame med minimum-kolonner til bfh_spc_plot()
#' @keywords internal
fixture_plot_qic_data <- function(
  n = 12,
  x_dates = TRUE,
  has_cl_limits = TRUE,
  sigma_signals = NULL,
  anhoej_signals = NULL,
  target_val = NA_real_,
  parts = NULL
) {
  if (x_dates) {
    x_vals <- as.Date("2024-01-01") + 0:(n - 1) * 30
  } else {
    x_vals <- seq_len(n)
  }

  y_vals <- c(50, 52, 48, 55, 47, 51, 49, 53, 50, 48, 52, 51)
  if (n != 12) y_vals <- rep_len(y_vals, n)

  d <- data.frame(
    x = x_vals,
    y = y_vals,
    cl = rep(50.5, n),
    part = if (is.null(parts)) rep(1L, n) else parts,
    sigma.signal = if (is.null(sigma_signals)) rep(FALSE, n) else sigma_signals,
    anhoej.signal = if (is.null(anhoej_signals)) rep(FALSE, n) else anhoej_signals,
    target = rep(target_val, n)
  )

  if (has_cl_limits) {
    d$ucl <- rep(59, n)
    d$lcl <- rep(42, n)
  }

  d
}

# ----------------------------------------------------------------------------
# qicharts2-format summary-input (format_qic_summary tests)
# ----------------------------------------------------------------------------

#' Fuld qicharts2-lignende data frame til format_qic_summary() tests
#'
#' Konsoliderer versionen fra test-utils_qic_summary.R. Bruges til at teste
#' formaterings-laget der konverterer qicharts2-output til danske kolonner.
#'
#' @param n Antal rækker (skal være deleligt med parts)
#' @param chart_type Chart-type streng (default "i")
#' @param parts Antal faser (default 1)
#' @param add_signals Hvis TRUE, indsæt runs.signal = TRUE i første del
#' @return data.frame med qicharts2's typiske kolonne-struktur
#' @keywords internal
fixture_qicharts_summary_data <- function(n = 24,
                                          chart_type = "i",
                                          parts = 1,
                                          add_signals = FALSE) {
  # Note: bruger set.seed her fordi det er helper-niveau — kalderen bør ikke
  # regne med at RNG-state bevares. For deterministiske numerical-tests:
  # brug fixture_deterministic_chart_data().
  set.seed(42)
  df <- data.frame(
    x = seq.Date(as.Date("2024-01-01"), by = "month", length.out = n),
    y = rnorm(n, mean = 50, sd = 5),
    cl = rep(50, n),
    lcl = rep(35, n),
    ucl = rep(65, n),
    n.obs = rep(n, n),
    n.useful = rep(n, n),
    longest.run = rep(4L, n),
    longest.run.max = rep(9L, n),
    n.crossings = rep(8L, n),
    n.crossings.min = rep(5L, n),
    runs.signal = rep(FALSE, n),
    sigma.signal = rep(FALSE, n),
    part = rep(seq_len(parts), each = n / parts),
    facet1 = rep(1, n),
    facet2 = rep(1, n),
    stringsAsFactors = FALSE
  )

  if (add_signals) {
    half <- n / 2
    df$longest.run[1:half] <- 12L
    df$runs.signal[1:half] <- TRUE
  }

  df
}

# ----------------------------------------------------------------------------
# bfh_qic_result S3-objekt
# ----------------------------------------------------------------------------

#' Konstrueret bfh_qic_result med kontrolleret sigma.signal
#'
#' Konsoliderer `make_fixture_result()` fra test-extract-spc-stats-dispatch.R.
#' Bruges til at teste S3-dispatch-logik uden at køre hele bfh_qic-pipelinen.
#'
#' @param sigma_signal Vector af logical til sigma.signal-kolonnen
#' @param part Vector af part-integers (NULL → ingen part-kolonne)
#' @param chart_type Chart-type-string (for config$chart_type)
#' @param summary_cols Named list med override-værdier til summary-data.frame
#' @return bfh_qic_result S3-objekt
#' @keywords internal
fixture_bfh_qic_result <- function(sigma_signal,
                                   part = NULL,
                                   chart_type = "i",
                                   summary_cols = list()) {
  n <- length(sigma_signal)
  qic_data <- data.frame(
    x = seq_len(n),
    y = seq_len(n),
    cl = rep(0, n),
    sigma.signal = sigma_signal
  )
  if (!is.null(part)) qic_data$part <- part

  default_summary <- data.frame(
    laengste_loeb = 3L,
    laengste_loeb_max = 7L,
    antal_kryds = 6L,
    antal_kryds_min = 4L,
    centerlinje = 0
  )
  for (nm in names(summary_cols)) default_summary[[nm]] <- summary_cols[[nm]]

  structure(
    list(
      plot = ggplot2::ggplot(),
      summary = default_summary,
      qic_data = qic_data,
      config = list(chart_type = chart_type)
    ),
    class = c("bfh_qic_result", "list")
  )
}

# ----------------------------------------------------------------------------
# Test-chart via bfh_qic() (real pipeline, produktions-lignende)
# ----------------------------------------------------------------------------

#' Typisk test-chart oprettet via faktisk bfh_qic()-kald
#'
#' Konsoliderer `create_test_chart()` fra test-security-export-pdf.R.
#' Bruges af tests der har brug for et ægte bfh_qic_result (ikke fixture).
#'
#' @param title Chart-titel (default "Test")
#' @param n Antal datapunkter (default 12)
#' @param lambda Poisson-lambda (default 15)
#' @return bfh_qic_result
#' @keywords internal
fixture_test_chart <- function(title = "Test", n = 12, lambda = 15) {
  data <- fixture_minimal_chart_data(n = n, lambda = lambda)
  bfh_qic(data,
    x = month,
    y = infections,
    chart_type = "i",
    chart_title = title
  )
}

# ----------------------------------------------------------------------------
# Analysis context (spc_analysis tests)
# ----------------------------------------------------------------------------

#' Minimal analyse-context til build_fallback_analysis() tests
#'
#' Konsoliderer `make_ctx()` fra test-spc_analysis.R.
#'
#' @param ... Named args der overskriver defaults (fx target_value, centerline)
#' @param spc_stats Override af spc_stats-liste (runs/crossings/outliers)
#' @return Named list med alle felter bfh_build_analysis_context() producerer
#' @keywords internal
fixture_analysis_context <- function(...,
                                     spc_stats = list(
                                       runs_actual = 5,
                                       runs_expected = 7,
                                       crossings_actual = 8,
                                       crossings_expected = 5,
                                       outliers_recent_count = 0
                                     )) {
  defaults <- list(
    chart_title = "Test",
    chart_type = "i",
    y_axis_unit = NULL,
    n_points = 20,
    centerline = 50,
    spc_stats = spc_stats,
    has_signals = FALSE,
    sigma_hat = NA_real_,
    sigma_data = NA_real_,
    data_definition = NULL,
    target_value = NA_real_,
    target_direction = NULL,
    target_display = "",
    hospital = NULL,
    department = NULL
  )
  modifyList(defaults, list(...))
}

# ----------------------------------------------------------------------------
# Simpel numerisk data (test-plot_margin.R mv.)
# ----------------------------------------------------------------------------

#' Minimal numerisk test-data frame
#'
#' Konsoliderer `setup_test_data()` fra test-plot_margin.R.
#'
#' @param n Antal punkter (default 24)
#' @param mean Gennemsnit (default 100)
#' @param sd Standard-afvigelse (default 10)
#' @param seed RNG-seed
#' @return data.frame med x (integer), y (numeric)
#' @keywords internal
fixture_numeric_data <- function(n = 24, mean = 100, sd = 10, seed = 42) {
  set.seed(seed)
  data.frame(
    x = seq_len(n),
    y = rnorm(n, mean = mean, sd = sd)
  )
}


# =============================================================================
# Structured SPC analysis fixtures (Phase 99 + 100 test-infra)
# =============================================================================

#' Stable test-data (24 punkter, rnorm 50, sd=3-5)
#'
#' Producerer deterministisk single-phase data uden signals. Brugt af
#' structured-analysis test-files (test-spc_features, test-spc_compose,
#' test-spc_render, test-spc_schema_stability, test-spc_golden_corpus).
#' withr::with_seed scoper RNG saa fixture ej forurener test-order.
#'
#' @param seed RNG-seed
#' @param n Antal observationer
#' @param mean Vaerdi-mean
#' @param sd Standard-afvigelse
#' @return data.frame med date + value
#' @keywords internal
fixture_phase_stable <- function(seed = 991L, n = 24L, mean = 50, sd = 5) {
  withr::with_seed(seed, {
    data.frame(
      date = seq(as.Date("2024-01-01"), by = "month", length.out = n),
      value = round(rnorm(n, mean, sd), 1)
    )
  })
}


#' Konstant data (no_variation override)
#' @keywords internal
fixture_phase_constant <- function(n = 24L, value = 50) {
  data.frame(
    date = seq(as.Date("2024-01-01"), by = "month", length.out = n),
    value = rep(value, n)
  )
}


#' Kort serie (n < N_MIN -> low confidence)
#' @keywords internal
fixture_phase_short <- function(seed = 992L, n = 8L) {
  withr::with_seed(seed, {
    data.frame(
      date = seq(as.Date("2024-01-01"), by = "month", length.out = n),
      value = round(rnorm(n, 50, 3), 1)
    )
  })
}


#' Shift data (runs_only-signal forventet)
#' @keywords internal
fixture_phase_shifted <- function(seed = 993L) {
  withr::with_seed(seed, {
    data.frame(
      date = seq(as.Date("2024-01-01"), by = "month", length.out = 24L),
      value = c(rep(45, 12L), rep(55, 12L)) + rnorm(24L, 0, 0.3)
    )
  })
}


#' Multi-phase data (baseline + intervention)
#'
#' NB: round=FALSE matcher legacy fixture_phased() pattern (raw rnorm-
#' vaerdier). Test-suite-fixtures der har baseret snapshots paa raw
#' vaerdier bevarer parity. Andre Slice 3/4/5-tests bruger round=TRUE.
#'
#' @keywords internal
fixture_phase_phased <- function(seed = 994L, baseline_mean = 50,
                                 current_mean = 55, sigma_d = 1.0, n = 12L,
                                 round = FALSE) {
  withr::with_seed(seed, {
    values <- c(
      rnorm(n, mean = baseline_mean, sd = sigma_d),
      rnorm(n, mean = current_mean, sd = sigma_d)
    )
    if (round) values <- round(values, 1)
    data.frame(
      date = seq(as.Date("2024-01-01"), by = "month", length.out = 2 * n),
      value = values
    )
  })
}


# Memo-cache for bfh_qic-result + bfh_analyse-objekter. Test-suite genbruger
# samme kombinationer paa tvaers af tests; cache fjerner gentagen
# qicharts2-pipeline-cost (~485ms per kald).
.fixture_qic_cache <- new.env(parent = emptyenv())
.fixture_analyse_cache <- new.env(parent = emptyenv())


#' Memoised bfh_qic for test-suite re-brug
#'
#' @keywords internal
fixture_qic_cached <- function(data, ..., cache_key = NULL) {
  if (is.null(cache_key)) {
    return(bfh_qic(data, ...))
  }
  if (is.null(.fixture_qic_cache[[cache_key]])) {
    .fixture_qic_cache[[cache_key]] <- bfh_qic(data, ...)
  }
  .fixture_qic_cache[[cache_key]]
}


#' Memoised bfh_analyse for test-suite re-brug
#'
#' Default analysis_date = 2026-05-18 (pinned for deterministisk
#' freshness-detektion paa tvaers af kalenderdage).
#'
#' @keywords internal
fixture_analyse_cached <- function(qic_result, metadata = list(),
                                   language = "da", cache_key = NULL) {
  if (is.null(metadata$analysis_date)) {
    metadata$analysis_date <- as.Date("2026-05-18")
  }
  if (is.null(cache_key)) {
    return(bfh_analyse(qic_result, metadata = metadata, language = language))
  }
  if (is.null(.fixture_analyse_cache[[cache_key]])) {
    .fixture_analyse_cache[[cache_key]] <- bfh_analyse(
      qic_result,
      metadata = metadata, language = language
    )
  }
  .fixture_analyse_cache[[cache_key]]
}
