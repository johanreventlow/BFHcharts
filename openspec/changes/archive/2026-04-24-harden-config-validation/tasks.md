# Tasks: harden-config-validation

## 1. Implementation

- [x] 1.1 Audit `spc_plot_config()`: list alle silent-coerce og warning-paths
- [x] 1.2 Konverter invalid-type warnings til `stop()` med class `bfhcharts_config_error`
- [x] 1.3 Audit `viewport_dims()`: samme behandling
- [x] 1.4 Audit øvrige constructors i `R/config_objects.R` (`phase_config`)
- [x] 1.5 Bevar silent defaults kun ved `NULL` argument (eksplicit opt-out)

## 2. Testing

- [x] 2.1 Test: invalid `chart_type` → `bfhcharts_config_error`
- [x] 2.2 Test: `viewport_dims(width = -10)` → error
- [x] 2.3 Test: `viewport_dims(width = NA)` → error
- [x] 2.4 Test: `phase_config(freeze_position = 0)` → error
- [x] 2.5 Verify eksisterende tests stadig passes (adfærd for valid input uændret)

## 3. Documentation

- [x] 3.1 Roxygen `@details`: opdater valideringsadfærd
- [x] 3.2 NEWS.md: breaking change for direkte config-constructor-kald (internal API)
