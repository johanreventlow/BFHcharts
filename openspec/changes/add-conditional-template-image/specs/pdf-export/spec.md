## ADDED Requirements

### Requirement: Typst template SHALL render conditionally on logo presence

The `bfh-diagram` Typst template SHALL accept a `logo_path` parameter
(default `none`) and SHALL render the foreground hospital logo only
when `logo_path` is supplied with a non-`none` value.

**Rationale:**
- Mirrors the font-fallback graceful-degradation contract: branding
  assets injected by companion packages take precedence; absence of
  assets does not block PDF rendering.
- `bfh_export_pdf()` succeeds out-of-the-box on a clean install
  without requiring `inject_assets` callback or
  `BFHchartsAssets` companion package.
- Layout calibration of header bar + title block is unchanged
  (foreground `place()` slot uses fixed offsets, not relative-to-image
  positioning).

#### Scenario: PDF compiles without logo when no companion assets present

- **GIVEN** a clean BFHcharts install without `BFHchartsAssets`
  companion package
- **AND** no `metadata$logo_path` is supplied
- **AND** no `inject_assets` callback creates `images/` subdirectory
- **WHEN** `bfh_export_pdf(result, "out.pdf")` is called
- **THEN** the Typst compile SHALL succeed (no file-not-found error)
- **AND** the PDF SHALL render with the calibrated header bar + title
- **AND** the foreground logo slot SHALL be empty (no broken-image
  marker)

```r
result <- bfh_qic(test_data, x = month, y = value, chart_type = "i")
bfh_export_pdf(result, "out.pdf")
# PDF compiles successfully; no logo visible
```

#### Scenario: PDF renders with logo when companion injects asset

- **GIVEN** an `inject_assets` callback that writes
  `<staged-template>/images/Hospital_Maerke_RGB_A1_str.png`
- **AND** no explicit `metadata$logo_path` is supplied
- **WHEN** `bfh_export_pdf(result, "out.pdf", inject_assets = MyAssets::inject_logo)`
  is called
- **THEN** R-side auto-detect SHALL discover the staged logo file
- **AND** R-side SHALL populate `metadata$logo_path` automatically
- **AND** the PDF SHALL render with the hospital logo at the
  calibrated foreground position

```r
result <- bfh_qic(test_data, x = month, y = value, chart_type = "i")
bfh_export_pdf(result, "out.pdf",
               inject_assets = BFHchartsAssets::inject_bfh_assets)
# PDF compiles with hospital logo embedded
```

#### Scenario: PDF renders with explicit logo_path

- **GIVEN** a caller-supplied logo path via metadata
- **WHEN** `bfh_export_pdf(result, "out.pdf", metadata = list(logo_path = "/abs/path/logo.png"))`
  is called
- **THEN** the PDF SHALL render with the supplied image
- **AND** the explicit `logo_path` SHALL override any auto-detected
  staged logo

#### Scenario: Invalid logo_path surfaces clear error

- **GIVEN** a `metadata$logo_path` pointing to a non-existent file
- **WHEN** `bfh_export_pdf(result, "out.pdf", metadata = list(logo_path = "/no/such/file.png"))`
  is called
- **THEN** the Typst compile SHALL fail with the underlying
  file-not-found error surfaced to the caller via the existing
  `bfh_compile_typst()` error reporting
- **AND** the error message SHALL contain enough information to
  identify the missing path

### Requirement: R wrapper SHALL auto-detect packaged logo

`bfh_compile_typst()` SHALL include a helper `.detect_packaged_logo()`
that mirrors the existing `.detect_packaged_fonts()` semantics.

When `metadata$logo_path` is not supplied AND
`<staged-template>/images/Hospital_Maerke_RGB_A1_str.png` exists, the
wrapper SHALL populate `metadata$logo_path` automatically before
emitting the Typst document.

When `metadata$logo_path` IS supplied (non-NULL), the wrapper SHALL
NOT override it (explicit takes precedence over auto-detect).

**Rationale:** Symmetric with `--font-path` auto-detect for fonts.
Companion-package callbacks that write the image file at the standard
staged path get logo rendering "for free" without requiring callers to
thread `logo_path` through their code.
