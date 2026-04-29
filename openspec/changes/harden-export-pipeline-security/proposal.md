## Why

Code review 2026-04 surfaced four export-pipeline correctness/security gaps:

1. **Unvalidated Quarto binary override.** `find_quarto()` (`R/utils_quarto.R:87-98`) accepts `getOption("bfhcharts.quarto_path")` and `Sys.getenv("QUARTO_PATH")` after only `file.exists()`. No `validate_export_path()`, no shell-metacharacter check, no executable-bit check. The path is cached session-wide via `.quarto_cache`. On a multi-user system, a poisoned `.Rprofile` or env-var directs `system2()` to an arbitrary executable for the rest of the R session.

2. **Inconsistent Quarto error-output truncation.** Compile-error output is truncated to 500 chars on non-zero exit status (`R/utils_typst.R:257`), but the "PDF not created" branch uses the full output. Path/environment details can leak through that second branch into app error messages.

3. **`escape_typst_string()` does not handle control characters.** `R/utils_typst.R:414-428` escapes `\`, `"`, `<`, `>` but not `\n`, `\r`, `\t`, or NUL. Metadata fields (`hospital`, `department`, `author`, `details`, `data_definition`) embedded as Typst `"..."` literals will produce a Typst syntax error if the source contains CRLF (e.g. department name copy-pasted from a Windows source). NUL byte behavior is undefined in Typst.

4. **`shQuote()` misapplied to argv-vector arguments on Unix.** `R/utils_typst.R:227-229` wraps `compile_args` elements in `shQuote()` and passes them as `args = vector` to `system2()`. On Unix/macOS, `system2()` with a character vector does not invoke a shell; each element is a direct argv token. Quoting adds literal `"` characters to the filename token, breaking paths with spaces (e.g. `~/My Files/`). On Windows the construction is correct, but the same code runs on both platforms.

**Risk profile (intern hospital usage, multi-user analyst workstations):** #1 is the highest impact (arbitrary code execution); #2 is information leak; #3 produces compile failures on legitimate metadata; #4 is a functional bug for paths with spaces.

## What Changes

- Apply `validate_export_path()` (with metachar check) and an executable-bit verification to both option/env override paths in `find_quarto()`; cache only after validation
- Truncate compile-error output to the same 500-char cap in the "PDF not created" branch
- Extend `escape_typst_string()` to strip or replace control characters: `gsub("[\n\r\t]", " ", s)` and `gsub("\x00", "", s)` before existing escapes
- Remove `shQuote()` from `compile_args` elements; pass paths as raw argv tokens to `system2()`. If Windows shell-string mode is a concern, replace with `processx::run()` for argv-safe behavior on all platforms
- Add unit tests for each fix (poisoned-option rejection, control-char escape, space-in-path argv, output truncation parity)

## Impact

**Affected specs:**
- `pdf-export` — MODIFIED requirements: Quarto binary discovery, error-output truncation, Typst string escaping, argv handling

**Affected code:**
- `R/utils_quarto.R:87-98` — validation gate before caching
- `R/utils_typst.R:227-229` — drop `shQuote()` (or migrate to processx)
- `R/utils_typst.R:414-428` — control-char handling in `escape_typst_string()`
- `R/utils_typst.R:256-260` — uniform truncation in PDF-not-created branch
- `R/utils_path_policy.R` — possibly extend `validate_export_path()` to support binary-path mode (executable bit)
- `tests/testthat/test-export_pdf.R` + new tests
- NEWS under `## Sikkerhed` and `## Bug fixes`

**Potentially breaking:** Callers relying on poisoned-option-path will fail with a clear error (intended). Paths with spaces previously broken on Unix will now work. No legitimate use case loses functionality.

## Cross-repo impact (biSPCharts)

biSPCharts may set `BFHCHARTS_QUARTO_PATH` env var in deployment configs. Verify the validated path satisfies the new metachar/executable checks. Document the new contract in deployment notes.

biSPCharts version bump: not required.

## Related

- Code review 2026-04 (Claude findings #3, #4, #5; Codex finding #7)
- `vignettes/safe-exports.Rmd` (existing trust-model documentation)
