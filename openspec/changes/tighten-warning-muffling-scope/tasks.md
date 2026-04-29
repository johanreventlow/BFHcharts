## 1. Narrow the muffler regex

- [ ] 1.1 In `.muffle_expected_warnings()` (`R/utils_bfh_qic_helpers.R:18-26`), replace the unanchored `"numeric"` with explicit patterns:
  - `"scale_[xy]_(continuous|date|datetime).*"` (scale warnings only)
  - `"font family.*not found in PostScript font database"`
  - `"Removed [0-9]+ rows containing"` (geom missing-value warnings)
- [ ] 1.2 Add comment naming the source of each pattern (qicharts2 column, ggplot2 layer, BFHtheme font register)
- [ ] 1.3 Verify removal of the bare `"numeric"` does not introduce noisy warnings for the documented test cases

## 2. Tests for muffler scope

- [ ] 2.1 Test: `simpleWarning("NAs introduced by coercion to numeric")` is NOT muffled (propagates to caller)
- [ ] 2.2 Test: `simpleWarning("non-numeric argument to binary operator")` is NOT muffled
- [ ] 2.3 Test: `simpleWarning("scale_x_date: Removed 3 rows")` IS muffled
- [ ] 2.4 Test: `simpleWarning("font family Mari not found in PostScript font database")` IS muffled
- [ ] 2.5 Test: `simpleWarning("Removed 5 rows containing missing values")` IS muffled
- [ ] 2.6 Test: BFHcharts smoke test on malformed denominator data emits the qicharts2 coercion warning to caller

## 3. Consolidate double-warning

- [ ] 3.1 In `build_bfh_qic_return()` (or wherever `print.summary` legacy branch lives, `R/utils_bfh_qic_helpers.R:85-109`), remove the unconditional generic deprecation block at L85-93 OR move it inside the `!return.data` guard
- [ ] 3.2 Single warning per legacy call; message includes both deprecation context and migration hint
- [ ] 3.3 Test: `print.summary = TRUE, return.data = FALSE` emits exactly one warning

## 4. Documentation

- [ ] 4.1 Roxygen comment on `.muffle_expected_warnings()` documenting which patterns are muffled and why
- [ ] 4.2 NEWS entry under `## Bug fixes`

## 5. Release

- [ ] 5.1 PATCH bump (bug fix)
- [ ] 5.2 Run full test suite; address any newly-surfaced warnings in tests by either fixing fixtures or adding `expect_warning()` where the warning is intended
- [ ] 5.3 `devtools::check()` clean
