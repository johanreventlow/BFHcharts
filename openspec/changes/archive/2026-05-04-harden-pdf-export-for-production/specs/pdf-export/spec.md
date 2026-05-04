## ADDED Requirements

### Requirement: `restrict_template` SHALL default to TRUE

`bfh_export_pdf(restrict_template)` SHALL default to `TRUE`. Callers
needing custom Typst templates via `template_path` SHALL explicitly
opt-in by passing `restrict_template = FALSE`.

**Rationale:**
- Custom Typst templates are compiled by the Typst binary with full
  filesystem and network access (equivalent to `source()`).
- A configuration pipeline forwarding user-controlled input to
  `template_path` (e.g. Shiny `input$template`, REST API parameter)
  produces a silent privilege-escalation vector.
- Default-safe matches the established pattern for `inject_assets`
  (which already requires explicit namespace-trusted callbacks).
- Pre-1.0 (0.15.x -> 0.16.0) breaking change is permitted per
  `VERSIONING_POLICY.md` §A; migration is mechanical (one parameter
  add).

#### Scenario: Default rejects template_path without explicit opt-out

- **GIVEN** a `bfh_qic_result` and a custom Typst template path
- **WHEN** `bfh_export_pdf(result, "out.pdf", template_path = "/my/template.typ")`
  is called WITHOUT `restrict_template`
- **THEN** the function SHALL raise an informative error mentioning
  `restrict_template = FALSE` as the explicit opt-out
- **AND** no PDF SHALL be created
- **AND** no Typst compile process SHALL be spawned

```r
expect_error(
  bfh_export_pdf(result, "out.pdf", template_path = "/my/template.typ"),
  "restrict_template"
)
```

#### Scenario: Explicit opt-out allows custom template

- **GIVEN** a `bfh_qic_result` and a custom Typst template path
- **WHEN** `bfh_export_pdf(result, "out.pdf",
  template_path = "/my/template.typ", restrict_template = FALSE)` is called
- **THEN** the function SHALL accept the custom template
- **AND** the PDF SHALL render using the supplied template

```r
expect_no_error(
  bfh_export_pdf(result, "out.pdf",
                 template_path = "/path/to/valid/template.typ",
                 restrict_template = FALSE)
)
```

#### Scenario: Default packaged template unaffected

- **GIVEN** a `bfh_qic_result` and no `template_path`
- **WHEN** `bfh_export_pdf(result, "out.pdf")` is called (default)
- **THEN** the packaged BFH template SHALL render normally
- **AND** the new `restrict_template = TRUE` default SHALL have no
  effect (no `template_path` to restrict)

```r
expect_no_error(
  bfh_export_pdf(result, "out.pdf")
)
```

### Requirement: PDF SHALL render caveat when centerline is user-supplied

The rendered PDF SHALL display a caveat block below the SPC table when `attr(bfh_qic_result$summary, "cl_user_supplied") == TRUE`, indicating that the centerline was manually specified and Anhoej signals were computed against the user-supplied centerline rather than the data-estimated process mean.

**Rationale:**
- The R-side warning (at `R/bfh_qic.R:674-682`) surfaces to interactive
  users only; clinical PDF readers never see R warnings.
- Clinicians correctly assume the SPC table reflects data-driven
  analysis. Without the caveat, they may misattribute Anhoej signals
  as clinically meaningful when they are artifacts of an arbitrary
  user-set centerline.
- Caveat-text is i18n-able via `inst/i18n/*.yaml`. Default Danish:
  `"Centerlinje fastsat manuelt -- Anhoej-signal beregnet mod denne,
  ikke data-estimeret middelvaerdi"`. English when `language = "en"`:
  `"Centerline manually specified -- Anhoej signal computed against
  user-supplied centerline, not data-estimated process mean"`.
- The R-side warning is RETAINED -- the PDF caveat is the SECOND
  surface, not a replacement.

The caveat block SHALL be visually distinguished (italic, smaller font,
grey colour) to match existing data-definition styling and SHALL be
positioned directly below the SPC statistics table.

#### Scenario: PDF with user-supplied cl renders caveat

- **GIVEN** `result <- bfh_qic(data, x, y, chart_type = "i", cl = 50)`
- **WHEN** `bfh_export_pdf(result, "out.pdf")` is called
- **THEN** the rendered PDF SHALL contain caveat text matching the
  i18n key `cl_user_supplied_caveat`
- **AND** the caveat SHALL appear below the SPC statistics table
- **AND** in Danish when `language = "da"` (default)

```r
result <- bfh_qic(data, x, y, chart_type = "i", cl = 50)
out <- tempfile(fileext = ".pdf")
bfh_export_pdf(result, out)
text <- pdftools::pdf_text(out)
expect_match(paste(text, collapse = "\n"), "fastsat manuelt")
```

#### Scenario: PDF without user-supplied cl does NOT render caveat

- **GIVEN** `result <- bfh_qic(data, x, y, chart_type = "i")` (no `cl`)
- **WHEN** `bfh_export_pdf(result, "out.pdf")` is called
- **THEN** the rendered PDF SHALL NOT contain caveat text
- **AND** the SPC table footer SHALL render unchanged from prior
  versions

```r
result <- bfh_qic(data, x, y, chart_type = "i")
out <- tempfile(fileext = ".pdf")
bfh_export_pdf(result, out)
text <- pdftools::pdf_text(out)
expect_no_match(paste(text, collapse = "\n"), "fastsat manuelt")
```

#### Scenario: PDF caveat renders in English when language = "en"

- **GIVEN** `result <- bfh_qic(data, x, y, chart_type = "i", cl = 50, language = "en")`
- **WHEN** `bfh_export_pdf(result, "out.pdf")` is called
- **THEN** the rendered PDF SHALL contain English caveat text
  ("Centerline manually specified ...")
- **AND** SHALL NOT contain Danish caveat text

```r
result <- bfh_qic(data, x, y, chart_type = "i", cl = 50, language = "en")
out <- tempfile(fileext = ".pdf")
bfh_export_pdf(result, out)
text <- pdftools::pdf_text(out)
expect_match(paste(text, collapse = "\n"), "manually specified")
expect_no_match(paste(text, collapse = "\n"), "fastsat manuelt")
```
