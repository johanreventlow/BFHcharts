## ADDED Requirements

### Requirement: Public functions SHALL support language selection via language parameter

Public-facing text-producing functions SHALL accept a `language` parameter selecting the output language, covering `bfh_qic()`, `bfh_generate_analysis()`, and `bfh_generate_details()`. All user-facing strings SHALL be resolved via a central i18n lookup in `inst/i18n/<lang>.yaml`.

**Rationale:**
- Hardcoded Danish strings block international use
- Translation lookup decouples rendering logic from locale
- YAML catalog enables non-developers to contribute translations

**Parameter:**
- `language` — character scalar, one of `"da"` (default) or `"en"`
- Invalid values SHALL raise an error
- Missing keys in target language SHALL fall back to Danish with a single warning per session

#### Scenario: Default language preserves Danish output

**Given** `bfh_generate_analysis(result)` is called without `language`
**When** the function executes
**Then** output text SHALL be in Danish (backward-compatible)

```r
analysis <- bfh_generate_analysis(result)
expect_match(analysis, "[æøåÆØÅ]|niveau|stabil")
```

#### Scenario: English language returns English strings

**Given** `language = "en"` is passed
**When** the function executes
**Then** output SHALL resolve from `inst/i18n/en.yaml`

```r
analysis <- bfh_generate_analysis(result, language = "en")
expect_match(analysis, "level|stable|process")
expect_false(grepl("[æøåÆØÅ]", analysis))
```

#### Scenario: Unknown language rejected

**Given** `language = "xx"`
**When** the function validates input
**Then** it SHALL raise an informative error listing supported languages

```r
expect_error(
  bfh_generate_analysis(result, language = "xx"),
  "da|en"
)
```

#### Scenario: Missing translation falls back to Danish

**Given** a key exists in `da.yaml` but not in `en.yaml`
**When** the function resolves the key with `language = "en"`
**Then** it SHALL return the Danish string
**And** SHALL emit a single warning per session for that key
