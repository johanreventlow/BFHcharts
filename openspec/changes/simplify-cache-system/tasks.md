# Implementation Tasks: simplify-cache-system

Tracking: GitHub Issue #42

## Phase A: Profiling (Investigation)

- [ ] A.1 Add cache profiling instrumentation
  - Add hit/miss counters to `.grob_height_cache`
  - Add hit/miss counters to `.panel_height_cache`
  - Add hit/miss counters to `.marquee_style_cache`
  - **File:** `R/utils_label_placement.R`, `R/utils_label_helpers.R`
  - **Validation:** Counters increment during cache operations

- [ ] A.2 Run profiling during test suite
  - Execute: `devtools::test()` with instrumented code
  - Capture hit/miss stats for each cache
  - **Validation:** Stats captured and logged

- [ ] A.3 Document profiling results
  - Calculate hit rate for each cache
  - Document in this file under "Profiling Results"
  - **Decision point:** <50% = Phase B, >50% = Phase C

## Phase B: Remove Caching (if hit rate <50%)

- [ ] B.1 Remove grob height cache
  - Delete `.grob_height_cache` environment
  - Remove TTL logic, stats tracking, purge logic
  - Replace cached calls with direct computation
  - **File:** `R/utils_label_placement.R`
  - **Validation:** No `.grob_height_cache` references remain

- [ ] B.2 Remove panel height cache
  - Delete `.panel_height_cache` environment
  - Remove all cache configuration functions
  - Replace cached calls with direct computation
  - **File:** `R/utils_label_placement.R`
  - **Validation:** No `.panel_height_cache` references remain

- [ ] B.3 Remove marquee style cache
  - Delete `.marquee_style_cache` environment
  - Simplify style creation to direct calls
  - **File:** `R/utils_label_helpers.R`
  - **Validation:** No `.marquee_style_cache` references remain

- [ ] B.4 Remove exported cache functions
  - Remove `configure_grob_cache()`
  - Remove `configure_panel_cache()`
  - Remove `get_cache_stats()` if exists
  - Update NAMESPACE
  - **File:** `R/utils_label_placement.R`, `NAMESPACE`
  - **Validation:** No cache configuration functions exported

- [ ] B.5 Update documentation
  - Remove cache-related Roxygen docs
  - Update `docs/CACHING_SYSTEM.MD` or delete if no longer relevant
  - **Validation:** No references to removed functions

## Phase C: Consolidate with cachem (if hit rate >50%)

- [ ] C.1 Add cachem dependency
  - Add `cachem` to Imports in DESCRIPTION
  - Add `digest` to Imports for cache keys
  - **File:** `DESCRIPTION`
  - **Validation:** Packages in Imports

- [ ] C.2 Replace grob cache with cachem
  - Create `.grob_cache <- cachem::cache_mem(...)`
  - Migrate cache_get/cache_set calls
  - Remove custom TTL, stats, purge logic
  - **File:** `R/utils_label_placement.R`
  - **Validation:** Uses cachem, reduced LOC

- [ ] C.3 Replace panel cache with cachem
  - Create `.panel_cache <- cachem::cache_mem(...)`
  - Migrate cache operations
  - Remove custom implementation
  - **File:** `R/utils_label_placement.R`
  - **Validation:** Uses cachem, reduced LOC

- [ ] C.4 Replace marquee cache with cachem
  - Create `.style_cache <- cachem::cache_mem(...)`
  - Simplify to single cache instance
  - **File:** `R/utils_label_helpers.R`
  - **Validation:** Uses cachem, reduced LOC

- [ ] C.5 Simplify exported cache API
  - Create single `clear_bfh_caches()` function
  - Remove complex configuration functions
  - **File:** `R/utils_label_placement.R`
  - **Validation:** Maximum 2 exported cache functions

## Phase D: Verification

- [ ] D.1 Run full test suite
  - Execute: `devtools::test()`
  - Verify: No regressions
  - **Validation:** All tests pass

- [ ] D.2 Run R CMD check
  - Execute: `devtools::check()`
  - Verify: 0 errors, 0 warnings, 0 notes (or acceptable notes)
  - **Validation:** Clean check

- [ ] D.3 Verify code reduction
  - Count lines before/after refactoring
  - Target: 80%+ reduction (1,500 → 200-300 lines)
  - **Validation:** Significant code reduction achieved

- [ ] D.4 Performance spot check
  - Create sample SPC chart with labels
  - Verify performance is acceptable
  - **Validation:** No noticeable performance regression

## Phase E: Commit and Deploy

- [ ] E.1 Commit changes
  - Commit message: `refactor: simplify cache system from 1,500 to ~200 LOC (#42)`
  - **Validation:** Clean git status

- [ ] E.2 Push to remote
  - **Validation:** Changes on GitHub

- [ ] E.3 Close GitHub issue #42
  - Add label: `openspec-deployed`
  - Add closing comment with profiling results and decision rationale
  - **Validation:** Issue closed

- [ ] E.4 Archive OpenSpec change
  - Execute: `openspec archive simplify-cache-system --yes`
  - **Validation:** Change archived

## Profiling Results

**To be completed in Phase A:**

| Cache | Hits | Misses | Hit Rate | Decision |
|-------|------|--------|----------|----------|
| grob_height | - | - | -% | TBD |
| panel_height | - | - | -% | TBD |
| marquee_style | - | - | -% | TBD |

**Overall decision:** TBD (Phase B or Phase C)

## Dependencies

**Sequential:**
- Complete Issue #23 (document caching) first for context
- Phase A → Decision → Phase B or C → Phase D → Phase E

**Conditional:**
- Phase B: If hit rate <50%
- Phase C: If hit rate >50%

## Validation Criteria

**Phase A complete when:**
- All three caches profiled
- Hit rates documented
- Decision made (B or C)

**Phase B/C complete when:**
- All cache code refactored
- Code reduced by 80%+

**Phase D complete when:**
- All tests pass
- R CMD check clean
- Performance acceptable

**Phase E complete when:**
- Changes committed and pushed
- Issue closed with rationale
- OpenSpec archived

## Effort Estimate

- Phase A: 2 hours (instrumentation + profiling)
- Phase B: 4 hours (removal + testing)
- Phase C: 6 hours (migration to cachem + testing)
- Phase D: 1 hour (verification)
- Phase E: 15 minutes (deploy)
- **Total: 7-9 hours (1-2 days)**

## Risk Mitigation

**Risk:** Breaking label placement functionality
- **Mitigation:** Comprehensive test coverage before refactoring
- **Mitigation:** Visual regression tests on sample charts

**Risk:** Performance regression without caching
- **Mitigation:** Profile typical use cases, not just tests
- **Mitigation:** Keep cachem option if needed

**Risk:** Profiling overhead affects results
- **Mitigation:** Use lightweight counters, not heavy logging
- **Mitigation:** Remove instrumentation after profiling
