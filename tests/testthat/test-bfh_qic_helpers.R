# ============================================================================
# TESTS FOR INTERNE bfh_qic() HELPERS
# ============================================================================
# Tests for add_anhoej_signal(), build_bfh_qic_return(),
# validate_bfh_qic_inputs(), build_qic_args(), compute_viewport_base_size()
# openspec: refactor-bfh_qic-orchestrator

# ============================================================================
# add_anhoej_signal()
# ============================================================================

test_that("add_anhoej_signal returnerer NULL for NULL input", {
  expect_null(add_anhoej_signal(NULL))
})

test_that("add_anhoej_signal normaliserer eksisterende anhoej.signal kolonne (NA bevares)", {
  df <- data.frame(
    x = 1:3,
    anhoej.signal = c(1, 0, NA)
  )
  result <- add_anhoej_signal(df)
  expect_type(result$anhoej.signal, "logical")
  # NA bevares — signalerer "for kort serie til evaluering"
  expect_equal(result$anhoej.signal, c(TRUE, FALSE, NA))
})

test_that("add_anhoej_signal bruger anhoej.signals fallback (NA bevares)", {
  df <- data.frame(
    x = 1:3,
    anhoej.signals = c(TRUE, FALSE, NA)
  )
  result <- add_anhoej_signal(df)
  expect_type(result$anhoej.signal, "logical")
  # NA bevares — signalerer "for kort serie til evaluering"
  expect_equal(result$anhoej.signal, c(TRUE, FALSE, NA))
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

test_that("add_anhoej_signal bevarer NA i output (NA = for kort serie til evaluering)", {
  df <- data.frame(
    x = 1:4,
    runs.signal = c(NA, TRUE, FALSE, NA),
    crossings.signal = c(FALSE, NA, FALSE, NA)
  )
  result <- add_anhoej_signal(df)
  expect_type(result$anhoej.signal, "logical")
  # NA i begge input-kolonner → NA i output (bevares som "ikke evaluerbar")
  # Rad 1: runs=NA OR crossings=FALSE → NA (NA OR FALSE = NA i R)
  # Rad 4: runs=NA OR crossings=NA   → NA
  expect_true(any(is.na(result$anhoej.signal)))
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

# ============================================================================
# validate_bfh_qic_inputs()
# ============================================================================

# Hjælper til at kalde validate_bfh_qic_inputs med gyldige defaults
# Brug explicit named args frem for modifyList (undgaar modifyList's rekursive merge af data.frame)
call_validate <- function(data = data.frame(x = 1:10, y = 1:10),
                          chart_type = "i",
                          y_axis_unit = "count",
                          part = NULL,
                          freeze = NULL,
                          base_size = 14,
                          width = NULL,
                          height = NULL,
                          exclude = NULL,
                          cl = NULL,
                          multiply = 1,
                          agg_fun_supplied = FALSE,
                          agg.fun = "mean",
                          return.data = FALSE,
                          print.summary = FALSE,
                          plot_margin = NULL,
                          target_value = NULL,
                          y_expr_char = "y",
                          n_expr_char = NULL) {
  validate_bfh_qic_inputs(
    data = data,
    chart_type = chart_type,
    y_axis_unit = y_axis_unit,
    part = part,
    freeze = freeze,
    base_size = base_size,
    width = width,
    height = height,
    exclude = exclude,
    cl = cl,
    multiply = multiply,
    agg_fun_supplied = agg_fun_supplied,
    agg.fun = agg.fun,
    return.data = return.data,
    print.summary = print.summary,
    plot_margin = plot_margin,
    target_value = target_value,
    y_expr_char = y_expr_char,
    n_expr_char = n_expr_char
  )
}

test_that("validate_bfh_qic_inputs accepterer gyldige defaults uden fejl", {
  expect_no_error(call_validate())
})

test_that("validate_bfh_qic_inputs fejler naar data ikke er data.frame", {
  expect_error(call_validate(data = list(x = 1:5, y = 1:5)), "data must be a data frame")
})

test_that("validate_bfh_qic_inputs fejler ved ugyldig chart_type", {
  expect_error(call_validate(chart_type = "xyz"), "chart_type must be one of")
})

test_that("validate_bfh_qic_inputs fejler ved ugyldig y_axis_unit", {
  expect_error(call_validate(y_axis_unit = "liters"), "y_axis_unit must be one of")
})

test_that("validate_bfh_qic_inputs returnerer NULL naar agg_fun ikke er angivet", {
  result <- call_validate(agg_fun_supplied = FALSE)
  expect_null(result)
})

test_that("validate_bfh_qic_inputs returnerer normaliseret agg.fun naar angivet", {
  result <- call_validate(agg_fun_supplied = TRUE, agg.fun = "median")
  expect_equal(result, "median")
})

test_that("validate_bfh_qic_inputs fejler ved ugyldig return.data", {
  expect_error(call_validate(return.data = "ja"), "return.data must be TRUE or FALSE")
})

test_that("validate_bfh_qic_inputs fejler ved ugyldig print.summary", {
  expect_error(call_validate(print.summary = NA), "print.summary must be TRUE or FALSE")
})

test_that("validate_bfh_qic_inputs fejler ved plot_margin med forkert laengde", {
  expect_error(call_validate(plot_margin = c(1, 2, 3)), "numeric vector of length 4")
})

test_that("validate_bfh_qic_inputs accepterer margin()-objekt som plot_margin", {
  m <- ggplot2::margin(t = 5, r = 5, b = 5, l = 5, unit = "mm")
  expect_no_error(call_validate(plot_margin = m))
})

# ============================================================================
# build_qic_args()
# ============================================================================

test_that("build_qic_args producerer korrekt basisliste for i-chart", {
  result <- build_qic_args(
    data = data.frame(x = 1:5, y = 1:5),
    x_expr = as.name("x"),
    y_expr = as.name("y"),
    n_expr = NULL,
    chart_type = "i",
    part = NULL,
    freeze = NULL,
    target_value = NULL,
    notes = NULL,
    exclude = NULL,
    cl = NULL,
    multiply = 1,
    agg.fun = NULL,
    y_axis_unit = "count"
  )
  expect_type(result, "list")
  expect_identical(result$chart, "i")
  expect_identical(result$return.data, TRUE)
  # multiply = 1 maa IKKE inkluderes (qicharts2 default)
  expect_false("multiply" %in% names(result))
  # y.percent maa IKKE inkluderes for count
  expect_false("y.percent" %in% names(result))
})

test_that("build_qic_args inkluderer n_expr naar angivet", {
  result <- build_qic_args(
    data = data.frame(x = 1:5, y = 1:5, n = 10),
    x_expr = as.name("x"),
    y_expr = as.name("y"),
    n_expr = as.name("n"),
    chart_type = "p",
    part = NULL, freeze = NULL, target_value = NULL,
    notes = NULL, exclude = NULL, cl = NULL,
    multiply = 1, agg.fun = NULL, y_axis_unit = "percent"
  )
  expect_identical(result$n, as.name("n"))
  expect_true(isTRUE(result$y.percent))
})

test_that("build_qic_args inkluderer y.percent for percent-enhed", {
  result <- build_qic_args(
    data = data.frame(x = 1:5, y = 1:5),
    x_expr = as.name("x"),
    y_expr = as.name("y"),
    n_expr = NULL,
    chart_type = "run",
    part = NULL, freeze = NULL, target_value = NULL,
    notes = NULL, exclude = NULL, cl = NULL,
    multiply = 1, agg.fun = NULL, y_axis_unit = "percent"
  )
  expect_true(isTRUE(result$y.percent))
})

test_that("build_qic_args inkluderer multiply naar forskellig fra 1", {
  result <- build_qic_args(
    data = data.frame(x = 1:5, y = 1:5),
    x_expr = as.name("x"),
    y_expr = as.name("y"),
    n_expr = NULL,
    chart_type = "i",
    part = NULL, freeze = NULL, target_value = NULL,
    notes = NULL, exclude = NULL, cl = NULL,
    multiply = 100, agg.fun = NULL, y_axis_unit = "percent"
  )
  expect_equal(result$multiply, 100)
})

test_that("build_qic_args inkluderer part, freeze, notes, exclude, cl naar angivet", {
  result <- build_qic_args(
    data = data.frame(x = 1:20, y = 1:20),
    x_expr = as.name("x"),
    y_expr = as.name("y"),
    n_expr = NULL,
    chart_type = "i",
    part = c(10),
    freeze = 10,
    target_value = 5,
    notes = rep(NA, 20),
    exclude = c(3),
    cl = 8,
    multiply = 1,
    agg.fun = "median",
    y_axis_unit = "count"
  )
  expect_equal(result$part, c(10))
  expect_equal(result$freeze, 10)
  expect_equal(result$target, 5)
  expect_equal(result$cl, 8)
  expect_equal(result$agg.fun, "median")
  expect_equal(result$exclude, c(3))
  expect_length(result$notes, 20)
})

# ============================================================================
# compute_viewport_base_size()
# ============================================================================

test_that("compute_viewport_base_size returnerer NULL dimensioner naar width/height mangler", {
  result <- compute_viewport_base_size(
    width = NULL, height = NULL,
    units = NULL, dpi = 96,
    base_size = 14, base_size_supplied = TRUE,
    xlab = "", ylab = ""
  )
  expect_null(result$width_inches)
  expect_null(result$height_inches)
  expect_equal(result$base_size, 14)
})

test_that("compute_viewport_base_size konverterer cm til inches korrekt", {
  # 25 cm auto-detekteres som cm (10 <= 25 <= 100)
  result <- compute_viewport_base_size(
    width = 25, height = 15,
    units = NULL, dpi = 96,
    base_size = 14, base_size_supplied = TRUE,
    xlab = "x", ylab = "y"
  )
  expect_false(is.null(result$width_inches))
  # 25 cm = 25/2.54 inches ≈ 9.84
  expect_equal(result$width_inches, 25 / 2.54, tolerance = 0.01)
})

test_that("compute_viewport_base_size beregner responsiv base_size naar ikke angivet af bruger", {
  result <- compute_viewport_base_size(
    width = 10, height = 6,
    units = "in", dpi = 96,
    base_size = 14, base_size_supplied = FALSE,
    xlab = "", ylab = ""
  )
  # base_size bør vaere beregnet via calculate_base_size() — og afvige fra default 14
  expect_false(is.null(result$base_size))
  # calculate_base_size(10, 6) er deterministisk — forvent eksakt vaerdi
  expect_equal(result$base_size, calculate_base_size(10, 6))
  expect_true(is.numeric(result$base_size))
})

test_that("compute_viewport_base_size respekterer eksplicit base_size fra bruger", {
  result <- compute_viewport_base_size(
    width = 10, height = 6,
    units = "in", dpi = 96,
    base_size = 20, base_size_supplied = TRUE,
    xlab = "x", ylab = "y"
  )
  expect_equal(result$base_size, 20)
})

test_that("compute_viewport_base_size normaliserer tomme akse-labels til NULL", {
  result <- compute_viewport_base_size(
    width = NULL, height = NULL,
    units = NULL, dpi = 96,
    base_size = 14, base_size_supplied = TRUE,
    xlab = "", ylab = "   "
  )
  expect_null(result$xlab)
  expect_null(result$ylab)
})

test_that("compute_viewport_base_size bevarer ikke-tomme akse-labels", {
  result <- compute_viewport_base_size(
    width = NULL, height = NULL,
    units = NULL, dpi = 96,
    base_size = 14, base_size_supplied = TRUE,
    xlab = "Maaned", ylab = "Antal"
  )
  expect_equal(result$xlab, "Maaned")
  expect_equal(result$ylab, "Antal")
})

# ============================================================================
# build_bfh_qic_config()
# ============================================================================

call_config <- function(chart_type = "i",
                        chart_title = NULL,
                        y_axis_unit = "count",
                        language = "da",
                        target_value = NULL,
                        target_text = NULL,
                        part = NULL,
                        freeze = NULL,
                        exclude = NULL,
                        cl = NULL,
                        multiply = 1,
                        agg.fun = NULL,
                        viewport_width_inches = NULL,
                        viewport_height_inches = NULL) {
  build_bfh_qic_config(
    chart_type = chart_type,
    chart_title = chart_title,
    y_axis_unit = y_axis_unit,
    language = language,
    target_value = target_value,
    target_text = target_text,
    part = part,
    freeze = freeze,
    exclude = exclude,
    cl = cl,
    multiply = multiply,
    agg.fun = agg.fun,
    viewport_width_inches = viewport_width_inches,
    viewport_height_inches = viewport_height_inches
  )
}

test_that("build_bfh_qic_config returnerer liste med korrekte topniveaufelter", {
  result <- call_config()
  expect_type(result, "list")
  expect_true("chart_type" %in% names(result))
  expect_true("y_axis_unit" %in% names(result))
  expect_true("label_config" %in% names(result))
})

test_that("build_bfh_qic_config label_config har korrekte underfelter", {
  result <- call_config()
  lc <- result$label_config
  expect_true("centerline_value" %in% names(lc))
  expect_true("has_frys_column" %in% names(lc))
  expect_true("has_skift_column" %in% names(lc))
  expect_true("original_label_size" %in% names(lc))
})

test_that("build_bfh_qic_config has_frys_column er TRUE naar freeze angivet", {
  result <- call_config(freeze = 6L)
  expect_true(result$label_config$has_frys_column)
})

test_that("build_bfh_qic_config has_skift_column er TRUE naar part angivet", {
  result <- call_config(part = 5L)
  expect_true(result$label_config$has_skift_column)
})

test_that("build_bfh_qic_config bruger PDF_LABEL_SIZE naar viewport er NULL", {
  result <- call_config(viewport_width_inches = NULL, viewport_height_inches = NULL)
  expect_equal(result$label_config$original_label_size, BFHcharts:::PDF_LABEL_SIZE)
})

test_that("build_bfh_qic_config beregner label_size naar viewport kendes", {
  result <- call_config(viewport_width_inches = 10, viewport_height_inches = 6)
  expected <- compute_label_size_for_viewport(10, 6)
  expect_equal(result$label_config$original_label_size, expected)
})
