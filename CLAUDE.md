
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

✅ **BRANCHING + PR-MODEL:**

```
feature/fix/chore branch  ──PR──▶  develop  ──PR──▶  main  ──tag──▶  release
```

- **Default PR-base = `develop`** (integration-branch). Feature/fix/chore/docs branches PR'es ALTID til `develop` medmindre brugeren eksplicit beder om andet.
- **`develop` → `main`** kun via release-PR (typisk efter version bump + NEWS-entry). Eksempel: PR #295.
- **Direkte PR mod `main`** undtagelsesvis tilladt for:
  - Hotfixes der skal i produktion straks
  - Ren-build-hygiejne PRs der ikke er feature-arbejde (ofte forhandles med bruger først)
- **Branch-fork:** feature-branches forkes fra `develop` (sikrer ren PR-diff). Hvis branch fork'ed fra `main` mens `develop` er bagefter, vil PR mod `develop` vise extra commits — flag det og tilbyd at sync `develop ← main` først.
- **Pre-commit hook** blokerer direkte commit på `main` (`.git/hooks/pre-commit` step 0).

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
│   ├── bfh_qic.R              # bfh_qic() — main public API
│   ├── spc_*.R                # Chart type implementations
│   ├── anhoej_*.R             # Anhøj rules
│   ├── utils_*.R              # Utilities
│   └── globals.R               # Global variables & constants
├── inst/examples/             # Example data/scripts
├── tests/testthat/            # Unit tests
├── vignettes/                 # Long-form docs
└── man/                       # Auto-generated docs
```

### Core Components

**Primært API (1 funktion):**
- `bfh_qic()` ⭐ - **Den eneste funktion de fleste brugere har brug for.** Returnerer et `bfh_qic_result`-objekt.

**Dokumenterede sekundære exports (eksporteret, ikke `internal`):**
Disse er rigtige public exports (se `NAMESPACE`) og bruges kun til eksport, analysetekst og introspektion af resultatet:

*PDF/PNG-eksport:*
- `bfh_export_pdf()`, `bfh_export_png()`, `bfh_create_export_session()`

*Analysetekst:*
- `bfh_generate_analysis()`, `bfh_generate_details()`, `bfh_analyse()`,
  `bfh_render_analysis()`, `bfh_build_analysis_context()`

*Introspektion/hjælpere:*
- `bfh_get_plot()`, `bfh_extract_spc_stats()`, `bfh_merge_metadata()`,
  `is_bfh_qic_result()`, `is_bfh_spc_analysis()`, `new_bfh_qic_result()`,
  `bfh_subsample_label_indices()`, `bfh_create_typst_document()`

*S3-metoder:* `print`/`plot` på `bfh_qic_result`; `as.list`/`format`/`print` på `bfh_spc_analysis`.

**Internal API (Advanced/Power Users):**
Følgende funktioner er markeret som `@keywords internal` og tilgængelige via `:::`:

*Low-level plotting:*
- `bfh_spc_plot()` - Low-level plot generation fra QIC data
- `add_spc_labels()` - Advanced label placement system
- `apply_y_axis_formatting()` - Y-axis formatting utilities
- `calculate_base_size()` - Responsive font size calculation

*Configuration objects:*
- `spc_plot_config()`, `viewport_dims()` - Config abstractions
- Kun brugt internt af `bfh_qic()`

*Constants:*
- `CHART_TYPES_EN` - Chart type identifiers (`run`, `i`, `mr`, `p`, `pp`, `u`, `up`, `c`, `g`, `xbar`, `s`, `t`)
- Brugere passer strings direkte: `chart_type = "p"`, ikke konstant-opslag

**Rationale:** **Simpelt primært API** - brugere lærer reelt kun `bfh_qic()`; de sekundære exports er kun nødvendige ved eksport/analysetekst. Resten af kompleksiteten er skjult under motorhjelmen. Advanced users kan tilgå internals med `BFHcharts:::function_name()`.

**Anhøj Rules:**
- Serielængde detection
- Antal kryds calculation
- Special cause detection
- Control limits calculation

### Chart Generation Pattern

Faktiske `bfh_qic()`-parametre (uddrag, se `R/bfh_qic.R` for fuld signatur):

```r
bfh_qic <- function(data, x, y,
                    n = NULL,
                    chart_type = "run",        # default "run", ikke NULL
                    y_axis_unit = "count",     # "count" | "percent" | "rate" | "time"
                    chart_title = NULL,
                    target_value = NULL,       # numerisk maal
                    target_text = NULL,        # m/ label-tekst
                    notes = NULL,              # annotationer (ikke "notes_column")
                    part = NULL,               # fase-split-indeks
                    freeze = NULL,             # frys baseline (ikke "freeze_period")
                    exclude = NULL, cl = NULL, ylim = NULL,
                    ...,
                    language = "da") {
  # Konceptuelt flow (illustrativt - de interne helper-navne nedenfor er
  # PSEUDO-KODE, ikke faktiske funktionsnavne):
  #   1. valider input
  #   2. byg qic-args + kald qicharts2
  #   3. tilfoej Anhoej-signaler
  #   4. render ggplot via BFHtheme + label-placement
  #   5. returner new_bfh_qic_result(plot, summary, qic_data, config)
}
```

### Anhøj Rules Implementation

Centerlinje (median/mean), serielaengde og antal kryds beregnes via
`qicharts2` + interne helpers (fx `add_anhoej_signal()` i
`R/utils_bfh_qic_helpers.R`). Nedenstaaende er **illustrativ pseudo-kode**
for konceptet - ikke eksporterede funktioner:

```r
# Serielængde: consecutive punkter paa samme side af CL (illustrativ)
detect_runs <- function(y, cl) max(rle(y > cl)$lengths)

# Antal kryds: antal gange linjen krydser CL (illustrativ)
count_crossings <- function(y, cl) sum(diff(y > cl) != 0)
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
- Update biSPCharts hvis påvirket
- Notify maintainer af biSPCharts

---

## 4) Cross-Repository Coordination

### Integration with biSPCharts

**BFHcharts er visualization engine for biSPCharts Shiny app.**

**Responsibility Boundaries:**

**BFHcharts ansvar:**
- Chart rendering
- Control limit calculations
- Anhøj rules implementation
- Statistical accuracy
- ggplot2 object generation

**biSPCharts ansvar:**
- User interface
- Data preprocessing
- Reactive programming
- State management
- Error handling for UI

### Communication Channel

**For biSPCharts feature requests:**
1. Opret issue i BFHcharts repo
2. Use label: `enhancement` og `from-spcify`
3. Reference biSPCharts use case i beskrivelsen
4. Diskutér API design før implementation

---

## 5) Project-Specific Configuration

### API Design Principles

**Consistent Interface:**

```r
bfh_qic(
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
p <- bfh_qic(data, "date", "value", "p")

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
bfh_qic <- function(..., theme = BFHtheme::theme_bfh()) {
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
- Changes requiring cross-repository coordination (e.g., with biSPCharts)

**See:** `openspec/AGENTS.md` for detailed workflow instructions

### /end-Skill R-Package Adaptation

Generisk `/end`-skill (`~/.claude/skills/end/`) antager web/app-konventioner.
For dette R-package gælder følgende override-mapping:

| Generisk skill-punkt | R-package-ækvivalent |
|----------------------|----------------------|
| `docs/changelog.md` | `NEWS.md` (CRAN-standard) |
| `docs/decisions.md` | `inst/adr/ADR-NNN-*.md` (canonical ADR-location) |
| CLAUDE.md Phase status | Ej anvendt — R-package er semver-driven |

**Konsekvens for `/end`-run:** skip ovenstående tre punkter uden yderligere
diskussion. Opdatér kun `NEWS.md` ved adfærdsændrende code-merge; ADR
oprettes per arkitektur-beslutning (ikke per session).

**Canonical ADR-location:** `inst/adr/` (ships med installed package; ADR'er
tilgængelige via `system.file("adr", ..., package = "BFHcharts")`). `docs/adr/`
deprecated efter consolidation 2026-05-26.

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
  chart <- bfh_qic(data, "x", "y", chart_type = "p")

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
* Internal comments: Engelsk (ASCII-only — se ASCII-policy nedenfor)
* Error messages: Engelsk (standard for R packages)

**Exports:**
- `bfh_qic()` ikke `lav_spc_diagram()`
- `add_control_limits()` ikke `tilfoej_kontrolgraenser()`

**Internal terminology (comments):**
- Serieplot = SPC chart
- Centrallinje = Center line
- Kontrolgraenser (transliteret) eller Control limits

### ASCII-policy for `R/*.R` (overrider global R_STANDARDS.md)

**Regel:** Alle filer under `R/*.R` SKAL kun indeholde ASCII-bytes (0x00-0x7F).
Håndhæves automatisk via `tests/testthat/test-source-ascii.R`.

**Begrundelse:** `R CMD check --as-cran` advarer om non-ASCII i R-kilder
(blokerer warning-clean releases). Global `~/.claude/rules/R_STANDARDS.md`
siger "Kommentarer: dansk" — den regel **overrides** for `R/*.R` her.

**Hvor er dansk OK?**
- ✅ `NEWS.md` (UTF-8 markdown)
- ✅ `vignettes/*.Rmd` (UTF-8 explicit)
- ✅ `inst/i18n/*.yaml` (runtime-strings)
- ✅ `README.md`
- ✅ Roxygen blocks i `R/*.R` — **kun** via translit (æ→ae, ø→oe, å→aa)
  eller engelsk (`tools::showNonASCIIfile()` flagger UTF-8 i roxygen)

**Hvor SKAL det være ASCII?**
- ❌ R-kommentarer (`# ...`) i `R/*.R` — engelsk eller transliteret
- ❌ R-strings i `R/*.R` med dansk indhold — brug `æ`/`ø`/`å`
  escapes (kompiler-fortolket; runtime-string forbliver UTF-8)
- ❌ Identifiers — engelsk altid

**Eksempler:**
```r
# ✅ Korrekt: ASCII-kommentar + Danish via \u-escape i string
warning("Kontrolgrænser er statistisk usikre")

# ❌ Forkert: dansk char direkte i source
warning("Kontrolgrænser er statistisk usikre")  # æ trigger CRAN warning
```

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
