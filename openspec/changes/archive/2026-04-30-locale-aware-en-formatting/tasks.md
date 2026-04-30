## 1. Number formatting

- [x] 1.1 Add `format_count(n, language = "da")` dispatcher in `R/utils_number_formatting.R`
- [x] 1.2 Implement `format_count_english()` using `scales::comma()`-equivalent (decimal `.`, thousand `,`)
- [x] 1.3 Mark existing `format_count_danish()` as `@keywords internal` (still called directly from da path) — already internal
- [x] 1.4 Add doc-test in roxygen: `format_count(1234.5, "en")` ↔ `format_count(1234.5, "da")` — covered by tests

## 2. Y-axis threading

- [x] 2.1 Add `language` parameter to `format_y_axis_count()`, `format_y_axis_percent()`, `format_y_axis_rate()` in `R/utils_y_axis_formatting.R`. `format_y_axis_time()` is locale-neutral (composite "1t 30m"-format).
- [x] 2.2 Switch on `language` in count formatter; route percent through `scales::label_percent(big.mark, decimal.mark, suffix)` set by language
- [x] 2.3 In `apply_y_axis_formatting()` (callsite), accept and propagate `language`

## 3. X-axis threading

- [x] 3.1 Add `language` parameter to `apply_temporal_x_axis()` in `R/utils_x_axis_formatting.R`
- [x] 3.2 Locale-aware month/weekday abbreviations via `with_lc_time_labeler()` — best-effort LC_TIME swap
- [x] 3.3 Wraps existing `scales::label_date_short()` rather than building custom labeller

## 4. Plumbing

- [x] 4.1 In `bfh_qic()` (`R/bfh_qic.R`), pass `language` through to plot-construction helpers
- [x] 4.2 In `bfh_spc_plot()` (`R/plot_core.R`), pass `language` to axis-formatting calls
- [x] 4.3 Confirm `language` reaches both y-axis and x-axis formatters
- [x] 4.4 Default `language = "da"` everywhere

## 5. Tests

- [x] 5.1 Test: `bfh_qic(... language = "en")` produces y-axis count config — covered indirectly via format_y_axis_count tests
- [x] 5.2 Test: `bfh_qic(... language = "da")` unchanged (regression for Danish path)
- [x] 5.3 Test: percent formatting respects language (decimal separator)
- [ ] 5.4 Test: monthly x-axis breaks show `Jan` (en) vs `jan` (da) — locale-dependent, manual verification
- [ ] 5.5 Test: weekly x-axis breaks use locale-aware weekday names — locale-dependent
- [ ] 5.6 Test: snapshot of axis labels for both languages on a representative chart — vdiffr update deferred

## 6. Documentation

- [x] 6.1 Update `bfh_qic()` Roxygen `@param language` to document that it affects both labels AND number/date formatting
- [x] 6.2 NEWS entry under `## Bug fixes` for v0.12.0
- [ ] 6.3 Update `vignettes/chart-types.Rmd` with English-language example — deferred

## 7. Release

- [x] 7.1 Bump `DESCRIPTION` 0.11.1 → 0.12.0
- [x] 7.2 `devtools::test()` passes
- [ ] 7.3 `devtools::check()` no new WARN/ERROR

Tracking: GitHub Issue #TBD
