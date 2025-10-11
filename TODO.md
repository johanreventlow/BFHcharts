# BFHcharts - TODO Liste

## 🚀 Fase 1: Core Package ✅ COMPLETED
- [x] Package struktur oprettet
- [x] Configuration system ekstraheret
- [x] Chart types og constants
- [x] BFH theme og hospital branding
- [x] Utility funktioner (date, helpers, y-axis)
- [x] Plot enhancements (extended lines, comments)
- [x] Hovedfunktion `bfh_spc_plot()`
- [x] High-level wrapper `create_spc_chart()`
- [x] Basic smoke tests og integration tests
- [x] README med eksempler
- [x] GitHub repository oprettet og pushet

**Status**: Package er funktionel og kan installeres fra GitHub

---

## 📋 Fase 2: Documentation & Quality Assurance (TODO)

### 2.1 Roxygen Documentation
- [ ] Kør `devtools::document()` for at generere man/ filer
- [ ] Verificer at alle eksporterede funktioner har komplet dokumentation
- [ ] Tjek at alle `@param` og `@return` tags er korrekte
- [ ] Verificer `@examples` kører uden fejl

### 2.2 Package Validation
- [ ] Kør `devtools::check()` for R CMD CHECK
- [ ] Fix eventuelle WARNINGS eller NOTES
- [ ] Kør `goodpractice::gp()` for best practices check
- [ ] Kør `lintr::lint_package()` for code style

### 2.3 Test Coverage
- [ ] Kør `covr::package_coverage()` for at måle test coverage
- [ ] Tilføj flere unit tests for edge cases
- [ ] Target: ≥ 80% test coverage
- [ ] Tilføj snapshot tests med `vdiffr` for plot output

---

## 🌐 Fase 3: GitHub Integration (TODO)

### 3.1 GitHub Actions CI/CD
- [ ] **R CMD CHECK workflow**
  - `.github/workflows/R-CMD-check.yaml`
  - Test på multiple OS (Ubuntu, macOS, Windows)
  - Test på multiple R versions (release, devel, oldrel)
  - Automatisk kør ved push og pull requests

- [ ] **Test Coverage workflow**
  - `.github/workflows/test-coverage.yaml`
  - Kør `covr::codecov()` og upload til Codecov
  - Generer coverage badge

- [ ] **Linting workflow**
  - `.github/workflows/lint.yaml`
  - Automatisk `lintr` check på pull requests

### 3.2 GitHub Repository Settings
- [ ] Enable Issues og Discussions
- [ ] Opret Issue templates:
  - Bug report template
  - Feature request template
  - Documentation improvement template
- [ ] Opret CONTRIBUTING.md guidelines
- [ ] Opret CODE_OF_CONDUCT.md
- [ ] Setup branch protection rules for main branch

### 3.3 README Badges
- [ ] R CMD CHECK status badge
- [ ] Codecov coverage badge
- [ ] CRAN version badge (når/hvis published)
- [ ] License badge
- [ ] Lifecycle badge (experimental/stable/mature)

**Template til badges**:
```markdown
[![R-CMD-check](https://github.com/johanreventlow/BFHcharts/workflows/R-CMD-check/badge.svg)](https://github.com/johanreventlow/BFHcharts/actions)
[![Codecov test coverage](https://codecov.io/gh/johanreventlow/BFHcharts/branch/main/graph/badge.svg)](https://codecov.io/gh/johanreventlow/BFHcharts?branch=main)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
```

---

## 📚 Fase 4: pkgdown Website (TODO)

### 4.1 pkgdown Setup
- [ ] Kør `usethis::use_pkgdown()` for setup
- [ ] Opret `_pkgdown.yml` configuration fil
- [ ] Definer website structure:
  - Home page (README)
  - Reference (function documentation)
  - Articles (vignettes)
  - News (changelog)

### 4.2 Vignettes
- [ ] **Getting Started vignette**
  - Installation guide
  - Quick start examples
  - Basic workflow: data → plot
  - File: `vignettes/getting-started.Rmd`

- [ ] **Chart Types Guide**
  - Oversigt over alle chart types (run, i, p, c, u, etc.)
  - Hvornår bruges hvilken chart type
  - Eksempler for hver type
  - File: `vignettes/chart-types.Rmd`

- [ ] **Theming & Customization**
  - BFH theme customization
  - Multi-hospital branding
  - Custom color palettes
  - Font scaling og responsive design
  - File: `vignettes/theming.Rmd`

- [ ] **Advanced Usage**
  - Low-level API (bfh_spc_plot)
  - Phase splits og baseline freeze
  - Comment annotations
  - Target line suppression med arrow symbols
  - File: `vignettes/advanced-usage.Rmd`

### 4.3 pkgdown Deployment
- [ ] Setup GitHub Actions workflow for pkgdown deployment
  - `.github/workflows/pkgdown.yaml`
  - Automatisk deploy til GitHub Pages ved push til main
- [ ] Enable GitHub Pages på repository (Settings → Pages)
- [ ] Verificer website virker: `https://johanreventlow.github.io/BFHcharts/`
- [ ] Tilføj website URL til DESCRIPTION fil
- [ ] Tilføj website link i README

---

## 🔧 Fase 5: Continuous Improvement (BACKLOG)

### 5.1 Performance Optimization
- [ ] Profile plot generation med `profvis`
- [ ] Benchmark date formatting performance
- [ ] Optimize ggplot layer construction
- [ ] Consider caching strategies for repeated plots

### 5.2 Feature Enhancements
- [ ] Support for faceted plots (multiple charts in one plot)
- [ ] Interactive plots med `plotly::ggplotly()`
- [ ] Export helper functions (save_plot, export_data)
- [ ] Batch plot generation utilities
- [ ] Template system for common hospital use cases

### 5.3 Internationalization
- [ ] English translations for all Danish labels
- [ ] Locale-aware number formatting
- [ ] Configurable language parameter

### 5.4 Integration Testing
- [ ] Visual regression tests med `vdiffr`
- [ ] Integration med andre tidyverse packages
- [ ] Compatibility testing med forskellige ggplot2 versions

---

## 📦 Fase 6: CRAN Submission (OPTIONAL)

### 6.1 CRAN Preparation
- [ ] Ensure 0 ERRORS, 0 WARNINGS, 0 NOTES in R CMD CHECK
- [ ] Verify all examples run < 5 seconds
- [ ] Add `\dontrun{}` eller `\donttest{}` hvor nødvendigt
- [ ] Create cran-comments.md
- [ ] Verify all URLs are valid (CRAN checks this)
- [ ] Ensure LICENSE file er korrekt formateret

### 6.2 CRAN Submission
- [ ] Submit via `devtools::release()`
- [ ] Respond til CRAN reviewer comments
- [ ] Announce release når accepted

---

## 📝 Noter

**Prioritet:**
1. **Høj**: Fase 2 (Documentation & Validation) - Nødvendig for production readiness
2. **Medium**: Fase 3 (GitHub Actions) - Forbedrer development workflow
3. **Medium**: Fase 4 (pkgdown) - Forbedrer user experience og adoption
4. **Lav**: Fase 5 (Enhancements) - Nice-to-have features
5. **Optional**: Fase 6 (CRAN) - Kun hvis offentlig distribution ønskes

**Kontakt:**
- Maintainer: Johan Reventlow
- Repository: https://github.com/johanreventlow/BFHcharts
- Issues: https://github.com/johanreventlow/BFHcharts/issues

**Sidste opdateret:** 2025-10-11
