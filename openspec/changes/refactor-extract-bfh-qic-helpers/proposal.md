# refactor-extract-bfh-qic-helpers

## Why

`bfh_qic()` i `R/create_spc_chart.R` har en lang funktionskrop, som i dag
blander flere forskellige lag af ansvar:

- input- og parameter-validering
- opbygning af `qicharts2::qic()`-kaldet
- Anhøj signal-postprocessering
- viewport- og labelrelateret plotopbygning
- summary-beregning og config-opbygning
- return-routing mellem nyt resultatobjekt og legacy formater

Issue `#117` peger specifikt på to områder, der bør skilles ud som
selvstændige interne funktioner:

- postprocessering af `anhoej.signal`
- return-routing for `return.data` / `print.summary`

Det vil gøre `bfh_qic()` lettere at læse, reducere regressionsrisiko ved
ændringer i legacy-returadfærd og gøre de mest komplekse grene testbare i
isolation.

## What Changes

Denne change foreslår en intern refaktorering uden adfærdsændringer:

1. Ekstraher Anhøj signal-postprocessering til en intern helper
2. Ekstraher return-routing til en intern helper, der ejer legacy-
   kompatibilitet
3. Lad `bfh_qic()` blive en kortere orchestration-funktion, der kalder de
   dedikerede helpers
4. Tilføj målrettede tests for de nye helpers og for bevaret returadfærd

## Impact

**Affected specs:**
- `code-organization`

**Affected code:**
- `R/create_spc_chart.R`
- evt. ny helperfil for interne `bfh_qic()`-helpers
- relevante tests for `bfh_qic()` og legacy return modes

**User-visible changes:**
- Ingen planlagte ændringer i `bfh_qic()` signatur
- Ingen planlagte ændringer i default `bfh_qic_result` output
- Ingen planlagte ændringer i deprecated `return.data` / `print.summary`
  adfærd ud over bevaret kompatibilitet

## Alternatives Considered

### Kun ekstrahere `add_anhoej_signal()`

Afvist, fordi return-routing er den anden store kompleksitetskilde i
`bfh_qic()` og samtidig den mest følsomme del ift. backward compatibility.

### Kun ekstrahere `build_bfh_qic_return()`

Afvist, fordi signal-postprocesseringen er et separat ansvar med sin egen
datamutation og derfor også bør kunne testes isoleret.

### Lade `bfh_qic()` være som den er

Afvist, fordi issue `#117` dokumenterer en reel læsbarheds- og
vedligeholdelsesomkostning i en central public entrypoint.

## Related

- GitHub Issue: [#117](https://github.com/johanreventlow/BFHcharts/issues/117)
