# ============================================================================
# TESTS FOR INTERNE bfh_qic() HELPERS
# ============================================================================
# Tests for add_anhoej_signal() og build_bfh_qic_return()
# openspec: refactor-extract-bfh-qic-helpers

# ============================================================================
# add_anhoej_signal()
# ============================================================================

test_that("add_anhoej_signal returnerer NULL for NULL input", {
  expect_null(add_anhoej_signal(NULL))
})

test_that("add_anhoej_signal normaliserer eksisterende anhoej.signal kolonne", {
  df <- data.frame(
    x = 1:3,
    anhoej.signal = c(1, 0, NA)
  )
  result <- add_anhoej_signal(df)
  expect_type(result$anhoej.signal, "logical")
  expect_equal(result$anhoej.signal, c(TRUE, FALSE, FALSE))
})

test_that("add_anhoej_signal bruger anhoej.signals fallback", {
  df <- data.frame(
    x = 1:3,
    anhoej.signals = c(TRUE, FALSE, NA)
  )
  result <- add_anhoej_signal(df)
  expect_type(result$anhoej.signal, "logical")
  expect_equal(result$anhoej.signal, c(TRUE, FALSE, FALSE))
})

test_that("add_anhoej_signal kombinerer runs.signal og crossings.signal", {
  df <- data.frame(
    x = 1:4,
    runs.signal = c(FALSE, TRUE, FALSE, FALSE),
    crossings.signal = c(FALSE, FALSE, TRUE, FALSE)
  )
  result <- add_anhoej_signal(df)
  expect_type(result$anhoej.signal, "logical")
  expect_equal(result$anhoej.signal, c(FALSE, TRUE, TRUE, FALSE))
})

test_that("add_anhoej_signal bruger kun runs.signal når crossings.signal mangler", {
  df <- data.frame(
    x = 1:3,
    runs.signal = c(TRUE, FALSE, TRUE)
  )
  result <- add_anhoej_signal(df)
  expect_type(result$anhoej.signal, "logical")
  expect_equal(result$anhoej.signal, c(TRUE, FALSE, TRUE))
})

test_that("add_anhoej_signal defaulter til FALSE når ingen signal-kolonner", {
  df <- data.frame(x = 1:3, y = c(10, 20, 30))
  result <- add_anhoej_signal(df)
  expect_type(result$anhoej.signal, "logical")
  expect_equal(result$anhoej.signal, c(FALSE, FALSE, FALSE))
})

test_that("add_anhoej_signal erstatter aldrig NA med NA i output", {
  df <- data.frame(
    x = 1:4,
    runs.signal = c(NA, TRUE, FALSE, NA),
    crossings.signal = c(FALSE, NA, FALSE, NA)
  )
  result <- add_anhoej_signal(df)
  expect_false(any(is.na(result$anhoej.signal)))
})

test_that("add_anhoej_signal bevarer øvrige kolonner uændret", {
  df <- data.frame(
    x = 1:3,
    cl = c(10, 10, 10),
    ucl = c(15, 15, 15),
    runs.signal = c(FALSE, FALSE, FALSE)
  )
  result <- add_anhoej_signal(df)
  expect_equal(result$cl, df$cl)
  expect_equal(result$ucl, df$ucl)
  expect_equal(result$x, df$x)
})

# ============================================================================
# build_bfh_qic_return()
# ============================================================================

# Hjælpefunktion til mock-plot (undgår font-krav)
make_mock_plot <- function() {
  ggplot2::ggplot(data.frame(x = 1, y = 1), ggplot2::aes(x, y)) +
    ggplot2::geom_point()
}

make_mock_summary <- function() {
  data.frame(fase = 1L, centerlinje = 10.5)
}

make_mock_qic_data <- function() {
  data.frame(x = 1:3, y = c(10, 11, 12), cl = 10.5)
}

make_mock_config <- function() {
  list(chart_type = "i", y_axis_unit = "count")
}

test_that("build_bfh_qic_return returnerer bfh_qic_result ved default", {
  result <- build_bfh_qic_return(
    qic_data = make_mock_qic_data(),
    plot = make_mock_plot(),
    summary_result = make_mock_summary(),
    config = make_mock_config(),
    return.data = FALSE,
    print.summary = FALSE
  )
  expect_s3_class(result, "bfh_qic_result")
})

test_that("build_bfh_qic_return returnerer qic_data data.frame ved return.data = TRUE", {
  result <- suppressWarnings(
    build_bfh_qic_return(
      qic_data = make_mock_qic_data(),
      plot = make_mock_plot(),
      summary_result = make_mock_summary(),
      config = make_mock_config(),
      return.data = TRUE,
      print.summary = FALSE
    )
  )
  expect_s3_class(result, "data.frame")
  expect_true("cl" %in% names(result))
})

test_that("build_bfh_qic_return returnerer list(plot, summary) ved print.summary = TRUE", {
  result <- suppressWarnings(
    build_bfh_qic_return(
      qic_data = make_mock_qic_data(),
      plot = make_mock_plot(),
      summary_result = make_mock_summary(),
      config = make_mock_config(),
      return.data = FALSE,
      print.summary = TRUE
    )
  )
  expect_type(result, "list")
  expect_named(result, c("plot", "summary"))
  expect_s3_class(result$plot, "ggplot")
  expect_s3_class(result$summary, "data.frame")
})

test_that("build_bfh_qic_return returnerer list(data, summary) ved begge TRUE", {
  result <- suppressWarnings(
    build_bfh_qic_return(
      qic_data = make_mock_qic_data(),
      plot = make_mock_plot(),
      summary_result = make_mock_summary(),
      config = make_mock_config(),
      return.data = TRUE,
      print.summary = TRUE
    )
  )
  expect_type(result, "list")
  expect_named(result, c("data", "summary"))
  expect_s3_class(result$data, "data.frame")
  expect_s3_class(result$summary, "data.frame")
})


test_that("build_bfh_qic_return udsender legacy-format-warning kun ved print.summary = TRUE og return.data = FALSE", {
  # Forventer to warnings: deprecation + legacy-format
  w <- character(0)
  withCallingHandlers(
    build_bfh_qic_return(
      qic_data = make_mock_qic_data(),
      plot = make_mock_plot(),
      summary_result = make_mock_summary(),
      config = make_mock_config(),
      return.data = FALSE,
      print.summary = TRUE
    ),
    warning = function(e) {
      w <<- c(w, conditionMessage(e))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(w, 2)
  expect_true(any(grepl("deprecated", w)))
  expect_true(any(grepl("legacy", w)))
})

test_that("build_bfh_qic_return udsender kun deprecation-warning ved return.data = TRUE og print.summary = TRUE", {
  # return.data && print.summary → kun én warning (deprecation), ingen legacy-format
  w <- character(0)
  withCallingHandlers(
    build_bfh_qic_return(
      qic_data = make_mock_qic_data(),
      plot = make_mock_plot(),
      summary_result = make_mock_summary(),
      config = make_mock_config(),
      return.data = TRUE,
      print.summary = TRUE
    ),
    warning = function(e) {
      w <<- c(w, conditionMessage(e))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(w, 1)
  expect_true(grepl("deprecated", w[1]))
})

test_that("build_bfh_qic_return udsender ingen warnings ved default", {
  expect_no_warning(
    build_bfh_qic_return(
      qic_data = make_mock_qic_data(),
      plot = make_mock_plot(),
      summary_result = make_mock_summary(),
      config = make_mock_config(),
      return.data = FALSE,
      print.summary = FALSE
    )
  )
})
