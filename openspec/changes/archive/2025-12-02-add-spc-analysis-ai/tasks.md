# Implementation Tasks: AI-Assisteret SPC Analyse

**GitHub Issue:** [#69](https://github.com/johanreventlow/BFHcharts/issues/69)
**Status:** COMPLETED

---

## Phase 1: Standardtekster (REQ-1)

- [x] Create `R/spc_analysis.R` with `bfh_interpret_spc_signals()`
- [x] Implement serielængde signal detection
- [x] Implement krydsnings signal detection
- [x] Implement outlier detection
- [x] Add combined conclusion logic
- [x] Create `tests/testthat/test-spc_analysis.R`
- [x] Add tests for all signal scenarios
- [x] Add roxygen2 documentation

**Verification:**
```r
devtools::test(filter = "spc_analysis")
```

---

## Phase 2: Kontekst-sammensætning (REQ-2)

- [x] Add `bfh_build_analysis_context()` to `R/spc_analysis.R`
- [x] Extract chart metadata from `bfh_qic_result$config`
- [x] Extract SPC stats via `bfh_extract_spc_stats()`
- [x] Generate signal interpretations
- [x] Merge user-provided metadata
- [x] Add input validation for `bfh_qic_result`
- [x] Add tests for context building
- [x] Document parameters

**Verification:**
```r
result <- bfh_qic(data, x, y, chart_type = "i")
ctx <- bfh_build_analysis_context(result)
str(ctx)  # Verify all fields present
```

---

## Phase 3: AI-Integration (REQ-3)

- [x] Add `bfh_generate_analysis()` to `R/spc_analysis.R`
- [x] Add BFHllm to `Suggests` in DESCRIPTION
- [x] Implement BFHllm detection via `requireNamespace()`
- [x] Build SPC result structure for BFHllm
- [x] Build context structure for BFHllm
- [x] Wrap BFHllm call in `tryCatch()`
- [x] Implement fallback to standardtekster
- [x] Add tests with mocked BFHllm
- [x] Add tests for fallback scenario

**Verification:**
```r
# Without BFHllm
analysis <- bfh_generate_analysis(result, use_ai = FALSE)
cat(analysis)

# With BFHllm (if installed)
analysis <- bfh_generate_analysis(result, use_ai = TRUE)
cat(analysis)
```

---

## Phase 4: PDF Integration (REQ-4)

- [x] Update `bfh_export_pdf()` signature with `auto_analysis`, `use_ai`
- [x] Add auto-analysis logic before metadata processing
- [x] Ensure user-provided analysis is not overwritten
- [x] Update roxygen2 documentation
- [x] Add integration tests
- [x] Verify backward compatibility

**Verification:**
```r
result <- bfh_qic(data, x, y, chart_type = "i")

# New workflow
bfh_export_pdf(result, "test.pdf",
  metadata = list(hospital = "BFH"),
  auto_analysis = TRUE
)

# Old workflow still works
bfh_export_pdf(result, "test2.pdf",
  metadata = list(analysis = "Manual text")
)
```

---

## Phase 5: Release

- [x] Run `devtools::document()` to update NAMESPACE
- [x] Run `devtools::check()` - must pass with 0 errors, 0 warnings
- [x] Update NEWS.md with feature description
- [x] Bump version to 0.6.0 in DESCRIPTION
- [ ] Commit with descriptive message
- [ ] Push to remote
- [ ] Close GitHub issue with summary

**Verification:**
```bash
R CMD check BFHcharts_0.6.0.tar.gz
```

---

## Definition of Done

- [x] All REQ-* requirements implemented
- [x] All tests pass
- [x] Documentation complete
- [x] No new warnings in `devtools::check()`
- [x] NEWS.md updated
- [x] Version bumped
- [ ] GitHub issue closed
