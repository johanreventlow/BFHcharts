test_that("notes parameter creates plot without errors", {
  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  notes_vec <- rep(NA, 12)
  notes_vec[3] <- "Test intervention"
  notes_vec[8] <- "New protocol"

  plot <- bfh_qic(
    data = data,
    x = month,
    y = infections,
    chart_type = "run",
    y_axis_unit = "count",
    notes = notes_vec
  )

  expect_s3_class(plot, "bfh_qic_result")
  expect_s3_class(plot$plot, "ggplot")
})

test_that("extract_comment_data extracts notes from qic output", {
  qic_data <- qicharts2::qic(
    x = month,
    y = infections,
    data = data.frame(
      month = 1:12,
      infections = rpois(12, 15)
    ),
    chart = "run",
    notes = c(NA, NA, "Intervention", rep(NA, 9)),
    return.data = TRUE
  )

  comment_data <- extract_comment_data(qic_data)

  expect_true(is.data.frame(comment_data))
  expect_equal(nrow(comment_data), 1)
  expect_equal(comment_data$comment[1], "Intervention")
})

test_that("extract_comment_data returns NULL when no notes present", {
  qic_data <- qicharts2::qic(
    x = month,
    y = infections,
    data = data.frame(
      month = 1:12,
      infections = rpois(12, 15)
    ),
    chart = "run",
    return.data = TRUE
  )

  comment_data <- extract_comment_data(qic_data)

  expect_null(comment_data)
})

test_that("extract_comment_data handles all-NA notes", {
  qic_data <- qicharts2::qic(
    x = month,
    y = infections,
    data = data.frame(
      month = 1:12,
      infections = rpois(12, 15)
    ),
    chart = "run",
    notes = rep(NA, 12),
    return.data = TRUE
  )

  comment_data <- extract_comment_data(qic_data)

  expect_null(comment_data)
})

test_that("extract_comment_data truncates long comments", {
  qic_data <- qicharts2::qic(
    x = month,
    y = infections,
    data = data.frame(
      month = 1:12,
      infections = rpois(12, 15)
    ),
    chart = "run",
    notes = c(NA, paste(rep("long text", 30), collapse = " "), rep(NA, 10)),
    return.data = TRUE
  )

  comment_data <- extract_comment_data(qic_data, max_length = 50)

  expect_true(nchar(comment_data$comment[1]) <= 50)
  expect_true(grepl("\\.\\.\\.$", comment_data$comment[1]))
})
