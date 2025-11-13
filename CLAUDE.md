<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Claude Instructions – BFHcharts

@~/.claude/rules/CLAUDE_BOOTSTRAP_WORKFLOW.md

---

## ⚠️ OBLIGATORISKE REGLER (KRITISK)

❌ **ALDRIG:**
1. Merge til master/main uden eksplicit godkendelse
2. Push til remote uden anmodning
3. Tilføj Claude attribution footers:
   - ❌ "🤖 Generated with [Claude Code]"
   - ❌ "Co-Authored-By: Claude <noreply@anthropic.com>"
   
---

## 1) Project Overview

- **Project Type:** R Package
- **Purpose:** SPC chart rendering package for healthcare quality improvement. Production-ready ggplot2-based SPC visualization med Anhøj rules implementation.
- **Status:** Production

**Technology Stack:**
- ggplot2 (chart rendering)
- BFHtheme (hospital branding)
- qicharts2 patterns reference (Anhøj rules)

---

## 2) Project-Specific Architecture

### Package Structure

```
BFHcharts/
├── R/
│   ├── create_spc_chart.R     # Main chart function
│   ├── spc_*.R                # Chart type implementations
│   ├── anhoej_*.R             # Anhøj rules
│   ├── utils_*.R              # Utilities
│   └── zzz.R                  # Package startup
├── inst/examples/             # Example data/scripts
├── tests/testthat/            # Unit tests
├── vignettes/                 # Long-form docs
└── man/                       # Auto-generated docs
```

### Core Components

**Public API (1 funktion):**
- `create_spc_chart()` ⭐ - **DEN ENESTE funktion brugere skal kende**

**Internal API (Advanced/Power Users):**
Følgende funktioner er markeret som `@keywords internal` og tilgængelige via `:::`:

*Low-level plotting:*
- `bfh_spc_plot()` - Low-level plot generation fra QIC data
- `add_spc_labels()` - Advanced label placement system
- `apply_y_axis_formatting()` - Y-axis formatting utilities
- `calculate_base_size()` - Responsive font size calculation
- `create_plot_footer()` - Footer generation

*Configuration objects:*
- `spc_plot_config()`, `viewport_dims()`, `phase_config()` - Config abstractions
- Kun brugt internt af `create_spc_chart()`

*Constants:*
- `CHART_TYPES_DA`, `CHART_TYPES_EN` - Chart type mappings
- `Y_AXIS_UNITS_DA` - Y-axis unit labels
- Brugere passer strings direkte: `chart_type = "p"`, ikke konstant-opslag

**Rationale:** **Ultra-simpelt API** - brugere lærer kun 1 funktion. Alt kompleksitet er skjult under motorhjelmen. Advanced users kan tilgå internals med `BFHcharts:::function_name()`.

**Anhøj Rules:**
- Serielængde detection
- Antal kryds calculation
- Special cause detection
- Control limits calculation

### Chart Generation Pattern

```r
create_spc_chart <- function(data, x, y, chart_type = NULL,
                             notes_column = NULL, target = NULL,
                             freeze_period = NULL, ...) {
  # 1. Input validation
  validate_chart_inputs(data, x, y)

  # 2. Auto-detect chart type hvis ikke angivet
  chart_type <- chart_type %||% auto_detect_chart_type(data[[y]])

  # 3. Calculate control limits
  limits <- calculate_control_limits(data, y, chart_type)

  # 4. Build ggplot
  p <- ggplot(data, aes(x = .data[[x]], y = .data[[y]])) +
    geom_line() + geom_point() +
    add_control_limits(limits) +
    BFHtheme::theme_bfh()

  # 5. Add special annotations
  if (!is.null(notes_column)) {
    p <- add_notes(p, data, notes_column)
  }

  return(p)
}
```

### Anhøj Rules Implementation

```r
# Serielængde: Consecutive points på samme side af CL
detect_runs <- function(y, cl) {
  above <- y > cl
  runs <- rle(above)
  max(runs$lengths)
}

# Antal kryds: Antal gange linjen krydser CL
count_crossings <- function(y, cl) {
  above <- y > cl
  sum(diff(above) != 0)
}
```

---

## 3) Critical Project Constraints

### Do NOT Modify

- Exported function signatures (breaking changes)
- Control limit formulas uden statistisk validering
- NAMESPACE (auto-generated via `devtools::document()`)
- Chart type detection logic uden tests

### Breaking Changes Policy

Kræver:
- Major version bump (semver)
- Deprecation warnings i minor version først
- Migration guide
- Update SPCify hvis påvirket
- Notify maintainer af SPCify

---

## 4) Cross-Repository Coordination

### Integration with SPCify

**BFHcharts er visualization engine for SPCify Shiny app.**

**Responsibility Boundaries:**

**BFHcharts ansvar:**
- Chart rendering
- Control limit calculations
- Anhøj rules implementation
- Statistical accuracy
- ggplot2 object generation

**SPCify ansvar:**
- User interface
- Data preprocessing
- Reactive programming
- State management
- Error handling for UI

### Communication Channel

**For SPCify feature requests:**
1. Opret issue i BFHcharts repo
2. Use label: `enhancement` og `from-spcify`
3. Reference SPCify use case i beskrivelsen
4. Diskutér API design før implementation

---

## 5) Project-Specific Configuration

### API Design Principles

**Consistent Interface:**

```r
create_spc_chart(
  data,              # Data frame
  x,                 # X-axis variable name
  y,                 # Y-axis variable name
  chart_type,        # Optional chart type
  notes_column,      # Optional notes for annotations
  target,            # Optional target line
  freeze_period,     # Optional period for baseline
  ...                # Additional ggplot2 layers
)
```

**Composability:**

```r
# Charts returnerer ggplot objects som kan modificeres
p <- create_spc_chart(data, "date", "value", "p")

# Add custom layers
p <- p +
  labs(title = "Custom Title") +
  scale_y_continuous(limits = c(0, 1))
```

**Graceful Defaults:**
- Auto-detect chart type
- Auto-calculate limits
- Use BFHtheme by default

### Integration with BFHtheme

```r
# Charts skal bruge BFHtheme som default
create_spc_chart <- function(..., theme = BFHtheme::theme_bfh()) {
  p <- base_plot + theme

  # Tilføj hospital branding hvis ønsket
  if (add_bfh_logo) {
    p <- BFHtheme::add_bfh_logo(p)
  }

  return(p)
}
```

### Development Commands

```r
devtools::load_all()       # Load package
devtools::document()       # Generate docs
devtools::test()           # Run tests
devtools::check()          # Check package
covr::package_coverage()   # Coverage
devtools::build_vignettes() # Build vignettes
```

### Git Workflow: Files to NEVER Commit

**Auto-generated outputs:**
- ❌ `Rplots.pdf` - R default plot output device
- ❌ `tests/testthat/Rplots.pdf` - Test plot outputs
- ❌ `*.png` / `*.jpg` in root or test directories (unless documented examples in `inst/`)
- ❌ `.Rhistory` - R command history
- ❌ `.RData` / `.rda` files (unless example data in `data/`)

**Development artifacts:**
- ❌ `.xcf`, `.psd` - Image editing work files
- ❌ Cache directories (`.cache/`, `*_cache/`)
- ❌ Personal IDE configs (unless already in `.gitignore`)
- ❌ `demo_*.R` with debug changes (commented-out code)

**When in doubt:** Check `.gitignore` or ask user before committing outputs/artifacts.

### OpenSpec Integration

**Available commands for structured change management:**

- `/openspec:proposal` - Scaffold a new OpenSpec change proposal
- `/openspec:apply` - Implement an approved OpenSpec change
- `/openspec:archive` - Archive a deployed OpenSpec change

**When to use:**
- Major feature additions that need design review
- Breaking changes to public API
- Architectural decisions that need documentation
- Changes requiring cross-repository coordination (e.g., with SPCify)

**See:** `openspec/AGENTS.md` for detailed workflow instructions

---

## 6) Domain-Specific Guidance

### Statistical Accuracy

**Control Limit Formulas:**

**p-chart (proportions):**
```r
p_bar <- mean(p)
UCL <- p_bar + 3 * sqrt(p_bar * (1 - p_bar) / n)
LCL <- max(0, p_bar - 3 * sqrt(p_bar * (1 - p_bar) / n))
```

**u-chart (rates):**
```r
u_bar <- mean(u)
UCL <- u_bar + 3 * sqrt(u_bar / n)
LCL <- max(0, u_bar - 3 * sqrt(u_bar / n))
```

**Reference:** qicharts2 implementations og SPC literature

### Testing Strategy

* **Unit tests** - Individual chart types
* **Integration tests** - Full workflow data → chart
* **Statistical tests** - Control limit calculations
* **Edge cases** - Missing data, outliers, small n
* **Visual regression** - Chart appearance consistency

**Coverage Goals:**
* **≥90% samlet coverage**
* **100% på exported functions**
* **Statistical accuracy** - Verify control limits

**Key Test Areas:**

```r
test_that("p-chart calculates correct control limits", {
  data <- data.frame(x = 1:10, y = c(0.1, 0.15, 0.12, ...))
  chart <- create_spc_chart(data, "x", "y", chart_type = "p")

  # Verify UCL/LCL calculations
  expect_equal(chart$ucl, expected_ucl, tolerance = 0.001)
  expect_equal(chart$lcl, expected_lcl, tolerance = 0.001)
})

test_that("Anhøj rules detect runs correctly", {
  # Construct data med known run
  data <- data.frame(y = c(rep(110, 8), rep(90, 8)))
  runs <- detect_runs(data$y, cl = 100)

  expect_equal(runs, 8)
})
```

### Danish Language

* Function names: Engelsk
* Function documentation: Engelsk
* Internal comments: Dansk
* Error messages: Engelsk (standard for R packages)

**Exports:**
- `create_spc_chart()` ikke `lav_spc_diagram()`
- `add_control_limits()` ikke `tilfoej_kontrolgraenser()`

**Internal terminology (comments):**
- Serieplot = SPC chart
- Centrallinje = Center line
- Kontrolgrænser = Control limits

---

## 📚 Global Standards Reference

**Dette projekt følger:**
- **R Development:** `~/.claude/rules/R_STANDARDS.md`
- **Architecture Patterns:** `~/.claude/rules/ARCHITECTURE_PATTERNS.md`
- **Git Workflow:** `~/.claude/rules/GIT_WORKFLOW.md`
- **Development Philosophy:** `~/.claude/rules/DEVELOPMENT_PHILOSOPHY.md`
- **Troubleshooting:** `~/.claude/rules/TROUBLESHOOTING_GUIDE.md`

**Globale agents:** tidyverse-code-reviewer, performance-optimizer, security-reviewer, test-coverage-analyzer, refactoring-advisor, legacy-code-detector

**Globale commands:** /boost, /code-review-recent, /double-check, /debugger

---

**Original documentation:** Se `CLAUDE.md.backup` for fuld dokumentation.
