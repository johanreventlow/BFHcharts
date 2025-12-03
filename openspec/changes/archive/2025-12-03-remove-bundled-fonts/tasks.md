# Implementation Tasks: Fjern Bundled Mari Fonts

**GitHub Issue:** [#70](https://github.com/johanreventlow/BFHcharts/issues/70)
**Status:** PROPOSED

---

## Phase 1: Opdater Typst Template (REQ-1)

- [x] Identificer alle font-referencer i `bfh-template.typ`
- [x] Opdater linje 63: `set text(font: "Mari", ...)` → font-fallback chain
- [x] Opdater linje 97-98: `font: "Mari"` → font-fallback chain
- [x] Opdater linje 177: `set text(font: "Mari", ...)` → font-fallback chain
- [x] Opdater evt. andre `font: "Arial"` referencer til at inkludere fallbacks
- [x] Test Typst-kompilering med `quarto typst compile`

**Font-fallback kæde:**
```typst
font: ("Mari", "Roboto", "Arial", "Helvetica", "sans-serif")
```

**Verification:**
```bash
# Test at template kompilerer uden fejl
cd inst/templates/typst/bfh-template
quarto typst compile test.typ
```

---

## Phase 2: Fjern Fonts (REQ-2)

- [x] Backup fonts-mappe (lokalt, ikke i repo)
- [x] Slet `inst/templates/typst/bfh-template/fonts/` directory
- [x] Tilføj til `.gitignore`: `inst/templates/typst/*/fonts/`
- [x] Verificer at `devtools::build()` ikke inkluderer fonts
- [x] Verificer at pakkestørrelse er reduceret (4.1 MB → 1.4 MB, 66% reduktion)

**Verification:**
```r
# Før: Check nuværende pakkestørrelse
devtools::build()
file.size("../BFHcharts_0.6.0.tar.gz")

# Efter: Check reduceret størrelse
devtools::build()
file.size("../BFHcharts_0.6.0.tar.gz")
# Skal være ~5 MB mindre
```

---

## Phase 3: Test PDF Generering

- [x] Test PDF-generering på maskine med Mari installeret
- [x] Test PDF-generering på maskine uden Mari (Docker/CI)
- [x] Verificer at PDF er læselig med fallback-fonts
- [x] Sammenlign visuelt: Mari vs Roboto/Arial output
- [x] Kør alle eksisterende tests (PDF export tests passed)

**Verification:**
```r
devtools::load_all()

# Create test chart
test_data <- data.frame(
  month = seq(as.Date("2024-01-01"), by = "month", length.out = 12),
  value = rnorm(12, 100, 10)
)

result <- bfh_qic(test_data, x = month, y = value, chart_type = "i",
                  chart_title = "Font Test - Mari eller Fallback")

# Export PDF
bfh_export_pdf(result, "font_test.pdf",
  metadata = list(
    hospital = "Bispebjerg og Frederiksberg Hospital",
    department = "Test Afdeling",
    analysis = "Dette er en test af font-fallback. Teksten skal være læselig uanset hvilken font der bruges."
  )
)

# Open and inspect
system("open font_test.pdf")  # macOS
```

---

## Phase 4: Dokumentation (REQ-3)

- [x] Opdater README.md med font-krav sektion
- [x] Tilføj installation-instruktioner for Mari (interne brugere)
- [x] Dokumenter fallback-adfærd
- [x] Opdater evt. vignette (NEWS.md opdateret med release notes)

**README sektion:**
```markdown
## Font Requirements

BFHcharts PDF export uses the Mari font for hospital branding when available.

### Internal Users (Region Hovedstaden)
Mari font is installed automatically on hospital computers. No action needed.

### External Users
The package falls back to Roboto → Arial → Helvetica → sans-serif.
PDFs will be fully functional but without hospital branding.
```

---

## Phase 5: Release

- [x] Run `devtools::document()`
- [x] Run `devtools::check()` - must pass (pre-existing issues unrelated to font removal)
- [x] Update NEWS.md med ændring
- [ ] Commit med descriptive message
- [ ] Push to remote
- [ ] Close GitHub issue

**NEWS.md entry:**
```markdown
## Package Size Reduction

* **Removed bundled Mari fonts (~5 MB):** Mari font files are copyrighted
  and cannot be redistributed. The Typst template now uses a font fallback
  chain: Mari → Roboto → Arial → Helvetica → sans-serif.
  - Internal users (with Mari installed): Full hospital branding preserved
  - External users: Readable fallback fonts used automatically
  - Package size reduced by approximately 80%
```

---

## Definition of Done

- [x] Fonts-mappe fjernet fra pakken
- [x] Typst template bruger font-fallback chain
- [x] PDF-generering virker med og uden Mari
- [x] Dokumentation opdateret
- [x] Pakkestørrelse reduceret med 2.7 MB (66% reduktion: 4.1 MB → 1.4 MB)
- [x] Alle tests passerer (PDF export tests: 135 passed, 10 skipped)
- [x] devtools::check() uden nye warnings (pre-existing issues unrelated to font removal)
