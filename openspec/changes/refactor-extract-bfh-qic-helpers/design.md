# Design Notes

## Goal

Reducere kompleksiteten i `bfh_qic()` ved at flytte to klart afgrænsede
ansvarsområder ud i interne helpers, uden at ændre public API eller legacy
returadfærd.

## Proposed Helpers

### `add_anhoej_signal(qic_data)`

Ansvar:

- normalisere `runs.signal`
- beregne crossings-signal per part når de nødvendige kolonner findes
- producere en altid-boolean `anhoej.signal`
- rydde midlertidige kolonner op

Returnerer det muterede `qic_data`-data frame.

### `build_bfh_qic_return(...)`

Ansvar:

- håndtere `return.data` / `print.summary` kombinationer
- bevare warnings for deprecated legacy paths
- returnere enten raw `qic_data`, legacy lister eller `bfh_qic_result`

Denne helper skal være eneste sted, hvor de legacy branches ligger.

## Refactor Boundary

`bfh_qic()` skal fortsat eje:

- input validation
- `qicharts2::qic()` invocation
- unit conversion og viewport-beregning
- plot generation
- config- og summary-opbygning

Helperne skal kun overtage de klart afgrænsede dele, som issue `#117`
peger på, så refaktoren forbliver lille og lav-risiko.
