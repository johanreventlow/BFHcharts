# Test suite: vaerdineutral action-tekst modsiger ej target-armen
#
# Baggrund: ved bart numerisk target (uden operator) er target_direction
# NULL, og action-armen dispatcher via den vaerdineutrale cascade
# (stable_not_at_target m.fl.). Tidligere formulerede disse noegler sig
# normativt ("Uden en maalrettet indsats ..."), selv om target-armen
# samtidig rapporterede "ligger over udviklingsmaalet". For en afdeling
# der praesterer OVER maalet laeste afsnittet derfor som en bebrejdelse.
#
# Kontrakt efter fix: den vaerdineutrale gren paastaar hverken
# maalopfyldelse eller maalsvigt -- den rapporterer retningen og beder
# laeseren vurdere, om niveauet er tilfredsstillende.

# Stabil p-chart-serie med CL ~89% og ingen Anhoej-signaler.
# Reproducerer DS-casen (Korrekt samlet scanning, uge 49/2025 - uge 32/2026).
make_stable_above_target_data <- function() {
  p <- c(
    0.905, 0.890, 0.898, 0.895, 0.893, 0.872, 0.879, 0.895, 0.891,
    0.883, 0.886, 0.878, 0.893, 0.881, 0.897, 0.887, 0.887, 0.891,
    0.875, 0.882, 0.884, 0.885, 0.899, 0.889, 0.902, 0.880, 0.895,
    0.897, 0.893, 0.876, 0.896, 0.894, 0.899, 0.889, 0.892, 0.890
  )
  data.frame(
    period = seq(as.Date("2025-12-01"), by = "week", length.out = length(p)),
    events = round(1370 * p),
    total  = rep(1370L, length(p))
  )
}

analyse_above_target <- function(target_value = 0.85) {
  result <- bfh_qic(make_stable_above_target_data(),
    x = period, y = events, n = total,
    chart_type = "p", y_axis_unit = "percent",
    target_value = target_value
  )
  bfh_analyse(result)
}


# -- Dispatch-kontrakt -------------------------------------------------------

test_that("bart numerisk target over maalet rammer vaerdineutral stable-gren", {
  analysis <- analyse_above_target()

  expect_identical(analysis$conclusions$action_key, "stable_not_at_target")
  expect_identical(analysis$conclusions$target_key, "over_target")
})


# -- Tekst-kontrakt: ingen selvmodsigelse ------------------------------------

test_that("stabil proces over maalet faar ej normativ indsats-tekst", {
  text <- bfh_render_analysis(analyse_above_target())

  # Target-armen rapporterer korrekt at niveauet ligger over maalet ...
  expect_match(text, "ligger over udviklingsmålet", fixed = FALSE)

  # ... og action-armen maa da ikke samtidig paastaa at en indsats
  # kraeves for at NAA maalet (den oprindelige selvmodsigelse).
  expect_no_match(text, "for at nå målet", fixed = FALSE)
  expect_no_match(text, "flytte niveauet mod målet", fixed = FALSE)
})

test_that("vaerdineutral action-tekst beder laeseren vurdere niveauet", {
  text <- bfh_render_analysis(analyse_above_target())

  expect_match(text, "[Vv]urdér, om", fixed = FALSE)
})

test_that("{level_direction} resolveres i vaerdineutral action-tekst", {
  text <- bfh_render_analysis(analyse_above_target())

  # Placeholder maa ej laekke uresolveret til brugeren.
  expect_no_match(text, "{level_direction}", fixed = TRUE)
  # Retningen skal vaere renderet konkret ("over" maalet).
  expect_match(text, "stabilt over målet", fixed = FALSE)
})


# -- Direction-aware gren er uaendret ----------------------------------------

test_that("target_text med operator giver fortsat skarp goal_met-tekst", {
  result <- bfh_qic(make_stable_above_target_data(),
    x = period, y = events, n = total,
    chart_type = "p", y_axis_unit = "percent",
    target_value = 0.85, target_text = "≥ 85%"
  )
  analysis <- bfh_analyse(result)

  expect_identical(analysis$conclusions$action_key, "stable_goal_met")
  expect_identical(analysis$conclusions$target_key, "goal_met")

  text <- bfh_render_analysis(analysis)
  expect_match(text, "opfylder udviklingsmålet", fixed = FALSE)
})
