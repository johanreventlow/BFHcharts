## 1. Charset split

- [x] 1.1 In `R/utils_path_policy.R`, retain `SHELL_METACHARS_BINARY` (no change)
- [x] 1.2 Define `SHELL_METACHARS_OUTPUT_PATH` containing only NUL (\\x00), LF (\\x0A), CR (\\x0D)
- [x] 1.3 Add internal predicate `.has_output_path_unsafe_chars(path)` returning TRUE if any unsafe byte present
- [x] 1.4 Audit `validate_export_path()` to use the output-path charset (not binary)
- [x] 1.5 Audit binary validators (Quarto path discovery) still use binary charset

## 2. Path-traversal check

- [x] 2.1 Confirm `..` component check (per `2026-04-29-relax-check-traversal-to-component-match`) is preserved in output-path validator
- [x] 2.2 Test: `output/../etc/passwd` still rejected
- [x] 2.3 Test: `report..final.pdf` (literal dots in name, not traversal component) accepted

## 3. Tests — newly accepted

- [x] 3.1 Test: `bfh_export_pdf(x, "rapport (final).pdf")` succeeds (parens accepted)
- [x] 3.2 Test: `Q1 [2026].pdf` accepted
- [x] 3.3 Test: `kvalitet {draft}.pdf` accepted
- [x] 3.4 Test: `Indikator & resultat.pdf` accepted
- [x] 3.5 Test: paths with multiple consecutive special chars (`(((test))).pdf`) accepted

## 4. Tests — still rejected

- [x] 4.1 Test: `report\\nname.pdf` (literal newline) rejected
- [x] 4.2 Test: `report\\x00.pdf` (NUL byte) rejected — covered by .check_metachars NUL guard
- [x] 4.3 Test: `output/../etc/passwd` (traversal) rejected (existing tests preserved)
- [x] 4.4 Test: binary-path-validator still rejects parens (`/bin/quarto (test)` rejected) — actually binary policy keeps `;|&\$\`<>` strict; parens were already permitted in binary

## 5. Documentation

- [x] 5.1 Update Roxygen for `validate_export_path()` to document the relaxed charset and rationale
- [x] 5.2 Reference: "system2() with character-vector args does not invoke shell, so shell metacharacters are not a concern for argv[1+] values"
- [x] 5.3 NEWS entry under `## Forbedringer` for v0.12.0

## 6. Cross-repo coordination

- [ ] 6.1 Note in biSPCharts release notes that filename pre-sanitization can be relaxed
- [ ] 6.2 Optional: open biSPCharts cleanup issue

## 7. Release

- [x] 7.1 Bump `DESCRIPTION` 0.11.1 → 0.12.0 (or 0.11.2 if standalone)
- [x] 7.2 `devtools::test()` passes
- [ ] 7.3 `devtools::check()` no new WARN/ERROR

Tracking: GitHub Issue #TBD
