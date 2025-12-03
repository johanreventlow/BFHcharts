# OpenSpec Proposal: Fjern Bundled Mari Fonts

## Summary

Fjern de bundlede Mari font-filer fra pakken da de er beskyttet af copyright og ikke kan distribueres. Opdater Typst-skabelonen til at bruge font-fallback så interne brugere (med Mari installeret) får Mari, mens eksterne brugere automatisk får Roboto/Arial.

## Why

Mari-fonten er Region Hovedstadens hospital-branding font og er beskyttet af copyright. Den må ikke distribueres med open source pakker. Pt. indeholder pakken 5.1 MB font-filer som:

1. **Juridisk problem**: Copyright-beskyttede fonts må ikke redistribueres
2. **Oppustet pakkestørrelse**: 5.1 MB fonts er ~80% af pakkens størrelse
3. **Unødvendigt for interne brugere**: BFH-medarbejdere har allerede Mari installeret system-wide
4. **Blokerer public release**: Pakken kan ikke publiceres på CRAN eller offentligt GitHub med disse fonts

### Nuværende situation

```
inst/templates/typst/bfh-template/fonts/
├── Mari.otf
├── Mari Bold.otf
├── Mari Book.otf
├── Mari Heavy.otf
├── Mari Light.otf
├── Mari Poster.otf
├── MariOffice.ttf
├── MariOffice-Bold.ttf
├── MariOffice-Book.ttf
├── MariOffice-Heavy.ttf
├── MariOffice-Light.ttf
└── MariOffice-Poster.ttf

Total: 5.1 MB (12 font-filer)
```

### Typst template font-brug (bfh-template.typ)

```typst
// Linje 63
set text(font: "Mari", lang: "da")

// Linje 97-98
text(rgb("ffffff"), font: "Mari", size: 55pt)

// Linje 177
set text(font: "Mari", lang: "da")
```

## How

### Løsning: Font Fallback Chain

Typst understøtter font-fallback lister. Hvis første font ikke findes, bruges næste:

```typst
set text(
  font: ("Mari", "Roboto", "Arial", "Helvetica", "sans-serif"),
  lang: "da"
)
```

**Resultat:**
- **Interne brugere** (Mari installeret): PDF bruger Mari font
- **Eksterne brugere** (uden Mari): PDF bruger Roboto → Arial → Helvetica → sans-serif

### Implementeringsskridt

1. **Fjern fonts-mappen** fra `inst/templates/typst/bfh-template/`
2. **Opdater bfh-template.typ** med font-fallback chain på 3 steder
3. **Opdater .gitignore** til at ekskludere fonts-mappen
4. **Opdater dokumentation** med font-krav for fuld branding
5. **Test** PDF-generering med og uden Mari installeret

## Requirements

### REQ-1: Font fallback chain i Typst template

Template SKAL bruge font-fallback kæde:
```typst
font: ("Mari", "Roboto", "Arial", "Helvetica", "sans-serif")
```

**Acceptance criteria:**
- PDF genereres uden fejl uanset hvilke fonts der er installeret
- Interne brugere med Mari ser hospital-branding
- Eksterne brugere får læselig fallback-font

### REQ-2: Fonts-mappe fjernet fra pakken

**Acceptance criteria:**
- `inst/templates/typst/bfh-template/fonts/` eksisterer ikke
- Pakkestørrelse reduceret med ~5 MB
- `devtools::check()` passerer uden font-relaterede fejl

### REQ-3: Dokumentation opdateret

**Acceptance criteria:**
- README/vignette forklarer font-krav for fuld branding
- Instruktioner til installation af Mari for interne brugere
- Forklaring af fallback-adfærd for eksterne brugere

## Non-Functional Requirements

### NFR-1: Bagudkompatibilitet

- Eksisterende PDF-generering skal fortsat virke
- Ingen breaking changes til API
- Interne brugere ser ingen forskel (Mari allerede installeret)

### NFR-2: Pakkestørrelse

- Mål: Reducer pakkestørrelse med mindst 4 MB
- Målt med: `devtools::build()` → filstørrelse

## Out of Scope

- Distribution af alternative open source fonts med pakken
- Automatisk font-installation
- Font-embedding i PDF (ville kræve licensaftale)

## Risks

| Risk | Sandsynlighed | Impact | Mitigation |
|------|---------------|--------|------------|
| Eksterne brugere får uventet font | Medium | Lav | Dokumentér font-krav tydeligt |
| Typst font-fallback virker ikke | Lav | Høj | Test på maskine uden Mari |
| Interne brugere mangler Mari | Meget lav | Lav | IT installer automatisk |

## Testing Strategy

1. **Lokal test (med Mari)**: Verificer PDF bruger Mari
2. **Docker test (uden Mari)**: Verificer fallback til Roboto/Arial
3. **devtools::check()**: Ingen nye warnings
4. **Visual inspection**: PDF ser acceptabel ud med begge fonts
