# refactor-split-export-pdf

## Why

`R/export_pdf.R` er vokset til en monolit, som blander flere adskilte
ansvarsområder:

- input- og sikkerhedsvalidering for eksport
- PDF-pipeline og orchestration
- offentlig SPC-statistik-API (`bfh_extract_spc_stats()`)
- offentlig metadata-API (`bfh_merge_metadata()`)
- details-generering og label-relaterede eksporthelpers

Det gør filen sværere at navigere i, øger risikoen ved ændringer, og
slører hvilke funktioner der er generelle utilities versus PDF-specifik
orchestration.

Issue `#116` peger specifikt på, at `bfh_extract_spc_stats()` og
`bfh_merge_metadata()` ikke hører hjemme i en eksportfil, og at de gamle
interne aliaser (`extract_spc_stats()`, `merge_metadata()`) bør fjernes nu,
hvor de navngivne `bfh_*` APIs allerede er etableret.

## What Changes

Denne change opdeler eksportkoden efter ansvar uden at ændre den
offentlige adfærd:

1. Flyt SPC-statistik-API til `R/utils_spc_stats.R`
2. Flyt metadata-merge-API til `R/utils_metadata.R`
3. Flyt details-generering til en dedikeret eksport-helperfil
4. Lad `R/export_pdf.R` fokusere på validering, plotting, Typst/Quarto og
   orchestration
5. Fjern de interne aliaser `extract_spc_stats()` og `merge_metadata()` og
   opdater interne tests/call sites til direkte `bfh_*`-kald

## Impact

**Affected specs:**
- `code-organization`

**Affected code:**
- `R/export_pdf.R`
- `R/utils_spc_stats.R` (ny)
- `R/utils_metadata.R` (ny)
- `R/export_details.R` eller tilsvarende helperfil (ny)
- relevante tests og generated docs

**User-visible changes:**
- Ingen planlagte adfærdsændringer i `bfh_export_pdf()`
- Ingen planlagte signaturændringer i `bfh_extract_spc_stats()`,
  `bfh_merge_metadata()` eller `bfh_generate_details()`

**Internal changes:**
- Utility-funktioner får canonical hjem uden for `R/export_pdf.R`
- `R/export_pdf.R` bliver en orchestration-fil frem for en catch-all modulfil
- Tests kan spejle den nye modulopdeling i stedet for at samle alt under
  `test-export_pdf.R`

## Alternatives Considered

### Beholde alt i `R/export_pdf.R`

Afvist, fordi issue `#116` netop dokumenterer at den nuværende fil bryder
med projektets separation-of-concerns princip og gør fremtidige ændringer
dyrere.

### Splitte filen men beholde de interne aliaser

Afvist, fordi aliaserne nu kun vedligeholder dobbelt navneflade internt.
Den offentlige `bfh_*` API findes allerede og bør være den eneste
kanoniske adgangsvej.

### Flytte utilities uden OpenSpec-change

Afvist, fordi dette er en arkitekturændring med flere filer og intern API-
oprydning. Den bør godkendes eksplicit før implementering.

## Related

- GitHub Issue: [#116](https://github.com/johanreventlow/BFHcharts/issues/116)
