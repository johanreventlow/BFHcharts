# ============================================================================
# Konsistenstests: result$summary Anhøj-stats vs result$qic_data per fase
# ============================================================================
#
# Spec: openspec/changes/2026-05-01-verify-anhoej-summary-vs-qic-data-consistency
# ADR:  docs/adr/ADR-002-anhoej-summary-source.md
#
# Kerne-krav (spec.md):
#   summary$laengste_loeb[i] == max(qic_data$longest.run[part == i], na.rm = TRUE)
#   summary$antal_kryds[i]   == max(qic_data$n.crossings[part == i], na.rm = TRUE)
#   summary$loebelaengde_signal[i] == any(qic_data$runs.signal[part == i])
#   summary$sigma_signal[i]  == any(qic_data$sigma.signal[part == i])
#
# Observeret qicharts2-adfærd (verificeret 2026-05-01):
#   - longest.run er per-row KONSTANT inden for en fase (qicharts2 gemmer
#     fasens globale loebtal på hver række i fasen).
#   - n.crossings er ligeledes per-row konstant inden for en fase.
#   - longest.run.max og n.crossings.min er GLOBALE konstanter (same for all rows).
#   - NA returneres for faser med al-identiske værdier (ingen meningsfulde stats).

# ============================================================================
# Hjælper: sammenlign summary mod qic_data per fase
# ============================================================================

#' Returnerer named list med divergenser (tom list = alt OK)
check_anhoej_consistency <- function(result) {
  divergences <- list()

  summary <- result$summary
  qic_data <- result$qic_data

  loeb_col <- grep("ngste_løb$", names(summary), value = TRUE)[1]
  sig_col <- grep("belængde_signal", names(summary), value = TRUE)[1]

  n_phases <- nrow(summary)

  for (i in seq_len(n_phases)) {
    phase_rows <- qic_data[qic_data$part == i, ]

    # --- laengste_loeb ---
    if ("longest.run" %in% names(qic_data)) {
      q_run <- suppressWarnings(max(phase_rows$longest.run, na.rm = TRUE))
      s_run <- as.integer(summary[i, loeb_col])
      # NA-faser: begge skal vaere NA (qicharts2 returnerer -Inf/NA for tomme faser)
      both_na <- is.na(s_run) && (is.na(q_run) || is.infinite(q_run))
      if (!both_na && !isTRUE(s_run == q_run)) {
        divergences[[length(divergences) + 1L]] <- sprintf(
          "Phase %d laengste_loeb: summary=%s, qic_data max=%s",
          i, s_run, q_run
        )
      }
    }

    # --- antal_kryds ---
    if ("n.crossings" %in% names(qic_data)) {
      q_cross <- suppressWarnings(max(phase_rows$n.crossings, na.rm = TRUE))
      s_cross <- as.integer(summary$antal_kryds[i])
      both_na <- is.na(s_cross) && (is.na(q_cross) || is.infinite(q_cross))
      if (!both_na && !isTRUE(s_cross == q_cross)) {
        divergences[[length(divergences) + 1L]] <- sprintf(
          "Phase %d antal_kryds: summary=%s, qic_data max=%s",
          i, s_cross, q_cross
        )
      }
    }

    # --- loebelaengde_signal ---
    if (!is.null(sig_col) && "runs.signal" %in% names(qic_data)) {
      q_sig <- any(phase_rows$runs.signal, na.rm = TRUE)
      s_sig <- as.logical(summary[i, sig_col])
      if (!isTRUE(s_sig == q_sig)) {
        divergences[[length(divergences) + 1L]] <- sprintf(
          "Phase %d loebelaengde_signal: summary=%s, qic_data any=%s",
          i, s_sig, q_sig
        )
      }
    }

    # --- sigma_signal ---
    if ("sigma_signal" %in% names(summary) && "sigma.signal" %in% names(qic_data)) {
      q_ssig <- any(phase_rows$sigma.signal, na.rm = TRUE)
      s_ssig <- as.logical(summary$sigma_signal[i])
      if (!isTRUE(s_ssig == q_ssig)) {
        divergences[[length(divergences) + 1L]] <- sprintf(
          "Phase %d sigma_signal: summary=%s, qic_data any=%s",
          i, s_ssig, q_ssig
        )
      }
    }
  }

  divergences
}

# ============================================================================
# Scenario: I-chart multi-fase (spec.md scenario 1)
# ============================================================================

test_that("summary Anhoej-stats matcher qic_data per fase - I-chart 2 faser", {
  # Fase 1: 8 punkter OVER centerlinje (klar run) + 4 under
  # Fase 2: alternerende (ingen run)
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(rep(15, 8), rep(5, 4), 20, 22, 18, 21, 19, 22, 18, 21, 19, 22, 18, 21)
  )
  result <- bfh_qic(d, x = month, y = value, chart_type = "i", part = c(12))

  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))

  # Eksplicitte fase-assertions (spec scenario 1)
  loeb_col <- grep("ngste_løb$", names(result$summary), value = TRUE)[1]
  for (i in 1:2) {
    phase_rows <- result$qic_data[result$qic_data$part == i, ]
    expect_equal(
      as.integer(result$summary[i, loeb_col]),
      max(phase_rows$longest.run, na.rm = TRUE),
      info = paste("Fase", i, "laengste_loeb")
    )
    expect_equal(
      as.integer(result$summary$antal_kryds[i]),
      max(phase_rows$n.crossings, na.rm = TRUE),
      info = paste("Fase", i, "antal_kryds")
    )
  }
})

test_that("summary Anhoej-stats matcher qic_data per fase - I-chart 3 faser", {
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 36),
    value = c(
      rep(20, 10), rep(10, 2), # Fase 1: klar 10-punkts run
      rnorm(12, 15, 0.5), # Fase 2: stabil
      c(20, 10, 20, 10, 20, 10, 20, 10, 20, 10, 20, 10) # Fase 3: krydsende
    )
  )
  result <- bfh_qic(d, x = month, y = value, chart_type = "i", part = c(12, 24))

  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))
})

# ============================================================================
# Scenario: Enkelt-fase data (spec.md scenario 2)
# ============================================================================

test_that("summary Anhoej-stats matcher qic_data - enkelt fase (ingen part)", {
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(rep(15, 8), rep(5, 4), rnorm(12, 10, 2))
  )
  result <- bfh_qic(d, x = month, y = value, chart_type = "i")

  expect_equal(nrow(result$summary), 1L)
  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))

  # Global aggregering skal matche enkelt-fase summary
  loeb_col <- grep("ngste_løb$", names(result$summary), value = TRUE)[1]
  expect_equal(
    as.integer(result$summary[1, loeb_col]),
    max(result$qic_data$longest.run, na.rm = TRUE)
  )
  expect_equal(
    as.integer(result$summary$antal_kryds[1]),
    max(result$qic_data$n.crossings, na.rm = TRUE)
  )
})

# ============================================================================
# Scenario: P-chart (ratio chart med varierende denominatorer)
# ============================================================================

test_that("summary Anhoej-stats matcher qic_data - P-chart 2 faser", {
  set.seed(42)
  d <- data.frame(
    month  = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    events = c(rpois(12, 5), rpois(12, 3)),
    denom  = rep(100L, 24)
  )
  result <- bfh_qic(d, x = month, y = events, n = denom, chart_type = "p", part = c(12))

  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))
})

# ============================================================================
# Scenario: U-chart
# ============================================================================

test_that("summary Anhoej-stats matcher qic_data - U-chart 2 faser", {
  set.seed(42)
  d <- data.frame(
    month  = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    events = c(rpois(12, 5), rpois(12, 3)),
    denom  = rep(50L, 24)
  )
  result <- bfh_qic(d, x = month, y = events, n = denom, chart_type = "u", part = c(12))

  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))
})

# ============================================================================
# Scenario: C-chart
# ============================================================================

test_that("summary Anhoej-stats matcher qic_data - C-chart 2 faser", {
  set.seed(42)
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(rpois(12, 8), rpois(12, 4))
  )
  result <- bfh_qic(d, x = month, y = value, chart_type = "c", part = c(12))

  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))
})

# ============================================================================
# Scenario: MR-chart
# ============================================================================

test_that("summary Anhoej-stats matcher qic_data - MR-chart 2 faser", {
  set.seed(42)
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(rnorm(12, 10, 2), rnorm(12, 15, 2))
  )
  result <- bfh_qic(d, x = month, y = value, chart_type = "mr", part = c(12))

  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))
})

# ============================================================================
# Scenario: PP-chart (Laney P-prime)
# ============================================================================

test_that("summary Anhoej-stats matcher qic_data - PP-chart 2 faser", {
  set.seed(42)
  d <- data.frame(
    month  = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    events = c(rpois(12, 50), rpois(12, 30)),
    denom  = rpois(24, 5000)
  )
  result <- bfh_qic(d, x = month, y = events, n = denom, chart_type = "pp", part = c(12))

  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))
})

# ============================================================================
# Scenario: UP-chart (Laney U-prime)
# ============================================================================

test_that("summary Anhoej-stats matcher qic_data - UP-chart 2 faser", {
  set.seed(42)
  d <- data.frame(
    month  = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    events = c(rpois(12, 50), rpois(12, 30)),
    denom  = rpois(24, 1000)
  )
  result <- bfh_qic(d, x = month, y = events, n = denom, chart_type = "up", part = c(12))

  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))
})

# ============================================================================
# Edge case: Fase med 1 punkt (task 3.8)
# ============================================================================

test_that("summary haandterer fase med 1 punkt korrekt", {
  # Del ved position 23 giver fase 1: 22 punkter, fase 2: 2 punkter
  # Med 2 punkter i fase 2 er statistikker stadig meningsloese (NA fra qicharts2)
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(rep(15, 12), rnorm(11, 10, 2), 10)
  )
  # Forvent ingen fejl -- summary skal eksistere med 2 raekker.
  # Fase 2 kan have NA Anhoej-stats (for korte serier).
  # Brug suppressWarnings fordi qicharts2 advarer om for faa observationer.
  result <- suppressWarnings(
    bfh_qic(d, x = month, y = value, chart_type = "i", part = c(23))
  )

  expect_equal(nrow(result$summary), 2L)
  # Konsistens: NA-fasen haandteres korrekt (begge sider er NA)
  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))
})

# ============================================================================
# Edge case: Exclude-punkter respekteres (spec.md scenario 3)
# ============================================================================

test_that("summary med exclude matcher qic_data kun over inkluderede raekker", {
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(rep(15, 8), rep(5, 4), 20, 22, 18, 21, 19, 22, 18, 21, 19, 22, 18, 21)
  )
  # Ekskluder punkt 3 og 15
  result <- bfh_qic(d,
    x = month, y = value, chart_type = "i",
    part = c(12), exclude = c(3, 15)
  )

  divs <- check_anhoej_consistency(result)
  expect_true(length(divs) == 0L, info = paste("Divergenser:", paste(divs, collapse = "; ")))

  # Verificer eksplicit at qic_data har exclude-markering (x.included kolonne)
  if ("include" %in% names(result$qic_data)) {
    expect_false(all(result$qic_data$include)) # mindst et punkt er excluded
  }
})

# ============================================================================
# Konsistens: bfh_extract_spc_stats() bruger summary (ingen duplikering)
# ============================================================================

test_that("bfh_extract_spc_stats(result) matcher result$summary vaerdier", {
  d <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = c(rep(15, 8), rep(5, 4), 20, 22, 18, 21, 19, 22, 18, 21, 19, 22, 18, 21)
  )
  result <- bfh_qic(d, x = month, y = value, chart_type = "i", part = c(12))

  stats <- bfh_extract_spc_stats(result)

  # stats er baseret paa seneste fase (fase 2)
  loeb_col <- grep("ngste_løb$", names(result$summary), value = TRUE)[1]
  latest_row <- result$summary[nrow(result$summary), ]

  expect_equal(stats$runs_actual, as.integer(latest_row[[loeb_col]]))
  expect_equal(stats$crossings_actual, as.integer(latest_row$antal_kryds))
})
