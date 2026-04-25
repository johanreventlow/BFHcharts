# harden-config-validation

## Why

Interne config-constructors (`spc_plot_config()`, `viewport_dims()` i
`R/config_objects.R:88`) advarer og fortsætter ved invalid input, eller
coercer silently til default. Det skubber fejl senere ind i render-pipeline,
hvor de er sværere at diagnosticere og fejlbeskederne refererer ikke til
den oprindelige brugerfejl.

Interne kontrakter bør fejle tidligt og loudly. Fallback-adfærd er kun
legitim ved dokumenteret brugerflade-adfærd (fx `bfh_qic()` parametre).

## What Changes

- `spc_plot_config()`, `viewport_dims()` SKAL `stop()` ved:
  - Ugyldig type (character hvor numeric forventes)
  - Negative eller NA dimensioner
  - Unknown option-nøgler (hvis constructor har whitelisted set)
- Fjern silent coerce (`as.numeric()` på character uden validering)
- Fjern warning-only-paths; konverter til errors
- Bevar fallback kun hvor brugerflade-dokumenteret (fx `bfh_qic(..., viewport = NULL)`)
- Tilføj tests: invalid input → informativ fejl

## Impact

**Affected specs:**
- `code-organization`

**Affected code:**
- `R/config_objects.R` (validate-logic)
- `tests/testthat/test-config-objects.R` (nye error-tests)

**User-visible changes:**
- Kode der utilsigtet sendte ugyldige værdier til interne constructors får nu tidlig fejl
- Public API (`bfh_qic`) uændret — dens validerings-lag bevares

## Related

- Codex review (blød validation skjuler fejl)
