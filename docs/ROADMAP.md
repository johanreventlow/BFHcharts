# BFHcharts Development Roadmap

Komplet oversigt over alle planlagte forbedringer og features for BFHcharts pakken.

**Sidste opdateret:** 2025-10-12

---

## 📊 Status Overview

### ✅ Completed
- **Fase 1:** Core Package functionality
- **Tidyverse modernization:** Quick wins + data frame operations
- **Documentation:** CACHING_SYSTEM.md, QIC_PARAMETER_ANALYSIS.md, VIEWPORT_DIMENSIONS.md

### 🚧 In Progress
- Code quality improvements (tidyverse modernization)

### 📋 Planned
- Documentation completion (Fase 2)
- GitHub Actions CI/CD (Fase 3)
- pkgdown website (Fase 4)
- Feature enhancements (Fase 5)

---

## 🎯 GitHub Issues Summary

### Critical Priority 🔴

| Issue | Title | Effort | Status |
|-------|-------|--------|--------|
| [#1](https://github.com/johanreventlow/BFHcharts/issues/1) | Facetting support (multi-panel plots) | HIGH | Open |
| [#14](https://github.com/johanreventlow/BFHcharts/issues/14) | Split utils_label_placement.R into 5 modules | 4-6h | Open |

**Impact:** Blocking major use cases (facetting) and maintainability (file splitting)

---

### High Priority 🟡

| Issue | Title | Effort | Status |
|-------|-------|--------|--------|
| [#2](https://github.com/johanreventlow/BFHcharts/issues/2) | User-controllable axis labels (ylab, xlab) | LOW | Open |
| [#3](https://github.com/johanreventlow/BFHcharts/issues/3) | Exclude parameter for outlier handling | LOW | Open |
| [#15](https://github.com/johanreventlow/BFHcharts/issues/15) | **FASE 2:** Documentation & Quality Assurance | 6-9h | Open |

**Impact:** Quick UX wins and production readiness

---

### Medium Priority 🟢

| Issue | Title | Effort | Status |
|-------|-------|--------|--------|
| [#4](https://github.com/johanreventlow/BFHcharts/issues/4) | Aggregation function parameter (agg.fun) | LOW | Open |
| [#5](https://github.com/johanreventlow/BFHcharts/issues/5) | Multiply parameter for y-axis scaling | LOW | Open |
| [#6](https://github.com/johanreventlow/BFHcharts/issues/6) | Subtitle and caption parameters | LOW | Open |
| [#7](https://github.com/johanreventlow/BFHcharts/issues/7) | Show 95% limits (3-sigma) | LOW | Open |
| [#16](https://github.com/johanreventlow/BFHcharts/issues/16) | **FASE 3:** GitHub Actions CI/CD | 4-7h | Open |
| [#17](https://github.com/johanreventlow/BFHcharts/issues/17) | **FASE 4:** pkgdown Website & Vignettes | 10-15h | Open |

**Impact:** Flexibility improvements and developer experience

---

### Low Priority ⚪

| Issue | Title | Effort | Status |
|-------|-------|--------|--------|
| [#8](https://github.com/johanreventlow/BFHcharts/issues/8) | X-axis formatting parameters | LOW | Open |
| [#9](https://github.com/johanreventlow/BFHcharts/issues/9) | User control for decimals and point.size | LOW | Open |
| [#10](https://github.com/johanreventlow/BFHcharts/issues/10) | Flip parameter for horizontal charts | LOW | Open |
| [#11](https://github.com/johanreventlow/BFHcharts/issues/11) | Part.labels parameter | LOW | Open |
| [#18](https://github.com/johanreventlow/BFHcharts/issues/18) | **FASE 5:** Continuous Improvement | Variable | Open |

**Impact:** Nice-to-have features

---

### Documentation 📚

| Issue | Title | Status |
|-------|-------|--------|
| [#12](https://github.com/johanreventlow/BFHcharts/issues/12) | Test coverage documentation | Open |
| [#13](https://github.com/johanreventlow/BFHcharts/issues/13) | **ROADMAP:** Complete qic() parameter coverage | Open |

---

### Optional ❓

| Issue | Title | Effort | Status |
|-------|-------|--------|--------|
| [#19](https://github.com/johanreventlow/BFHcharts/issues/19) | **FASE 6:** CRAN Submission | 4-8h + review | Open |

**Decision needed:** Should BFHcharts be submitted to CRAN?

---

## 🗓️ Recommended Implementation Order

### Sprint 1: Quick Wins (1-2 days)
1. **#2** - Axis labels (ylab, xlab) - 30 min
2. **#3** - Exclude parameter - 30 min
3. **#4** - agg.fun parameter - 30 min
4. **#5** - Multiply parameter - 30 min
5. **#6** - Subtitle/caption - 30 min

**Total effort:** ~2.5 hours
**Impact:** Immediate UX improvements

---

### Sprint 2: Documentation (1 week)
1. **#15** - FASE 2: Documentation & QA
   - Roxygen completion
   - R CMD CHECK validation
   - Test coverage to ≥80%

**Total effort:** 6-9 hours
**Impact:** Production readiness

---

### Sprint 3: Major Refactoring (1 week)
1. **#14** - Split utils_label_placement.R
   - 4-6 hours carefully executed
   - Comprehensive testing required

**Total effort:** 4-6 hours
**Impact:** Long-term maintainability

---

### Sprint 4: Critical Feature (1-2 weeks)
1. **#1** - Facetting support
   - HIGH effort, CRITICAL impact
   - Requires design, implementation, extensive testing

**Total effort:** Significant
**Impact:** Enables multi-site comparisons

---

### Sprint 5: Infrastructure (1 week)
1. **#16** - FASE 3: GitHub Actions
   - CI/CD setup
   - Repository configuration

**Total effort:** 4-7 hours
**Impact:** Automated quality checks

---

### Sprint 6: User Documentation (2 weeks)
1. **#17** - FASE 4: pkgdown website
   - 4 comprehensive vignettes
   - Website deployment

**Total effort:** 10-15 hours
**Impact:** User onboarding and adoption

---

### Future Sprints
1. **#7-11** - Low priority parameters (as needed)
2. **#18** - FASE 5: Enhancements (backlog)
3. **#19** - FASE 6: CRAN submission (if desired)

---

## 📈 Metrics & Goals

### Code Quality
- **Current:** Tidyverse adherence 8.7/10
- **Target:** 9.5/10 after file splitting

### Test Coverage
- **Current:** Basic smoke tests
- **Target:** ≥80% coverage

### Documentation
- **Current:** Partial Roxygen docs
- **Target:** 100% exports documented + vignettes

### Performance
- **Current:** ~150ms per plot
- **Target:** <100ms per plot

---

## 🎯 Release Milestones

### v0.2.0 (Current Development)
- ✅ Core functionality
- ✅ Label placement system
- ✅ Responsive typography
- ✅ Basic tests

### v0.3.0 (Next Release)
**Focus:** Documentation & Quick Wins

- [ ] Complete Roxygen docs (#15)
- [ ] R CMD CHECK clean
- [ ] Test coverage ≥80%
- [ ] Axis labels (#2)
- [ ] Exclude parameter (#3)
- [ ] Basic parameters (#4-6)

**Target:** Production-ready for internal use

### v0.4.0
**Focus:** Major Features & Refactoring

- [ ] Facetting support (#1)
- [ ] File splitting (#14)
- [ ] GitHub Actions (#16)

**Target:** Enterprise-ready

### v0.5.0
**Focus:** Documentation & Usability

- [ ] pkgdown website (#17)
- [ ] Comprehensive vignettes
- [ ] All parameter coverage complete

**Target:** Public-ready

### v1.0.0 (Stable Release)
**Focus:** Polish & Optional CRAN

- [ ] All HIGH/MEDIUM features complete
- [ ] Extensive testing
- [ ] Performance optimized
- [ ] Optional: CRAN submission (#19)

**Target:** Mature, stable package

---

## 🤝 Contributing

Contributions are welcome! Please see individual issues for details.

**Priority areas for contributors:**
- Documentation improvements
- Test coverage
- Bug reports
- Feature requests

---

## 📞 Contact

- **Maintainer:** Johan Reventlow
- **Repository:** https://github.com/johanreventlow/BFHcharts
- **Issues:** https://github.com/johanreventlow/BFHcharts/issues

---

## 📚 Related Documentation

- [QIC Parameter Analysis](QIC_PARAMETER_ANALYSIS.md) - Complete analysis of missing qic() parameters
- [Caching System](CACHING_SYSTEM.md) - Multi-level caching documentation
- [Viewport Dimensions](VIEWPORT_DIMENSIONS.md) - Responsive sizing guide
- [Development Warnings](DEVELOPMENT_WARNINGS.md) - Common warnings explained
- [Installing Fonts](INSTALLING_FONTS.md) - Roboto font setup

---

**Note:** Dette roadmap opdateres løbende. Se GitHub issues for latest status.
