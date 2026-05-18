## ADDED Requirements

### Requirement: Package SHALL export bfh_analyse for structured SPC analysis

The package SHALL export `bfh_analyse(x, metadata, language)` returning a
`bfh_spc_analysis` S3-object as new public API surface.

The exported function SHALL be documented via roxygen with `@export` and
SHALL appear in NAMESPACE. The function signature SHALL be stable across
PATCH-versions; MINOR-versions MAY add optional parameters with defaults.
Removing or renaming the function SHALL require MAJOR version bump
(post-1.0).

**Public surface extension:** The package's previously-listed minimal
public surface — `bfh_qic()`, `bfh_export_pdf()`,
`bfh_extract_spc_stats()`, `bfh_create_export_session()`,
`bfh_generate_analysis()`, `bfh_merge_metadata()` — SHALL be extended to
include `bfh_analyse()`. Semantic specification of `bfh_analyse()`'s
behavior, return-schema, and feature-extraction contract lives in
`spc-analysis-api`.

**Stability contract for downstream consumers:**

- `bfh_analyse(x, metadata, language)`-signatur SHALL accept positional
  + named arguments as documented.
- Return-value SHALL inherit from class `bfh_spc_analysis`.
- `as.list()` SHALL produce JSON-serializable named list.
- `schema_version`-field SHALL follow semver pattern.

#### Scenario: bfh_analyse is exported and callable from package namespace

**Given** the BFHcharts package is loaded via `library(BFHcharts)`
**When** caller invokes `bfh_analyse(result)` with valid `bfh_qic_result`
**Then** the call SHALL succeed without `:::` accessor
**And** the return value SHALL inherit from `bfh_spc_analysis`

```r
library(BFHcharts)
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
analysis <- bfh_analyse(result)
expect_s3_class(analysis, "bfh_spc_analysis")
expect_true("bfh_analyse" %in% getNamespaceExports("BFHcharts"))
```

#### Scenario: bfh_analyse signature stable across patch releases

**Given** a caller written against `bfh_analyse(x, metadata, language)`
**When** the package upgrades within the same MINOR version
**Then** existing positional + named argument-passing SHALL continue to
work without error

```r
# Both calling conventions SHALL remain valid:
analysis1 <- bfh_analyse(result)
analysis2 <- bfh_analyse(result, metadata = list(target = ">= 90%"))
analysis3 <- bfh_analyse(x = result, metadata = list(), language = "da")
```

## MODIFIED Requirements

### Requirement: bfh_generate_analysis SHALL remain exported with stable signature

The `bfh_generate_analysis()` function SHALL remain exported as part of
the package's public API with the existing signature preserved verbatim:

```r
bfh_generate_analysis(
  x,
  metadata = list(),
  use_ai = FALSE,
  data_consent = NULL,
  use_rag = FALSE,
  min_chars = 300,
  max_chars = 375,
  target_tolerance = 0.05,
  language = "da",
  texts_loader = NULL
)
```

The function SHALL continue to return a character vector of length 1
respecting `max_chars`-budget. The internal implementation MAY change
(per `spc-analysis-api` MODIFIED Requirement for the restructure) to
delegate to `bfh_analyse()` + `bfh_render_analysis()`, but the public
contract SHALL be backward-compatible.

`target_tolerance`-deprecation-warning behavior SHALL be preserved.
`data_consent`-validation for `use_ai = TRUE` SHALL be preserved.
AI-egress-audit-event SHALL be preserved.

#### Scenario: Existing biSPCharts caller code continues to work

**Given** biSPCharts code calling
`BFHcharts::bfh_generate_analysis(result, metadata = list(target = ">= 90%"))`
**When** BFHcharts is upgraded to version including this restructure
**Then** the call SHALL succeed without error
**And** SHALL return character of length 1
**And** SHALL respect default max_chars = 375

```r
# biSPCharts-style invocation (simplified):
result <- bfh_qic(data, x = date, y = value, chart_type = "i")
text <- BFHcharts::bfh_generate_analysis(
  result,
  metadata = list(target = ">= 90%", hospital = "BFH")
)
expect_type(text, "character")
expect_length(text, 1)
expect_lte(nchar(text), 375)
```
