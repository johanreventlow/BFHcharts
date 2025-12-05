## Why

Når brugere eksporterer SPC charts til PDF, skal de manuelt skrive en "details" tekst med periode, gennemsnit og aktuelle værdier. Denne information er allerede tilgængelig i chart data og kan auto-genereres.

Ved at implementere automatisk details-generering:
- Brugeren slipper for at beregne og formatere disse værdier manuelt
- Konsistent format på tværs af alle PDF-eksporter
- Korrekt interval-tilpasning (måned/uge/dag) baseret på data
- Chart-type specifik formatering (p/u-charts viser tæller/nævner, andre kun værdi)

## What Changes

### Ny funktion `bfh_generate_details()`:
- Detekterer interval type via `detect_date_interval()`
- Formaterer periode-range med danske datoer (f.eks. "feb. 2019 – mar. 2022")
- Beregner gennemsnit: tæller/nævner for p/u-charts, kun værdi for andre
- Henter seneste periode data
- Henter centerline værdi med korrekt formatering baseret på y_axis_unit
- Sammensætter med "•" separator

### Opdater `bfh_export_pdf()`:
- Kald `bfh_generate_details()` hvis `metadata$details` er NULL
- Bruger-angivet details har forrang (override)

### Ny helper `format_danish_date_short()`:
- Formaterer dato til kort dansk format (f.eks. "feb. 2019")

## Details Format

```
Periode: [start] – [slut] • Gns. [interval]: [tæller]/[nævner] • Seneste [interval]: [tæller]/[nævner] • Nuværende niveau: [cl_værdi]
```

**Eksempel p-chart:**
```
Periode: feb. 2019 – mar. 2022 • Gns. måned: 58938/97266 • Seneste måned: 60756/88509 • Nuværende niveau: 64,5%
```

**Eksempel i-chart:**
```
Periode: jan. 2023 – dec. 2024 • Gns. måned: 127 • Seneste måned: 143 • Nuværende niveau: 132,5
```

## Impact

- Affected specs: pdf-export (ADDED requirements)
- Affected code:
  - `R/export_pdf.R` (bfh_generate_details, bfh_export_pdf)
  - `R/utils_date_formatting.R` (format_danish_date_short helper)

## Related

- GitHub Issue: #73
- Relateret ændring: centralize-plot-margins (implementeret)
