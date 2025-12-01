# Tasks: Performance Optimization for PDF Export

**Status:** pending
**Priority:** Medium
**Tracking:** GitHub Issue #67

## Phase 1: High-Impact Optimizations

- [ ] 1.1 Replace manual template copy loop with `file.copy(..., recursive = TRUE)`
  - Location: lines 341-361 in `bfh_create_typst_document()`
  - Expected: 5-10x faster template copy
- [ ] 1.2 Reduce PNG DPI from 300 to 150
  - Location: line 179 in `bfh_export_pdf()`
  - Expected: 75% smaller temp files
- [ ] 1.3 Visual QA: Verify 150 DPI quality is acceptable
- [ ] 1.4 Add benchmark test for single PDF export

## Phase 2: Caching Optimizations

- [ ] 2.1 Create `.quarto_cache` environment for session-level caching
- [ ] 2.2 Implement cached `quarto_available()` with expiry
- [ ] 2.3 Add cache invalidation option for testing
- [ ] 2.4 Add benchmark test for batch exports (10 PDFs)

## Phase 3: Minor Optimizations

- [ ] 3.1 Batch file copy operations where possible
- [ ] 3.2 Replace `c()` vector growth with pre-allocation (line 598)
- [ ] 3.3 Consider lazy loading template path at package load

## Phase 4: Validation and Release

- [ ] 4.1 Create benchmark suite in `tests/testthat/test-performance.R`
- [ ] 4.2 Profile with `profvis::profvis({ bfh_export_pdf(...) })`
- [ ] 4.3 Document performance improvements in NEWS.md
- [ ] 4.4 Run `devtools::check()`
- [ ] 4.5 Bump version

## Performance Targets

| Metric | Current | Target |
|--------|---------|--------|
| Single PDF export | ~500-800ms | ~300-400ms |
| Batch export (10) | ~6-7s | ~3-4s |
| Temp file size | ~15-25 MB | ~4-6 MB |
| Quarto check (cached) | ~50ms | ~2ms |

## Critical Files

### Modified
1. `R/export_pdf.R` - Optimization changes
2. `tests/testthat/test-performance.R` - Benchmark suite (new)
3. `NEWS.md` - Performance notes

## Effort Estimates

| Phase | Effort | Impact |
|-------|--------|--------|
| Phase 1 | 1 hour | High |
| Phase 2 | 45 min | Medium |
| Phase 3 | 30 min | Low |
| Phase 4 | 1 hour | Validation |

**Total:** ~3.5 hours
