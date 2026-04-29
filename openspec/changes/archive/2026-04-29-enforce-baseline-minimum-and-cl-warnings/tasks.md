## 1. Constant

- [x] 1.1 Add `MIN_BASELINE_N <- 8L` to `R/globals.R` with rationale comment

## 2. Warnings

- [x] 2.1 Add freeze warning in `validate_bfh_qic_inputs()` when `freeze < MIN_BASELINE_N`
- [x] 2.2 Add part-phase warning in `validate_bfh_qic_inputs()` when any phase has fewer than `MIN_BASELINE_N` obs
- [x] 2.3 Add cl-override Anhøj warning in `bfh_qic()` after `invoke_qicharts2()`

## 3. NA preservation

- [x] 3.1 Remove NA coercion block from `add_anhoej_signal()` (`R/utils_bfh_qic_helpers.R:61-64`)
- [x] 3.2 Update roxygen `@return` on `add_anhoej_signal()` to document NA possibility
- [x] 3.3 Patch `plot_core.R` linetype aesthetic to coerce NA→FALSE at rendering layer

## 4. i18n

- [x] 4.1 Add `analysis.anhoej_not_evaluable` to `inst/i18n/da.yaml`
- [x] 4.2 Add `analysis.anhoej_not_evaluable` to `inst/i18n/en.yaml`

## 5. Tests

- [ ] 5.1 Add freeze=3 → warning test
- [ ] 5.2 Add freeze=8 → no warning test
- [ ] 5.3 Add freeze=NULL → no warning test
- [ ] 5.4 Add part with short first phase → warning test
- [ ] 5.5 Add part with all phases ≥ 8 → no warning test
- [ ] 5.6 Add cl=50 with sufficient data → cl-override warning test
- [ ] 5.7 Add cl=NULL → no cl-override warning test
- [ ] 5.8 Add short series (n=6) → anhoej.signal has NA

## 6. Documentation

- [x] 6.1 Roxygen for `MIN_BASELINE_N` in `globals.R`
- [ ] 6.2 NEWS entry under `## Forbedringer`

## 7. Release

- [ ] 7.1 MINOR bump: 0.10.5 → 0.11.0
- [ ] 7.2 Tests pass
- [ ] 7.3 `devtools::check()` clean
