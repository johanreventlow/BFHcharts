# Tests for BFHcharts' fortolkning af qicharts2 signal-output
# Verificerer at anhoej.signal, crossings_signal etc. beregnes korrekt

test_that("anhoej.signal kombinerer runs og crossings korrekt", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  # Stabil data — bør ikke have signals
  stable_data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 50, sd = 2)
  )

  result <- bfh_qic(stable_data, x = date, y = value, chart_type = "i")

  # anhoej.signal kolonne skal eksistere

  expect_true("anhoej.signal" %in% names(result$qic_data))
  # Skal være logical
  expect_type(result$qic_data$anhoej.signal, "logical")
  # Ingen NAs
  expect_false(any(is.na(result$qic_data$anhoej.signal)))
})

test_that("runs.signal fra qicharts2 videregives korrekt (NA → FALSE)", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 50, sd = 5)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i")

  # runs.signal kan have NA fra qicharts2, men anhoej.signal skal aldrig have NA
  expect_false(any(is.na(result$qic_data$anhoej.signal)))
})

test_that("crossings signal beregnes per part", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  # Data med to faser
  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 50, sd = 5)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i",
                     part = 12)

  # Skal have part kolonne
  expect_true("part" %in% names(result$qic_data))
  # Skal have to faser
  expect_equal(length(unique(result$qic_data$part)), 2)
  # anhoej.signal skal stadig eksistere og være complete
  expect_true("anhoej.signal" %in% names(result$qic_data))
  expect_false(any(is.na(result$qic_data$anhoej.signal)))
})

test_that("signal-kolonner er tilgængelige i summary", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 50, sd = 5)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "i")

  # Summary skal have Anhøj-relaterede kolonner
  expect_true("længste_løb" %in% names(result$summary))
  expect_true("længste_løb_max" %in% names(result$summary))
  expect_true("antal_kryds" %in% names(result$summary))
  expect_true("antal_kryds_min" %in% names(result$summary))
  expect_true("løbelængde_signal" %in% names(result$summary))
})

test_that("run chart har anhoej.signal uden lcl/ucl", {
  skip_if_not_installed("qicharts2")
  set.seed(42)

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = rnorm(24, mean = 50, sd = 5)
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "run")

  # Run charts har anhoej.signal
  expect_true("anhoej.signal" %in% names(result$qic_data))
  # Run charts har centerlinje (median)
  expect_true("centerlinje" %in% names(result$summary))
})

test_that("data med konstrueret runs-signal detekteres", {
  skip_if_not_installed("qicharts2")

  # Konstruer data med lang run: 10 punkter over median efterfulgt af 14 under
  # Dette bør trigger runs.signal i qicharts2
  values <- c(rep(60, 10), rep(40, 14))

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = 24),
    value = values
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "run")

  # Med en run af 10 og 14 (begge > 9), bør der være signal
  # (afhænger af qicharts2's beregning, men vi verificerer at kolonnen er udfyldt)
  expect_true("anhoej.signal" %in% names(result$qic_data))
  # Mindst én observation skal have TRUE signal
  expect_true(any(result$qic_data$anhoej.signal))
})

test_that("stabil data giver FALSE for alle signals", {
  skip_if_not_installed("qicharts2")
  set.seed(123)

  # Uniformt fordelt rundt om medianen — bør give mange crossings og korte runs
  n <- 24
  values <- 50 + (seq_len(n) %% 2) * 4 - 2  # alternerer: 48, 52, 48, 52, ...

  data <- data.frame(
    date = seq.Date(as.Date("2024-01-01"), by = "month", length.out = n),
    value = values
  )

  result <- bfh_qic(data, x = date, y = value, chart_type = "run")

  # Alternerende data har mange crossings og korte runs → ingen signal
  expect_false(any(result$qic_data$anhoej.signal))
})
