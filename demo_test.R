# BFHcharts Demo Test
# Demonstrerer at pakken fungerer korrekt

# Load required packages
# library(BFHcharts)
devtools::load_all()
library(ggplot2)

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

# print("=== BFHcharts Demo Test ===")
# print("")
# print("Demo data (first 6 rows):")
# print(head(demo_data))
# print("")

# Test 1: Simple Run Chart
# print("Test 1: Creating simple run chart...")
plot1 <- create_spc_chart(
  data = demo_data,
  x = month,
  y = infections,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Monthly Hospital-Acquired Infections - Run Chart"
)
plot1

# print("✓ Run chart created successfully")
# print("")

# Test 2: I-Chart with Phase Split (intervention at month 12)
# print("Test 2: Creating I-chart with intervention and labels...")
plot2 <- create_spc_chart(
  data = demo_data,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count",
  chart_title = "Infections Before/After Intervention - I-Chart",
  part = c(12),  # Phase split after 12 months
  # freeze = 12,   # Freeze baseline at month 12
  target_value = 18,
  target_text = "<18",
  # width = 10,    # Specify dimensions for optimal label placement
  # height = 6
)

plot2

# print("✓ I-chart with phase split and labels created successfully")
# print("")

# Test 3: P-Chart with denominator and target
# print("Test 3: Creating P-chart with arrow symbol...")
plot3 <- create_spc_chart(
  data = demo_data,
  x = month,
  y = infections,
  n = surgeries,
  chart_type = "p",
  y_axis_unit = "percent",
  chart_title = "Infection Rate per 100 Surgeries - P-Chart",
  target_text = "<",  # Arrow symbol - suppresses target line
  # width = 10,
  # height = 6
)

plot3

print("✓ P-chart with arrow symbol and labels created successfully")
print("")

# Test 4: Custom colors
print("Test 4: Creating chart with custom colors...")
custom_colors <- create_color_palette(
  primary = "#003366",
  secondary = "#808080",
  accent = "#FF9900"
)

plot4 <- create_spc_chart(
  data = demo_data,
  x = month,
  y = infections,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Custom Branded Chart",
  colors = custom_colors
)

plot4

print("✓ Custom colored chart created successfully")
print("")

# Save plots to output directory
output_dir <- "demo_output"
if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}

print(paste0("Saving plots to ", output_dir, "/..."))

ggsave(
  filename = file.path(output_dir, "01_run_chart.png"),
  plot = plot1,
  width = 10,
  height = 6,
  dpi = 300
)
print("  ✓ Saved: 01_run_chart.png")

ggsave(
  filename = file.path(output_dir, "02_i_chart_intervention.png"),
  plot = plot2,
  width = 10,
  height = 6,
  dpi = 300
)
print("  ✓ Saved: 02_i_chart_intervention.png")

ggsave(
  filename = file.path(output_dir, "03_p_chart_target.png"),
  plot = plot3,
  width = 10,
  height = 6,
  dpi = 300
)
print("  ✓ Saved: 03_p_chart_target.png")

ggsave(
  filename = file.path(output_dir, "04_custom_colors.png"),
  plot = plot4,
  width = 10,
  height = 6,
  dpi = 300
)
print("  ✓ Saved: 04_custom_colors.png")

print("")
print("=== ALL TESTS PASSED ===")
print("")
print(paste0("📊 4 plots saved to: ", normalizePath(output_dir)))
print("")
print("To view the plots:")
print(paste0("  open ", file.path(output_dir, "01_run_chart.png")))
print("")
print("Or display in R:")
print("  print(plot1)  # Run chart")
print("  print(plot2)  # I-chart with intervention")
print("  print(plot3)  # P-chart with target")
print("  print(plot4)  # Custom colors")
print("")

# Return the last plot for interactive viewing
print(plot2)
