# BFHcharts 0.8.3

## Nye features

* **Batch eksport-session:** Ny funktion `bfh_create_export_session()` opretter
  en genanvendelig eksport-session der kopierer Typst-template-assets én gang og
  deler dem på tværs af multiple `bfh_export_pdf()`-kald. I batch-workflows
  (N eksporter fra løkke) eliminerer dette den rekursive template-copy der
  dominerer I/O-cost. Brug: `session <- bfh_create_export_session()`,
  send `batch_session = session` til hvert `bfh_export_pdf()`-kald, og luk med
  `close(session)`. `inject_assets`- og `font_path`-argumenter overføres til
  session-konstruktøren i stedet for til individuelle kald
  (#reuse-typst-template-assets).

## Interne ændringer

* **Cache-nøgle reproducerbarhed:** Font-cache i `utils_add_right_labels_marquee.R`
  nøglede kun på device-type — ikke på fontfamily. Kald som
  `.resolve_font_family("Arial")` og `.resolve_font_family("Helvetica")` på
  samme device delte cache-entry (første vinder). Nøgle er nu
  `dev_type + fontfamily` for at forhindre stale cache ved fontskift.
  Ny intern helper `bfh_reset_caches()` tømmer alle package-level caches —
  bruges automatisk i test-setup via `helper-cache.R`
  (#cache-keying-and-reset).

## Sikkerhed

* **AST-baseret markdown → Typst parser:** `markdown_to_typst()` bruger nu
  CommonMark AST-parsing (`commonmark` + `xml2`) i stedet for regex-baseret
  konvertering. Alle Typst markup-tegn (`#`, `$`, `@`, `_`, `*`, `[`, `]`,
  `<`, `>`, `` ` ``, `~`, `^`, `\`) escapes i plain text-noder, hvilket
  forhindrer Typst injection via user-supplied strenge (fx AI-analysetekst).
  Understøttede markdown-elementer: bold, italic, inline code, lister,
  linjeskift. **Potentielle outputforskelle:** (1) `\n\n` (dobbelt newline)
  producerer ét Typst-linjeskift i stedet for to — visuelt identisk da
  Typst collapser consecutive linjeskift; (2) markdown-links
  `[tekst](url)` renderer nu som synlig tekst alene (ikke bracket-notation);
  (3) backtick og `*` i plain text escapes — var ikke escaped i den gamle
  regex-parser (#harden-typst-markdown-parser).

* **Centraliseret path policy for eksport-funktioner:** Duplikeret
  sti-valideringslogik i `bfh_export_png()`, `bfh_export_pdf()` og
  `bfh_compile_typst()` er samlet i en ny intern helper
  `validate_export_path()` i `R/utils_path_policy.R`. Alle tre
  call-sites anvender nu den samme komplette metacharacter-blacklist
  (`; | & $ \` ( ) { } < > \n \r`) og det samme path-traversal-check.
  **Adfærdsændringer:** `bfh_export_png()` afviser nu også `<`, `>`,
  `\n` og `\r` i stier (tidligere tilladt); `bfh_export_pdf()` kræver
  nu `.pdf`-extension på output-stien (tidligere ukontrolleret).
  Ingen ændringer i public API-signaturer
  (#central-export-path-policy).

# BFHcharts 0.8.2

## Breaking changes (internal API)

* **`spc_plot_config()`, `viewport_dims()`, `phase_config()` fejler nu
  ved ugyldigt input** i stedet for at udsende en advarsel og returnere
  en coerced/default-værdi. Alle valideringsfejl kaster en condition med
  class `bfhcharts_config_error`. Dette påvirker kun kode der direkte
  kalder disse interne constructors — `bfh_qic()` er upåvirket
  (#harden-config-validation).

## Interne ændringer

* **Testbarhed af Quarto-pipeline:** `bfh_compile_typst()` og
  `quarto_available()` accepterer nu `.system2 = system2` og
  `.quarto_path = NULL` parametre (dependency injection). Produktionskald
  er uændret; tests kan injicere mocks uden live Quarto-installation
  (#inject-quarto-system2).

* **Testsuite stabilisering:** Kanoniske skip-helpers tilføjet til
  `tests/testthat/helper-skips.R`: `skip_if_no_quarto()` og
  `skip_if_no_mari_font()`. Alle render/PDF-tests migreret fra rå
  `skip_if_not(quarto_available(), ...)` til `skip_if_not_render_test()` +
  `skip_if_no_quarto()` — sikrer at `devtools::test()` kører rent uden
  Quarto installeret og uden render-gate sat (#stabilize-default-test-suite).

* Fjernet biSPCharts-specifik kode fra `chart_types.R` (#119):
  `CHART_TYPES_DA`, `CHART_TYPE_DESCRIPTIONS`, `get_qic_chart_type()`,
  `chart_type_requires_denominator()` og `get_chart_description()` var aldrig
  en del af BFHcharts' pipeline og lå ubrugte i pakken. biSPCharts vedligeholder
  egne versioner i `R/config_chart_types.R`. Kun `CHART_TYPES_EN` er bibeholdt
  da den bruges internt til validering af chart-type input.



* **CI: fuld R CMD check med tests.** Fjernede `--no-tests` workaround fra
  `R-CMD-check.yaml` efter at to pre-existing test-failures blev rettet:
  `test-smoke.R:10` brugte udfasede BFHtheme farvenavne
  (`hospital_grey`/`hospital_dark_grey` → `grey`/`dark_grey`);
  `test-export_pdf.R:423` forventede forældet fejlbesked-regex efter
  `bfh_extract_spc_stats()` blev konverteret til S3 generic. CI fanger nu
  nye test-regressioner.

# BFHcharts 0.8.1

## Bug fixes

* Tilføjet `Remotes:` til `DESCRIPTION` for `BFHtheme` og `BFHllm`. Downstream-
  pakker (fx biSPCharts) kunne tidligere ikke installere `BFHcharts` via pak
  uden eksplicit workaround, fordi pak ikke transitivt fandt `BFHtheme`.
  Fra v0.8.1 er transitiv dep-resolution fixet.

# BFHcharts 0.8.0

## Breaking changes

* Y-akse-formatet for `y_axis_unit = "time"` er skiftet fra enkelt-enhed
  (`"30 minutter"`, `"1,5 timer"`, `"2 dage"`) til **komposit-format**
  (`"30m"`, `"1t 30m"`, `"2d 13t"`). Ændringen løser to konkrete problemer:
  (1) Tidligere kunne y-aksen vise 7-cifrede kommatal som `"0,6666667 timer"`
  når brudværdier ikke var hele enheder (issue #138). (2) Det nye format
  er mere kompakt og matcher nu data-punkt labels (centrallinje, target)
  — pilene fra CL/target rammer præcis samme tekst som y-aksen. Samtidig
  placeres ticks på **tids-naturlige intervaller** (1m, 5m, 15m, 30m, 1t,
  2t, 6t, 12t, 1d, 2d, 7d, 30d) via den nye interne `time_breaks()`,
  så ggplot2's default-breaks ikke længere producerer fraktionelle timer
  (#138). Downstream-pakker (biSPCharts m.fl.) kan fjerne workarounds der
  overlay'er deres eget tidsformat oven på plottet.
* `format_y_value()` ignorerer nu `y_range`-parameteren for `time`-enhed;
  komposit-formatet håndterer selv unit-valg via komponentopdeling.
  Parameteren er bibeholdt for bagudkompatibilitet men har ingen effekt.
* `bfh_interpret_spc_signals()` er fjernet. Funktionen producerede parallel
  Anhøj-tekst via hardcoded `sprintf()`-kald, men dens output
  (`context$signal_interpretations`) blev aldrig læst af
  `build_fallback_analysis()` i praksis. Al analysetekst genereres nu via
  YAML-skabeloner i `inst/texts/spc_analysis.yml`. `bfh_build_analysis_context()`
  returnerer ikke længere `signal_interpretations`-feltet. Downstream-kaldere
  bør bruge `bfh_generate_analysis()` for den samlede analysetekst.

## Bug fixes

* Fiks `0,8541667 timer`-bug på y-aksen ved tids-data: `51 min` formateres
  nu korrekt som `"51m"` i stedet for det 7-cifrede kommatal som
  ggplot2's default `scale_y_continuous` producerede ved fractional-hour-
  værdier (#138).
* Overflow-rounding: værdier lige under en unit-grænse rundes nu til
  næste unit i stedet for at producere komponent-overflow. Eksempelvis
  kollapser `59,7 min` til `"1t"` (ikke `"60m"`), og `1439,7 min` til
  `"1d"` (ikke `"23t 60m"`).

# BFHcharts 0.7.2

## Nye features

* `bfh_generate_details()` er nu eksporteret. Funktionen genererer den
  formaterede detail-tekst (periode, gennemsnit, seneste, niveau) som vises
  over SPC-grafen i PDF-eksporter. Tidligere kun tilgængelig internt — nu
  kan downstream-pakker (fx biSPCharts) sætte `metadata$details` selv,
  så preview-veje (via `bfh_create_typst_document()`) matcher
  `bfh_export_pdf()`-vejen.

# BFHcharts 0.7.1

## Bug fixes

* Analyseteksten formulerer nu eksplicit at outlier-tallet kun omfatter
  **seneste observationer**, f.eks. "2 af de seneste observationer ligger
  uden for kontrolgrænserne". Tidligere skrev teksten blot "2 observation(er)
  uden for kontrolgrænserne", hvilket kunne misforstås som totalen i PDF-
  tabellen (der viser total i seneste part). Nu er det tydeligt at analyse-
  tallet kun afspejler nylige outliers (`outliers_recent_count`, seneste 6 obs),
  mens tabellen fortsat viser totalen (`outliers_actual`).
* Opdatering dækker både fallback-tekster i
  `inst/texts/spc_analysis.yml` (`outliers_only`, `runs_outliers`,
  `crossings_outliers`, `all_signals`) og den hardkodede tekst i
  `bfh_interpret_spc_signals()`.

# BFHcharts 0.7.0

## Nye features

* `bfh_extract_spc_stats()` er nu en S3-generic med methods for `data.frame`,
  `bfh_qic_result` og `NULL`. Kald direkte med et `bfh_qic_result`-objekt for
  at få fyldestgørende outlier-tal — tidligere krævede det den interne funktion
  `extract_spc_stats_extended()`, som nedarvede problemer mellem forskellige
  downstream-pakker.

```r
result <- bfh_qic(data, x = date, y = value, chart_type = "i")

# Nyt (anbefalet): fyldestgørende stats inkl. outliers
stats <- bfh_extract_spc_stats(result)

# Gammelt: kun runs/crossings fra summary — bevares for bagudkompatibilitet
stats_summary_only <- bfh_extract_spc_stats(result$summary)
```

## Bug fixes

* **PDF-tabellen under "OBS. UDEN FOR KONTROLGRÆNSE" viser nu det korrekte
  antal outliers.** Tidligere blev `outliers_actual` begrænset til de seneste
  6 observationer, hvilket medførte uoverensstemmelse mellem diagrammet (alle
  blå punkter) og tabellen (kun de nyeste outliers). Tabellen viser nu TOTAL
  antal outliers i seneste part.

* Analyseteksten (`bfh_interpret_spc_signals()`, `bfh_generate_analysis()`)
  nævner fortsat kun outliers indenfor de seneste 6 observationer, så ældre
  outliers ikke beskrives som aktuelle problemer. Denne adfærd er nu
  eksponeret som et separat stats-felt `outliers_recent_count`.

## Interne ændringer

* Den interne funktion `extract_spc_stats_extended()` er fjernet. Al intern
  brug (`bfh_export_pdf`, `bfh_build_analysis_context`) er skiftet til
  `bfh_extract_spc_stats(x)` med S3-dispatch på `bfh_qic_result`.

# BFHcharts 0.6.2

## Forbedringer

* `spc_analysis.yml` har nu short/standard/detailed varianter for alle tekster,
  hvilket giver bedre kontrol over analysetekst-længde (#115)
* `pick_text()` vælger nu automatisk den længste variant der passer inden for
  tegnbudgettet — erstatter trimning med naturligt variantvalg

## Breaking changes

* `bfh_interpret_spc_signals()` er ikke længere eksporteret. Brug
  `BFHcharts:::` for direkte adgang. Funktionen bruges kun internt af
  `bfh_generate_analysis()` (#115)

# BFHcharts 0.6.0

## Package Size Reduction

* **Removed bundled Mari fonts (~2.7 MB):** Mari font files are copyrighted and cannot be redistributed. The Typst template now uses a font fallback chain: `Mari → Roboto → Arial → Helvetica → sans-serif`.
  - **Internal users** (with Mari installed): Full hospital branding preserved - no visible changes
  - **External users**: Readable fallback fonts used automatically
  - **Package size** reduced by 66% (4.1 MB → 1.4 MB)
  - **Legal compliance**: No copyright issues blocking CRAN/public release

## New Features

* **AI-assisted SPC analysis generation:** Automatically generate analysis text for PDF exports with intelligent fallback to Danish standard texts:
  - `bfh_generate_analysis()` - Generates analysis using AI (BFHllm) or standard texts
  - `bfh_interpret_spc_signals()` - Danish standard texts for Anhøj SPC signals (runs, crossings, outliers)
  - `bfh_build_analysis_context()` - Collects context from `bfh_qic_result` for analysis
  - `bfh_export_pdf()` gains `auto_analysis` and `use_ai` parameters for automatic analysis generation
  - Graceful degradation: Falls back to standard texts if AI unavailable or fails
  - BFHllm added as optional dependency (Suggests, not required)
  - Fixes GitHub issue #69

**Example usage:**
```r
# Auto-generate analysis with AI (if BFHllm installed)
bfh_qic(data, x = month, y = infections, chart_type = "i") |>
  bfh_export_pdf("report.pdf",
    metadata = list(
      data_definition = "Antal infektioner pr. 1000 patientdage",
      target = 2.5
    ),
    auto_analysis = TRUE
  )

# Use standard texts only (no AI)
bfh_generate_analysis(result, use_ai = FALSE)
```

---

# BFHcharts 0.5.1

## New Features

* **Rich text support in PDF export:** Title and analysis fields in PDF exports now support markdown-style formatting that is converted to Typst rich text:
  - `**bold text**` → Typst `#strong[bold text]`
  - `*italic text*` → Typst `#emph[italic text]`
  - Newlines (`\n`) → Typst line breaks
  - Restores functionality that was available in SPCify's previous internal export implementation
  - Adds new internal function `markdown_to_typst()` for CommonMark-to-Typst conversion

---

# BFHcharts 0.5.0

## Breaking Changes

* **Removed complex TTL-based caching system (~1,500 LOC):** The grob height cache and panel height cache have been removed to simplify the codebase. These caches were disabled by default and rarely used in production.
  - **Removed:** `.grob_height_cache`, `.panel_height_cache`, and all related configuration functions
  - **Kept:** Simple marquee style cache (~45 LOC) which is always beneficial
  - **Impact:** No performance regression for typical usage (caches were disabled by default)
  - **Benefit:** Reduced code complexity from ~2,700 to ~1,200 lines in label placement utilities
  - Updated `docs/CACHING_SYSTEM.md` to reflect simplified architecture
  - Fixes GitHub issue #42

## Internal Improvements

* Simplified label height measurement - removed `use_cache` parameters from all measurement functions
* Removed global state management complexity (TTL tracking, stats, purge logic)
* Updated documentation to explain caching removal rationale

---

# BFHcharts 0.4.1

## Improvements

* **Contextual percent precision for centerline labels:** Centerline labels on SPC charts now show one decimal place when the centerline is within 5 percentage points of the target value. This provides better precision where it matters (close to goal) while keeping labels clean when far from target.
  - Example: 88.7% shown as "88,7%" when target is 90%, but shown as "63%" when target is 90% (far from target)
  - Uses Danish comma notation for decimal separator
  - Fixes GitHub issue #68

* **Range-aware y-axis precision:** Y-axis ticks for percent charts now show decimals when the axis range spans less than 5 percentage points, preventing repeated or indistinguishable tick labels on narrow ranges.
  - Example: Range 98%-100% shows "98.5%", "99.0%", "99.5%"
  - Wide ranges continue to show whole percentages

---

# BFHcharts 0.4.0

## New Features

* **Public API for SPC utility functions:** Exported `bfh_extract_spc_stats()` and `bfh_merge_metadata()` as public API functions to support downstream packages (like SPCify) without requiring `:::` accessor.
  - `bfh_extract_spc_stats()` extracts SPC statistics (runs, crossings) from qic summary data frames
  - `bfh_merge_metadata()` merges user-provided metadata with default values for PDF generation
  - Both functions include comprehensive parameter validation and documentation
  - Internal versions maintained as deprecated aliases for backward compatibility
  - Enables SPCify to migrate from `BFHcharts:::function()` to `BFHcharts::bfh_function()`
  - Provides API stability guarantees via semantic versioning
  - Fixes GitHub issue #64

---


# BFHcharts 0.3.5

## Performance Improvements

Significant performance optimizations for PDF export functionality, delivering 40-50% faster export times and 75% smaller temporary files.

### High-Impact Optimizations

* **5-10x faster template copying:** Replaced manual file iteration loop with `file.copy(..., recursive = TRUE)` for dramatically faster template directory operations
* **4x faster PNG generation:** Reduced DPI from 300 to 150, resulting in 75% smaller temporary files without visible quality loss in PDF output
* **25x faster Quarto checks:** Implemented session-level caching for `quarto_available()` with ~2ms cache hits vs ~50ms system calls

### Performance Benchmarks

| Metric | Before (v0.3.4) | After (v0.3.5) | Improvement |
|--------|-----------------|----------------|-------------|
| Single PDF export | ~500-800ms | ~300-400ms | **40-50% faster** |
| Temp file size | ~15-25 MB | ~4-6 MB | **75% smaller** |
| Quarto check (cached) | ~50ms | ~2ms | **96% faster** |

### Implementation Details

* Template copy optimization at R/export_pdf.R:490-499
* PNG resolution reduction at R/export_pdf.R:307
* Quarto caching system at R/export_pdf.R:344-386

**Note:** Visual QA confirms 150 DPI provides excellent quality for PDF output. Temporary files are automatically cleaned up after each export.

---

# BFHcharts 0.3.4

## Code Quality and Error Handling

This release improves internal code organization, error handling, and API clarity.

### API Improvements

* **Reduced exported API surface:** Three internal helper functions (`quarto_available()`, `bfh_create_typst_document()`, `bfh_compile_typst()`) are no longer exported to users. They remain accessible via `BFHcharts:::` for advanced use cases. This change simplifies the public API without affecting functionality.

### Error Handling Enhancements

* **Improved error reporting:** File operations (`ggplot2::ggsave()`, `writeLines()`) now wrapped in `tryCatch()` with informative error messages
* **Better compilation failures:** Quarto/Typst compilation errors now report exit codes and output for easier debugging
* **Fail-safe version checking:** Unparseable Quarto version strings now correctly return `FALSE` (fail-safe) instead of `TRUE`
* **Fixed cleanup timing:** Temporary directory cleanup handler now registered before `dir.create()` to ensure cleanup even if directory creation fails

### Dead Code Removal

* Removed unused internal function `escape_typst_path()` and its tests

### Testing

* Added 4 new error handling tests:
  - ggsave failure handling
  - Unparseable Quarto version handling
  - Malformed input structure validation
  - Quarto compilation failure reporting

**Impact:** No breaking changes. Internal API changes only affect advanced users who directly call helper functions with `:::`.

---

# BFHcharts 0.3.3

## Security Hardening

**IMPORTANT:** This release addresses critical security vulnerabilities in PDF export functionality. Healthcare organizations using BFHcharts in production environments should update immediately.

### Critical Path Validation
* **Path traversal prevention:** All file paths now reject `..` directory traversal attempts
* **Shell injection protection:** Path parameters are validated against shell metacharacters (`;`, `|`, `&`, `$`, etc.) before being passed to system commands
* **Template path validation:** Custom Typst template paths undergo strict security checks before file operations

### Input Validation Strengthening
* **Metadata type checking:** All metadata fields now validate type constraints (string or Date for date field)
* **Length limits:** Metadata fields limited to 10,000 characters to prevent DoS attacks
* **Unknown field warnings:** Unknown metadata fields now trigger warnings to catch typos and misuse
* **Symlink resolution:** Template paths are now resolved through `normalizePath()` to prevent TOCTOU attacks

### Defense in Depth
* **Restrictive temp permissions:** Temporary directories created with mode 0700 (owner-only) to protect sensitive healthcare data
* **Ownership verification:** Temp directory ownership validated on Unix systems to prevent directory substitution attacks
* **File copy integrity:** All file copy operations verified with size checks to detect corruption or tampering
* **Path sanitization:** Error messages use `basename()` to avoid exposing sensitive full paths

### Testing
* Added comprehensive security test suite with 20 tests covering:
  - Path traversal rejection
  - Shell metacharacter validation
  - Metadata type and length validation
  - All tests passing with 0 failures

**Compliance:** These changes strengthen BFHcharts for HIPAA/GDPR compliance requirements in healthcare environments.

---

# BFHcharts 0.3.2

## Bug Fixes

* **Fixed chart path handling regression:** `bfh_create_typst_document()` now correctly handles chart images from any location. Charts are copied to the output directory before Typst generation, fixing the regression where only charts in the same directory worked.

* **Fixed Quarto version parsing:** `check_quarto_version()` now correctly parses version strings in formats like "Quarto 1.4.557" (prefixed) and "1.4" (two-part). Previously, prefixed version strings would bypass the version guard.

* **Strengthened template validation:** `bfh_export_pdf()` now properly rejects directories and non-.typ files as `template_path`. Added validation for file copy success with clear error messages.

* **Consistent path escaping:** All user-provided paths in generated Typst content are now properly escaped, including custom template paths and chart filenames with special characters.

## Improvements

* Added comprehensive content verification tests that check for metadata, chart references, and template imports in generated Typst (not just file existence)
* Tests now verify version parsing with prefixed formats and edge cases
* All 63 tests pass (7 skipped without Quarto)

---

# BFHcharts 0.3.1

## Bug Fixes

* **Fixed Windows path handling:** Typst import and image paths are now properly escaped for Windows paths and paths containing spaces. Previously, Windows-style backslashes would cause invalid Typst escape sequences.

* **Fixed date metadata propagation:** User-supplied `metadata$date` is now correctly forwarded to the Typst template. Previously, the PDF always showed today's date from the template, ignoring user-supplied dates.

* **Enhanced Quarto version checking:** `quarto_available()` now verifies that Quarto version is >= 1.4.0 (required for Typst support). Previously, only binary existence was checked, leading to opaque errors with older Quarto versions.

## New Features

* **Custom template support:** Added `template_path` parameter to `bfh_export_pdf()` allowing users to specify custom Typst template files instead of using the packaged BFH template.

## Improvements

* Added comprehensive unit tests for path escaping, version checking, and metadata propagation
* Improved error messages for Quarto version requirements

---

# BFHcharts 0.3.0

## Breaking Changes

* **Return type changed:** `bfh_qic()` now returns a `bfh_qic_result` S3 object instead of a ggplot object
  - **Rationale:** Enables pipe-compatible export workflows (`bfh_qic() |> bfh_export_pdf()`) and preserves SPC statistics for PDF metadata
  - **Migration:** Access plot with `result$plot` - see Migration Guide below
  - Print method maintains backwards-compatible console display (plot still shows when printing result)

* **Deprecated parameter:** `print.summary` parameter is deprecated
  - Summary is now always included in `bfh_qic_result$summary`
  - Using `print.summary = TRUE` will trigger a deprecation warning but still works (legacy behavior)
  - This parameter will be removed in a future version

## New Features

### Export Functionality

* **PNG Export:** `bfh_export_png()` - Export charts to PNG with configurable dimensions
  - MM-based dimensions (Danish/European standard)
  - Configurable DPI resolution (96-600)
  - Pipe-compatible workflow
  - Title rendered in PNG image

* **PDF Export:** `bfh_export_pdf()` - Export charts to PDF via Typst templates
  - Hospital-branded PDF reports with BFH styling
  - SPC statistics table (runs, crossings, outliers)
  - Customizable metadata (department, analysis, data definition)
  - Title in PDF template (not in chart image)
  - **Requires:** Quarto CLI (>= 1.4.0)

* **Low-level Functions:**
  - `bfh_create_typst_document()` - Generate Typst documents
  - `bfh_compile_typst()` - Compile Typst to PDF
  - `quarto_available()` - Check Quarto CLI availability

### S3 Class System

* **New S3 class:** `bfh_qic_result`
  - Components: `$plot`, `$summary`, `$qic_data`, `$config`
  - Print method: Displays plot for backwards compatibility
  - Plot method: Extracts and displays ggplot
  - Helper functions: `is_bfh_qic_result()`, `get_plot()`

### Typst Templates

* **Hospital branding templates** included in `inst/templates/typst/`
  - BFH-diagram2 template for A4 landscape reports
  - Mari and Arial fonts bundled
  - Hospital logos and branding assets

## Migration Guide (0.2.0 → 0.3.0)

### Basic Usage (Plot Display)

If you only display plots in console/viewer, no changes needed:

```r
# Works exactly the same in 0.3.0
bfh_qic(data, x = date, y = value, chart_type = "i")
```

### Accessing the ggplot Object

If you need to customize the plot with ggplot2 layers:

```r
# Before (0.2.0):
plot <- bfh_qic(data, x = date, y = value, chart_type = "i")
plot + labs(caption = "Source: EPJ")

# After (0.3.0):
result <- bfh_qic(data, x = date, y = value, chart_type = "i")
result$plot + labs(caption = "Source: EPJ")
```

### Getting Summary Statistics

```r
# Before (0.2.0):
result <- bfh_qic(data, x, y, chart_type = "i", print.summary = TRUE)
summary_stats <- result$summary

# After (0.3.0) - Recommended:
result <- bfh_qic(data, x, y, chart_type = "i")
summary_stats <- result$summary  # Always available

# After (0.3.0) - Legacy (with deprecation warning):
result <- bfh_qic(data, x, y, chart_type = "i", print.summary = TRUE)
summary_stats <- result$summary  # Still works but warns
```

### Using return.data Parameter

```r
# Backwards compatible - no changes needed
qic_data <- bfh_qic(data, x, y, chart_type = "i", return.data = TRUE)
```

### New Export Workflows

```r
# PNG export
bfh_qic(data, x, y, chart_type = "i", chart_title = "Infections") |>
  bfh_export_png("infections.png", width_mm = 200, height_mm = 120, dpi = 300)

# PDF export (requires Quarto CLI)
bfh_qic(data, x, y, chart_type = "i", chart_title = "Infections") |>
  bfh_export_pdf(
    "infections_report.pdf",
    metadata = list(
      hospital = "BFH",
      department = "Kvalitetsafdeling",
      analysis = "Signifikant fald observeret",
      data_definition = "Antal infektioner per måned"
    )
  )
```

## System Requirements

* **New dependency:** Quarto CLI (>= 1.4.0) for PDF export
  - Install from: https://quarto.org
  - Only required for PDF export; PNG export works without Quarto
  - Check availability with `BFHcharts::quarto_available()`

## Documentation

* Added comprehensive README examples for export workflows
* Added Typst template documentation in `inst/templates/typst/README.md`
* Updated function documentation for new S3 class

---

# BFHcharts 0.2.0

## Breaking Changes

* **Function renamed:** `create_spc_chart()` has been renamed to `bfh_qic()`
  - **Rationale:** Shorter, more memorable name (7 vs 17 characters) with clear BFH branding and connection to qicharts2
  - **Migration:** Simple find-and-replace - function signature is unchanged (drop-in replacement)
  - All parameters, defaults, and behavior remain identical

## Migration Guide

Update your code by replacing `create_spc_chart` with `bfh_qic`:

```r
# Before (0.1.0):
plot <- create_spc_chart(
  data = my_data,
  x = date,
  y = value,
  chart_type = "i"
)

# After (0.2.0):
plot <- bfh_qic(
  data = my_data,
  x = date,
  y = value,
  chart_type = "i"
)
```

No other changes required - all parameters work exactly the same.

# BFHcharts 0.1.0

* Initial release
* SPC chart visualization with BFH branding
* Support for multiple chart types (run, i, p, c, u, etc.)
* Intelligent label placement system
* Responsive typography
