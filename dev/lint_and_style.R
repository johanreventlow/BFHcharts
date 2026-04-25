# lint_and_style.R
# Pre-commit code quality: lint + style kun staged R-filer
# Exit codes: 0 = OK, 1 = kritiske fejl, 2 = warnings

library(lintr)
library(styler)

args <- commandArgs(trailingOnly = TRUE)

if (length(args) > 0) {
  paths_to_check <- args[file.exists(args)]
  cat("Koerer lintr code quality check paa staged filer...\n")
} else {
  paths_to_check <- list.files("R/", pattern = "\\.R$",
    full.names = TRUE, recursive = TRUE)
  cat("Koerer lintr code quality check paa hele projektet...\n")
}

if (length(paths_to_check) == 0) {
  cat("Ingen R-filer at checke.\n")
  quit(save = "no", status = 0)
}

# LINTING ====================================================================

lint_results <- list()
for (path in paths_to_check) {
  cat("Checker:", path, "\n")
  lint_results[[path]] <- tryCatch(
    lint(path),
    error = function(e) {
      cat("  Lint fejl:", e$message, "\n")
      list()
    }
  )
}

total_issues <- sum(vapply(lint_results, length, integer(1)))
cat("\nLintr resultater: ", total_issues, " issues\n")

has_errors <- FALSE
has_warnings <- FALSE

if (total_issues > 0) {
  for (file in names(lint_results)) {
    issues <- lint_results[[file]]
    if (length(issues) > 0) {
      cat("\n", file, ":\n")
      print(issues)
      for (issue in issues) {
        if (issue$type == "error") has_errors <- TRUE
        if (issue$type %in% c("warning", "style")) has_warnings <- TRUE
      }
    }
  }
}

# STYLING ====================================================================

cat("\nKoerer styler code formatting...\n")

for (path in paths_to_check) {
  if (file.exists(path) && !dir.exists(path)) {
    tryCatch(
      style_file(path),
      error = function(e) {
        cat("  Styler fejl (ikke-kritisk):", conditionMessage(e), "\n")
      }
    )
  }
}

cat("Styling faerdig.\n")

# EXIT =======================================================================

if (has_errors) {
  quit(save = "no", status = 1)
} else if (has_warnings) {
  quit(save = "no", status = 2)
} else {
  quit(save = "no", status = 0)
}
