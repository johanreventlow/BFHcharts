# Tasks: harden-config-validation

## 1. Implementation

- [ ] 1.1 Audit `spc_plot_config()`: list alle silent-coerce og warning-paths
- [ ] 1.2 Konverter invalid-type warnings til `stop()` med class `bfhcharts_config_error`
- [ ] 1.3 Audit `viewport_dims()`: samme behandling
- [ ] 1.4 Audit øvrige constructors i `R/config_objects.R`
- [ ] 1.5 Bevar silent defaults kun ved `NULL` argument (eksplicit opt-out)

## 2. Testing

- [ ] 2.1 Test: `spc_plot_config(width = "big")` → error
- [ ] 2.2 Test: `viewport_dims(width_mm = -10)` → error
- [ ] 2.3 Test: `viewport_dims(width_mm = NA)` → error
- [ ] 2.4 Test: `spc_plot_config(unknown_option = TRUE)` → error (hvis constructor har whitelist)
- [ ] 2.5 Verify eksisterende tests stadig passes (adfærd for valid input uændret)

## 3. Documentation

- [ ] 3.1 Roxygen `@details`: opdater valideringsadfærd
- [ ] 3.2 NEWS.md: breaking change for direkte config-constructor-kald (internal API)
