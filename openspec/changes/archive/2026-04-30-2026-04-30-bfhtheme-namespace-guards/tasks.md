## 1. Helper

- [x] 1.1 Create `R/utils_dep_guards.R` (or extend `R/utils_helpers.R`) with `.ensure_bfhtheme(min_version = "0.5.0")`
- [x] 1.2 Helper checks `requireNamespace("BFHtheme", quietly = TRUE)` then `utils::packageVersion("BFHtheme") >= min_version`
- [x] 1.3 Cache positive result in package-private env (`.dep_guard_cache`) to avoid repeated namespace lookups
- [x] 1.4 Error message: `"BFHcharts requires BFHtheme >= <version>; install with remotes::install_github('johanreventlow/BFHtheme@v<version>')"`

## 2. Wiring

- [x] 2.1 Wrap `apply_spc_theme()` first call in `.ensure_bfhtheme()` (`R/themes.R:36`)
- [x] 2.2 Wrap `bfh_spc_plot()` color-caching path (`R/plot_core.R:85` -- entry-point guard covers both line 108 + 228)
- [x] 2.3 Wrap `add_right_labels_marquee()` paths (`R/utils_add_right_labels_marquee.R:13, 136`; covers lines 33 + 139)
- [x] 2.4 Confirm no other `BFHtheme::` calls -- `grep -rn "BFHtheme::" R/` -- 17 active sites identified across 7 files; all 13 enclosing entry-point functions guarded

## 3. Load-time message

- [x] 3.1 In `R/zzz.R` `.onAttach()`, soft-check BFHtheme presence (chosen over `.onLoad` per R conventions: messages belong in attach, not load)
- [x] 3.2 If missing/old: `packageStartupMessage()` with install hint (do not error -- let user load and trigger guard at use)

## 4. Tests

- [x] 4.1 Test: BFHtheme present + correct version -> guard passes silently, cached
- [x] 4.2 Test: simulate missing BFHtheme via `require_fn = function(...) FALSE` (function-arg injection used instead of mocking; cleaner) -> error with install hint
- [x] 4.3 Test: simulate version too low -> error mentions required version + installed version
- [x] 4.4 Test: cache works (second call to guard does not re-invoke `requireNamespace`)
- [x] (extra) Test: custom `min_version` argument honored

## 5. Documentation

- [x] 5.1 Update `BFHcharts-package.R` (added `@section BFHtheme dependency:` block with install hint)
- [x] 5.2 NEWS entry under `## Forbedringer`
- [x] 5.3 README "Installation" section (added "BFHtheme dependency" subsection)

## 6. Release

- [x] 6.1 Rolled into 0.12.0 development cycle (current Version: 0.12.0)
- [x] 6.2 `devtools::test()` passes (dep-guard suite: 11 PASS / 0 FAIL)
- [x] 6.3 `devtools::check()` no new WARN/ERROR (2026-04-30: 0 errors, 0 warnings, 1 unrelated NOTE = "unable to verify current time")

Tracking: GitHub Issue #TBD
