## Why

`.muffle_expected_warnings()` (`R/utils_bfh_qic_helpers.R:18-26`) uses the regex pattern:

```r
grepl("numeric|datetime|scale_[xy]_date|PostScript font database", msg)
```

The `"numeric"` term is unanchored. It matches **any** warning whose text contains the substring "numeric". This includes:

- `"NAs introduced by coercion to numeric"` (qicharts2 / base R, signals malformed denominators)
- `"non-numeric argument to ..."` (type errors)
- ggplot2 / scales messages containing "numeric"

All of these are silently muffled today.

**Clinical consequence:** A chart rendered from character-typed denominators or otherwise malformed data produces a coercion warning that should guide the user to fix data. With the current muffler, no signal is raised; the chart silently renders with wrong values.

Both review passes flagged this (Claude finding #2, Codex finding #5).

A secondary issue: `R/utils_bfh_qic_helpers.R:85-93` and 99-109 produce a double-warning when `print.summary = TRUE, return.data = FALSE` — first the generic deprecation, then the legacy-list warning. The double-warning predates the muffler issue but lives in the same helper.

## What Changes

- Replace the bare `"numeric"` term with a tightly-anchored set of patterns matching only the known benign ggplot2/scales/font warnings:
  - `"scale_[xy]_(continuous|date|datetime).*Removed"` (datetime/date scale row removal)
  - `"font family.*not found in PostScript font database"` (BFHtheme font register)
  - `"Removed [0-9]+ rows containing missing values"` (geom_*)
- Document each pattern in a comment naming the source (qicharts2, ggplot2, scales)
- Consolidate the double-deprecation warning into a single message in the legacy-list branch
- Add tests verifying that legitimate "numeric" / "datetime" warnings DO propagate

## Impact

**Affected specs:**
- `code-organization` — MODIFIED requirement for warning-muffler scope and predictability

**Affected code:**
- `R/utils_bfh_qic_helpers.R:18-26` — narrow regex
- `R/utils_bfh_qic_helpers.R:85-109` — consolidate double-warning
- `tests/testthat/test-bfh_qic_helpers.R` — add propagation tests
- NEWS entry under `## Bug fixes`

**Not breaking:** Some warnings that were previously hidden will now surface. Callers running with `options(warn = 2)` may see new failures (correctly, since the underlying data has issues). Callers that test for `expect_no_warning()` around `bfh_qic()` may need to provide cleaner test fixtures.

## Cross-repo impact (biSPCharts)

biSPCharts may see new warnings in logs for previously-silent data issues. This is intended — it surfaces real data-quality problems. Verify Shiny error-handling does not crash UI on the new warnings.

biSPCharts version bump: not required.

## Related

- Code review 2026-04 (Claude finding #2, Codex finding #5)
- Severity: high. Confidence: high.
