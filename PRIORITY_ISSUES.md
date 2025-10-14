# BFHcharts Priority Issues - Next Phase

**Updated:** 2025-01-14
**Context:** After implementing `notes` parameter (issue #29 resolved)

---

## 🔴 Critical Priority

### 1. Security Issues
**Must address immediately before any production use:**

- **#36** - Incomplete marquee text sanitization (CRITICAL)
  - `<` og `>` ikke escaped i marquee rendering
  - Potentiel markup injection vulnerability
  - Fix: Complete HTML entity escaping
  - Effort: 30 min

- **#37** - NSE injection risk (HIGH)
  - Column names ikke valideret før substitute()
  - Risk i Shiny apps med user-selected columns
  - Fix: Add pattern validation for column names
  - Effort: 1 hour

- **#41** - Input validation gaps (MEDIUM)
  - Mangler bounds checking (DoS risk)
  - part/freeze positions ikke valideret
  - Fix: Add range validation
  - Effort: 1 hour

**Total critical security work:** ~2.5 hours

---

## 🟡 High Priority

### 2. Test Coverage (#38)
**Current:** <20% coverage
**Target:** ≥90% coverage

**Missing test files:**
1. `test-label_placement.R` - Collision avoidance logic (CRITICAL)
2. `test-y_axis_formatting.R` - All formatters + Danish notation
3. `test-plot_enhancements.R` - Extended lines, comments, target suppression
4. `test-label_helpers.R` - Sanitization, formatting, cache
5. `test-visual_regression.R` - vdiffr snapshots
6. `test-date_formatting.R` - Expand with edge cases
7. `test-themes.R` - Theme application

**Effort:** 50-70 hours (2-3 weeks)
**Note:** Can be done incrementally alongside other work

### 3. Missing QIC Parameters (NEW ISSUE)
**Create issue documenting which qicharts2::qic() parameters are not yet exposed:**

**High-value parameters to implement:**
- `exclude` - Exclude specific data points from calculations (most useful)
- `multiply` - Multiply y-axis by factor (useful for unit conversion)
- `agg.fun` - Aggregation function: "mean", "median", "sum", "sd" (important for run/I charts)

**Lower priority parameters:**
- `method` - Runs analysis method ("anhoej", "bestbox", "cutbox")
- `facets` - Faceting formula for multiple charts
- `x.period`, `x.format`, `x.angle` - X-axis formatting (mostly handled by BFH theme)
- `y.percent`, `y.neg`, `y.expand` - Y-axis formatting (handled by BFH)

**Effort:** 2-3 hours for high-value params
**Action:** Create GitHub issue documenting all missing params

### 4. Performance (#39)
- Redundant `ggplot_build()` calls (2x per plot)
- 50-150ms overhead
- Fix: Cache built plot, pass as parameter
- Effort: 1-2 hours

---

## 🟢 Medium Priority

### 5. Code Quality

**#40** - DRY violations
- Time formatting duplicated i 3 filer
- Number formatting duplicated i 2 filer
- Fix: Extract til shared utilities
- Effort: 2-3 hours

**#43** - Complex functions
- `apply_x_axis_formatting()` er 150 linjer
- For mange ansvarsområder
- Fix: Extract til strategy pattern
- Effort: 4-6 hours

**#42** - Cache over-engineering (1,500+ linjer)
- Three separate cache systems
- Unclear benefit (cache hit rates unknown)
- Fix: Profile first, then simplify or remove
- Effort: 1-2 days

### 6. User Experience

**#27** - Multi-unit support (cm/mm/px)
- Current: inches only
- Users request: cm/mm/pixels for Danish users
- Fix: Add unit conversion with smart detection
- Effort: 3-4 hours

---

## ⚪ Low Priority

### 7. Polish & Cleanup

**#44** - i18n limitations (Danish-only formatting)
**#35** - Undefined function in demo (`create_color_palette`)
**#26** - Code quality polish (diverse mindre forbedringer)
**#46** - Hybrid comment API consideration (user-driven)

**Effort:** Incremental, as time permits

---

## Recommended Implementation Order

### Week 1: Security First
1. Fix #36 (text sanitization) - 30 min
2. Fix #37 (NSE injection) - 1 hour
3. Fix #41 (input validation) - 1 hour
4. Run security review

### Week 2-3: High-Value Features
1. Create issue for missing QIC parameters
2. Implement `exclude`, `multiply`, `agg.fun` - 2-3 hours
3. Fix performance (#39) - 1-2 hours
4. Start test coverage expansion (incremental)

### Week 4+: Code Quality
1. Remove DRY violations (#40) - 2-3 hours
2. Refactor complex functions (#43) - 4-6 hours
3. Profile and simplify cache (#42) - 1-2 days
4. Multi-unit support (#27) - 3-4 hours

### Ongoing:
- Test coverage expansion (parallel med andet arbejde)
- Low priority polish items (as needed)

---

## Success Metrics

**Security:** All critical issues resolved before v1.0
**Test Coverage:** ≥90% before CRAN submission
**QIC Parameters:** Top 3 high-value params implemented
**Performance:** <100ms overhead per plot
**User Experience:** cm/mm support for Danish users

---

## Notes

- **Test coverage** can be done incrementally alongside feature work
- **Security issues** MUST be resolved before any production use
- **QIC parameters** should be driven by user requests
- **Performance** optimization should be profile-driven
- **Code quality** improvements can wait until after feature complete

---

## Status After Notes Implementation

✅ **Completed:**
- Issue #29 - Comment functionality fixed
- `notes` parameter implemented
- Tests added for notes functionality
- Documentation updated
- Issue #46 created for hybrid approach consideration

**Ready for next phase:** Security fixes (#36, #37, #41)
