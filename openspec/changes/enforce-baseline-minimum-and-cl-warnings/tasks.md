## 1. Constant + helper

- [ ] 1.1 Add `MIN_BASELINE_N <- 8L` to `R/globals.R` with rationale comment + Anhøj reference
- [ ] 1.2 Add internal `.warn_short_baseline(n, source)` helper for consistent message format

## 2. Freeze validation

- [ ] 2.1 In `bfh_qic()` (or `validate_bfh_qic_inputs()`), emit `warning()` when `!is.null(freeze) && freeze < MIN_BASELINE_N`
- [ ] 2.2 Test: `freeze = 3` triggers warning; result still produced
- [ ] 2.3 Test: `freeze = 8` does not trigger warning
- [ ] 2.4 Test: `freeze = NULL` does not trigger warning

## 3. Part phase-length validation

- [ ] 3.1 Compute phase boundaries from `part` argument; check each phase length
- [ ] 3.2 Emit `warning()` listing phase indices with length < `MIN_BASELINE_N`
- [ ] 3.3 Test: `part = c(3, 9)` on n=18 → warning for phase 1 (length 3)
- [ ] 3.4 Test: `part = c(8, 16)` on n=24 → no warning

## 4. cl-override Anhøj warning

- [ ] 4.1 In `bfh_qic()` post-qicharts2-invocation, if `cl` was non-NULL AND result includes runs.signal or crossings.signal, emit warning
- [ ] 4.2 Message: "Custom cl supplied: Anhøj run/crossing signals are computed against the supplied centerline, not the data-estimated process mean. Interpret with caution."
- [ ] 4.3 Test: `cl = 50` with sufficient data → warning emitted
- [ ] 4.4 Test: `cl = NULL` → no warning

## 5. NA-preservation in anhoej.signal

- [ ] 5.1 In `add_anhoej_signal()` (`R/utils_bfh_qic_helpers.R:62-64`), remove the `ifelse(is.na(...), FALSE, ...)` coercion
- [ ] 5.2 Propagate NA through to `qic_summary` and analysis text
- [ ] 5.3 Add i18n keys `analysis.anhoej_not_evaluable` (da: "ikke evaluerbar (for kort serie)"; en: "not evaluable (series too short)")
- [ ] 5.4 Update fallback analysis text generation to handle NA case
- [ ] 5.5 Test: 6-point series → summary shows "ikke evaluerbar", not "0 signaler"

## 6. Documentation

- [ ] 6.1 Update `vignettes/phases-and-freeze.Rmd` to document each new warning
- [ ] 6.2 Update `bfh_qic()` Roxygen `@param freeze`, `@param part`, `@param cl` to mention warnings
- [ ] 6.3 NEWS entries

## 7. Release

- [ ] 7.1 MINOR bump (new warnings = behavior change but additive; pre-1.0)
- [ ] 7.2 Coordinate with biSPCharts: verify warning-handling + display logic for NA Anhøj state
- [ ] 7.3 `devtools::test()` clean
- [ ] 7.4 `devtools::check()` clean
