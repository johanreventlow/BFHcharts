# Implementation Tasks: AI-Assisteret SPC Analyse

**GitHub Issue:** [#69](https://github.com/johanreventlow/BFHcharts/issues/69)
**Status:** PROPOSED

---

## Phase 1: Standardtekster (REQ-1)

- [ ] Create `R/spc_analysis.R` with `bfh_interpret_spc_signals()`
- [ ] Implement serielængde signal detection
- [ ] Implement krydsnings signal detection
- [ ] Implement outlier detection
- [ ] Add combined conclusion logic
- [ ] Create `tests/testthat/test-spc_analysis.R`
- [ ] Add tests for all signal scenarios
- [ ] Add roxygen2 documentation

**Verification:**
```r
devtools::test(filter = "spc_analysis")
```

---

## Phase 2: Kontekst-sammensætning (REQ-2)

- [ ] Add `bfh_build_analysis_context()` to `R/spc_analysis.R`
- [ ] Extract chart metadata from `bfh_qic_result$config`
- [ ] Extract SPC stats via `bfh_extract_spc_stats()`
- [ ] Generate signal interpretations
- [ ] Merge user-provided metadata
- [ ] Add input validation for `bfh_qic_result`
- [ ] Add tests for context building
- [ ] Document parameters

**Verification:**
```r
result <- bfh_qic(data, x, y, chart_type = "i")
ctx <- bfh_build_analysis_context(result)
str(ctx)  # Verify all fields present
```

---

## Phase 3: AI-Integration (REQ-3)

- [ ] Add `bfh_generate_analysis()` to `R/spc_analysis.R`
- [ ] Add BFHllm to `Suggests` in DESCRIPTION
- [ ] Implement BFHllm detection via `requireNamespace()`
- [ ] Build SPC result structure for BFHllm
- [ ] Build context structure for BFHllm
- [ ] Wrap BFHllm call in `tryCatch()`
- [ ] Implement fallback to standardtekster
- [ ] Add tests with mocked BFHllm
- [ ] Add tests for fallback scenario

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

- [ ] Update `bfh_export_pdf()` signature with `auto_analysis`, `use_ai`
- [ ] Add auto-analysis logic before metadata processing
- [ ] Ensure user-provided analysis is not overwritten
- [ ] Update roxygen2 documentation
- [ ] Add integration tests
- [ ] Verify backward compatibility

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

- [ ] Run `devtools::document()` to update NAMESPACE
- [ ] Run `devtools::check()` - must pass with 0 errors, 0 warnings
- [ ] Update NEWS.md with feature description
- [ ] Bump version to 0.6.0 in DESCRIPTION
- [ ] Commit with descriptive message
- [ ] Push to remote
- [ ] Close GitHub issue with summary

**Verification:**
```bash
R CMD check BFHcharts_0.6.0.tar.gz
```

---

## Definition of Done

- [ ] All REQ-* requirements implemented
- [ ] All tests pass
- [ ] Documentation complete
- [ ] No new warnings in `devtools::check()`
- [ ] NEWS.md updated
- [ ] Version bumped
- [ ] GitHub issue closed
