# BFHcharts Demo Test
# Demonstrerer at pakken fungerer korrekt med forskellige chart typer

# Load required packages
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

# Test 1: Simple Run Chart
plot1 <- create_spc_chart(
  data = demo_data,
  x = month,
  y = infections,
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = "Monthly Hospital-Acquired Infections - Run Chart",
  notes = c("","","","","","","","","","","Intervention","","","","","","","","","","","","","")
)

# Test 2: I-Chart with Phase Split (intervention at month 12)
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
) |> BFHtheme::add_logo()

# Test 3: P-Chart with denominator and target
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

# Return the plots for viewing
# Note: Plots are created and stored in plot1, plot2, plot3
# To view them in RStudio: plot1, plot2, plot3
# To save them: ggsave("filename.png", plot1)
