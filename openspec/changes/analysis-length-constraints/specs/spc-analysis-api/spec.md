## MODIFIED Requirements

### Requirement: bfh_generate_analysis SHALL support text length constraints

The `bfh_generate_analysis()` function SHALL accept `min_chars` and `max_chars` parameters to control the length of generated analysis text.

**MODIFICATION:** Added `min_chars` parameter and updated `max_chars` default value to ensure consistent analysis text length.

**Parameters:**
- `min_chars`: Minimum number of characters for the analysis (default: 300)
- `max_chars`: Maximum number of characters for the analysis (default: 400)

#### Scenario: Generate analysis with default length constraints

**Given** a valid `bfh_qic_result` object
**When** `bfh_generate_analysis()` is called without explicit length parameters
**Then** the analysis text SHALL be at least 300 characters
**And** the analysis text SHALL be at most 400 characters

```r
result <- bfh_qic(data, x = date, y = value, chart_type = "i")
analysis <- bfh_generate_analysis(result)
# Analysis length: 300-400 characters
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

---
