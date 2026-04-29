## 1. Quarto binary discovery validation

- [ ] 1.1 In `find_quarto()` (`R/utils_quarto.R:87-98`), gate `opt_path` and `env_path` behind `validate_export_path(path, allow_root = NULL, normalize = TRUE)` (or a binary-mode variant)
- [ ] 1.2 Apply `.check_metachars()` to override paths
- [ ] 1.3 Verify executable bit on Unix/macOS via `file.access(path, mode = 1L)`
- [ ] 1.4 On validation failure, emit informative error and fall back to PATH discovery (do NOT cache the invalid path)
- [ ] 1.5 Cache only after successful validation

## 2. Tests for binary discovery

- [ ] 2.1 Test: `options(bfhcharts.quarto_path = "/tmp/poisoned;rm -rf")` → rejected, error names the metachar issue
- [ ] 2.2 Test: `options(bfhcharts.quarto_path = "/nonexistent")` → rejected, falls back to PATH
- [ ] 2.3 Test: `Sys.setenv(QUARTO_PATH = "/tmp/script")` for non-executable file → rejected on Unix
- [ ] 2.4 Test: valid override path → cached and used

## 3. Error-output truncation parity

- [ ] 3.1 In `bfh_compile_typst()` (`R/utils_typst.R`), apply same `substr(..., 1, 500)` to the "PDF not created" branch
- [ ] 3.2 Extract truncation into named helper `.truncate_compile_output()` for single source of truth
- [ ] 3.3 Test: error path with PDF-not-created scenario → output truncated to 500 chars

## 4. Control-character escaping in Typst strings

- [ ] 4.1 In `escape_typst_string()` (`R/utils_typst.R:414-428`), prepend control-char handling:
  ```r
  s <- gsub("[\n\r\t]", " ", s)
  s <- gsub("\x00", "", s, fixed = TRUE)
  ```
- [ ] 4.2 Apply before existing `\`, `"`, `<`, `>` escapes
- [ ] 4.3 Test: metadata containing `\n` → Typst compile succeeds
- [ ] 4.4 Test: metadata containing `\x00` → NUL stripped, no Typst error
- [ ] 4.5 Test: metadata containing `\\`, `"`, `<`, `>` continues to be escaped correctly

## 5. Remove shQuote on argv vector args

- [ ] 5.1 In `bfh_compile_typst()` `compile_args` construction (`R/utils_typst.R:227-229`), drop `shQuote()` wrapping
- [ ] 5.2 Verify all `system2()` invocations use `args = character_vector` form
- [ ] 5.3 Optionally migrate to `processx::run()` for explicit argv-safe semantics on Windows
- [ ] 5.4 Test: temp directory containing space (e.g. `/tmp/My Files/`) → PDF compiles successfully on macOS/Linux
- [ ] 5.5 Test: same on Windows (manual or CI-conditioned)

## 6. Documentation

- [ ] 6.1 Update `vignettes/safe-exports.Rmd` to mention the new override-path validation
- [ ] 6.2 NEWS entries under `## Sikkerhed` (validation, control chars) and `## Bug fixes` (truncation, shQuote)

## 7. Release

- [ ] 7.1 PATCH bump (security + bug fix)
- [ ] 7.2 `devtools::test()` clean
- [ ] 7.3 `devtools::check()` clean
- [ ] 7.4 If migrating to processx, add to `Imports` and run installation test on fresh env
