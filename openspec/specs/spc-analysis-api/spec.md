# spc-analysis-api Specification

## Purpose
TBD - created by archiving change add-spc-analysis-ai. Update Purpose after archive.
## Requirements
### Requirement: bfh_interpret_spc_signals SHALL generate Danish standard texts for Anhøj signals

The function SHALL detect Anhøj SPC signals and return human-readable Danish descriptions.

**Function Signature:**
```r
bfh_interpret_spc_signals(spc_stats)
```

**Parameters:**
- `spc_stats`: Named list from `bfh_extract_spc_stats()` containing `runs_actual`, `runs_expected`, `crossings_actual`, `crossings_expected`, `outliers_actual`

**Returns:** Character vector with Danish interpretations

#### Scenario: Serielængde signal detected

**Given** a process with `runs_actual = 9` and `runs_expected = 7`
**When** `bfh_interpret_spc_signals()` is called
**Then** the output SHALL contain "Serielængde-signal"
**And** the output SHALL contain the actual (9) and expected (7) values

```r
stats <- list(runs_actual = 9, runs_expected = 7)
result <- bfh_interpret_spc_signals(stats)
expect_match(result[1], "Serielængde-signal")
expect_match(result[1], "9")
expect_match(result[1], "7")
```

#### Scenario: Krydsnings signal detected

**Given** a process with `crossings_actual = 3` and `crossings_expected = 5`
**When** `bfh_interpret_spc_signals()` is called
**Then** the output SHALL contain "Krydsnings-signal"

```r
stats <- list(crossings_actual = 3, crossings_expected = 5)
result <- bfh_interpret_spc_signals(stats)
expect_match(result[1], "Krydsnings-signal")
```

#### Scenario: Normal stable process

**Given** a process with normal run and crossing counts
**When** `bfh_interpret_spc_signals()` is called
**Then** the output SHALL NOT contain "signal"

```r
stats <- list(runs_actual = 5, runs_expected = 7,
              crossings_actual = 8, crossings_expected = 5)
result <- bfh_interpret_spc_signals(stats)
expect_false(any(grepl("signal", result, ignore.case = TRUE)))
```

---

### Requirement: bfh_build_analysis_context SHALL collect complete context from bfh_qic_result

The function SHALL extract all relevant metadata from a `bfh_qic_result` object for analysis generation.

**Function Signature:**
```r
bfh_build_analysis_context(x, metadata = list())
```

**Parameters:**
- `x`: `bfh_qic_result` object (required)
- `metadata`: Optional list with `data_definition`, `target`, `hospital`, `department`

**Returns:** Named list with complete context

#### Scenario: Context built from bfh_qic_result

**Given** a valid `bfh_qic_result` object
**When** `bfh_build_analysis_context()` is called
**Then** the returned list SHALL contain: `chart_title`, `chart_type`, `n_points`, `spc_stats`, `signal_interpretations`, `has_signals`

```r
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
ctx <- bfh_build_analysis_context(result)
expect_true("chart_title" %in% names(ctx))
expect_true("spc_stats" %in% names(ctx))
expect_true("signal_interpretations" %in% names(ctx))
expect_true("has_signals" %in% names(ctx))
```

#### Scenario: Invalid input rejected

**Given** a non-bfh_qic_result object
**When** `bfh_build_analysis_context()` is called
**Then** it SHALL throw an error mentioning "bfh_qic_result"

```r
expect_error(bfh_build_analysis_context(data.frame()), "bfh_qic_result")
```

---

### Requirement: bfh_generate_analysis SHALL produce analysis with graceful fallback

The function SHALL generate analysis text using AI when available, with automatic fallback to standard texts.

**Function Signature:**
```r
bfh_generate_analysis(x, metadata = list(), use_ai = NULL, max_chars = 350)
```

**Parameters:**
- `x`: `bfh_qic_result` object (required)
- `metadata`: Optional context list
- `use_ai`: Logical; NULL = auto-detect BFHllm
- `max_chars`: Maximum output length (default 350)

**Returns:** Character string with analysis text

#### Scenario: Fallback when AI disabled

**Given** a valid `bfh_qic_result`
**When** `bfh_generate_analysis()` is called with `use_ai = FALSE`
**Then** it SHALL return non-empty Danish standard text

```r
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
analysis <- bfh_generate_analysis(result, use_ai = FALSE)
expect_type(analysis, "character")
expect_gt(nchar(analysis), 0)
```

#### Scenario: Graceful fallback on AI error

**Given** BFHllm is installed but AI call fails
**When** `bfh_generate_analysis()` is called with `use_ai = TRUE`
**Then** it SHALL return standard text
**And** it SHOULD emit a warning

```r
# Simulated by mocking BFHllm::bfhllm_spc_suggestion to error
result <- bfh_qic(test_data, x = date, y = value, chart_type = "i")
expect_warning(
  analysis <- bfh_generate_analysis(result, use_ai = TRUE),
  "standardtekster"
)
expect_gt(nchar(analysis), 0)
```

---

