# package-config Specification

## Purpose
TBD - created by archiving change remove-vignette-builder. Update Purpose after archive.
## Requirements
### Requirement: DESCRIPTION SHALL only declare features that exist

The DESCRIPTION file SHALL only declare VignetteBuilder if vignettes exist in the package.

**Rationale:**
- Prevents misleading R CMD CHECK warnings
- Keeps package configuration honest
- Follows R package best practices

#### Scenario: Package without vignettes

**Given** a package with no files in `vignettes/` directory
**When** R CMD CHECK is executed
**Then** DESCRIPTION SHALL NOT contain `VignetteBuilder:` field
**And** R CMD CHECK SHALL NOT produce vignette-related warnings

**Implementation:**
```
# DESCRIPTION - Remove this line:
# VignetteBuilder: knitr

# Keep Suggests only if packages are used elsewhere:
Suggests:
    testthat (>= 3.0.0),
    # knitr - REMOVE if only used for vignettes
    # rmarkdown - REMOVE if only used for vignettes
    vdiffr,
    covr,
    pdftools (>= 3.3.0),
    withr
```

**Validation:**
- `VignetteBuilder:` line does not exist in DESCRIPTION
- `devtools::check()` produces no vignette warnings
- Package installs without vignette-related issues

#### Scenario: Adding vignettes in future

**Given** a future decision to add vignettes
**When** vignettes are implemented
**Then** DESCRIPTION SHALL add `VignetteBuilder: knitr`
**And** `vignettes/` directory SHALL contain `.Rmd` files
**And** R CMD CHECK SHALL build vignettes successfully

**Implementation:**
```
# DESCRIPTION - Add when vignettes exist:
VignetteBuilder: knitr

Suggests:
    knitr,
    rmarkdown,
    ...
```

**Validation:**
- VignetteBuilder matches actual vignette presence
- All vignettes build without errors

