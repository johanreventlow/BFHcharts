## ADDED Requirements

### Requirement: Markdown SHALL be converted to Typst via AST-based parser

The package SHALL convert user-supplied markdown text to Typst markup via an AST-based parser (built on `commonmark`), not via regex substitution.

**Rationale:**
- Regex-based conversion is fragile against Typst-markup injection
- AST parsing yields deterministic, testable node-mapping
- All Typst special characters must be escaped in text nodes

**Escaped characters in text nodes:** `#`, `$`, `@`, `[`, `]`, `<`, `>`, `` ` ``, `\`

#### Scenario: Injection attempt is neutralized

**Given** user-supplied text contains `#import "x": *`
**When** `markdown_to_typst()` converts the text
**Then** the resulting Typst text SHALL escape `#` so `#import` renders as literal text
**And** the Typst compiler SHALL NOT execute the import directive

```r
input <- "Analyse: #import \"evil\": *"
output <- markdown_to_typst(input)
expect_false(grepl("^#import", output))
expect_match(output, "\\\\#import", fixed = FALSE)
```

#### Scenario: Canonical markdown renders correctly

**Given** well-formed markdown with emphasis, bold, code, and lists
**When** `markdown_to_typst()` is called
**Then** output SHALL preserve semantic structure as Typst markup

```r
input <- "**Bold** and *emphasis* with `code` and\n\n- item 1\n- item 2"
output <- markdown_to_typst(input)
expect_match(output, "\\*Bold\\*")
expect_match(output, "_emphasis_")
```

#### Scenario: Unicode and Danish characters pass through

**Given** markdown containing Danish characters (æ, ø, å, Æ, Ø, Å)
**When** parsed
**Then** characters SHALL appear verbatim in Typst output without mojibake

```r
input <- "Gennemsnittet er på nåleøjet"
output <- markdown_to_typst(input)
expect_match(output, "nåleøjet", fixed = TRUE)
```
