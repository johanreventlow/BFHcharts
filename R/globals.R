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

# ============================================================================
# SIZING CONSTANTS
# ============================================================================

# Reference base_size for label sizing calculations
# Used to scale labels responsively based on viewport
REFERENCE_BASE_SIZE <- 14

# Default label size multiplier at reference base_size
# Produces optimal label sizing across different viewport sizes
DEFAULT_LABEL_SIZE_MULTIPLIER <- 6
