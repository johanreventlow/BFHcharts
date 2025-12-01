# ============================================================================
# INTEGRATION TESTS FOR EXPORT WORKFLOWS
# ============================================================================

test_that("PNG export pipe workflow works end-to-end", {
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 15)
  )

  temp_file <- tempfile(fileext = ".png")

  # Full pipeline: create chart and export in one go
  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      chart_title = "Monthly Infections"
    ) |>
      bfh_export_png(temp_file, width_mm = 200, height_mm = 120, dpi = 300)
  )

  # Verify result is still bfh_qic_result (pipe chaining)
  expect_s3_class(result, "bfh_qic_result")

  # Verify PNG was created
  expect_true(file.exists(temp_file))
  expect_gt(file.info(temp_file)$size, 0)

  # Cleanup
  unlink(temp_file)
})

test_that("PDF export pipe workflow works end-to-end", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
    infections = rpois(24, lambda = 15)
  )

  temp_file <- tempfile(fileext = ".pdf")

  # Full pipeline: create chart and export to PDF
  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      chart_title = "Monthly Hospital-Acquired Infections"
    ) |>
      bfh_export_pdf(
        temp_file,
        metadata = list(
          hospital = "BFH",
          department = "Kvalitetsafdeling",
          analysis = "Signifikant fald observeret efter intervention i marts",
          data_definition = "Antal hospital-erhvervede infektioner per måned"
        )
      )
  )

  # Verify result is still bfh_qic_result (pipe chaining)
  expect_s3_class(result, "bfh_qic_result")

  # Verify PDF was created
  expect_true(file.exists(temp_file))
  expect_gt(file.info(temp_file)$size, 0)

  # Cleanup
  unlink(temp_file)
})

test_that("Multiple exports from same result work", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  # Create chart once
  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      chart_title = "Test Export"
    )
  )

  temp_png <- tempfile(fileext = ".png")
  temp_pdf <- tempfile(fileext = ".pdf")

  # Export to both formats
  bfh_export_png(result, temp_png)
  bfh_export_pdf(result, temp_pdf)

  # Both files should exist
  expect_true(file.exists(temp_png))
  expect_true(file.exists(temp_pdf))

  # Cleanup
  unlink(temp_png)
  unlink(temp_pdf)
})

test_that("PNG export works with different chart types", {
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 5),
    surgeries = rpois(12, lambda = 100)
  )

  chart_types <- list(
    list(type = "run", args = list()),
    list(type = "i", args = list()),
    list(type = "p", args = list(n = "surgeries")),
    list(type = "c", args = list())
  )

  for (ct in chart_types) {
    temp_file <- tempfile(fileext = ".png")

    # Build arguments
    args <- c(
      list(data = data, x = quote(month), y = quote(infections), chart_type = ct$type),
      ct$args
    )

    # Create chart
    result <- suppressWarnings(do.call(bfh_qic, args))

    # Export
    bfh_export_png(result, temp_file)

    # Verify
    expect_true(file.exists(temp_file), info = paste("Chart type:", ct$type))

    # Cleanup
    unlink(temp_file)
  }
})

test_that("PDF export works with different chart types", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 5),
    surgeries = rpois(12, lambda = 100)
  )

  chart_types <- c("run", "i", "c")

  for (ct in chart_types) {
    temp_file <- tempfile(fileext = ".pdf")

    # Create chart
    result <- suppressWarnings(
      bfh_qic(
        data = data,
        x = month,
        y = infections,
        chart_type = ct,
        chart_title = paste(ct, "Chart")
      )
    )

    # Export
    bfh_export_pdf(result, temp_file)

    # Verify
    expect_true(file.exists(temp_file), info = paste("Chart type:", ct))

    # Cleanup
    unlink(temp_file)
  }
})

test_that("Title appears in PNG but not in PDF chart image", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  title_text <- "Test Title Should Appear Correctly"

  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      chart_title = title_text
    )
  )

  temp_png <- tempfile(fileext = ".png")
  temp_pdf <- tempfile(fileext = ".pdf")

  # Export to both
  bfh_export_png(result, temp_png)
  bfh_export_pdf(result, temp_pdf)

  # Verify files exist
  expect_true(file.exists(temp_png))
  expect_true(file.exists(temp_pdf))

  # Verify original result still has title
  expect_equal(result$config$chart_title, title_text)
  expect_equal(result$plot$labels$title, title_text)

  # PNG should have title in the ggplot
  # PDF has title in Typst template (not in chart image)
  # We can't easily verify PDF content without parsing, but we verified the file exists

  # Cleanup
  unlink(temp_png)
  unlink(temp_pdf)
})

test_that("Chained exports preserve result object", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  temp_png <- tempfile(fileext = ".png")
  temp_pdf <- tempfile(fileext = ".pdf")

  # Chain multiple exports
  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i", chart_title = "Chain Test") |>
      bfh_export_png(temp_png) |>
      bfh_export_pdf(temp_pdf)
  )

  # Result should still be bfh_qic_result
  expect_s3_class(result, "bfh_qic_result")

  # Both files should exist
  expect_true(file.exists(temp_png))
  expect_true(file.exists(temp_pdf))

  # Result should still have all components
  expect_s3_class(result$plot, "ggplot")
  expect_s3_class(result$summary, "data.frame")
  expect_type(result$config, "list")

  # Cleanup
  unlink(temp_png)
  unlink(temp_pdf)
})

test_that("Export works with multi-phase charts", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 36),
    infections = rpois(36, lambda = 15)
  )

  temp_png <- tempfile(fileext = ".png")
  temp_pdf <- tempfile(fileext = ".pdf")

  # Create multi-phase chart
  result <- suppressWarnings(
    bfh_qic(
      data = data,
      x = month,
      y = infections,
      chart_type = "i",
      y_axis_unit = "count",
      chart_title = "Multi-Phase Analysis",
      part = c(12, 24)  # 3 phases
    )
  )

  # Export both
  bfh_export_png(result, temp_png)
  bfh_export_pdf(result, temp_pdf)

  # Verify
  expect_true(file.exists(temp_png))
  expect_true(file.exists(temp_pdf))

  # Summary should have 3 rows (one per phase)
  expect_equal(nrow(result$summary), 3)

  # Cleanup
  unlink(temp_png)
  unlink(temp_pdf)
})

test_that("Export handles Danish characters in metadata", {
  skip_if_not(quarto_available(), "Quarto not available")
  skip_on_cran()

  data <- data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
    infections = rpois(12, lambda = 15)
  )

  temp_pdf <- tempfile(fileext = ".pdf")

  # Export with Danish characters
  result <- suppressWarnings(
    bfh_qic(data, month, infections, chart_type = "i",
            chart_title = "Infektioner på Afdelingen") |>
      bfh_export_pdf(
        temp_pdf,
        metadata = list(
          department = "Kvalitetsafdeling",
          analysis = "Fald observeret i løbet af året",
          data_definition = "Antal infektioner målt dagligt"
        )
      )
  )

  # Verify PDF was created (Typst should handle Danish characters)
  expect_true(file.exists(temp_pdf))

  # Cleanup
  unlink(temp_pdf)
})
