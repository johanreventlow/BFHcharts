# remove-vignette-builder

## Why

**Problem:** DESCRIPTION deklarerer `VignetteBuilder: knitr` men ingen vignettes eksisterer i `vignettes/` directory. Dette giver R CMD CHECK WARNING.

**Current situation:**
- DESCRIPTION har `VignetteBuilder: knitr`
- `vignettes/` directory eksisterer ikke eller er tom
- R CMD CHECK genererer: "VignetteBuilder specified but no vignettes found"
- Inkonsistent package configuration

**Impact:**
- R CMD CHECK WARNING (noise i build output)
- Signalerer til brugere at vignettes burde eksistere
- Uklart om vignettes er planlagt eller glemt
- Blokerer clean check output

## What Changes

**Fjern VignetteBuilder fra DESCRIPTION (Quick fix):**

1. **Fjern `VignetteBuilder: knitr` linje**
   - Ingen vignettes eksisterer nu
   - Pakken er til intern brug
   - Fjerner R CMD CHECK warning øjeblikkeligt

2. **Fjern `knitr` og `rmarkdown` fra Suggests (hvis kun brugt til vignettes)**
   - Review om de bruges andre steder
   - Fjern kun hvis ikke nødvendige

**Rationale:**
- Pakken bruges internt på hospitalet
- README og function documentation er tilstrækkelig for nu
- Vignettes kan tilføjes senere ved public release (se #17)
- Quick fix der løser warning med minimal effort

## Impact

**Affected specs:**
- `package-config` (DESCRIPTION requirements)

**Affected code:**
- `DESCRIPTION` - Fjern VignetteBuilder linje

**User-visible changes:**
- ✅ Clean R CMD CHECK output
- ✅ Ingen funktionalitetsændringer

**Breaking changes:**
- ⚠️ Ingen - vignettes eksisterede ikke alligevel

## Alternatives Considered

**Alternative 1: Opret vignettes**
```
vignettes/
├── getting-started.Rmd
├── chart-types.Rmd
├── theming.Rmd
└── advanced-usage.Rmd
```
**Rejected for now because:**
- 8-12 timer effort
- Pakken er til intern brug
- README er tilstrækkelig for nu
- Kan implementeres senere ved public release

**Alternative 2: Opret tom placeholder vignette**
```r
# vignettes/BFHcharts.Rmd
---
title: "Introduction to BFHcharts"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Introduction to BFHcharts}
  %\VignetteEngine{knitr::rmarkdown}
---

Coming soon...
```
**Rejected because:**
- Uprofessionelt med "Coming soon" placeholder
- Giver false promise til brugere
- Fjerner ikke det underliggende problem

**Chosen approach: Fjern VignetteBuilder**
- ✅ 1 minut effort
- ✅ Clean R CMD CHECK
- ✅ Ærlig signalering (ingen vignettes nu)
- ✅ Kan nemt tilføjes tilbage senere

## Related

- GitHub Issue: [#24](https://github.com/johanreventlow/BFHcharts/issues/24)
- Future: Issue #17 (pkgdown website & vignettes for public release)
