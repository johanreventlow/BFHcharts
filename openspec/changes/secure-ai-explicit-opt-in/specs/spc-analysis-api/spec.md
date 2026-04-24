## MODIFIED Requirements

### Requirement: bfh_generate_analysis SHALL produce analysis with graceful fallback

The function SHALL generate analysis text using AI **only when explicitly opted in** via `use_ai = TRUE`, with automatic fallback to YAML-based standard texts. When target direction is known (via operator-prefixed `metadata$target`), the fallback text SHALL describe whether the goal is met or not met instead of value-neutral "over/under" wording.

**Function Signature:**
```r
bfh_generate_analysis(x, metadata = list(), use_ai = FALSE,
                      min_chars = 300, max_chars = 375,
                      target_tolerance = 0.05)
```

**Parameters:**
- `x`: `bfh_qic_result` object (required)
- `metadata`: Optional context list; `target` may be numeric or character (supports operator prefixes)
- `use_ai`: Logical; **default `FALSE`**. Must be set explicitly to `TRUE` to enable external AI processing. The function SHALL NOT auto-detect `BFHllm` availability.
- `min_chars` / `max_chars`: Output length bounds
- `target_tolerance`: Fractional tolerance for `at_target` classification when direction is unknown (default 0.05)

**Returns:** Character string with analysis text bounded by `[min_chars, max_chars]` characters.

**Security rationale:** Implicit AI activation risks leaking `qic_data`, metadata, department, and hospital context to `BFHllm` (and any downstream services) without user consent. Default `FALSE` enforces explicit opt-in for external data processing in healthcare contexts.

#### Scenario: Default disables AI without auto-detection

**Given** `BFHllm` is installed on the system
**When** `bfh_generate_analysis(x)` is called without `use_ai` argument
**Then** the function SHALL NOT call `BFHllm::bfhllm_spc_suggestion()`
**And** it SHALL return fallback standard text

```r
# BFHllm present but no explicit opt-in
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
with_mocked_bindings(
  bfhllm_spc_suggestion = function(...) stop("AI called without opt-in"),
  .package = "BFHllm",
  {
    analysis <- bfh_generate_analysis(result)
    expect_type(analysis, "character")
  }
)
```

#### Scenario: Fallback when AI disabled

**Given** a valid `bfh_qic_result`
**When** `bfh_generate_analysis()` is called with `use_ai = FALSE`
**Then** it SHALL return non-empty Danish standard text within the character bounds

```r
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
analysis <- bfh_generate_analysis(result, use_ai = FALSE)
expect_type(analysis, "character")
expect_gte(nchar(analysis), 300)
expect_lte(nchar(analysis), 375)
```

#### Scenario: Explicit opt-in requires BFHllm installed

**Given** `BFHllm` is NOT installed
**When** `bfh_generate_analysis()` is called with `use_ai = TRUE`
**Then** the function SHALL raise an informative error naming the missing package

```r
# Without BFHllm
expect_error(
  bfh_generate_analysis(result, use_ai = TRUE),
  "BFHllm"
)
```

#### Scenario: max_chars is never exceeded

**Given** any valid `bfh_qic_result`
**When** `bfh_generate_analysis()` is called with any `max_chars`
**Then** the returned string SHALL satisfy `nchar(result) <= max_chars`

```r
analysis <- bfh_generate_analysis(result, use_ai = FALSE, max_chars = 250)
expect_lte(nchar(analysis), 250)
```

#### Scenario: Graceful fallback on AI error

**Given** BFHllm is installed but AI call fails
**When** `bfh_generate_analysis()` is called with `use_ai = TRUE`
**Then** it SHALL return standard text
**And** it SHOULD emit a warning

```r
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
expect_warning(
  analysis <- bfh_generate_analysis(result, use_ai = TRUE),
  "standardtekster"
)
expect_gt(nchar(analysis), 0)
```
