## Why

`validate_export_path()` (`R/utils_path_policy.R`) currently rejects output filenames containing parentheses, ampersands, and other shell-metacharacters. Codex code review 2026-04-30 (finding #10) noted this is over-restrictive: `bfh_export_pdf()` invokes Quarto via `system2(quarto_bin, args = c(...))` (vector form), which does not invoke a shell. Argument-vector calls are immune to shell metacharacter injection.

Consequence: legitimate filenames like `rapport (final).pdf`, `Q1 (2026).pdf`, or `kvalitet [draft].pdf` fail with "invalid characters in path" — a false-positive that hospital users encounter regularly.

The path policy correctly differentiates **binary paths** (`SHELL_METACHARS_BINARY`, used to validate the Quarto binary location) from **output paths** but applies the same strict rule. Codex correctly identified that output paths have a different threat model.

## What Changes

- **Differentiate threat models** in `R/utils_path_policy.R`:
  - `SHELL_METACHARS_BINARY` (existing): strict — path becomes argv[0] of `system2()`. Reject `;`, `|`, `&`, `$`, backtick, parens, braces, redirects.
  - `SHELL_METACHARS_OUTPUT_PATH` (new): permissive — path is a value in argv[1+] passed via vector to `system2()`. Reject only characters that break the file system itself: NUL, LF, CR, and characters Quarto/Typst cannot quote in `--output` argument value (none, since system2 vector form passes them as-is).
- **What stays rejected for output paths:**
  - Path traversal (`..` as a component) — security
  - NUL bytes — file system / C library
  - Newline / carriage return — would corrupt error logs and confuses Quarto's output parser
- **What becomes permitted for output paths:**
  - Spaces (already permitted, restated)
  - Parentheses `(`, `)`
  - Square brackets `[`, `]`
  - Curly braces `{`, `}`
  - Ampersand `&`
  - Dollar sign `$`
  - Single quote `'` (escaped at file-system level by R)
- **What stays rejected universally** (binary AND output):
  - `..` traversal
  - NUL, LF, CR
- **Test updates**:
  - `tests/testthat/test-path-policy.R`: add tests for `rapport (final).pdf`, `Q1 [2026].pdf`, etc. — succeed
  - Existing rejection tests for `..` traversal, NUL bytes, newlines: unchanged
  - Binary-path validation tests: unchanged (still strict)

## Impact

**Affected specs:**
- `pdf-export` — MODIFIED requirement: output path policy differentiates from binary path policy

**Affected code:**
- `R/utils_path_policy.R` — split policy into two charsets
- `R/export_pdf.R`, `R/export_png.R`, `R/export_session.R` — verify they call the output-path validator (not the binary-path validator) for output destinations
- `tests/testthat/test-path-policy.R` — extend with parens/bracket/brace cases
- `NEWS.md` — entry under `## Forbedringer`

**Breaking change scope:** None negative. This relaxes a restriction. Files with previously-rejected names succeed; previously-accepted files continue to succeed.

## Cross-repo impact (biSPCharts)

**Verification:**
```bash
# In biSPCharts:
grep -rn "rapport\|filename\|output_path" R/ | head -20
```

**Likely affected:** biSPCharts UI that constructs filenames from user-provided strings (e.g., department name with parens) starts working without the user pre-sanitizing.

**biSPCharts version bump:** PATCH.

**Lower-bound:** `BFHcharts (>= 0.12.0)` (or PATCH 0.11.2 if released standalone).

## Related

- Source: Codex code review 2026-04-30 (finding #10)
- Builds on `2026-04-29-relax-check-traversal-to-component-match` (component-based traversal check)
