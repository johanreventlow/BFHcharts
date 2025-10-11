#!/usr/bin/env Rscript
# Test script for label placement system
# Kører uden at pakken skal være kompileret

# Load all package functions
devtools::load_all(".")

library(qicharts2)
library(ggplot2)

cat("Testing label placement system...\n\n")

# Test 1: Basic I-chart with labels ----
cat("Test 1: I-chart med CL og Target labels\n")

set.seed(123)
data1 <- data.frame(
  month = seq(as.Date("2023-01-01"), by = "month", length.out = 24),
  infections = c(
    rnorm(12, 22, 3),  # Baseline
    rnorm(12, 14, 2)   # Efter intervention
  )
)

# Calculate QIC data
qic_result <- qic(
  x = month,
  y = infections,
  data = data1,
  chart = "i",
  part = 12,
  target = 18,
  return.data = TRUE
)

# Create plot with BFH styling
plot1 <- bfh_spc_plot(
  qic_data = qic_result,
  plot_config = spc_plot_config(
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Test: I-Chart med Labels",
    target_value = 18,
    target_text = "<18"
  ),
  viewport = viewport_dims(base_size = 14)
)

# Add labels
plot1_with_labels <- add_spc_labels(
  plot = plot1,
  qic_data = qic_result,
  y_axis_unit = "count",
  label_size = 6,
  target_text = "<18",
  verbose = TRUE
)

# Save plot
ggsave(
  "demo_output/test_labels_01_ichart.png",
  plot1_with_labels,
  width = 10,
  height = 6,
  dpi = 96
)

cat("✓ Test 1 completed: demo_output/test_labels_01_ichart.png\n\n")

# Test 2: P-chart with arrow symbol ----
cat("Test 2: P-chart med pil-symbol (target suppression)\n")

data2 <- data.frame(
  month = seq(as.Date("2023-01-01"), by = "month", length.out = 24),
  infections = c(rpois(12, 25), rpois(12, 15)),
  surgeries = rep(100, 24)
)

qic_result2 <- qic(
  x = month,
  y = infections,
  n = surgeries,
  data = data2,
  chart = "p",
  multiply = 100,
  part = 12,
  return.data = TRUE
)

plot2 <- bfh_spc_plot(
  qic_data = qic_result2,
  plot_config = spc_plot_config(
    chart_type = "p",
    y_axis_unit = "percent",
    chart_title = "Test: P-Chart med Pil",
    target_text = "<"  # Pil ned
  ),
  viewport = viewport_dims(base_size = 14)
)

plot2_with_labels <- add_spc_labels(
  plot = plot2,
  qic_data = qic_result2,
  y_axis_unit = "percent",
  label_size = 6,
  target_text = "<",  # Should trigger arrow symbol
  verbose = TRUE
)

ggsave(
  "demo_output/test_labels_02_pchart_arrow.png",
  plot2_with_labels,
  width = 10,
  height = 6,
  dpi = 96
)

cat("✓ Test 2 completed: demo_output/test_labels_02_pchart_arrow.png\n\n")

# Test 3: Coincident lines (CL = Target) ----
cat("Test 3: Sammenfaldende linjer (CL ≈ Target)\n")

data3 <- data.frame(
  month = seq(as.Date("2023-01-01"), by = "month", length.out = 24),
  value = rnorm(24, 50, 5)
)

qic_result3 <- qic(
  x = month,
  y = value,
  data = data3,
  chart = "i",
  target = 50,  # Very close to CL
  return.data = TRUE
)

plot3 <- bfh_spc_plot(
  qic_data = qic_result3,
  plot_config = spc_plot_config(
    chart_type = "i",
    y_axis_unit = "count",
    chart_title = "Test: Sammenfaldende Linjer",
    target_value = 50,
    target_text = ">=50"
  ),
  viewport = viewport_dims(base_size = 14)
)

plot3_with_labels <- add_spc_labels(
  plot = plot3,
  qic_data = qic_result3,
  y_axis_unit = "count",
  label_size = 6,
  target_text = ">=50",
  verbose = TRUE
)

ggsave(
  "demo_output/test_labels_03_coincident.png",
  plot3_with_labels,
  width = 10,
  height = 6,
  dpi = 96
)

cat("✓ Test 3 completed: demo_output/test_labels_03_coincident.png\n\n")

cat("All tests completed successfully!\n")
cat("Check demo_output/ for generated plots.\n")
