## MODIFIED Requirements

### Requirement: Quarto binary discovery SHALL validate override paths

`find_quarto()` SHALL validate any path supplied via `getOption("bfhcharts.quarto_path")` or `Sys.getenv("QUARTO_PATH")` before invoking `system2()` or caching the result. Validation SHALL include:
- `.check_metachars()` (no shell metacharacters)
- Path-traversal containment via `validate_export_path()`
- Executable-bit verification on Unix/macOS (`file.access(path, mode = 1L)`)

On validation failure, the override SHALL be rejected (with informative error or warning) and discovery SHALL fall back to `Sys.which("quarto")`.

#### Scenario: poisoned option with shell metacharacter is rejected

- **GIVEN** `options(bfhcharts.quarto_path = "/tmp/x;rm -rf /")`
- **WHEN** `find_quarto()` is invoked
- **THEN** the function SHALL reject the override (error or warning naming the metachar issue)
- **AND** the cache SHALL NOT be populated with the invalid path
- **AND** discovery SHALL fall back to PATH

#### Scenario: valid override path is cached

- **GIVEN** `Sys.setenv(QUARTO_PATH = "/usr/local/bin/quarto")` pointing at a real executable
- **WHEN** `find_quarto()` is invoked
- **THEN** the path SHALL be cached and used for subsequent calls

### Requirement: Compile-error output SHALL be uniformly truncated

All Quarto compile-error output exposed through `bfh_compile_typst()` SHALL be truncated to a fixed maximum (500 characters) regardless of which error branch was hit. The truncation logic SHALL live in a single named helper.

#### Scenario: PDF-not-created branch truncates output

- **GIVEN** a Quarto invocation that exits 0 but produces no output PDF
- **WHEN** `bfh_compile_typst()` raises the resulting error
- **THEN** the included compile output SHALL be ≤ 500 characters
- **AND** the truncation SHALL be applied via the same helper as the non-zero-exit branch

### Requirement: Typst string escaping SHALL handle control characters

`escape_typst_string()` SHALL replace `\n`, `\r`, `\t` with a single space and strip NUL bytes before applying the existing `\`, `"`, `<`, `>` escapes. Metadata fields containing CRLF or other control characters SHALL produce valid Typst output.

#### Scenario: metadata with CRLF compiles successfully

- **GIVEN** `metadata = list(department = "Afdeling A\r\nUndergruppe B")`
- **WHEN** `bfh_export_pdf()` is called
- **THEN** the embedded Typst string SHALL be valid (no syntax error)
- **AND** the rendered PDF SHALL contain "Afdeling A Undergruppe B" (or visually equivalent space substitution)

#### Scenario: metadata with NUL byte is sanitized

- **GIVEN** metadata containing `\x00`
- **WHEN** the Typst string is constructed
- **THEN** the NUL byte SHALL be stripped before quoting

### Requirement: system2 SHALL receive raw argv tokens (no shQuote on Unix vector args)

When `system2()` is invoked with `args` as a character vector, individual element values SHALL NOT be wrapped in `shQuote()`. Paths containing spaces SHALL be passed as single argv tokens directly to the called process.

#### Scenario: temp directory with space in path renders successfully

- **GIVEN** a temp directory at `/tmp/with spaces/` produced by `tempfile()` on a system with such a path
- **WHEN** `bfh_compile_typst()` is invoked
- **THEN** Quarto SHALL be able to read the input `.typ` file at that path
- **AND** the output PDF SHALL be created successfully
