# Rename create_spc_chart() to bfh_qic()

## Why

**Current naming is verbose and doesn't follow ecosystem conventions.**

The main exported function `create_spc_chart()` is:
- **Too verbose** (17 characters) for a primary API function
- **Verb-heavy** ("create") when most tidyverse/ggplot2 functions are concise
- **Not immediately recognizable** to users familiar with qicharts2

**Better alignment with design philosophy:**

The package is fundamentally a **BFH-themed wrapper around qicharts2::qic()** that:
- Adds hospital branding via BFHtheme integration
- Provides intelligent label placement
- Simplifies the API with smart defaults
- Returns composable ggplot2 objects

**Proposed name: `bfh_qic()`**

Benefits:
- ✅ **Branded prefix** (`bfh_`) signals this is BFH's version
- ✅ **Recognizable** to users familiar with qicharts2
- ✅ **Concise** (7 characters vs 17)
- ✅ **Consistent** with package identity (BFHcharts)
- ✅ **Efficient** for interactive use and code writing

**Alternative considered:** `spc_chart()` - more self-explanatory but loses the qicharts2 connection and BFH branding.

## What Changes

### Code Changes

1. **Rename function in R/create_spc_chart.R**
   - `create_spc_chart()` → `bfh_qic()`
   - Update roxygen2 documentation @name, @title, @description
   - Maintain all existing parameters and behavior

2. **Update NAMESPACE (via devtools::document())**
   - Export will change from `export(create_spc_chart)` to `export(bfh_qic)`

3. **Update all internal references**
   - Update @seealso references in other functions
   - Update package documentation (BFHcharts-package.R)

4. **Update examples and tests**
   - All test files referencing `create_spc_chart()`
   - All example code in roxygen2 comments
   - Demo scripts (demo_*.R)

5. **Update documentation files**
   - CLAUDE.md project instructions
   - openspec/project.md conventions
   - README.md (if exists)

### Breaking Changes

**This is a breaking change:**
- Existing code using `create_spc_chart()` will fail
- Requires minor version bump: 0.1.x → 0.2.0 (breaking changes acceptable in 0.x.x series)
- **Deprecation strategy:** NOT APPLICABLE
  - Package is pre-1.0, early-stage development
  - User (maintainer) will handle SPCify migration directly
  - Clean break preferred over deprecation overhead

## Impact

**Affected specs:**
- `public-api` - Main exported function signature

**Affected code:**
- `R/create_spc_chart.R` - Main function definition (rename)
- `R/BFHcharts-package.R` - Package documentation
- `R/*.R` - All @seealso cross-references
- `tests/testthat/test-*.R` - All test files
- `demo_*.R` - Demo scripts
- NAMESPACE - Auto-generated export (via roxygen2)

**Affected external projects:**
- **SPCify** - Shiny application that uses this package
  - User (maintainer) will handle migration
  - No coordination needed beyond this proposal

**Migration path:**
- Simple find-and-replace: `create_spc_chart` → `bfh_qic`
- Function signature unchanged - drop-in replacement
- All parameters, defaults, and behavior identical

## Validation

**Testing strategy:**
- Run full test suite: `devtools::test()`
- Run package check: `devtools::check()`
- Verify all examples run: Check man/*.Rd examples
- Test in SPCify locally (user responsibility)

**Documentation verification:**
- [ ] All roxygen2 docs updated
- [ ] NAMESPACE regenerated correctly
- [ ] No broken @seealso cross-references
- [ ] Examples in ?bfh_qic work

## Timeline

**Implementation:** Single PR, all changes together
**Deployment:** Immediate (no deprecation period)
**Version bump:** Minor (0.1.x → 0.2.0)

## Related

- GitHub Issue: #58
