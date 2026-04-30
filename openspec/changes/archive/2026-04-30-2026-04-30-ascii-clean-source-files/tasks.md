## 1. Sweep

- [x] 1.1 Run `grep -rn -P '[^\x00-\x7F]' R/ --include='*.R'` and inventory hits
- [x] 1.2 Categorize each hit: comment (translate or escape), string (escape via \u-sequence), identifier (rename, last resort)
- [x] 1.3 Confirm `R/utils_bfh_qic_helpers.R:8` is the WARNING locus per Codex (note: line 8 was already ASCII at sweep time; broader sweep covered 14 files / 124 hits)

## 2. Conversion

- [x] 2.1 Replace Danish comments containing æ/ø/å in implementation context with English equivalents
- [x] 2.2 Replace operator-symbol comments (≥, ≤, ±) with ASCII (>=, <=, +/-)
- [x] 2.3 Escape any string-literal Danish content via `"æ"` / `"ø"` / `"å"` form
- [x] 2.4 Move clinically-meaningful Danish prose into roxygen `@details` blocks (UTF-8 docs are allowed) (n/a: existing roxygen prose translated/transliterated rather than relocated; runtime warning strings keep Danish via \u escapes)

## 3. Test guard

- [x] 3.1 Create `tests/testthat/test-source-ascii.R` that lists `R/*.R` and asserts no non-ASCII byte in any file
- [x] 3.2 Test SHALL produce file:line:char output on failure for fast remediation

## 4. Verification

- [x] 4.1 Run `R CMD check --as-cran .` (or `devtools::check(args = "--as-cran")`) -- confirm no WARNING for non-ASCII (2026-04-30: `checking code files for non-ASCII characters ... OK`)
- [x] 4.2 Run `devtools::test()` -- all pass including new ASCII guard (2806 PASS, 0 FAIL, 47 SKIP, 11 WARN)
- [x] 4.3 Run `devtools::check()` -- confirm 0 errors, no new warnings (0 errors, 0 warnings, 1 NOTE = "unable to verify current time" -- unrelated to this change)

## 5. Documentation

- [x] 5.1 Update CONTRIBUTING-style note (added "ASCII-policy for R/*.R" section in BFHcharts CLAUDE.md, overriding global R_STANDARDS.md "kommentarer: dansk" rule for this package)
- [x] 5.2 NEWS entry under `## Interne ændringer`

## 6. Release

- [x] 6.1 Increment PATCH on next release (rolled into 0.12.0 development cycle; current DESCRIPTION Version: 0.12.0)
- [x] 6.2 `devtools::check(args = "--as-cran")` warning-clean (verified 4.1: 0 errors, 0 warnings, 1 unrelated NOTE)

Tracking: GitHub Issue #TBD
