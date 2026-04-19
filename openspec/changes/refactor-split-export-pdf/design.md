# Design Notes

## Goal

Splitte `R/export_pdf.R` efter ansvar uden at ændre den offentlige API
eller PDF-renderingens adfærd.

## Proposed Module Boundaries

### `R/export_pdf.R`

Beholder kun PDF-exportspecifik orchestration:

- input- og miljøvalidering
- plot-forberedelse og label-recalculation
- Typst-dokumentoprettelse
- compile/invoke pipeline

### `R/utils_spc_stats.R`

Canonical hjem for SPC-statistik-API:

- `bfh_extract_spc_stats()`
- `bfh_extract_spc_stats.default()`
- `bfh_extract_spc_stats.data.frame()`
- `bfh_extract_spc_stats.bfh_qic_result()`
- tilhørende interne helpers (`empty_spc_stats()`, `clean_spc_value()`)

### `R/utils_metadata.R`

Canonical hjem for metadata utilities:

- `bfh_merge_metadata()`

### `R/export_details.R`

Hjem for details-tekst og tilhørende formattering:

- `bfh_generate_details()`
- `format_centerline_for_details()`

## Alias Strategy

De tidligere interne aliaser `extract_spc_stats()` og `merge_metadata()`
fjernes i implementeringen. Rationalet er:

- `bfh_*`-navnene er allerede den etablerede public API
- aliaserne giver ikke længere migrationsværdi internt i BFHcharts
- tests og interne call sites skal bruge de kanoniske navne direkte

Hvis der under implementering opdages eksterne downstream-kald til disse
interne aliaser, skal ændringen stoppes og revurderes som potentiel
breaking change.

## Test Impact

Der forventes ingen ændring i assertions om output, men tests skal flyttes
væk fra interne aliaser og gerne organiseres nærmere de nye modulgrænser.
