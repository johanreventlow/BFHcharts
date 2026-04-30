## Why

`BFHcharts` supports `language = "en"` in `bfh_qic()` for translated labels (via `inst/i18n/*.yaml`), but **number and date formatting on the y/x axes is hardcoded to Danish conventions**:

- `R/utils_number_formatting.R` — `format_count_danish()` always uses `,` decimal and `.` thousand-separator
- `R/utils_y_axis_formatting.R:166-175` — `format_y_axis_count()` calls Danish formatter for every break, regardless of `language`
- `R/utils_x_axis_formatting.R` — date breaks/labels rely on locale defaults; no `language` parameter threading

Engelske brugere får y-akse som `1.000,5` i stedet for `1,000.5` — ikke en typografisk præference men en faktuel formatering-fejl der i grænsetilfælde kan misforstås (engelsk `1.000` betyder ét).

This is a real user-facing bug for the documented English-language path.

## What Changes

- **Threading**: `language` parameter SHALL be passed from `bfh_qic()` through `apply_y_axis_formatting()` and into all `format_y_axis_*` formatters and date-axis formatters.
- **Number formatting**:
  - New `format_count(n, language = "da")` in `R/utils_number_formatting.R` dispatching:
    - `language = "da"`: existing `format_count_danish()` (decimal `,`, thousand `.`)
    - `language = "en"`: `format_count_english()` (decimal `.`, thousand `,`) using `scales::comma()`
  - Existing `format_count_danish()` retained for backward compat, marked `@keywords internal` (no breaking change for callers using it directly).
- **Date formatting**:
  - `apply_temporal_x_axis()` SHALL accept a `language` argument and pass to `scales::label_date_short(format = ..., locale = language)` or use locale-aware month abbreviations
  - Month/weekday abbreviations: when `language = "en"`, use English abbreviations (`Jan`, `Feb`, `Mon`); when `language = "da"`, use Danish (`jan`, `feb`, `man`)
- **Percent formatting**: already locale-neutral via `scales::label_percent()`. Verify the decimal separator follows the same `language` parameter (likely already handled by scales but worth verifying).
- **Tests**: 6 new tests verifying English formatting on y-axis (count), x-axis (dates), and verifying Danish unchanged when `language = "da"`.

## Impact

**Affected specs:**
- `public-api` — MODIFIED requirement: `bfh_qic` language parameter affects axis formatting

**Affected code:**
- `R/utils_number_formatting.R` — new `format_count()` dispatcher
- `R/utils_y_axis_formatting.R` — accept and thread `language`
- `R/utils_x_axis_formatting.R` — accept and thread `language`, locale-aware month abbreviations
- `R/utils_bfh_qic_helpers.R` — pass `language` through to formatting helpers
- `R/plot_core.R` — pass `language` through axis-formatting calls
- `tests/testthat/test-locale-en-formatting.R` — new file, 6 tests
- `tests/testthat/test-i18n.R` — extend to verify number/date formatting (currently only label translation)
- `NEWS.md` — entry under `## Bug fixes`

**Breaking change scope:** None. Default `language = "da"` preserves existing output. English path was already documented but produced incorrect formatting; this is a bug fix, not a behavior change for compliant Danish users.

## Cross-repo impact (biSPCharts)

**Verification:**
```bash
# In biSPCharts:
grep -rn "language\s*=" R/
```

**Likely affected:** biSPCharts apps that pass `language = "en"` start producing correctly-formatted PDFs. No code change required.

**biSPCharts version bump:** PATCH.

**Lower-bound:** `BFHcharts (>= 0.12.0)`.

## Related

- Source: BFHcharts code review 2026-04-30 (Claude finding #3)
- Builds on `2026-04-25-i18n-chart-strings` (which added label translation but not formatting)
