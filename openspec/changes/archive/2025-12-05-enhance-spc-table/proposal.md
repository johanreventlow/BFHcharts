## Why

SPC-tabellen i Typst PDF-skabelonen mangler vigtige funktioner:

1. **Run charts**: Viser "OBS. UDEN FOR KONTROLGRÆNSE"-rækken selvom run charts ikke har kontrolgrænser
2. **Outlier-data**: Viser ikke antal punkter uden for kontrolgrænser for andre chart types
3. **Visuel indikation**: Ingen visuel fremhævning når SPC-regler er overtrådt

Ved at implementere disse forbedringer:
- Run chart PDF'er får en renere tabel uden irrelevant kontrolgrænse-række
- Andre chart types viser faktisk antal outliers (fra `sigma.signal`)
- Brugere kan hurtigt identificere når SPC-regler er overtrådt via farve-indikation

## What Changes

### 1. R-kode ændringer (`R/export_pdf.R`)

**Udvid `bfh_extract_spc_stats()` eller opret ny funktion til at:**
- Modtage hele `bfh_qic_result` objektet (ikke kun summary)
- Hente runs/crossings fra `$summary` (allerede implementeret)
- Beregne `outliers_actual` fra `sum(qic_data$sigma.signal)` (vektor af booleans)
- Sætte `outliers_expected` til 0 for ikke-run charts
- Tilføje `is_run_chart` flag baseret på `config$chart_type == "run"`

**Data kilder:**
- `$summary$længste_løb` / `$summary$længste_løb_max` → runs (allerede brugt)
- `$summary$antal_kryds` / `$summary$antal_kryds_min` → crossings (allerede brugt)
- `$qic_data$sigma.signal` → outliers count (sum af TRUE værdier)
- `$config$chart_type` → run chart detection

**Opdater `bfh_export_pdf()` til at:**
- Kalde udvidet stats-funktion med hele result objektet
- Sende `is_run_chart` til Typst template

### 2. Typst template ændringer (`bfh-template.typ`)

**Tilføj `is_run_chart` parameter:**
- Skjul "OBS. UDEN FOR KONTROLGRÆNSE"-rækken når `is_run_chart == true`

**Tilføj betinget baggrundsfarve på data-celler:**
- Grå baggrund + hvid tekst når:
  - SERIELÆNGDE: `runs_actual > runs_expected`
  - ANTAL KRYDS: `crossings_actual < crossings_expected`
  - OBS. UDEN FOR KONTROLGRÆNSE: `outliers_actual > 0`

## Details

### SPC Table Changes

**Før (run chart):**
| | FORVENTET | FAKTISK |
|---|---|---|
| SERIELÆNGDE (MAKSIMUM) | 8 | 6 |
| ANTAL KRYDS (MINIMUM) | 5 | 7 |
| OBS. UDEN FOR KONTROLGRÆNSE | - | - |

**Efter (run chart):**
| | FORVENTET | FAKTISK |
|---|---|---|
| SERIELÆNGDE (MAKSIMUM) | 8 | 6 |
| ANTAL KRYDS (MINIMUM) | 5 | 7 |

**Før (i-chart med overtrådt regel):**
| | FORVENTET | FAKTISK |
|---|---|---|
| SERIELÆNGDE (MAKSIMUM) | 8 | 10 |
| ANTAL KRYDS (MINIMUM) | 5 | 7 |
| OBS. UDEN FOR KONTROLGRÆNSE | - | - |

**Efter (i-chart med overtrådt regel):**
| | FORVENTET | FAKTISK |
|---|---|---|
| SERIELÆNGDE (MAKSIMUM) | 8 | **[10]** (grå bg) |
| ANTAL KRYDS (MINIMUM) | 5 | 7 |
| OBS. UDEN FOR KONTROLGRÆNSE | 0 | 2 |

### Farve-specifikation

- **Normal celle**: Grå tekst (`#888888`) på hvid baggrund
- **Signal celle**: Hvid tekst (`#ffffff`) på grå baggrund (`#888888`)

## Impact

- Affected specs: pdf-export (MODIFIED)
- Affected code:
  - `R/export_pdf.R` (bfh_extract_spc_stats, bfh_export_pdf)
  - `inst/templates/typst/bfh-template/bfh-template.typ`

## Related

- GitHub Issue: #74
- Relateret: auto-pdf-details (#73)
