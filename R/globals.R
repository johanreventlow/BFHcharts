# Global variables for NSE in ggplot2/dplyr
# Suppresses R CMD check NOTEs about "no visible binding"

utils::globalVariables(c(
  # ggplot2 aesthetics
  "x", "y", "lcl", "ucl", "target", "cl", 
  "label", "color", "vjust",
  
  # dplyr/qicharts2 columns
  "part", "anhoej.signal",
  "n.crossings", "n.crossings.min",
  "part_n_cross", "part_n_cross_min",
  
  # From stats/utils
  "median", "var", "head", "tail"
))
