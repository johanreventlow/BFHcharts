# Tasks: harden-typst-markdown-parser

## 1. Dependencies

- [x] 1.1 Tilføj `commonmark` til `DESCRIPTION` Imports (version >= 1.9)
- [x] 1.2 Verificér `commonmark::markdown_xml()` output-format (brug XML tree eller latex)
- [x] 1.3 Opdater `renv.lock` / Suggests hvis relevant

## 2. Implementation

- [x] 2.1 Implementér intern `parse_markdown_ast()` via commonmark
- [x] 2.2 Implementér node-mapper: paragraph, emph, strong, code, list, break
- [x] 2.3 Implementér Typst special-char escape: `#`, `$`, `@`, `[`, `]`, `<`, `>`, backtick, backslash
- [x] 2.4 Replace eksisterende regex-baseret logik i `R/utils_typst.R`

## 3. Testing

- [x] 3.1 Snapshot-tests for kanonisk markdown-input
- [x] 3.2 Injection-tests: Typst-directives som `#import`, `#let`, scripting-constructs, raw `@package`
- [x] 3.3 Edge cases: nested emphasis, escaped chars, unicode
- [x] 3.4 Backward compat: eksisterende PDF-snapshots forbliver identiske

## 4. Documentation

- [x] 4.1 Roxygen note om AST-baseret parser
- [x] 4.2 NEWS.md: security hardening + potentielle output-forskelle
