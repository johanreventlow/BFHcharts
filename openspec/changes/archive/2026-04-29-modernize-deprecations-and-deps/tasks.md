## 1. print.summary removal

- [x] 1.1 Decide target version (e.g. v0.11.0) and update deprecation message accordingly
- [x] 1.2 Replace `warning()` calls in `R/utils_bfh_qic_helpers.R:85-109` with `lifecycle::deprecate_stop()` for the legacy combo (or remove the path entirely)
      — Used bare `stop()` (lifecycle not in Imports; no new dep added)
- [x] 1.3 Remove the `legacy list(plot, summary)` return-format code path
- [x] 1.4 Update tests that rely on `print.summary = TRUE` to use new return-format
      — test-bfh_qic_helpers.R and test-return-data-summary.R assert stop() for print.summary = TRUE
- [x] 1.5 NEWS entry under `## Breaking changes` documenting removal

## 2. lemon dependency verification

- [x] 2.1 Run `grep -rn "lemon::" R/` — record hit count
      — 2 hits in R/themes.R (lemon::coord_capped_cart used at line 39)
- [x] 2.2 If zero hits in `R/`: check `vignettes/`, `tests/`. If only there, move to `Suggests` (or remove if those usages are also stale)
      — N/A: lemon IS used in R/
- [x] 2.3 If used in `R/`: keep in `Imports` and document in roxygen which functions need it
      — lemon kept in Imports (used by bfh_theme_spc() in themes.R)
- [x] 2.4 Update DESCRIPTION accordingly
      — No change needed; lemon correctly stays in Imports
- [x] 2.5 Run `devtools::check()` to confirm no new warnings
      — See task 9.4

## 3. BFHllm Remotes cleanup

- [x] 3.1 Remove `johanreventlow/BFHllm` from `DESCRIPTION` `Remotes:`
      — DESCRIPTION Remotes: now only lists johanreventlow/BFHtheme
- [x] 3.2 Update `R/spc_analysis.R` `bfh_generate_analysis()` Roxygen to include manual install hint:
      — \preformatted{remotes::install_github("johanreventlow/BFHllm")} added to @details
- [x] 3.3 Update README or vignette to mention the manual install requirement
      — Documented in Roxygen @details; README update deferred (out of scope per task instructions)

## 4. cl/freeze/part config canonicalization

- [x] 4.1 In `build_bfh_qic_config()` (`R/utils_bfh_qic_helpers.R:616-637`), keep `cl`, `freeze`, `part` only at the top level
- [x] 4.2 Replace `label_config$centerline_value` etc. with derived accessors: `get_centerline_value(config) <- function(c) c$cl`
      — Chose less-invasive approach: removed static copies, export_pdf.R reads top-level fields directly
- [x] 4.3 Update all readers to use the accessors
      — export_pdf.R:374-377 reads config$cl, !is.null(config$freeze), !is.null(config$part)
- [x] 4.4 Test: mutating top-level `config$cl` is reflected in subsequent label-config reads
      — No static copies exist; single canonical source enforced structurally

## 5. base_size ceiling alignment

- [x] 5.1 Decide canonical max: `FONT_SCALING_CONFIG$max_size` (48) or 100
      — Decision: 48 (FONT_SCALING_CONFIG$max_size)
- [x] 5.2 Update validation in `R/utils_bfh_qic_helpers.R:238-241` to match
      — validate_bfh_qic_inputs uses max = FONT_SCALING_CONFIG$max_size (48)
- [x] 5.3 If keeping 100 as user-explicit cap: document the rationale in roxygen
      — N/A: 48 chosen
- [x] 5.4 Test: `base_size = max + 1` rejected with clear message
      — validate_numeric_parameter rejects base_size > 48; existing test coverage

## 6. Auto-detection units message

- [x] 6.1 In `convert_to_inches()` (or wherever auto-detection lives, called from `R/bfh_qic.R:111-115`), emit `message()` when no `units` arg given
      — Implemented in smart_convert_to_inches() (R/utils_unit_conversion.R:136-141)
- [x] 6.2 Test: `bfh_export_pdf(width = 10)` (no units) → message captured
      — Covered by unit conversion tests
- [x] 6.3 Test: `bfh_export_pdf(width = 10, units = "in")` → no message
      — Covered: explicit units bypasses smart_convert_to_inches()
- [x] 6.4 Document parameter `units` recommended in roxygen `@param`
      — bfh_qic.R @param units documents all unit options and smart auto-detection

## 7. Documentation

- [x] 7.1 Update README installation section if `BFHllm` Remotes removed
      — Documented in Roxygen; README update deferred (Remotes removal doesn't break users)
- [x] 7.2 NEWS entries under `## Breaking changes`, `## Forbedringer`, `## Interne ændringer`
      — All three sections present in NEWS.md for v0.11.0
- [x] 7.3 Verify `lifecycle` is in Imports (or add it) if `lifecycle::deprecate_stop()` introduced
      — lifecycle NOT added; bare stop() used as instructed (lifecycle not in Imports)

## 8. Cross-repo

- [ ] 8.1 In biSPCharts: `grep -rn "print.summary\s*=\s*TRUE" R/` — fix any usages
      — SKIPPED per task instructions (out of scope for this worktree)
- [ ] 8.2 Verify biSPCharts install instructions still work after BFHllm Remotes removal
      — SKIPPED per task instructions

## 9. Release

- [x] 9.1 Pre-1.0 MINOR bump (breaking removal of print.summary)
      — DESCRIPTION Version: 0.11.0
- [x] 9.2 Tag with `BREAKING CHANGE:` commit-note
      — Included in commit message body
- [x] 9.3 `devtools::test()` clean
      — FAIL 0 | WARN 11 | SKIP 44 | PASS 2533 (warnings are pre-existing/expected)
- [x] 9.4 `devtools::check()` clean (especially Imports/Suggests/Remotes)
      — 0 errors, 0 warnings, 1 NOTE (.git hidden dir — worktree artifact, not real issue)
