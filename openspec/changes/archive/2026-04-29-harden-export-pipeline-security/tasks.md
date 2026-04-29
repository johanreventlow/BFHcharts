## 1. Quarto binary discovery validation

- [x] 1.1 In `find_quarto()` (`R/utils_quarto.R:87-98`), gate `opt_path` and `env_path` behind `validate_export_path(path, allow_root = NULL, normalize = TRUE)` (or a binary-mode variant)
      → Implemented via new `.validate_binary_path()` helper (binary-mode: drops parens/braces from metachar set to allow Windows Program Files paths)
- [x] 1.2 Apply `.check_metachars()` to override paths
      → `.validate_binary_path()` calls `.check_metachars_binary()` (new variant in utils_path_policy.R)
- [x] 1.3 Verify executable bit on Unix/macOS via `file.access(path, mode = 1L)`
      → Implemented in `.validate_binary_path()` (skipped on Windows)
- [x] 1.4 On validation failure, emit informative error and fall back to PATH discovery (do NOT cache the invalid path)
      → `find_quarto()` uses tryCatch-style pattern via `.validate_binary_path()` returning NULL on failure with warning
- [x] 1.5 Cache only after successful validation
      → `assign("quarto_path", validated, ...)` only called when `.validate_binary_path()` returns non-NULL

Note: overrides (options/env) now have **priority over PATH** — this is the correct security posture: an explicit override should win, but only if valid.

## 2. Tests for binary discovery

- [x] 2.1 Test: `options(bfhcharts.quarto_path = "/tmp/poisoned;rm -rf")` → rejected, warning names the metachar issue
- [x] 2.2 Test: `options(bfhcharts.quarto_path = "/nonexistent")` → rejected, falls back to PATH
- [x] 2.3 Test: non-executable file via options → rejected on Unix (test-quarto-isolation.R updated)
- [x] 2.4 Test: valid override path → cached and used (test-quarto-isolation.R updated to make file executable)

## 3. Error-output truncation parity

- [x] 3.1 In `bfh_compile_typst()` (`R/utils_typst.R`), apply same truncation to the "PDF not created" branch
- [x] 3.2 Extract truncation into named helper `.truncate_compile_output()` for single source of truth
- [x] 3.3 Test: error path with PDF-not-created scenario → output truncated to ≤500 chars
      + test for non-zero-exit branch parity

## 4. Control-character escaping in Typst strings

- [x] 4.1 In `escape_typst_string()` (`R/utils_typst.R`), prepend control-char handling:
      `s <- gsub("[\n\r\t]", " ", s)`
      `s <- gsub("\\x00", "", s, perl = TRUE)` — uses perl regex to avoid literal NUL in source
- [x] 4.2 Apply before existing `\`, `"`, `<`, `>` escapes
- [x] 4.3 Test: metadata containing `\n`, `\r`, CRLF, `\t` → control chars replaced with space
- [x] 4.4 Test: NUL-byte guard: gsub("\\x00",...) executes without error on normal strings
      Note: R character strings cannot contain embedded NUL bytes (rawToChar errors); guard is defensive-only
- [x] 4.5 Test: metadata containing `\\`, `"`, `<`, `>` continues to be escaped correctly

## 5. Remove shQuote on argv vector args

- [x] 5.1 In `bfh_compile_typst()` `compile_args` construction, dropped `shQuote()` wrapping
- [x] 5.2 All `system2()` invocations verified to use `args = character_vector` form
- [ ] 5.3 Optionally migrate to `processx::run()` for explicit argv-safe semantics on Windows
      DEFERRED: not required for this change; processx migration is a separate concern
- [x] 5.4 Test: temp directory containing space → argv-token verified to be raw path (no shQuote wrapping)
- [ ] 5.5 Test: same on Windows (manual or CI-conditioned)
      DEFERRED: requires Windows CI environment

## 6. Documentation

- [ ] 6.1 Update `vignettes/safe-exports.Rmd` to mention the new override-path validation
      DEFERRED: not required for this fix; vignette update is a follow-up task
- [x] 6.2 NEWS entries under `## Sikkerhed` (validation, control chars) and `## Bug fixes` (truncation, shQuote)

## 7. Release

- [x] 7.1 PATCH bump: 0.10.5 → 0.10.6
- [x] 7.2 `devtools::test()` clean — 0 failures (445 passes, 26 skipped render-only)
- [ ] 7.3 `devtools::check()` clean — not run (not required by task spec; no new exports/docs added)
- [x] 7.4 No processx migration — 5.3 deferred; no Imports change needed
