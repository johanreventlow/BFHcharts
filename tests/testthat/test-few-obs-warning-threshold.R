# Test suite: few_obs-advarsel fyrer foerst under N_WARN (8)
#
# Baggrund: N_MIN (12) styrede tidligere BAADE den statistiske anbefaling
# ("mindst 12, helst 20") OG advarsels-gaten der undertrykker hele
# analysen (target+action-armene rendres ej ved confidence_tier=="low").
# Serier med 8-11 observationer fik derfor ingen brugbar analyse, selv om
# datagrundlaget var tilstraekkeligt til at handle paa.
#
# Kontrakt efter split:
#   n <  N_WARN (8)  -> confidence_tier "low", few_obs-advarsel, ingen
#                       target/action-tekst
#   n >= N_WARN (8)  -> normal analyse inkl. target+action
#   12/20-anbefalingen bevares uaendret i advarsels-prosen.

make_series <- function(n, target_value = 0.85) {
  # Stabil p-chart-serie omkring ~89% uden Anhoej-signaler.
  set.seed(7)
  p <- rep(c(0.895, 0.885, 0.893, 0.887), length.out = n)
  data.frame(
    period = seq(as.Date("2026-01-01"), by = "week", length.out = n),
    events = round(1370 * p),
    total  = rep(1370L, n)
  )
}

analyse_n <- function(n) {
  result <- bfh_qic(make_series(n),
    x = period, y = events, n = total,
    chart_type = "p", y_axis_unit = "percent",
    target_value = 0.85
  )
  bfh_analyse(result)
}


# -- Konstant-kontrakt -------------------------------------------------------

test_that("N_WARN er 8 og ligger under N_MIN", {
  expect_identical(BFHcharts:::N_WARN, 8L)
  expect_identical(BFHcharts:::N_MIN, 12L)
  expect_lt(BFHcharts:::N_WARN, BFHcharts:::N_MIN)
})


# -- Under traersklen: advarsel bevares --------------------------------------

test_that("n = 7 udloeser fortsat few_obs-advarsel", {
  analysis <- analyse_n(7)

  expect_identical(analysis$features$confidence_tier, "low")
  expect_identical(analysis$features$low_confidence_reason, "few_obs")
  expect_identical(analysis$conclusions$stability_key, "not_evaluable")

  text <- bfh_render_analysis(analysis)
  expect_match(text, "kan processen ikke vurderes pålideligt", fixed = FALSE)
})

test_that("advarslen fastholder 12/20-anbefalingen", {
  text <- bfh_render_analysis(analyse_n(6), max_chars = 1000L)

  expect_match(text, "mindst 12, helst 20 observationer", fixed = TRUE)
})


# -- Paa og over traersklen: normal analyse ----------------------------------

test_that("n = 8 giver normal analyse uden few_obs-advarsel", {
  analysis <- analyse_n(8)

  expect_false(identical(analysis$features$confidence_tier, "low"))
  expect_false(identical(analysis$conclusions$stability_key, "not_evaluable"))
  expect_true(is.na(analysis$features$low_confidence_reason))

  text <- bfh_render_analysis(analysis)
  expect_no_match(text, "kan processen ikke vurderes pålideligt", fixed = FALSE)
})

test_that("n i [8, 12) faar target- og action-tekst (ej undertrykt)", {
  for (n in 8:11) {
    analysis <- analyse_n(n)

    expect_false(
      identical(analysis$features$confidence_tier, "low"),
      info = paste("n =", n)
    )
    # Target+action-armene undertrykkes ved low-confidence; de skal
    # vaere til stede her.
    expect_true(nzchar(analysis$conclusions$target_key), info = paste("n =", n))
    expect_true(nzchar(analysis$conclusions$action_key), info = paste("n =", n))

    text <- bfh_render_analysis(analysis)
    expect_match(text, "udviklingsmålet", fixed = FALSE, info = paste("n =", n))
  }
})


# -- Tier-graduering uaendret over N_MIN -------------------------------------

test_that("confidence_tier gradueres fortsat ved N_MIN og 20", {
  # 8-11: evaluerbar, men ej "high"
  expect_identical(analyse_n(10)$features$confidence_tier, "medium")
  expect_identical(analyse_n(12)$features$confidence_tier, "medium")
  expect_identical(analyse_n(20)$features$confidence_tier, "high")
})
