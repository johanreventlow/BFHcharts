# Debug script til at teste date formatting
library(BFHcharts)

# Test label_date_short() direkte
cat("=== Test 1: label_date_short() direkte ===\n")
test_dates <- seq(as.Date("2022-01-01"), as.Date("2025-01-01"), by = "6 months")
test_dates_posix <- as.POSIXct(test_dates)

# Test default
labeler1 <- scales::label_date_short()
cat("Default format:\n")
print(labeler1(test_dates_posix))

# Test med format parameter (som monthly >= 40 case)
labeler2 <- scales::label_date_short(format = c("%Y", "", ""), sep = "")
cat("\nMed format = c('%Y', '', ''), sep = '':\n")
print(labeler2(test_dates_posix))

# Test med format for quarterly
labeler3 <- scales::label_date_short(format = c("%Y", "%b", ""))
cat("\nMed format = c('%Y', '%b', ''):\n")
print(labeler3(test_dates_posix))

# Test interval detection
cat("\n=== Test 2: Interval Detection ===\n")
monthly_dates <- seq(as.Date("2022-01-01"), by = "month", length.out = 47)
interval_info <- BFHcharts:::detect_date_interval(monthly_dates)
cat("47 monthly observations:\n")
print(interval_info)

format_config <- BFHcharts:::get_optimal_formatting(interval_info)
cat("\nOptimal formatting config:\n")
print(format_config)

# Test med gaps (quarterly classification)
cat("\n=== Test 3: Data med Gaps ===\n")
dates_with_gaps <- as.Date(c(
  "2022-01-01", "2022-04-01", "2022-07-01", "2022-10-01",
  "2023-01-01", "2023-04-01", "2023-07-01", "2023-10-01",
  "2024-01-01", "2024-04-01", "2024-07-01", "2024-10-01"
))
interval_info_gaps <- BFHcharts:::detect_date_interval(dates_with_gaps)
cat("Quarterly-spaced data:\n")
print(interval_info_gaps)

format_config_gaps <- BFHcharts:::get_optimal_formatting(interval_info_gaps)
cat("\nOptimal formatting config:\n")
print(format_config_gaps)

cat("\n=== Test 4: Apply labels ===\n")
if (!is.null(format_config_gaps$labels) && is.function(format_config_gaps$labels)) {
  cat("Applying labels to quarterly dates:\n")
  print(format_config_gaps$labels(as.POSIXct(dates_with_gaps)))
} else {
  cat("ERROR: labels er ikke en funktion!\n")
  print(format_config_gaps$labels)
}

cat("\n=== Done ===\n")
