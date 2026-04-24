## ADDED Requirements

### Requirement: Export paths SHALL be validated via centralized helper

All export entry points SHALL validate user-supplied output paths via a single canonical helper `validate_export_path()` in `R/utils_path_policy.R`, covering `bfh_export_pdf()`, `bfh_export_png()`, and internal Typst helpers.

**Rationale:**
- Single source of truth prevents policy drift between formats
- Consistent security posture across export surfaces
- Central place to tighten rules in response to future threats

**The helper SHALL reject:**
- Paths containing `..` segments (path traversal)
- Shell metacharacters: `;`, `|`, `&`, backtick, `$`, `(`, `)`, newline
- Extensions not in the format-specific whitelist
- Symlinks that resolve outside the configured allowlist root (when root is configured)

**The helper SHALL return:**
- A normalized absolute path on success
- An informative error (with class `bfhcharts_path_policy_error`) on rejection

#### Scenario: Path traversal rejected

**Given** a user supplies `../../etc/passwd` as output path
**When** any export function validates the path
**Then** it SHALL raise an error mentioning path traversal
**And** no file SHALL be written

```r
expect_error(
  bfh_export_pdf(result, "../../etc/passwd.pdf"),
  "path|traversal"
)
```

#### Scenario: Shell metacharacters rejected

**Given** a user supplies a path containing shell metacharacters
**When** validation runs
**Then** the helper SHALL reject the path regardless of file extension

```r
expect_error(
  bfh_export_pdf(result, "output;rm -rf /.pdf"),
  "invalid|character"
)
```

#### Scenario: Wrong extension for format rejected

**Given** a user calls `bfh_export_pdf()` with path `output.png`
**When** validation runs
**Then** the helper SHALL reject with message naming expected extension

```r
expect_error(
  bfh_export_pdf(result, "output.png"),
  "pdf"
)
```

#### Scenario: Valid path returned normalized

**Given** a legitimate path with `.` segments
**When** validation succeeds
**Then** the helper SHALL return an absolute, normalized path

```r
normalized <- validate_export_path("./out/./chart.pdf", extension = "pdf")
expect_true(startsWith(normalized, "/"))
expect_false(grepl("/./", normalized, fixed = TRUE))
```
