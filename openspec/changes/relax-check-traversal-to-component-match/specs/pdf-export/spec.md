## MODIFIED Requirements

### Requirement: Export paths SHALL be validated via centralized helper

All export entry points SHALL validate user-supplied output paths via a single canonical helper `validate_export_path()` in `R/utils_path_policy.R`, covering `bfh_export_pdf()`, `bfh_export_png()`, and internal Typst helpers.

**Rationale:**
- Single source of truth prevents policy drift between formats
- Consistent security posture across export surfaces
- Central place to tighten rules in response to future threats

**The helper SHALL reject:**
- Paths where any path-separator-delimited component equals exactly `..` (path traversal)
- Shell metacharacters: `;`, `|`, `&`, backtick, `$`, `(`, `)`, `{`, `}`, `<`, `>`, newline, carriage return
- Extensions not in the format-specific whitelist
- Symlinks that resolve outside the configured allowlist root (when root is configured)

**The helper SHALL NOT reject:**
- Filenames containing `..` as part of a longer string (e.g., `report..v2.pdf`, `..hidden.pdf`, `analyse..final.pdf`) — these are legitimate filename patterns
- Paths with spaces, underscores, dashes, or unicode characters (already accepted)

**The helper SHALL return:**
- A normalized absolute path on success (when `normalize = TRUE`)
- An informative error (with class `bfhcharts_path_policy_error`) on rejection

#### Scenario: Path traversal rejected at component level

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

#### Scenario: Embedded subdirectory traversal rejected

**Given** a user supplies `output/../secret.pdf`
**When** validation runs
**Then** the helper SHALL reject the path

```r
expect_error(
  bfh_export_pdf(result, "output/../secret.pdf"),
  "path|traversal"
)
```

#### Scenario: Filenames containing double-dot substring accepted

**Given** a user supplies `report..v2.pdf` (component is the whole filename, not `..`)
**When** validation runs
**Then** the helper SHALL accept the path
**And** export SHALL proceed normally

```r
expect_no_error(
  bfh_export_pdf(result, file.path(tempdir(), "report..v2.pdf"))
)
```

#### Scenario: Dotfile prefix accepted

**Given** a user supplies `..hidden.pdf` as filename (single component, not traversal)
**When** validation runs
**Then** the helper SHALL accept the path

```r
expect_no_error(
  bfh_export_pdf(result, file.path(tempdir(), "..hidden.pdf"))
)
```

#### Scenario: Shell metacharacters rejected

**Given** a user supplies a path containing shell metacharacters
**When** validation runs
**Then** the helper SHALL reject the path regardless of file extension

```r
expect_error(
  bfh_export_pdf(result, "output;rm -rf /.pdf"),
  "invalid|character|disallowed"
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
**When** validation succeeds with normalize = TRUE
**Then** the helper SHALL return an absolute, normalized path

```r
normalized <- validate_export_path("./out/./chart.pdf", extension = "pdf", normalize = TRUE)
expect_true(startsWith(normalized, "/"))
expect_false(grepl("/./", normalized, fixed = TRUE))
```

#### Scenario: Cross-platform separator handling

**Given** a Windows-style path `..\\evil.pdf`
**When** validation runs
**Then** the helper SHALL recognize `..` as a path component
**And** SHALL reject the path
