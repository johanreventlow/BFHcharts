## Why

`bfh_qic()` silently accepts short baseline configurations and custom centerline (`cl`) overrides without informing users that the resulting Anhøj signals may be statistically unreliable.

Concrete risks:
- `freeze = 3`: baseline from 3 observations → control limits and Anhøj signals are statistically meaningless, but no warning is emitted
- `part = c(3, ...)`: first phase with 3 observations → same issue
- `cl = 42`: Anhøj run/crossing signals computed against user-supplied centerline instead of data-estimated process mean → valid use case, but needs explicit caution
- `anhoej.signal` coerced from NA to FALSE when qicharts2 returns NA (too-short series) → masks "not evaluable" state as "no signal"

SPC/Anhøj theory (Anhøj & Olesen 2014) requires approximately 8+ observations for meaningful control limits and reliable signal detection.

## What Changes

- Add named constant `MIN_BASELINE_N <- 8L` in `R/globals.R` with rationale comment
- Add `warning()` in `validate_bfh_qic_inputs()` when `freeze < MIN_BASELINE_N`
- Add `warning()` in `validate_bfh_qic_inputs()` when any `part` phase has fewer than `MIN_BASELINE_N` observations
- Add `warning()` in `bfh_qic()` after `invoke_qicharts2()` when custom `cl` is supplied and Anhøj signal columns are present
- Remove NA coercion (`ifelse(is.na(...), FALSE, ...)`) from `add_anhoej_signal()` — preserve NA to signal "not evaluable (series too short)"
- Patch `plot_core.R` to coerce NA→FALSE in linetype aesthetic only (rendering layer, not data layer)
- Add i18n keys `analysis.anhoej_not_evaluable` to `inst/i18n/da.yaml` and `inst/i18n/en.yaml`

## Impact

**Affected specs:**
- `spc-analysis-api` — MODIFIED: `anhoej.signal` contract now allows NA; ADDED: baseline minimum warning contract

**Affected code:**
- `R/globals.R` — add `MIN_BASELINE_N` constant
- `R/utils_bfh_qic_helpers.R` — add freeze/part warnings; remove NA coercion
- `R/bfh_qic.R` — add cl-override Anhøj warning
- `R/plot_core.R` — NA→FALSE coercion in linetype aesthetic
- `inst/i18n/da.yaml` + `inst/i18n/en.yaml` — add `anhoej_not_evaluable` key

**Not breaking:**
- Adds new warnings (callers using `suppressWarnings()` are unaffected)
- `anhoej.signal` NA only for short series where previous behavior (FALSE) was misleading
- i18n key is additive
- Behavior unchanged for normal n ≥ 8 series

## Cross-repo impact (biSPCharts)

**Verification:**
```bash
grep -rn "anhoej.signal\|freeze\|MIN_BASELINE" R/ inst/
```

**Expected impact:** Additive warnings only. biSPCharts may need to add `suppressWarnings()` if it passes short freeze/part values in tests.

## Related

- GitHub Issue: #207 (related — baseline reliability)
- Source: BFHcharts OpenSpec enforce-baseline-minimum-and-cl-warnings
