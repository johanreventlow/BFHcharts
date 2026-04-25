# Tasks: harden-typst-markdown-parser

## 1. Dependencies

- [ ] 1.1 Tilføj `commonmark` til `DESCRIPTION` Imports (version >= 1.9)
- [ ] 1.2 Verificér `commonmark::markdown_xml()` output-format (brug XML tree eller latex)
- [ ] 1.3 Opdater `renv.lock` / Suggests hvis relevant

## 2. Implementation

- [ ] 2.1 Implementér intern `parse_markdown_ast()` via commonmark
- [ ] 2.2 Implementér node-mapper: paragraph, emph, strong, code, list, break
- [ ] 2.3 Implementér Typst special-char escape: `#`, `$`, `@`, `[`, `]`, `<`, `>`, backtick, backslash
- [ ] 2.4 Replace eksisterende regex-baseret logik i `R/utils_typst.R`

## 3. Testing

- [ ] 3.1 Snapshot-tests for kanonisk markdown-input
- [ ] 3.2 Injection-tests: Typst-directives som `#import`, `#let`, scripting-constructs, raw `@package`
- [ ] 3.3 Edge cases: nested emphasis, escaped chars, unicode
- [ ] 3.4 Backward compat: eksisterende PDF-snapshots forbliver identiske

## 4. Documentation

- [ ] 4.1 Roxygen note om AST-baseret parser
- [ ] 4.2 NEWS.md: security hardening + potentielle output-forskelle
