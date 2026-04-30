## MODIFIED Requirements

### Requirement: Export-path policy SHALL differentiate output paths from binary paths

The path-validation policy SHALL apply two distinct character sets based on the path's role:

**Binary paths** (path of the executable invoked via `system2()` argv[0], e.g., the Quarto binary):
- Must be ASCII shell-safe even if `system2()` is called with vector args, because some R wrappers internally re-quote the binary
- Reject any of: `;`, `|`, `&`, `$`, backtick (`), `(`, `)`, `{`, `}`, `<`, `>`, NUL, LF, CR
- Reject `..` path traversal
- Existing strict policy unchanged

**Output paths** (paths passed as values in argv[1+] via vector form to `system2()`):
- Reject only:
  - NUL byte (`\x00`)
  - LF (`\n`)
  - CR (`\r`)
  - `..` path traversal (component-based check from `2026-04-29-relax-check-traversal-to-component-match`)
- Permit:
  - Spaces
  - Parentheses `(`, `)`
  - Square brackets `[`, `]`
  - Curly braces `{`, `}`
  - Ampersand `&`
  - Dollar sign `$`
  - Single quote `'`
  - Other Unicode (already permitted)

**Rationale:**
- `system2()` invoked with `args = c(...)` (vector form) bypasses shell expansion, so argv[1+] values are immune to shell metacharacter injection
- Hospital filename conventions routinely include parens/brackets (`rapport (final).pdf`, `Q1 [2026].pdf`) — strict rejection produced false-positive errors that frustrated users
- NUL/LF/CR remain rejected because they corrupt logs and break Quarto's output parser independent of any shell concern
- `..` traversal remains rejected as a security check (file-system access boundary)
- Binary paths remain strict because R's internal handling of argv[0] varies by platform and may re-quote in edge cases

#### Scenario: Output path with parentheses accepted

- **GIVEN** target path `/tmp/rapport (final).pdf`
- **WHEN** `validate_export_path("/tmp/rapport (final).pdf")` is called
- **THEN** the function SHALL return successfully
- **AND** the path SHALL pass through unchanged to `system2()`

#### Scenario: Output path with square brackets accepted

- **GIVEN** target path `/tmp/Q1 [2026].pdf`
- **WHEN** `validate_export_path("/tmp/Q1 [2026].pdf")` is called
- **THEN** the function SHALL return successfully

#### Scenario: Output path with newline still rejected

- **GIVEN** target path containing `\n`
- **WHEN** `validate_export_path(...)` is called
- **THEN** an error SHALL be raised mentioning the unsafe character class

#### Scenario: Output path with NUL byte still rejected

- **GIVEN** target path containing `\x00`
- **WHEN** validation is invoked
- **THEN** an error SHALL be raised

#### Scenario: Path traversal still rejected

- **GIVEN** target path `output/../../../etc/passwd`
- **WHEN** validation is invoked
- **THEN** an error SHALL be raised because `..` is a path component

#### Scenario: Binary path with parentheses still rejected

- **GIVEN** binary path candidate `/usr/local/bin/quarto (test)`
- **WHEN** the binary-path validator is invoked (e.g., via Quarto discovery)
- **THEN** an error SHALL be raised — binary policy remains strict
