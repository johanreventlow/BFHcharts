# ============================================================================
# Preview label-placement på 9 vdiffr baseline-scenarier
# ============================================================================
#
# Renderer alle baseline-charts fra tests/testthat/test-visual-regression.R
# som PNG i dev/preview_labels/ for visuel inspektion af label-placering.
#
# Usage:
#   Rscript dev/preview_labels.R
#
# Output:
#   dev/preview_labels/{scenario}.png — 1200x900 px, ~150 dpi
#   Aabner output-dir i Finder paa macOS
#
# Iteration:
#   - Rediger BFHcharts kode
#   - Genkoer scriptet (devtools::load_all() reloader pakke)
#   - Sammenlign PNG i Preview.app
# ============================================================================

devtools::load_all(quiet = TRUE)

out_dir <- file.path("dev", "preview_labels")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Deterministisk fixture (matcher tests/testthat/helper-fixtures.R:45)
fixture_run <- function(n = 12) {
  values <- c(14, 16, 13, 15, 18, 12, 17, 14, 19, 13, 15, 16)
  data.frame(
    month = seq(as.Date("2024-01-01"), by = "month", length.out = n),
    infections = rep_len(values, n)
  )
}

scenarios <- list(
  list(
    name = "run-chart-basic",
    fn = function() {
      bfh_qic(
        fixture_run(),
        x = month, y = infections,
        chart_type = "run", y_axis_unit = "count",
        chart_title = "Run Chart Reference"
      )
    }
  ),
  list(
    name = "i-chart-with-limits",
    fn = function() {
      bfh_qic(
        fixture_run(),
        x = month, y = infections,
        chart_type = "i", y_axis_unit = "count",
        chart_title = "I-Chart Reference"
      )
    }
  ),
  list(
    name = "p-chart-variable-limits",
    fn = function() {
      data <- data.frame(
        month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
        events = c(5, 8, 12, 10, 15, 11, 9, 14, 13, 16, 12, 10),
        total = c(100, 120, 150, 110, 180, 130, 115, 160, 145, 170, 135, 125)
      )
      suppressWarnings(bfh_qic(
        data,
        x = month, y = events, n = total,
        chart_type = "p", y_axis_unit = "percent",
        chart_title = "P-Chart Reference"
      ))
    }
  ),
  list(
    name = "u-chart-basic",
    fn = function() {
      data <- data.frame(
        month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
        events = c(3, 5, 8, 4, 7, 6, 5, 9, 7, 8, 6, 5),
        exposure = c(50, 60, 80, 55, 75, 65, 58, 90, 72, 85, 68, 62)
      )
      suppressWarnings(bfh_qic(
        data,
        x = month, y = events, n = exposure,
        chart_type = "u", y_axis_unit = "count",
        chart_title = "U-Chart Reference"
      ))
    }
  ),
  list(
    name = "c-chart-basic",
    fn = function() {
      data <- data.frame(
        month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
        count = c(3, 7, 5, 5, 5, 5, 6, 4, 5, 6, 4, 5)
      )
      suppressWarnings(bfh_qic(
        data,
        x = month, y = count,
        chart_type = "c", y_axis_unit = "count",
        chart_title = "C-Chart Reference"
      ))
    }
  ),
  list(
    name = "i-chart-multi-phase",
    fn = function() {
      data <- data.frame(
        month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
        value = c(rep(c(19, 20, 21), 4), rep(c(14, 15, 16), 4))
      )
      bfh_qic(
        data,
        x = month, y = value,
        chart_type = "i", y_axis_unit = "count",
        chart_title = "Multi-Phase Reference",
        part = 12
      )
    }
  ),
  list(
    name = "run-chart-with-target",
    fn = function() {
      bfh_qic(
        fixture_run(),
        x = month, y = infections,
        chart_type = "run", y_axis_unit = "count",
        chart_title = "Chart with Target",
        target_value = 15,
        target_text = "Target: 15"
      )
    }
  ),
  list(
    name = "p-chart-with-notes",
    fn = function() {
      data <- data.frame(
        month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
        events = c(5, 8, 12, 10, 15, 11, 9, 14, 13, 16, 12, 10),
        total = c(100, 120, 150, 110, 180, 130, 115, 160, 145, 170, 135, 125)
      )
      notes_vec <- c(
        NA, NA, "Intervention", NA, NA, NA,
        "Audit", NA, NA, NA, NA, "Follow-up"
      )
      suppressWarnings(bfh_qic(
        data,
        x = month, y = events, n = total,
        notes = notes_vec,
        chart_type = "p", y_axis_unit = "percent",
        chart_title = "P-Chart with Notes"
      ))
    }
  ),
  list(
    name = "run-chart-with-custom-labels",
    fn = function() {
      bfh_qic(
        fixture_run(),
        x = month, y = infections,
        chart_type = "run", y_axis_unit = "count",
        chart_title = "Chart with Custom Labels",
        xlab = "Maaned",
        ylab = "Infektioner pr. maaned"
      )
    }
  )
)

cat("Rendering", length(scenarios), "scenarios to", out_dir, "...\n\n")

for (s in scenarios) {
  cat(sprintf("  %-30s ... ", s$name))
  t0 <- Sys.time()
  result <- tryCatch(s$fn(), error = function(e) {
    cat("ERROR:", conditionMessage(e), "\n")
    return(NULL)
  })
  if (is.null(result)) next

  out_path <- file.path(out_dir, paste0(s$name, ".png"))
  ggplot2::ggsave(
    out_path,
    plot = result$plot,
    width = 10, height = 7.5, dpi = 150,
    bg = "white"
  )
  dt <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
  cat(sprintf("OK (%ss)\n", dt))
}

cat("\nDone.\n")
cat("Output:", normalizePath(out_dir), "\n")

# Open dir on macOS
if (Sys.info()[["sysname"]] == "Darwin") {
  system2("open", out_dir)
}
