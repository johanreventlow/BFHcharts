## ADDED Requirements

### Requirement: Typst compilation SHALL support dependency-injected system2 and quarto path

`bfh_compile_typst()` SHALL accept internal dependency-injection parameters
`.system2` (default `base::system2`) and `.quarto_path` (default resolved via
`get_quarto_path()`) to enable isolated unit testing without requiring a real
Quarto installation.

**Rationale:**
- Tests must not depend on Quarto binary availability or version
- External process failures must be reproducible in unit tests
- Compile logic must be verifiable independent of system state

The DI parameters SHALL be marked `@keywords internal` and documented as
test-only hooks.

#### Scenario: Compile logic unit-tested with mocked system2

**Given** a Typst document and mocked `.system2`
**When** `bfh_compile_typst(doc, output, .system2 = mock_fn)` is called
**Then** `mock_fn` SHALL receive the constructed quarto arguments
**And** no real Quarto process SHALL be spawned

```r
captured <- NULL
mock_fn <- function(command, args, ...) {
  captured <<- list(command = command, args = args)
  0L  # success
}
bfh_compile_typst(doc, tmpfile, .system2 = mock_fn, .quarto_path = "/fake/quarto")
expect_equal(captured$command, "/fake/quarto")
expect_true(any(grepl("render", captured$args)))
```

#### Scenario: Quarto errors surface as informative R errors

**Given** mocked `.system2` returning non-zero exit code with stderr
**When** compile is called
**Then** the function SHALL raise an informative R error
**And** the error message SHALL reference the captured stderr content

```r
mock_fail <- function(...) {
  attr(result <- 1L, "errmsg") <- "compilation failed: syntax error"
  result
}
expect_error(
  bfh_compile_typst(doc, tmpfile, .system2 = mock_fail),
  "compilation failed"
)
```
