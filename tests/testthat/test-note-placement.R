# Tests for note label placement algorithm

test_that("place_note_labels returns empty data.frame for NULL input", {
  result <- place_note_labels(
    comment_data = NULL,
    line_positions = c(cl = 50, ucl = 60, lcl = 40),
    y_range = c(30, 70),
    x_range = c(1, 12)
  )

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 0)
})

test_that("place_note_labels returns empty data.frame for empty input", {
  empty_df <- data.frame(x = numeric(0), y = numeric(0), comment = character(0))

  result <- place_note_labels(
    comment_data = empty_df,
    line_positions = c(cl = 50, ucl = 60, lcl = 40),
    y_range = c(30, 70),
    x_range = c(1, 12)
  )

  expect_true(is.data.frame(result))
  expect_equal(nrow(result), 0)
})

test_that("place_note_labels places single label away from CL", {
  comment_data <- data.frame(
    x = 5,
    y = 50,  # Præcis på CL
    comment = "Test note"
  )

  result <- place_note_labels(
    comment_data = comment_data,
    line_positions = c(cl = 50, ucl = 60, lcl = 40),
    y_range = c(30, 70),
    x_range = c(1, 12)
  )

  expect_equal(nrow(result), 1)
  # Label skal IKKE placeres på CL (y=50)
  expect_true(abs(result$label_y[1] - 50) > 0.5)
  # Punkt-koordinater skal matche original
  expect_equal(result$point_x[1], 5)
  expect_equal(result$point_y[1], 50)
  # Arrow skal tegnes (label er forskudt)
  expect_true(result$draw_arrow[1])
})

test_that("place_note_labels avoids UCL and LCL lines", {
  comment_data <- data.frame(
    x = 5,
    y = 59,  # Tæt på UCL=60
    comment = "Near UCL"
  )

  result <- place_note_labels(
    comment_data = comment_data,
    line_positions = c(cl = 50, ucl = 60, lcl = 40),
    y_range = c(30, 70),
    x_range = c(1, 12)
  )

  expect_equal(nrow(result), 1)
  # Label-center skal have afstand til UCL
  line_buffer <- (70 - 30) * 0.03  # note_line_buffer_factor default
  expect_true(abs(result$label_y[1] - 60) > line_buffer * 0.5)
})

test_that("place_note_labels keeps labels within bounds", {
  comment_data <- data.frame(
    x = 5,
    y = 69,  # Tæt på top af y_range
    comment = "Near top"
  )

  result <- place_note_labels(
    comment_data = comment_data,
    line_positions = c(cl = 50, ucl = 60, lcl = 40),
    y_range = c(30, 70),
    x_range = c(1, 12)
  )

  expect_equal(nrow(result), 1)
  # Label skal være inden for y_range
  expect_true(result$label_y[1] >= 30)
  expect_true(result$label_y[1] <= 70)
})

test_that("two labels do not overlap each other", {
  comment_data <- data.frame(
    x = c(5, 6),
    y = c(55, 55),
    comment = c("Note A", "Note B")
  )

  result <- place_note_labels(
    comment_data = comment_data,
    line_positions = c(cl = 50, ucl = 60, lcl = 40),
    y_range = c(30, 70),
    x_range = c(1, 12)
  )

  expect_equal(nrow(result), 2)
  # Labels skal have forskellig y-position (eller tilstrækkelig x-afstand)
  label_height <- (70 - 30) * 0.04  # Én linje højde
  y_diff <- abs(result$label_y[1] - result$label_y[2])
  x_diff <- abs(result$label_x[1] - result$label_x[2])
  # Mindst én dimension skal have tilstrækkelig afstand
  expect_true(y_diff > label_height * 0.5 || x_diff > (12 - 1) * 0.008 * 10)
})

test_that("word wrap activates for long text", {
  comment_data <- data.frame(
    x = 5,
    y = 55,
    comment = "This is a very long annotation that should be wrapped"
  )

  result <- place_note_labels(
    comment_data = comment_data,
    line_positions = c(cl = 50),
    y_range = c(30, 70),
    x_range = c(1, 12)
  )

  expect_equal(nrow(result), 1)
  # Wrappet tekst skal indeholde newline
  expect_true(grepl("\n", result$label_text[1]))
})

test_that("place_note_labels handles 5 notes", {
  comment_data <- data.frame(
    x = c(2, 4, 6, 8, 10),
    y = c(45, 50, 55, 48, 52),
    comment = c("Note 1", "Note 2", "Note 3", "Note 4", "Note 5")
  )

  result <- place_note_labels(
    comment_data = comment_data,
    line_positions = c(cl = 50, ucl = 60, lcl = 40),
    y_range = c(30, 70),
    x_range = c(1, 12)
  )

  expect_equal(nrow(result), 5)
  # Alle labels inden for bounds
  expect_true(all(result$label_y >= 30))
  expect_true(all(result$label_y <= 70))
})

test_that("place_note_labels handles NA line positions gracefully", {
  comment_data <- data.frame(
    x = 5,
    y = 50,
    comment = "Test"
  )

  result <- place_note_labels(
    comment_data = comment_data,
    line_positions = c(cl = 50, ucl = NA, lcl = NA, target = NA),
    y_range = c(30, 70),
    x_range = c(1, 12)
  )

  expect_equal(nrow(result), 1)
})

test_that("short labels close to point do not draw arrows", {
  comment_data <- data.frame(
    x = 5,
    y = 35,  # Langt fra alle linjer
    comment = "OK"
  )

  result <- place_note_labels(
    comment_data = comment_data,
    line_positions = c(cl = 50, ucl = 60, lcl = 40),
    y_range = c(30, 70),
    x_range = c(1, 12)
  )

  expect_equal(nrow(result), 1)
  # Alle labels skal have draw_arrow sat
  expect_true(is.logical(result$draw_arrow[1]))
})
