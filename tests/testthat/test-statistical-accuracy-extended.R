# ============================================================================
# STATISTICAL ACCURACY (extended) — numerisk verifikation for xbar/s/mr/t/g/pp/up
# ============================================================================
#
# Supplementer test-statistical-accuracy.R som dækker p/c/u/i/run.
#
# Formål: fange regressioner i BFHcharts' wrapping af qicharts2 for de 7
# chart-typer der ikke havde numerisk verifikation før (#208).
#
# Verifikationsstrategi:
# - xbar, s, mr, t, g: tæt tolerance (1e-3) mod Montgomery 6.ed kapitel 6-7
#   formler + Nelson y^(1/3.6)-transformation for t-charts.
# - pp, up: regression-style cross-verification mod qicharts2::qic() direkte.
#   pp/up er Laney prime-charts (Wheeler/Laney sigma-Z overdispersion-
#   correction) — formel ikke-trivielt at reproducere uden at duplikere
#   qicharts2's interne logik. Cross-verifikation fanger BFHcharts' wrapping-
#   regressioner men ikke qicharts2-formel-ændringer (det er acceptabelt
#   trade-off for prime-charts).
#
# Alle test-data er håndlavede deterministiske vektorer — ingen RNG.
#
# Referencer:
# - Montgomery DC (2009) "Introduction to Statistical Quality Control", 6th ed.
# - Wheeler DJ (1995) "Advanced Topics in Statistical Process Control"
# - Laney DB (2002) "Improved Control Charts for Attributes" Quality Engineering
# - qicharts2 source for prime-chart implementations

# ============================================================================
# XBAR-CHART — mean of subgroups (Montgomery 6.1)
# ============================================================================
#
# Formler (s-bar based, qicharts2 standard):
#   centerlinje = grand_mean = mean(subgroup_means)
#   UCL = grand_mean + A3 · s_bar
#   LCL = grand_mean - A3 · s_bar
#
# A3-konstant afhænger af subgroup-størrelse n:
#   n=4: A3 = 1.628
#   n=5: A3 = 1.427
#   n=6: A3 = 1.287

test_that("xbar-chart UCL/LCL matcher Montgomery formel (n=5, konstant subgroup)", {
  # 8 subgroups × 5 obs, hver subgroup [9, 10, 11, 10, 10]
  # subgroup_mean = 10, subgroup_sd = 0.7071
  data <- data.frame(
    subgroup = rep(1:8, each = 5),
    value = rep(c(9, 10, 11, 10, 10), 8)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = subgroup, y = value, chart_type = "xbar")
  )

  qd <- result$qic_data
  grand_mean <- 10
  s_bar <- sd(c(9, 10, 11, 10, 10)) # 0.7071068
  A3_n5 <- 1.427

  expect_equal(qd$cl[1], grand_mean,
    tolerance = 1e-6,
    label = "xbar centerlinje = grand mean"
  )
  expect_equal(qd$ucl[1], grand_mean + A3_n5 * s_bar,
    tolerance = 1e-3,
    label = "xbar UCL = grand_mean + A3·s_bar"
  )
  expect_equal(qd$lcl[1], grand_mean - A3_n5 * s_bar,
    tolerance = 1e-3,
    label = "xbar LCL = grand_mean - A3·s_bar"
  )
})

test_that("xbar-chart LCL kan være negativ (ingen clipping)", {
  # Mean nær 0, sd > 0 → LCL < 0
  data <- data.frame(
    subgroup = rep(1:6, each = 4),
    value = rep(c(-1, 0, 1, 0), 6)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = subgroup, y = value, chart_type = "xbar")
  )

  qd <- result$qic_data
  expect_equal(qd$cl[1], 0, tolerance = 1e-6)
  expect_lt(qd$lcl[1], 0)
  expect_gt(qd$ucl[1], 0)
  # LCL og UCL skal være symmetriske om centerlinjen
  expect_equal(qd$ucl[1], -qd$lcl[1], tolerance = 1e-6)
})

# ============================================================================
# S-CHART — within-subgroup standard deviation (Montgomery 6.2)
# ============================================================================
#
# Formler:
#   centerlinje = s_bar = mean(subgroup_sds)
#   UCL = B4 · s_bar
#   LCL = B3 · s_bar  (B3 = 0 for n ≤ 5, så LCL = 0)
#
# B-konstanter:
#   n=4: B3 = 0,     B4 = 2.266
#   n=5: B3 = 0,     B4 = 2.089
#   n=6: B3 = 0.030, B4 = 1.970

test_that("s-chart UCL matcher Montgomery formel (n=5, B4=2.089)", {
  data <- data.frame(
    subgroup = rep(1:8, each = 5),
    value = rep(c(9, 10, 11, 10, 10), 8)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = subgroup, y = value, chart_type = "s")
  )

  qd <- result$qic_data
  s_bar <- sd(c(9, 10, 11, 10, 10)) # 0.7071068
  B4_n5 <- 2.089

  expect_equal(qd$cl[1], s_bar,
    tolerance = 1e-6,
    label = "s-chart centerlinje = s_bar"
  )
  expect_equal(qd$ucl[1], B4_n5 * s_bar,
    tolerance = 1e-3,
    label = "s-chart UCL = B4·s_bar"
  )
  expect_equal(qd$lcl[1], 0,
    tolerance = 1e-6,
    label = "s-chart LCL = 0 for n≤5"
  )
})

test_that("s-chart har konsistent centerlinje på tværs af subgroups", {
  # Identiske subgroups → konstant s_bar over alle perioder
  data <- data.frame(
    subgroup = rep(1:6, each = 4),
    value = rep(c(8, 10, 12, 10), 6)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = subgroup, y = value, chart_type = "s")
  )

  expect_true(all(result$qic_data$cl == result$qic_data$cl[1]))
})

# ============================================================================
# MR-CHART — moving range (Montgomery 6.3, n=2 par-vis)
# ============================================================================
#
# Formler (n=2, consecutive observation pairs):
#   MR_bar = mean(|y[i+1] - y[i]|)
#   centerlinje = MR_bar
#   UCL = D4 · MR_bar  (D4 = 3.267 for n=2)
#   LCL = D3 · MR_bar  (D3 = 0 for n=2)

test_that("mr-chart UCL matcher Montgomery formel (D4=3.267)", {
  # Deterministiske moving ranges: |11-10|=1, |9-11|=2, |12-9|=3, ...
  values <- c(10, 11, 9, 12, 10, 11, 13, 10, 12, 11)
  expected_mr <- abs(diff(values)) # c(1, 2, 3, 2, 1, 2, 3, 2, 1)
  expected_mr_bar <- mean(expected_mr) # 17/9 ≈ 1.889

  data <- data.frame(period = seq_along(values), value = values)

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = value, chart_type = "mr")
  )

  qd <- result$qic_data
  D4_n2 <- 3.267

  # Note: første række MR er NA (ingen forudgående observation)
  expect_equal(qd$cl[1], expected_mr_bar,
    tolerance = 1e-3,
    label = "mr centerlinje = MR_bar"
  )
  expect_equal(qd$ucl[1], D4_n2 * expected_mr_bar,
    tolerance = 1e-3,
    label = "mr UCL = D4·MR_bar"
  )
  expect_equal(qd$lcl[1], 0,
    tolerance = 1e-6,
    label = "mr LCL = 0 for n=2 (D3=0)"
  )
})

test_that("mr-chart første række har NA i y-værdi (ingen MR for første obs)", {
  data <- data.frame(period = 1:5, value = c(10, 11, 9, 12, 10))

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = value, chart_type = "mr")
  )

  expect_true(is.na(result$qic_data$y[1]))
  expect_false(any(is.na(result$qic_data$y[2:5])))
})

# ============================================================================
# T-CHART — time between events (Nelson y^(1/3.6) transformation)
# ============================================================================
#
# qicharts2 t-chart implementerer Nelson's transformation:
#   z = y^(1/3.6)
#   I-chart på z med MR-baseret sigma-estimering:
#     sigma_hat = MR_bar(z) / 1.128  (d2 for n=2)
#   UCL_z = mean(z) + 3·sigma_hat
#   LCL_z = max(0, mean(z) - 3·sigma_hat)
#   Back-transformation: cl = mean(z)^3.6, UCL = UCL_z^3.6, LCL = LCL_z^3.6

test_that("t-chart UCL/LCL matcher Nelson-transformation (y^(1/3.6))", {
  values <- c(5, 3, 7, 4, 6, 5, 8, 6)
  data <- data.frame(event = seq_along(values), days = values)

  result <- suppressWarnings(
    bfh_qic(data, x = event, y = days, chart_type = "t")
  )

  qd <- result$qic_data

  # Hand-calculation
  z <- values^(1 / 3.6)
  z_mean <- mean(z)
  mr_bar <- mean(abs(diff(z)))
  sigma_hat <- mr_bar / 1.128
  ucl_z <- z_mean + 3 * sigma_hat
  lcl_z <- max(0, z_mean - 3 * sigma_hat)

  expected_cl <- z_mean^3.6
  expected_ucl <- ucl_z^3.6
  expected_lcl <- lcl_z^3.6

  expect_equal(qd$cl[1], expected_cl,
    tolerance = 1e-3,
    label = "t-chart cl = mean(z)^3.6"
  )
  expect_equal(qd$ucl[1], expected_ucl,
    tolerance = 1e-3,
    label = "t-chart UCL = (mean(z)+3·sigma_hat)^3.6"
  )
  expect_equal(qd$lcl[1], expected_lcl,
    tolerance = 1e-3,
    label = "t-chart LCL = max(0, mean(z)-3·sigma_hat)^3.6"
  )
})

test_that("t-chart har bredere UCL end I-chart (Nelson-transformation udvider)", {
  values <- c(5, 3, 7, 4, 6, 5, 8, 6)
  data <- data.frame(event = seq_along(values), days = values)

  t_result <- suppressWarnings(
    bfh_qic(data, x = event, y = days, chart_type = "t")
  )
  i_result <- suppressWarnings(
    bfh_qic(data, x = event, y = days, chart_type = "i")
  )

  # Nelson-transformation gør UCL mere konservativ for skæve fordelinger
  expect_gt(t_result$qic_data$ucl[1], i_result$qic_data$ucl[1])
})

# ============================================================================
# G-CHART — counts between events (geometric distribution)
# ============================================================================
#
# qicharts2 g-chart formler:
#   centerlinje = median(y)  (robust mod outliers)
#   sigma-estimering baseret på mean: sigma_hat = sqrt(c_bar · (c_bar + 1))
#     (geometric distribution variance)
#   UCL = c_bar + 3 · sqrt(c_bar · (c_bar + 1))
#   LCL = max(0, c_bar - 3 · sqrt(c_bar · (c_bar + 1)))
#
# Note: cl bruger median, UCL/LCL bruger mean. qicharts2-design (median er
# robust visuel reference, mean driver kontrolgrænser).

test_that("g-chart UCL matcher geometric formel (c_bar + 3·sqrt(c_bar·(c_bar+1)))", {
  values <- c(5, 8, 6, 7, 4, 9, 5, 7)
  data <- data.frame(shift = seq_along(values), count = values)

  result <- suppressWarnings(
    bfh_qic(data, x = shift, y = count, chart_type = "g")
  )

  qd <- result$qic_data
  c_bar <- mean(values) # 6.375
  c_med <- stats::median(values) # 6.5
  sigma_geom <- sqrt(c_bar * (c_bar + 1))

  expect_equal(qd$cl[1], c_med,
    tolerance = 1e-6,
    label = "g-chart cl = median(y)"
  )
  expect_equal(qd$ucl[1], c_bar + 3 * sigma_geom,
    tolerance = 1e-3,
    label = "g-chart UCL = c_bar + 3·sqrt(c_bar·(c_bar+1))"
  )
  expect_equal(qd$lcl[1], max(0, c_bar - 3 * sigma_geom),
    tolerance = 1e-6,
    label = "g-chart LCL = max(0, c_bar - 3·sqrt(...))"
  )
})

test_that("g-chart LCL clippes til 0 når c_bar er lille", {
  # Lave counts → c_bar - 3·sqrt(...) går negativ → LCL = 0
  values <- c(2, 3, 1, 4, 2, 3)
  data <- data.frame(shift = seq_along(values), count = values)

  result <- suppressWarnings(
    bfh_qic(data, x = shift, y = count, chart_type = "g")
  )

  expect_equal(result$qic_data$lcl[1], 0, tolerance = 1e-6)
})

# ============================================================================
# PP-CHART — proportion percent (Laney p' / Wheeler prime correction)
# ============================================================================
#
# qicharts2 pp-chart implementerer Laney's p' (p-prime) formel der
# justerer sigma for overdispersion via Z-statistik:
#   z_i = (p_i - p_bar) / sqrt(p_bar·(1-p_bar)/n_i)
#   sigma_z = MR_bar(z) / 1.128  (d2)
#   sigma_pp_i = sqrt(p_bar·(1-p_bar)/n_i) · sigma_z
#   UCL_i = p_bar + 3 · sigma_pp_i
#
# Reference: Laney DB (2002) "Improved Control Charts for Attributes"
#
# Cross-verifikation mod qicharts2::qic() direkte siden Laney prime-formlen
# er non-triviel at reproducere uden at duplikere qicharts2 internals.

test_that("pp-chart wrapping matcher qicharts2::qic() direkte output", {
  data <- data.frame(
    period = 1:10,
    events = c(8, 12, 10, 14, 9, 11, 13, 7, 10, 12),
    total = rep(100L, 10)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "pp")
  )

  expected <- qicharts2::qic(
    period, events,
    n = total, data = data,
    chart = "pp", return.data = TRUE
  )

  expect_equal(result$qic_data$cl, expected$cl, tolerance = 1e-9)
  expect_equal(result$qic_data$ucl, expected$ucl, tolerance = 1e-9)
  expect_equal(result$qic_data$lcl, expected$lcl, tolerance = 1e-9)
  expect_equal(result$qic_data$y, expected$y, tolerance = 1e-9)
})

test_that("pp-chart cl er pooled p_bar (sum(events) / sum(n))", {
  data <- data.frame(
    period = 1:8,
    events = c(8, 12, 10, 14, 9, 11, 13, 7),
    total = c(80, 100, 90, 120, 85, 95, 110, 75)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "pp")
  )

  expected_p_bar <- sum(data$events) / sum(data$total)

  # Centerlinje = pooled p_bar (samme formel som klassisk p-chart)
  expect_equal(result$qic_data$cl[1], expected_p_bar, tolerance = 1e-6)
})

test_that("pp-chart har ikke-trivielle kontrolgrænser (ikke konstant cl=ucl=lcl)", {
  data <- data.frame(
    period = 1:10,
    events = c(8, 12, 10, 14, 9, 11, 13, 7, 10, 12),
    total = rep(100L, 10)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "pp")
  )

  qd <- result$qic_data
  expect_gt(qd$ucl[1], qd$cl[1])
  expect_lt(qd$lcl[1], qd$cl[1])
})

# ============================================================================
# UP-CHART — rate percent (Laney u' / Wheeler prime correction)
# ============================================================================
#
# Tilsvarende pp men for u-chart (rates per exposure unit):
#   sigma_u_classic_i = sqrt(u_bar / n_i)
#   z_i = (u_i - u_bar) / sigma_u_classic_i
#   sigma_z = MR_bar(z) / 1.128
#   sigma_up_i = sigma_u_classic_i · sigma_z
#   UCL_i = u_bar + 3 · sigma_up_i
#
# Reference: Laney's prime-formel udvidet til rates.

test_that("up-chart wrapping matcher qicharts2::qic() direkte output", {
  data <- data.frame(
    period = 1:10,
    events = c(3, 5, 4, 6, 2, 7, 4, 5, 3, 6),
    total = rep(100L, 10)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "up")
  )

  expected <- qicharts2::qic(
    period, events,
    n = total, data = data,
    chart = "up", return.data = TRUE
  )

  expect_equal(result$qic_data$cl, expected$cl, tolerance = 1e-9)
  expect_equal(result$qic_data$ucl, expected$ucl, tolerance = 1e-9)
  expect_equal(result$qic_data$lcl, expected$lcl, tolerance = 1e-9)
  expect_equal(result$qic_data$y, expected$y, tolerance = 1e-9)
})

test_that("up-chart cl er pooled u_bar (sum(events) / sum(n))", {
  data <- data.frame(
    period = 1:8,
    events = c(3, 5, 4, 6, 2, 7, 4, 5),
    total = c(80, 100, 90, 120, 85, 95, 110, 75)
  )

  result <- suppressWarnings(
    bfh_qic(data, x = period, y = events, n = total, chart_type = "up")
  )

  expected_u_bar <- sum(data$events) / sum(data$total)
  expect_equal(result$qic_data$cl[1], expected_u_bar, tolerance = 1e-6)
})

# ============================================================================
# CROSS-CHART CONSISTENCY
# ============================================================================
#
# Sanity-check at chart-typer der er statistisk relaterede producerer
# konsistente outputs.

test_that("xbar og s charts på samme data har samme grand_mean baseline", {
  data <- data.frame(
    subgroup = rep(1:6, each = 4),
    value = rep(c(8, 10, 12, 10), 6)
  )

  xbar_result <- suppressWarnings(
    bfh_qic(data, x = subgroup, y = value, chart_type = "xbar")
  )
  s_result <- suppressWarnings(
    bfh_qic(data, x = subgroup, y = value, chart_type = "s")
  )

  # xbar.cl = grand mean = 10
  # s.cl = sd of subgroup = 1.633 (sd of c(8,10,12,10))
  expect_equal(xbar_result$qic_data$cl[1], 10, tolerance = 1e-6)
  expect_equal(s_result$qic_data$cl[1], sd(c(8, 10, 12, 10)), tolerance = 1e-6)
})

test_that("mr og i charts på samme data har konsistente sigma-estimater", {
  values <- c(10, 11, 9, 12, 10, 11, 13, 10, 12, 11)
  data <- data.frame(period = seq_along(values), value = values)

  i_result <- suppressWarnings(
    bfh_qic(data, x = period, y = value, chart_type = "i")
  )
  mr_result <- suppressWarnings(
    bfh_qic(data, x = period, y = value, chart_type = "mr")
  )

  # I-chart UCL bruger sigma_hat = MR_bar / d2 (d2 = 1.128 for n=2)
  # mr-chart UCL = D4 · MR_bar
  # I-chart half-width = 3 · MR_bar / 1.128 ≈ 2.66 · MR_bar
  # mr-chart UCL/MR_bar = D4 = 3.267
  mr_bar <- mr_result$qic_data$cl[1]

  i_half_width <- i_result$qic_data$ucl[1] - i_result$qic_data$cl[1]
  expect_equal(i_half_width, 3 * mr_bar / 1.128,
    tolerance = 1e-3,
    label = "I-chart half-width = 3·MR_bar/d2"
  )
})
