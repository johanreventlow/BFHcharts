# Project Context

## Purpose

Production-ready R package for rendering Statistical Process Control (SPC) charts in healthcare quality improvement contexts. Provides ggplot2-based SPC visualizations with Anhøj rules implementation for special cause detection.

**Goals:**
- Statistical accuracy in control limit calculations
- Hospital branding integration via BFHtheme
- Composable API returning ggplot2 objects
- Visualization engine for SPCify Shiny application

## Tech Stack

**Core:**
- R (≥4.1.0)
- ggplot2 (chart rendering engine)
- BFHtheme (hospital branding and theming)

**Development:**
- devtools/usethis (package development)
- testthat (unit testing framework)
- covr (test coverage reporting)
- roxygen2 (documentation generation)

**Statistical Reference:**
- qicharts2 patterns (Anhøj rules implementation)

## Project Conventions

### Code Style

**Language:**
- Function names: English (e.g., `create_spc_chart()`, not `lav_spc_diagram()`)
- Function documentation: English (roxygen2)
- Internal comments: Danish
- Error messages: English (R package standard)

**Naming Conventions:**
- Functions: snake_case
- Internal utilities: prefix with `utils_`
- Anhøj rule functions: prefix with `anhoej_`
- Chart type implementations: prefix with `spc_`

**Formatting:**
- Follow tidyverse style guide
- Use tidyverse code patterns (dplyr, ggplot2)
- Maximum line length: 80 characters
- Use `<-` for assignment (not `=`)

### Architecture Patterns

**Composable API Design:**
```r
# Charts return ggplot2 objects that can be extended
p <- create_spc_chart(data, "date", "value", "p")
p + labs(title = "Custom Title") + scale_y_continuous(limits = c(0, 1))
```

**Chart Generation Flow:**
1. Input validation (`validate_chart_inputs()`)
2. Auto-detect chart type if not specified
3. Calculate control limits with statistical accuracy
4. Build ggplot with BFHtheme defaults
5. Add special annotations (notes, targets, freeze periods)
6. Return composable ggplot2 object

**Separation of Concerns:**
- `create_spc_chart.R` - Main API and orchestration
- `spc_*.R` - Chart type-specific implementations
- `anhoej_*.R` - Statistical rules (runs, crossings, special cause)
- `utils_*.R` - Shared utilities and helpers

### Testing Strategy

**Coverage Goals:**
- ≥90% overall coverage
- 100% on exported functions
- Statistical accuracy verification on all control limit calculations

**Test Categories:**
1. **Unit tests** - Individual chart types and utilities
2. **Integration tests** - Full data → chart workflows
3. **Statistical tests** - Control limit formulas verification
4. **Edge cases** - Missing data, outliers, small sample sizes
5. **Visual regression** - Chart appearance consistency (future)

**Test Organization:**
- `tests/testthat/test-{component}.R` pattern
- Use descriptive test names: `test_that("p-chart calculates correct UCL for edge case", {...})`
- Include tolerance checks for floating-point comparisons

**Commands:**
```r
devtools::test()              # Run test suite
covr::package_coverage()      # Coverage report
devtools::check()             # R CMD check (includes tests)
```

### Git Workflow

**Branching Strategy:**
- `main` - Production-ready code
- Feature branches: `feature/descriptive-name`
- Bugfix branches: `fix/descriptive-name`
- Never commit directly to `main`

**Commit Message Format:**
```
type(scope): subject

Body (optional)
```

**Types:** feat, fix, docs, test, refactor, perf, chore

**Examples:**
- `feat(charts): add freeze period support to p-charts`
- `fix(anhoej): correct run detection for edge case with ties`
- `docs(vignette): add examples for target line usage`

**Pre-Commit Checklist:**
- [ ] `devtools::document()` (update NAMESPACE and man pages)
- [ ] `devtools::test()` passes
- [ ] `devtools::check()` passes with no errors/warnings
- [ ] Code coverage maintained or improved
- [ ] DESCRIPTION version bumped if needed (semver)

**NEVER:**
- ❌ Merge to main without explicit approval
- ❌ Push to remote without request
- ❌ Add Claude attribution footers to commits
- ❌ Manually edit NAMESPACE (use roxygen2)

## Domain Context

### Statistical Process Control (SPC)

**Purpose:** Monitor healthcare quality metrics over time to distinguish between:
- **Common cause variation** - Natural, expected fluctuation
- **Special cause variation** - Unusual patterns requiring investigation

**Chart Types Supported:**
- **p-chart** - Proportions (e.g., infection rates, readmission rates)
- **u-chart** - Rates per unit (e.g., falls per 1000 patient days)
- **c-chart** - Counts (e.g., medication errors per month)
- **xbar-chart** - Averages of continuous data
- **i-chart** - Individual measurements
- **mr-chart** - Moving range between consecutive measurements

### Anhøj Rules

Statistical rules for detecting special cause variation:

**Run Detection (Serielængde):**
- 8+ consecutive points on same side of center line indicates special cause
- Used to identify sustained shifts in process performance

**Crossing Detection (Antal kryds):**
- Too few crossings of center line suggests non-random pattern
- Formula: Expected crossings ≈ (n-1)/2 ± 3√(n-1)/2

**Control Limits:**
- UCL/LCL calculated at ±3 sigma from center line
- Limits based on statistical formulas specific to each chart type
- Points outside limits indicate special cause

### Healthcare Context

**Use Cases:**
- Hospital-acquired infection surveillance
- Patient safety metrics monitoring
- Readmission rate tracking
- Wait time analysis
- Medication error monitoring

**Stakeholders:**
- Quality improvement teams
- Clinical leadership
- Patient safety officers
- Hospital administration

## Important Constraints

### Breaking Changes Policy

**Requirements:**
- Major version bump (semver) required
- Deprecation warnings in minor version first
- Migration guide documentation
- Notification to SPCify maintainers
- Update SPCify if integration affected

### Do NOT Modify Without Validation

**Statistical accuracy:**
- Control limit formulas (require statistical validation)
- Anhøj rule implementations (verify against literature)
- Chart type detection logic (must maintain test coverage)

**API stability:**
- Exported function signatures (breaking change)
- Return value structure (ggplot2 object contract)
- Default behavior (affects downstream usage)

**Auto-generated files:**
- NAMESPACE (use `devtools::document()`)
- man/*.Rd (use roxygen2 comments)
- DESCRIPTION (manual edits only)

### Production Use

**This package is in production use:**
- Used by SPCify Shiny application
- Hospital quality improvement teams depend on accuracy
- Statistical correctness is critical for patient safety decisions
- Visual consistency important for stakeholder communication

## External Dependencies

### BFHtheme Package

**Purpose:** Hospital branding and theming for ggplot2 charts

**Integration Points:**
- `theme_bfh()` - Default theme applied to all charts
- `add_bfh_logo()` - Optional hospital logo watermark
- `scale_x_datetime_bfh()` - Custom datetime scales
- Brand colors and typography

**Location:** `~/Documents/R/BFHtheme`

**Dependency Management:**
- BFHcharts requires BFHtheme to be installed
- Listed in DESCRIPTION Imports
- Breaking changes in BFHtheme may affect chart rendering

### SPCify Application

**Purpose:** Shiny application for interactive SPC chart creation

**Relationship:**
- BFHcharts is the visualization engine for SPCify
- SPCify handles: UI, data preprocessing, reactive programming, state management
- BFHcharts handles: Chart rendering, statistical calculations, ggplot2 generation

**Communication:**
- Feature requests from SPCify → GitHub issues with label `from-spcify`
- API changes in BFHcharts → Notify SPCify maintainer
- Testing coordination for integrated workflows

### R Package Ecosystem

**Direct Dependencies:**
- ggplot2 (≥3.4.0) - Chart rendering
- dplyr - Data manipulation
- rlang - Tidy evaluation
- BFHtheme - Hospital theming

**Development Dependencies:**
- devtools - Package development workflow
- testthat (≥3.0.0) - Unit testing
- covr - Coverage reporting
- roxygen2 - Documentation generation
- usethis - Package scaffolding

## GitHub Integration

### OpenSpec + GitHub Issues

This project uses a **complementary approach** where OpenSpec changes are tracked via both `tasks.md` files (source of truth for implementation details) and GitHub issues (high-level tracking and visibility).

**Rationale:**
- Preserves OpenSpec workflow (offline-first, structured validation)
- Gains GitHub visibility (project boards, search, notifications, cross-references)
- Enables automation via slash commands

### Label System

**OpenSpec-specific labels:**
- `openspec-proposal` - Change in proposal phase (yellow)
- `openspec-implementing` - Change being implemented (blue)
- `openspec-deployed` - Change archived/deployed (green)

**Type labels (existing):**
- `enhancement`, `bug`, `documentation`, `technical-debt`, `performance`, `testing`

### Automated Workflow

**Stage 1: Proposal** (`/openspec:proposal`)
```bash
# Automatically creates GitHub issue with:
gh issue create --title "[OpenSpec] add-feature" \
  --body "$(cat openspec/changes/add-feature/proposal.md)" \
  --label "openspec-proposal,enhancement"

# Issue reference added to proposal.md:
## Related
- GitHub Issue: #142
```

**Stage 2: Implementation** (`/openspec:apply`)
```bash
# Updates issue label and adds comment:
gh issue edit 142 --add-label "openspec-implementing" --remove-label "openspec-proposal"
gh issue comment 142 --body "Implementation started"
```

**Stage 3: Archive** (`/openspec:archive`)
```bash
# Updates label, closes issue with timestamp:
gh issue edit 142 --add-label "openspec-deployed" --remove-label "openspec-implementing"
gh issue close 142 --comment "Deployed via openspec archive on $(date +%Y-%m-%d)"
```

### Linking Pattern

**In proposal.md:**
```markdown
## Why
[Problem description]

## What Changes
- [Change list]

## Impact
- Affected specs: [capabilities]
- Affected code: [files]

## Related
- GitHub Issue: #142
```

**In tasks.md:**
```markdown
## 1. Implementation
- [ ] 1.1 Create schema (see #142)
- [ ] 1.2 Write tests (see #142)
- [ ] 1.3 Deploy (see #142)

Tracking: GitHub Issue #142
```

### Manual Operations

If automatic GitHub integration fails or needs manual intervention:

```bash
# Create issue manually
gh issue create --title "[OpenSpec] add-feature" \
  --body "$(cat openspec/changes/add-feature/proposal.md)" \
  --label "openspec-proposal,enhancement"

# Update labels manually during implementation
gh issue edit 142 --add-label "openspec-implementing" --remove-label "openspec-proposal"

# Close manually after deployment
gh issue close 142 --comment "Deployed via openspec archive on 2025-11-02"
```

### Best Practices

**Do:**
- ✅ Create GitHub issue for every OpenSpec change (automatic via `/openspec:proposal`)
- ✅ Reference issue in commit messages (`fixes #142`, `relates to #142`)
- ✅ Keep tasks.md as source of truth for implementation details
- ✅ Use GitHub issue for discussions and stakeholder visibility
- ✅ Update issue labels as workflow progresses (automatic via slash commands)

**Don't:**
- ❌ Skip GitHub issue creation
- ❌ Update tasks.md via GitHub (tasks.md is authoritative, sync is one-way)
- ❌ Close issues before archiving change (use `/openspec:archive` workflow)
- ❌ Use GitHub issues for implementation checklists (that's tasks.md's role)
