# Design Notes

## Goal

Reducere kompleksiteten i `bfh_qic()` ved at flytte to klart afgrænsede
ansvarsområder ud i interne helpers, uden at ændre public API eller legacy
returadfærd.

## Proposed Helpers

### `add_anhoej_signal(qic_data)`

**Signatur:** `add_anhoej_signal(qic_data)`

**Input:** `qic_data` — data.frame fra `qicharts2::qic()` (eller NULL)

**Output:** Same data.frame med en normaliseret `anhoej.signal` kolonne
(altid logical, aldrig NA). Returnerer NULL hvis input er NULL.

**Ansvar:**

- normalisere `runs.signal`
- beregne crossings-signal per part når de nødvendige kolonner findes
- producere en altid-boolean `anhoej.signal`
- rydde midlertidige kolonner op

Fallback-priority: `anhoej.signal` → `anhoej.signals` → `runs.signal | crossings.signal` → `runs.signal` → `FALSE`.

### `build_bfh_qic_return(...)`

**Signatur:** `build_bfh_qic_return(qic_data, plot, summary_result, config, return.data, print.summary)`

**Input:**
- `qic_data` — data.frame med rå qic-beregninger
- `plot` — ggplot2-objekt
- `summary_result` — data.frame med SPC-summary
- `config` — liste med konfigurationsparametre
- `return.data` — logical
- `print.summary` — logical

**Output:** Én af fire returtyper:
- `return.data && print.summary` → `list(data, summary)` (legacy)
- `return.data` → `qic_data` data.frame (legacy)
- `print.summary` → `list(plot, summary)` (deprecated, warns)
- default → `bfh_qic_result` S3-objekt

**Ansvar:**

- håndtere `return.data` / `print.summary` kombinationer
- bevare warnings for deprecated legacy paths (begge warnings indefra helper)
- returnere enten raw `qic_data`, legacy lister eller `bfh_qic_result`

Denne helper skal være eneste sted, hvor de legacy branches ligger.

**Warning-adfærd bevares præcist:**
1. Deprecation-warning fyres for alle `print.summary = TRUE` cases
2. Legacy-format-warning fyres kun for `print.summary = TRUE && return.data = FALSE`

## Refactor Boundary

`bfh_qic()` skal fortsat eje:

- input validation
- `qicharts2::qic()` invocation
- unit conversion og viewport-beregning
- plot generation
- config- og summary-opbygning

Helperne skal kun overtage de klart afgrænsede dele, som issue `#117`
peger på, så refaktoren forbliver lille og lav-risiko.
