test_that("resolve_constant_series_ylim returnerer NULL naar brugeren selv har sat ylim", {
  qic_data <- data.frame(y = c(0, 0, 0), target = NA_real_)

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "percent",
    ylim = c(0, 0.5)
  )

  expect_null(result)
})

test_that("resolve_constant_series_ylim returnerer NULL naar serien ikke er konstant", {
  qic_data <- data.frame(y = c(0, 0.1, 0), target = NA_real_)

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "percent",
    ylim = NULL
  )

  expect_null(result)
})

test_that("resolve_constant_series_ylim returnerer NULL naar der kun er ét datapunkt", {
  qic_data <- data.frame(y = 0, target = NA_real_)

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "percent",
    ylim = NULL
  )

  expect_null(result)
})

test_that("resolve_constant_series_ylim giver 0-100% for konstant percent-serie paa 0", {
  qic_data <- data.frame(y = c(0, 0, 0), target = NA_real_)

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "percent",
    ylim = NULL
  )

  expect_equal(result, c(0, 1))
})

test_that("resolve_constant_series_ylim giver 0-100% for konstant percent-serie midt i skalaen", {
  qic_data <- data.frame(y = rep(0.45, 5), target = NA_real_)

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "percent",
    ylim = NULL
  )

  expect_equal(result, c(0, 1))
})

test_that("resolve_constant_series_ylim skalerer count til [0, vaerdi*1.2] naar vaerdi > 0", {
  qic_data <- data.frame(y = c(10, 10, 10), target = NA_real_)

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "count",
    ylim = NULL
  )

  expect_equal(result, c(0, 12))
})

test_that("resolve_constant_series_ylim bruger vaerdi+1 naar vaerdi*1.2 er for lille (fx 0)", {
  qic_data <- data.frame(y = c(0, 0, 0), target = NA_real_)

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "count",
    ylim = NULL
  )

  expect_equal(result, c(0, 1))
})

test_that("resolve_constant_series_ylim udvider range til at daekke target for count", {
  qic_data <- data.frame(y = c(5, 5, 5), target = 20)

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "count",
    ylim = NULL
  )

  expect_equal(result, c(0, 20))
})

test_that("resolve_constant_series_ylim udvider ikke unoedigt naar target er inden for range", {
  qic_data <- data.frame(y = c(10, 10, 10), target = 11)

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "count",
    ylim = NULL
  )

  expect_equal(result, c(0, 12))
})

test_that("resolve_constant_series_ylim virker for rate og time paa samme maade som count", {
  qic_data <- data.frame(y = c(3, 3, 3), target = NA_real_)

  expect_equal(
    resolve_constant_series_ylim(qic_data, y_axis_unit = "rate", ylim = NULL),
    c(0, 4)
  )
  expect_equal(
    resolve_constant_series_ylim(qic_data, y_axis_unit = "time", ylim = NULL),
    c(0, 4)
  )
  expect_equal(
    resolve_constant_series_ylim(qic_data, y_axis_unit = "clock", ylim = NULL),
    c(0, 4)
  )
})

test_that("resolve_constant_series_ylim ignorerer NA-vaerdier i y ved konstant-tjek", {
  qic_data <- data.frame(y = c(5, NA, 5, 5), target = NA_real_)

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "count",
    ylim = NULL
  )

  expect_equal(result, c(0, 6))
})

test_that("resolve_constant_series_ylim returnerer NULL naar alle y er NA", {
  qic_data <- data.frame(y = c(NA_real_, NA_real_))

  result <- resolve_constant_series_ylim(
    qic_data,
    y_axis_unit = "count",
    ylim = NULL
  )

  expect_null(result)
})
