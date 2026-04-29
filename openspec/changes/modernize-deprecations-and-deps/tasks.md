## 1. print.summary removal

- [ ] 1.1 Decide target version (e.g. v0.11.0) and update deprecation message accordingly
- [ ] 1.2 Replace `warning()` calls in `R/utils_bfh_qic_helpers.R:85-109` with `lifecycle::deprecate_stop()` for the legacy combo (or remove the path entirely)
- [ ] 1.3 Remove the `legacy list(plot, summary)` return-format code path
- [ ] 1.4 Update tests that rely on `print.summary = TRUE` to use new return-format
- [ ] 1.5 NEWS entry under `## Breaking changes` documenting removal

## 2. lemon dependency verification

- [ ] 2.1 Run `grep -rn "lemon::" R/` — record hit count
- [ ] 2.2 If zero hits in `R/`: check `vignettes/`, `tests/`. If only there, move to `Suggests` (or remove if those usages are also stale)
- [ ] 2.3 If used in `R/`: keep in `Imports` and document in roxygen which functions need it
- [ ] 2.4 Update DESCRIPTION accordingly
- [ ] 2.5 Run `devtools::check()` to confirm no new warnings

## 3. BFHllm Remotes cleanup

- [ ] 3.1 Remove `johanreventlow/BFHllm` from `DESCRIPTION` `Remotes:`
- [ ] 3.2 Update `R/spc_analysis.R` `bfh_generate_analysis()` Roxygen to include manual install hint:
  ```
  @details If you wish to enable AI-driven analysis (use_ai = TRUE), install
  the optional BFHllm package manually:
  remotes::install_github("johanreventlow/BFHllm")
  ```
- [ ] 3.3 Update README or vignette to mention the manual install requirement

## 4. cl/freeze/part config canonicalization

- [ ] 4.1 In `build_bfh_qic_config()` (`R/utils_bfh_qic_helpers.R:616-637`), keep `cl`, `freeze`, `part` only at the top level
- [ ] 4.2 Replace `label_config$centerline_value` etc. with derived accessors: `get_centerline_value(config) <- function(c) c$cl`
- [ ] 4.3 Update all readers to use the accessors
- [ ] 4.4 Test: mutating top-level `config$cl` is reflected in subsequent label-config reads

## 5. base_size ceiling alignment

- [ ] 5.1 Decide canonical max: `FONT_SCALING_CONFIG$max_size` (48) or 100
- [ ] 5.2 Update validation in `R/utils_bfh_qic_helpers.R:238-241` to match
- [ ] 5.3 If keeping 100 as user-explicit cap: document the rationale in roxygen
- [ ] 5.4 Test: `base_size = max + 1` rejected with clear message

## 6. Auto-detection units message

- [ ] 6.1 In `convert_to_inches()` (or wherever auto-detection lives, called from `R/bfh_qic.R:111-115`), emit `message()` when no `units` arg given:
  ```
  message("Auto-detected units: ", inferred, " (pass units = '...' to silence)")
  ```
- [ ] 6.2 Test: `bfh_export_pdf(width = 10)` (no units) → message captured
- [ ] 6.3 Test: `bfh_export_pdf(width = 10, units = "in")` → no message
- [ ] 6.4 Document parameter `units` recommended in roxygen `@param`

## 7. Documentation

- [ ] 7.1 Update README installation section if `BFHllm` Remotes removed
- [ ] 7.2 NEWS entries under `## Breaking changes`, `## Forbedringer`, `## Interne ændringer`
- [ ] 7.3 Verify `lifecycle` is in Imports (or add it) if `lifecycle::deprecate_stop()` introduced

## 8. Cross-repo

- [ ] 8.1 In biSPCharts: `grep -rn "print.summary\s*=\s*TRUE" R/` — fix any usages
- [ ] 8.2 Verify biSPCharts install instructions still work after BFHllm Remotes removal

## 9. Release

- [ ] 9.1 Pre-1.0 MINOR bump (breaking removal of print.summary)
- [ ] 9.2 Tag with `BREAKING CHANGE:` commit-note
- [ ] 9.3 `devtools::test()` clean
- [ ] 9.4 `devtools::check()` clean (especially Imports/Suggests/Remotes)
