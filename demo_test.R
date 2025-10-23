# BFHcharts Demo Test
# Demonstrerer at pakken fungerer korrekt med forskellige chart typer

# Load required packages
devtools::load_all()
library(ggplot2)

# IMPORTANT: When running scripts non-interactively, R opens a PDF device by default
# PDF devices have font rendering issues. Use PNG device instead.
if (!interactive()) {
  # Close any auto-opened PDF device
  if (names(dev.cur()) == "pdf") {
    dev.off()
  }
  # Open PNG device for plot rendering
  png("demo_plots.png", width = 1200, height = 1600, res = 96)
  cat("Non-interactive mode: Plots will be saved to demo_plots.png\n")
}

# Create example data: Monthly hospital-acquired infections
set.seed(123) # For reproducible results

demo_data <- data.frame(
  month = seq(as.Date("2023-01-01"), by = "month", length.out = 24),
  infections = c(
    # First 12 months - before intervention
    18, 22, 19, 25, 21, 23, 20, 24, 22, 26, 21, 23,
    # Last 12 months - after intervention (lower mean)
    15, 14, 16, 13, 15, 12, 14, 13, 15, 11, 14, 12
  ),
  surgeries = rpois(24, lambda = 100)
)

# Test 1: Simple Run Chart
cat("\n=== Test 1: Run Chart ===\n")
plot1 <- create_spc_chart(
  data = demo_data,
  x = month,
  y = infections,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Monthly Hospital-Acquired Infections - Run Chart",
  notes = c(rep(NA, 10), "Intervention", rep(NA, 13))  # Note at position 11
)
print(plot1)

# Test 2: I-Chart with Phase Split (intervention at month 12)
cat("\n=== Test 2: I-Chart with Phase Split ===\n")
plot2 <- create_spc_chart(
  data = demo_data,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count",
  chart_title = "Infections Before/After Intervention - I-Chart",
  part = c(12),  # Phase split after 12 months
  target_value = 18,
  target_text = ">=18"
)

# Try to add logo (may fail if fonts not available)
tryCatch({
  plot2 <- plot2 |> BFHtheme::add_logo()
}, error = function(e) {
  cat("Note: Could not add logo (font issue). Chart still works fine.\n")
})
print(plot2)

# Test 3: P-Chart with denominator and target
cat("\n=== Test 3: P-Chart with Target ===\n")
plot3 <- create_spc_chart(
  data = demo_data,
  x = month,
  y = infections,
  n = surgeries,
  chart_type = "p",
  y_axis_unit = "percent",
  chart_title = "Infection Rate per 100 Surgeries",
  subtitle = "Control chart with target line",
  caption = "Created with BFHcharts",
  target_text = "<",  # Arrow symbol - suppresses target line
  target_value = 25,
  xlab = "Month",
  ylab = "Infections"
)
print(plot3)

# Test 4: Get summary statistics (new feature)
cat("\n=== Test 4: Summary Statistics (New Feature) ===\n")
result <- create_spc_chart(
  data = demo_data,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count",
  chart_title = "Infections with Summary",
  part = c(12),
  print.summary = TRUE
)
print(result$plot)
cat("\nSummary Statistics:\n")
print(result$summary)

cat("\n=== All tests completed ===\n")

# Close graphics device if non-interactive
if (!interactive()) {
  dev.off()
  cat("\nPlots saved to demo_plots.png\n")
  cat("Open the file to view all 4 test plots\n")
} else {
  cat("Plots are stored in: plot1, plot2, plot3, result$plot\n")
  cat("To save: ggsave('filename.png', plot1, width = 25, height = 15, units = 'cm')\n")
}
