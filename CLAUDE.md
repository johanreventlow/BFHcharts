# Claude Instruktioner – BFHcharts

## 1) Projektoversigt

**BFHcharts** er en R package til **Statistical Process Control (SPC) visualisering** i healthcare settings. Built on ggplot2 og qicharts2 med fokus på beautiful defaults, publication-ready output og multi-organizational branding support.

**Udviklingsstatus:** Standard R package development med test-driven development, defensive programming og stabil API design.

---

## 2) Udviklingsprincipper

### 2.1 Test-First Development (TDD)

✅ **OBLIGATORISK:** Al udvikling følger TDD:

1. Skriv tests først
2. Kør tests kontinuerligt – skal altid bestå
3. Refactor med test-sikkerhed
4. Ingen breaking changes uden eksplicit godkendelse

**Test-kommandoer:**
```r
# Alle tests
devtools::test()

# Specifik test-fil
testthat::test_file("tests/testthat/test-*.R")

# Check package
devtools::check()

# Code coverage
covr::package_coverage()
```

### 2.2 Defensive Programming

* **Input validation** ved exported functions
* **Error handling** via `tryCatch()` med informative messages
* **Type checking** med `stopifnot()`, `is.*()` checks
* **Graceful degradation** med fallback defaults
* **NULL safety** – eksplicit NULL-håndtering

```r
# Eksempel: Input validation pattern
create_spc_chart <- function(data, x, y, chart_type = "run", ...) {
  # Input validation
  stopifnot(
    "data must be a data.frame" = is.data.frame(data),
    "chart_type must be character" = is.character(chart_type)
  )

  if (nrow(data) == 0) {
    stop("data cannot be empty", call. = FALSE)
  }

  # ... implementation
}
```

### 2.3 Git Workflow (OBLIGATORISK)

✅ **KRITISKE REGLER:**

1. **ALDRIG merge til main uden eksplicit godkendelse**
2. **ALDRIG push til remote uden anmodning**
3. **STOP efter feature branch commit – vent på instruktioner**
4. **Do NOT add Claude co-authorship footer to commits**

**Workflow:**
```bash
git checkout -b fix/feature-name
# ... arbejd og commit ...
git commit -m "beskrivelse"
# STOP - vent på instruktion
```

**VIGTIGT:** Commit messages skal IKKE indeholde:
- ❌ "🤖 Generated with [Claude Code]"
- ❌ "Co-Authored-By: Claude <noreply@anthropic.com>"
- ❌ Andre Claude attribution footers

Undtagelse: Simple operationer (`git status`, `git diff`, `git log`)

### 2.4 Code Quality Standards

* **Danske kommentarer**, engelske funktionsnavne
* **snake_case** for all funktioner og objekter
* **Roxygen2 documentation** for all exported functions
* **Type safety**: eksplicit type checks før operationer
* **`lintr`** via `devtools::lint()` før commits
* **`styler`** for consistent formatting

### 2.5 Architecture Principles

* **Single Responsibility** – én opgave pr. funktion
* **Immutable patterns** – returnér nye ggplot objects, modificér ikke in-place
* **Composition over complexity** – byg komplekse plots fra simple layers
* **Configuration objects** – brug structured configs (spc_plot_config, viewport_dims)
* **Minimal dependencies** – kun tilføj dependencies hvis strengt nødvendigt

---

## 3) Package Development Best Practices

### 3.1 R Package Structure

**File organization i `/R/`:**
* `plot_core.R` – Core plotting functions (bfh_spc_plot, create_spc_chart)
* `plot_enhancements.R` – Plot enhancement layers (target lines, labels, etc.)
* `themes.R` – ggplot2 theme functions (bfh_theme)
* `chart_types.R` – Chart type definitions og mappings
* `config_objects.R` – Configuration constructors (spc_plot_config, viewport_dims)
* `utils_*.R` – Utility functions (date formatting, y-axis formatting, helpers)
* `*-package.R` – Package documentation

### 3.2 Function Design Patterns

**Exported functions:**
```r
#' Create SPC Chart
#'
#' High-level convenience function for creating complete SPC charts
#'
#' @param data Data frame with time series data
#' @param x Column name for x-axis (date/time)
#' @param y Column name for y-axis (measurement)
#' @param chart_type Character. One of: "run", "i", "p", "u", "c", "xbar"
#' @param ... Additional arguments passed to qicharts2::qic()
#'
#' @return A ggplot2 object
#' @export
#'
#' @examples
#' \dontrun{
#' create_spc_chart(data = my_data, x = date, y = count, chart_type = "run")
#' }
create_spc_chart <- function(data, x, y, chart_type = "run", ...) {
  # Implementation
}
```

**Internal utilities (ikke exported):**
```r
# Danske kommentarer for interne funktioner
# Beregn centerline position for label placement
calculate_centerline_position <- function(qic_data) {
  # Implementation
}
```

### 3.3 ggplot2 Best Practices

**Layer composition:**
```r
# ✅ Korrekt: Build plot incrementally
base_plot <- ggplot(data, aes(x = x, y = y)) +
  geom_line()

enhanced_plot <- base_plot +
  add_target_line(target_value) +
  bfh_theme()

# ❌ Forkert: Massive nested calls
ggplot(...) + geom_line(...) + geom_hline(...) + theme(...) + labs(...) + ...
```

**Theme design:**
```r
# Themes skal returnere theme() objects
bfh_theme <- function(base_size = 14, colors = NULL) {
  # Defaults hvis colors ikke angivet
  colors <- colors %||% default_bfh_colors()

  theme_minimal(base_size = base_size) +
    theme(
      plot.title = element_text(size = rel(1.2), face = "bold"),
      # ... more theme elements
    )
}
```

### 3.4 Configuration Objects

**Structured configs via constructors:**
```r
#' Create SPC Plot Configuration
#'
#' @param chart_type Character. Chart type identifier
#' @param y_axis_unit Character. Unit for y-axis ("count", "percent", "rate")
#' @param chart_title Character. Plot title
#' @param target_value Numeric. Optional target line value
#' @param target_text Character. Label for target line
#'
#' @return A list with class "spc_plot_config"
#' @export
spc_plot_config <- function(
  chart_type = "run",
  y_axis_unit = "count",
  chart_title = NULL,
  target_value = NULL,
  target_text = NULL
) {
  structure(
    list(
      chart_type = chart_type,
      y_axis_unit = y_axis_unit,
      chart_title = chart_title,
      target_value = target_value,
      target_text = target_text
    ),
    class = "spc_plot_config"
  )
}
```

### 3.5 Dependencies & NAMESPACE

**ALDRIG ændre NAMESPACE manuelt:**
```r
# ✅ Korrekt: Lad roxygen2 håndtere NAMESPACE
#' @export
#' @importFrom ggplot2 ggplot aes geom_line
my_function <- function() { ... }

# Kør derefter:
devtools::document()
```

**Dependency management:**
* Brug `@importFrom pkg function` for specifikke funktioner
* Brug `pkg::function()` i kode når det giver mening
* Undgå `@import pkg` (importerer alt)
* Tilføj nye dependencies i DESCRIPTION under `Imports:` eller `Suggests:`

---

## 4) Testing Strategy

### 4.1 Test Organization

**Test files i `/tests/testthat/`:**
* `test-plot_core.R` – Tests for core plotting functions
* `test-plot_enhancements.R` – Tests for plot enhancements
* `test-themes.R` – Tests for theme functions
* `test-config_objects.R` – Tests for config constructors
* `test-utils_*.R` – Tests for utility functions

### 4.2 Test Patterns

**Unit tests:**
```r
test_that("create_spc_chart validates input data", {
  # Arrange
  invalid_data <- list(not = "a dataframe")

  # Act & Assert
  expect_error(
    create_spc_chart(data = invalid_data, x = date, y = count),
    "data must be a data.frame"
  )
})

test_that("create_spc_chart returns ggplot object", {
  # Arrange
  data <- data.frame(date = 1:10, count = rnorm(10))

  # Act
  result <- create_spc_chart(data = data, x = date, y = count)

  # Assert
  expect_s3_class(result, "ggplot")
})
```

**Visual regression tests (vdiffr):**
```r
test_that("bfh_theme produces consistent visual output", {
  # Arrange
  data <- data.frame(x = 1:10, y = rnorm(10))
  plot <- ggplot(data, aes(x, y)) + geom_line() + bfh_theme()

  # Act & Assert
  vdiffr::expect_doppelganger("bfh_theme_basic", plot)
})
```

### 4.3 Coverage Goals

* **≥90% samlet coverage**
* **100% på exported functions**
* **Edge cases**: NULL inputs, empty data, invalid types
* **Integration tests**: Full workflow fra data → plot

---

## 5) Documentation Standards

### 5.1 Roxygen2 Documentation

**Required fields for exported functions:**
```r
#' Function Title (One Line)
#'
#' Longer description explaining what the function does, when to use it,
#' and any important details.
#'
#' @param param_name Description of parameter
#' @param another_param Description with details about expected values
#'
#' @return Description of what is returned
#'
#' @export
#'
#' @examples
#' # Commented example
#' result <- my_function(x = 1:10)
#'
#' \dontrun{
#' # Example that requires external data
#' my_function(data = my_data)
#' }
```

### 5.2 Vignettes

**Vignettes i `/vignettes/`:**
* `getting-started.Rmd` – Basic usage patterns
* `customization.Rmd` – Advanced customization options
* `theming.Rmd` – Multi-hospital branding guide

**Vignette struktur:**
```rmd
---
title: "Getting Started with BFHcharts"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Getting Started with BFHcharts}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

# Introduction

Brief introduction...

# Basic Usage

Example code...
```

### 5.3 README Updates

**Når funktionalitet ændres:**
1. Opdater eksempler i README.md
2. Verificer at eksempler kører uden fejl
3. Opdater screenshots hvis relevant (future: når vi har them)

---

## 6) Workflow & Process

### 6.1 Development Lifecycle

1. **Problem definition** – Én-linje beskrivelse
2. **Test design** – Skriv failing tests
3. **Implementation** – Minimal implementation som får tests til at bestå
4. **Documentation** – Roxygen + eksempler
5. **Integration test** – Verificer i context
6. **Check package** – `devtools::check()`
7. **Commit** – Vent på godkendelse før merge

### 6.2 Pre-Commit Checklist

- [ ] Tests kørt og bestået (`devtools::test()`)
- [ ] Package check uden errors/warnings (`devtools::check()`)
- [ ] Roxygen documentation opdateret
- [ ] NAMESPACE regenereret (`devtools::document()`)
- [ ] Eksempler verificeret
- [ ] Code formateret (`styler::style_pkg()`)
- [ ] Linted (`lintr::lint_package()`)
- [ ] Manual test af ny funktionalitet

### 6.3 Commit Message Format

```
type(scope): kort handle-orienteret beskrivelse

Fritekst med kontekst og rationale.

- Bullet points for flere ændringer
- Breaking changes markeres eksplicit
```

**Typer:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`

**Branch naming:** `fix/`, `feat/`, `refactor/`, `docs/`, `test/`

---

## 7) Common Patterns & Anti-Patterns

### 7.1 ggplot2 Patterns

**✅ Korrekt:**
```r
# Return ggplot objects for composition
create_base_plot <- function(data) {
  ggplot(data, aes(x = x, y = y)) +
    geom_line()
}

# Users can add their own layers
plot <- create_base_plot(data) +
  geom_point() +
  labs(title = "Custom Title")
```

**❌ Forkert:**
```r
# Don't print inside functions
create_plot <- function(data) {
  plot <- ggplot(data, aes(x = x, y = y)) + geom_line()
  print(plot)  # DON'T DO THIS
}

# Don't modify global state
create_plot <- function(data) {
  theme_set(theme_minimal())  # DON'T DO THIS
  # ...
}
```

### 7.2 Configuration Patterns

**✅ Korrekt:**
```r
# Use structured config objects
plot_cfg <- spc_plot_config(
  chart_type = "p",
  y_axis_unit = "percent"
)

plot <- bfh_spc_plot(qic_data, plot_cfg)
```

**❌ Forkert:**
```r
# Don't use unstructured lists
plot_cfg <- list(type = "p", unit = "percent")  # No validation!
```

### 7.3 NULL Handling

**✅ Korrekt:**
```r
# Use %||% operator for defaults
colors <- user_colors %||% default_colors()

# Explicit NULL checks
if (is.null(target_value)) {
  # Skip target line
} else {
  # Add target line
}
```

**❌ Forkert:**
```r
# Implicit NULL behavior kan føre til uventede errors
plot + geom_hline(yintercept = target_value)  # Fails hvis NULL
```

---

## 8) Troubleshooting

### 8.1 Common Issues

**ggplot2 layer errors:**
```r
# Problem: "cannot add ggproto objects together"
# Solution: Ensure alle layers returnerer valid ggplot2 components

# ✅ Korrekt
add_layer <- function(p) {
  if (condition) {
    p + geom_point()
  } else {
    p  # Return unchanged
  }
}

# ❌ Forkert
add_layer <- function(p) {
  if (condition) {
    p + geom_point()
  }
  # Returns NULL hvis condition FALSE!
}
```

**Namespace conflicts:**
```r
# Problem: Function not found efter @export
# Solution: Kør devtools::document() og check NAMESPACE

# Problem: Konflikt med anden package
# Solution: Brug explicit namespace
stats::filter(data)  # Instead of filter(data)
```

**Test failures:**
```r
# Problem: vdiffr snapshots fail på CI
# Solution: Brug svg device for consistent rendering
vdiffr::expect_doppelganger("name", plot, writer = "svg")

# Problem: Tests fail lokalt men ikke på CI
# Solution: Check system-specific assumptions (fonts, locales, etc.)
```

---

## 9) Kommunikation & Filosofi

### 9.1 Udviklerkommunikation

* **Præcise action items**: "Tilføj parameter X til funktion Y i fil Z"
* **Faktuel rapportering** af resultater
* **Kritisk evaluering** – stil spørgsmål ved trade-offs
* **Intellektuel ærlighed** – vær direkte om begrænsninger

### 9.2 Development Philosophy

**Kerneprincipper:**
* **Quality over speed** – healthcare software kræver stabilitet
* **Test-driven confidence** – tests før implementation
* **User-focused design** – beautiful defaults, flexible customization
* **Minimal surprise** – følg R/ggplot2 conventions
* **Continuous improvement** – dokumentér beslutninger

**Goals:**
* Publication-ready output med minimalt setup
* Stabil API med backward compatibility
* Comprehensive documentation og eksempler
* Multi-organizational flexibility
* Best practice compliance

### 9.3 Samtale Guidelines

* **Kritisk engagement** – evaluér forslag objektivt
* **Balanceret evaluering** – undgå tomme komplimenter
* **Retningsklarhed** – fokusér på long-term maintainability
* **Succeskriterium**: Fremmer dette produktiv tænkning eller standser det?

---

## 📎 Appendix A: Package Constraints

**Hard constraints:**
* Ingen commits til main uden godkendelse
* Ingen nye dependencies uden godkendelse
* ALDRIG modificer NAMESPACE direkte
* Ingen breaking changes til exported API uden diskussion
* Tests skal altid bestå før commit

**Soft guidelines:**
* Prefer simple solutions over clever ones
* Prefer composition over complexity
* Document "why", not just "what"
* Keep functions focused and testable

---

## 📎 Appendix B: Key Files Reference

| Fil | Ansvar | Vigtige funktioner |
|-----|--------|-------------------|
| **plot_core.R** | Core plotting logic | `create_spc_chart()`, `bfh_spc_plot()` |
| **plot_enhancements.R** | Plot enhancements | Target lines, labels, annotations |
| **themes.R** | ggplot2 themes | `bfh_theme()`, color palettes |
| **chart_types.R** | Chart type definitions | Chart type mappings, validering |
| **config_objects.R** | Config constructors | `spc_plot_config()`, `viewport_dims()`, `phase_config()` |
| **utils_y_axis_formatting.R** | Y-axis formatting | Format functions for different units |
| **utils_date_formatting.R** | Date/time formatting | Date axis helpers |
| **utils_helpers.R** | General utilities | Generic helper functions |

---

## 📎 Appendix C: Quick Reference Commands

```bash
# Development workflow
devtools::load_all()           # Load package for testing
devtools::test()               # Run tests
devtools::check()              # Full package check
devtools::document()           # Update documentation + NAMESPACE

# Code quality
styler::style_pkg()            # Format code
lintr::lint_package()          # Lint code

# Testing
testthat::test_file("tests/testthat/test-*.R")
covr::package_coverage()

# Documentation
devtools::build_vignettes()
pkgdown::build_site()          # (future: når vi setup pkgdown)

# Installation
devtools::install()            # Install lokalt
devtools::install_github("johanreventlow/BFHcharts")
```
