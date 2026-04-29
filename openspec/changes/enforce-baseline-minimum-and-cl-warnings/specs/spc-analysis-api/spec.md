# Spec: spc-analysis-api — Baseline Minimum and CL Override Warnings

## Contract Changes

### `bfh_qic()` — new warnings

**freeze baseline too short:**
- When `freeze < MIN_BASELINE_N` (8), emit `warning()` before qicharts2 call
- Message: `"freeze = {n}: baseline har færre end 8 observationer. Kontrolgrænser er statistisk usikre."`

**part phase too short:**
- When any phase derived from `part` boundaries has fewer than `MIN_BASELINE_N` observations, emit `warning()`
- Message identifies which phase number(s) are short

**cl override:**
- When `cl` is non-NULL and qicharts2 output contains `runs.signal` or `crossings.signal`, emit `warning()`
- Message: `"Custom cl supplied: Anhøj run/crossing signals are computed against the supplied centerline, not the data-estimated process mean. Interpret with caution."`

### `anhoej.signal` — NA contract

**MODIFIED:** `anhoej.signal` may now be `NA` (was always `TRUE`/`FALSE`)

- NA occurs when qicharts2 returns NA for a series too short to evaluate Anhøj rules
- Downstream callers must handle NA explicitly
- `plot_core.R` coerces NA→FALSE at the linetype aesthetic rendering layer only
- `utils_qic_summary.R` already uses `na.rm = TRUE` for `runs.signal` aggregation (safe)

### `MIN_BASELINE_N` constant

- Value: `8L`
- Rationale: Anhøj & Olesen (2014) — approximately 8+ points needed for reliable SPC signal detection
- Location: `R/globals.R`

## i18n

**Added keys:**
- `analysis.anhoej_not_evaluable` (da): `"ikke evaluerbar (for kort serie)"`
- `analysis.anhoej_not_evaluable` (en): `"not evaluable (series too short)"`
