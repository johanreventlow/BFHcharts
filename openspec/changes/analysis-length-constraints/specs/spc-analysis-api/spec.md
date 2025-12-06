## MODIFIED Requirements

### Requirement: bfh_generate_analysis SHALL support configurable text length constraints

The `bfh_generate_analysis()` function SHALL accept `min_chars` and `max_chars` parameters to control the length of generated analysis text. These parameters SHALL be configurable by the user.

**MODIFICATION:** Added `min_chars` parameter (default: 300) and updated `max_chars` default to 400. Both parameters are user-configurable.

**Parameters:**
- `min_chars`: Minimum number of characters for the analysis (default: 300, configurable)
- `max_chars`: Maximum number of characters for the analysis (default: 400, configurable)

**Validation:**
- `min_chars` must be less than `max_chars`
- Both must be positive integers

#### Scenario: Generate analysis with default length constraints

**Given** a valid `bfh_qic_result` object
**When** `bfh_generate_analysis()` is called without explicit length parameters
**Then** the analysis text SHALL be at least 300 characters
**And** the analysis text SHALL be at most 400 characters

```r
result <- bfh_qic(data, x = date, y = value, chart_type = "i")
analysis <- bfh_generate_analysis(result)
# Analysis length: 300-400 characters (defaults)
```

#### Scenario: Generate analysis with custom length constraints

**Given** a valid `bfh_qic_result` object
**When** `bfh_generate_analysis()` is called with custom `min_chars` and `max_chars`
**Then** the analysis text SHALL respect the specified constraints

```r
result <- bfh_qic(data, x = date, y = value, chart_type = "i")
analysis <- bfh_generate_analysis(result, min_chars = 200, max_chars = 500)
# Analysis length: 200-500 characters
```

#### Scenario: Configure length constraints via bfh_export_pdf

**Given** a valid `bfh_qic_result` object
**When** `bfh_export_pdf()` is called with `auto_analysis = TRUE` and custom length parameters
**Then** the generated analysis SHALL respect the specified constraints

```r
result <- bfh_qic(data, x = date, y = value, chart_type = "i")
bfh_export_pdf(result, "output.pdf",
               auto_analysis = TRUE,
               analysis_min_chars = 250,
               analysis_max_chars = 350)
# Analysis in PDF: 250-350 characters
```

---
