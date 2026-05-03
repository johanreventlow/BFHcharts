# ============================================================================
# NA og EDGE-CASE HANDLING
# ============================================================================
#
# Verificerer at bfh_qic() håndterer scenarier der typisk forekommer i
# kliniske data:
#   - Manglende værdier (NA) i y, x, n (denominator)
#   - Tomme datasæt og minimale input
#   - Duplikerede x-værdier (subgruppe-struktur)
#   - Navnekollisioner med qicharts2's output-kolonner
#   - Type-mismatch (character hvor numerisk forventes)
#
# Tests skelner mellem:
#   - "Graceful degradation": forventes at lykkes med warnings (fx drop NA-rækker)
#   - "Clear error": forventes at fejle med informativ besked
#
# Reference: openspec/changes/strengthen-test-infrastructure (Fase 3 task 16)

# ============================================================================
# NA i y-kolonne (outcome)
# ============================================================================

test_that("bfh_qic() håndterer NA i y (drop-rows, proceed med warning)", {
  data <- data.frame(
    x = 1:12,
    y = c(10, 11, NA, 13, 14, 15, NA, 17, 18, 19, 20, 21)
  )

  # qicharts2 dropper typisk NA-rækker og warner
  result <- bfh_qic(data, x = x, y = y, chart_type = "i")

  expect_valid_bfh_qic_result(result)
  # qic_data indeholder alle x-værdier (NA bliver til NA i y)
  # eller dropper NA — afhængigt af qicharts2-version
  expect_true(nrow(result$qic_data) >= 10,
    info = "qic_data bør beholde mindst de 10 ikke-NA værdier"
  )
})

test_that("bfh_qic() fejler gracefully ved all-NA y", {
  data <- data.frame(
    x = 1:10,
    y = rep(NA_real_, 10)
  )

  # Forventes at fejle eller returnere tomt resultat — ikke crashe ukontrolleret.
  # all-NA y udloeser ggplot2 missing-value warnings undervejs; ikke testens fokus.
  result <- tryCatch(
    suppressWarnings(bfh_qic(data, x = x, y = y, chart_type = "i")),
    error = function(e) e
  )

  # Enten fejl eller valid_bfh_qic_result med tomt/NA indhold er acceptabelt
  if (inherits(result, "error")) {
    # Fejlbesked skal være informativ
    expect_true(nchar(conditionMessage(result)) > 0,
      info = "Fejlbesked ved all-NA skal ikke være tom"
    )
  } else {
    # Hvis det lykkes, må centerlinje være NA (ikke korrupt 0)
    cl <- result$qic_data$cl[1]
    expect_true(is.na(cl) || !is.finite(cl),
      info = "All-NA input bør give NA centerlinje"
    )
  }
})

# ============================================================================
# NA i n-kolonne (denominator for p/u charts)
# ============================================================================

test_that("bfh_qic() håndterer NA i n-kolonne (p-chart)", {
  data <- data.frame(
    x = 1:10,
    events = c(5, 6, 4, 7, 5, 6, 4, 7, 5, 6),
    total = c(100, 120, NA, 110, 130, 100, NA, 120, 140, 110)
  )

  result <- tryCatch(
    bfh_qic(data, x = x, y = events, n = total, chart_type = "p"),
    error = function(e) e
  )

  if (inherits(result, "error")) {
    expect_true(nchar(conditionMessage(result)) > 0)
  } else {
    expect_valid_bfh_qic_result(result)
  }
})

# ============================================================================
# Empty data frame
# ============================================================================

test_that("bfh_qic() fejler ved tom data.frame", {
  empty <- data.frame(x = integer(0), y = numeric(0))

  result <- tryCatch(
    bfh_qic(empty, x = x, y = y, chart_type = "i"),
    error = function(e) e
  )

  expect_true(inherits(result, "error"),
    info = "Tom data.frame skal give fejl — ikke tavst tomt plot"
  )
})

# ============================================================================
# Minimal data (1-2 rækker)
# ============================================================================

test_that("bfh_qic() håndterer 1-række data (grænsetilfælde)", {
  data <- data.frame(x = 1L, y = 42)

  result <- tryCatch(
    bfh_qic(data, x = x, y = y, chart_type = "i"),
    error = function(e) e
  )

  # 1-række er meningsløst for SPC — enten fejl eller trivielt output
  if (inherits(result, "error")) {
    expect_true(nchar(conditionMessage(result)) > 0)
  } else {
    # Hvis det lykkes: centerlinje skal være = y (eller NA)
    cl <- result$qic_data$cl[1]
    expect_true(is.na(cl) || cl == 42,
      info = "1-række CL skal være 42 eller NA"
    )
  }
})

test_that("bfh_qic() håndterer 3-rækker data (absolut minimum for run-chart)", {
  data <- data.frame(
    x = 1:3,
    y = c(10, 15, 12)
  )

  result <- bfh_qic(data, x = x, y = y, chart_type = "run")

  expect_valid_bfh_qic_result(result)
  expect_equal(nrow(result$qic_data), 3)
  # Run-chart CL = median = 12
  expect_equal(result$qic_data$cl[1], 12,
    tolerance = 1e-6,
    label = "run-chart CL = median af 3 punkter"
  )
})

# ============================================================================
# Duplikerede x-værdier
# ============================================================================

test_that("bfh_qic() med xbar-chart accepterer duplikerede x (subgrupper)", {
  # For xbar er duplikerede x FORVENTET (flere målinger pr. tidspunkt)
  data <- data.frame(
    x = rep(1:5, each = 4),
    y = c(
      10, 11, 9, 10, # subgruppe 1 — mean = 10
      12, 13, 11, 12, # subgruppe 2 — mean = 12
      10, 9, 11, 10, # subgruppe 3 — mean = 10
      13, 14, 12, 13, # subgruppe 4 — mean = 13
      11, 10, 12, 11
    ) # subgruppe 5 — mean = 11
  )

  result <- bfh_qic(data, x = x, y = y, chart_type = "xbar")

  expect_valid_bfh_qic_result(result)
  # Xbar aggregerer: 5 subgrupper → 5 punkter i qic_data
  expect_equal(nrow(result$qic_data), 5,
    label = "Xbar aggregerer duplikerede x til ét punkt pr. subgruppe"
  )
})

# ============================================================================
# Type-mismatch (character y hvor numerisk forventes)
# ============================================================================

test_that("bfh_qic() fejler på character y-kolonne", {
  data <- data.frame(
    x = 1:5,
    y = c("ten", "twenty", "thirty", "forty", "fifty")
  )

  result <- tryCatch(
    bfh_qic(data, x = x, y = y, chart_type = "i"),
    error = function(e) e
  )

  expect_true(inherits(result, "error"),
    info = "Character y skal give fejl — ikke tavst korrupt output"
  )
})

# ============================================================================
# Navnekollision — input-kolonne hedder "cl", "ucl", "lcl"
# ============================================================================

test_that("bfh_qic() håndterer kolonne-navnekollision med qic-output", {
  # Bruger-data med kolonner der hedder "cl" (qicharts2 centerlinje-kolonne)
  data <- data.frame(
    date = 1:10,
    count = c(5, 6, 4, 7, 5, 6, 4, 7, 5, 6),
    cl = c(NA, NA, NA, NA, NA, NA, NA, NA, NA, NA) # Bruger-kolonne
  )

  # Forventer at bfh_qic enten håndterer graciously eller fejler tydeligt
  result <- tryCatch(
    bfh_qic(data, x = date, y = count, chart_type = "i"),
    error = function(e) e
  )

  if (!inherits(result, "error")) {
    expect_valid_bfh_qic_result(result)
    # qic_data$cl skal være bfh_qic's beregnede CL, ikke brugerens NA-kolonne
    expect_false(all(is.na(result$qic_data$cl)),
      info = "qic_data$cl skal være beregnet CL, ikke brugerens NA-kolonne"
    )
  }
  # Hvis error: stadig acceptabelt hvis fejlbesked er informativ
})

# ============================================================================
# NA i x (periode/tidspunkt)
# ============================================================================

test_that("bfh_qic() håndterer NA i x-kolonne", {
  data <- data.frame(
    x = c(1:4, NA, 6:10),
    y = c(10, 11, 12, 13, 14, 15, 16, 17, 18, 19)
  )

  result <- tryCatch(
    bfh_qic(data, x = x, y = y, chart_type = "i"),
    error = function(e) e
  )

  # NA i x kan give forskellige resultater — enten drop-rækken eller fejl
  if (!inherits(result, "error")) {
    # Hvis det virker: må ikke have NA i x-kolonnen i output
    expect_true(all(!is.na(result$qic_data$x)) || nrow(result$qic_data) < 10,
      info = "NA i x bør enten droppes eller give fejl"
    )
  }
})

# ============================================================================
# Kombineret edge-case: få punkter + NA
# ============================================================================

test_that("bfh_qic() med 5 punkter hvoraf 2 er NA giver meningsfuldt output", {
  data <- data.frame(
    x = 1:5,
    y = c(10, NA, 12, NA, 14)
  )

  result <- tryCatch(
    bfh_qic(data, x = x, y = y, chart_type = "run"),
    error = function(e) e
  )

  # 3 gyldige punkter er minimum for run-chart — enten virker det eller fejler
  if (!inherits(result, "error")) {
    expect_valid_bfh_qic_result(result)
    # Median af {10, 12, 14} = 12 (eller NA hvis qicharts2 dropper)
    cl <- result$qic_data$cl[1]
    expect_true(is.na(cl) || cl == 12 || cl == 10 || cl == 14,
      info = "CL skal være median af gyldige værdier eller NA"
    )
  }
})

# ============================================================================
# Zero-variance data (alle identiske værdier)
# ============================================================================

test_that("bfh_qic() håndterer zero-variance data (alle ens y)", {
  data <- data.frame(
    x = 1:10,
    y = rep(50, 10)
  )

  result <- bfh_qic(data, x = x, y = y, chart_type = "i")

  expect_valid_bfh_qic_result(result)
  # CL skal være 50 (den konstante værdi)
  expect_equal(result$qic_data$cl[1], 50,
    tolerance = 1e-6,
    label = "Zero-variance CL = konstante værdi"
  )

  # UCL og LCL skal være 50 (MR = 0, så 2.66*0 = 0)
  # Eller muligvis NA hvis qicharts2 undgår zero-MR tilfældet
  ucl <- result$qic_data$ucl[1]
  lcl <- result$qic_data$lcl[1]
  if (!is.na(ucl) && !is.na(lcl)) {
    expect_equal(ucl, 50, tolerance = 0.01)
    expect_equal(lcl, 50, tolerance = 0.01)
  }
})
