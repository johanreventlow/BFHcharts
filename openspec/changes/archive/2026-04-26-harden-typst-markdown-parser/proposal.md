# harden-typst-markdown-parser

## Why

Nuværende markdown → Typst konvertering i `R/utils_typst.R` er regex-baseret
og escaper ad hoc. Det er sandsynligvis rimeligt for kontrolleret intern
tekst, men er ikke en stærk security boundary mod Typst-markup injection
via user-supplied strings (fx AI-genereret analysetekst, eksterne noter).

Gemini review anbefaler en AST-baseret approach: parse markdown med
`commonmark`, map AST-noder til Typst-markup. Det giver:
- Fuldstændig escaping af Typst-special-tegn
- Korrekt håndtering af nested/edge-case markdown
- Klarere testbarhed (node-mapping er deterministisk)

## What Changes

- Tilføj `commonmark` som `Imports` dependency
- Implementér `markdown_to_typst()` via commonmark AST-parsing
- Fjern regex-baseret escaping (behold kun Typst-specifik character escaping)
- Tilføj fuzz-/property-tests for injection-forsøg (`#`, `$`, `[`, `]`, `@`, `<`, `>`)
- Behold backward-kompatibel API (samme input → samme output for dokumenteret markdown)

## Impact

**Affected specs:**
- `pdf-export`

**Affected code:**
- `R/utils_typst.R` (ny parser)
- `DESCRIPTION` (commonmark Imports)
- `tests/testthat/test-typst-markdown.R` (nye injection tests)

**User-visible changes:**
- Ingen signaturændringer
- Potentielt ændret Typst-output for kanttilfælde hvor regex-parser misparsed markdown — dokumentér i NEWS

## Related

- Gemini review (Markdown Injection)
