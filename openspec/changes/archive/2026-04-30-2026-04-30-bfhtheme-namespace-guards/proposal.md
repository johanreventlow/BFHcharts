## Why

`BFHcharts` declares `BFHtheme (>= 0.5.0)` in `Imports:` and calls into it at multiple sites without `requireNamespace()` guards or load-order checks:

- `R/plot_core.R:107` — `BFHtheme::bfh_cols()` for color caching
- `R/themes.R:38` — `BFHtheme::theme_bfh()` in `apply_spc_theme()`
- `R/utils_add_right_labels_marquee.R:137, 160` — `BFHtheme::bfh_cols()` and `BFHtheme::get_right_aligned_marquee_style()`

If `BFHtheme` is not installed (forgotten Remotes install), or fails to load due to a font registration issue, or has its NAMESPACE shadowed by a loaded sibling package, the user sees a cryptic `could not find function "..."` or an inscrutable namespace error mid-plot. The user cannot connect this to the dependency contract.

`BFHtheme` lives in `Remotes:` (not CRAN), so install-time validation is not enforced by default — it must be installed via `pak::pkg_install("johanreventlow/BFHcharts")` or equivalent. Forgetting this step is realistic for new contributors and CI environments that bypass `pak`.

## What Changes

- **Load-time check**: `R/zzz.R` `.onLoad()` SHALL call `requireNamespace("BFHtheme", quietly = TRUE)` and emit a packageStartupMessage if the package is missing or has version `< 0.5.0`. Message includes install instructions.
- **Hard-error guard at first use**: A new internal helper `.ensure_bfhtheme()` SHALL check `requireNamespace("BFHtheme", quietly = TRUE)` and `packageVersion("BFHtheme") >= "0.5.0"`. Called from:
  - `apply_spc_theme()` (`R/themes.R`)
  - `bfh_spc_plot()` (`R/plot_core.R`) — at the color-caching site
  - `add_right_labels_marquee()` (`R/utils_add_right_labels_marquee.R`)
- Error message format: `"BFHcharts requires BFHtheme >= 0.5.0; install with remotes::install_github('johanreventlow/BFHtheme@v0.5.0')"`
- The `.ensure_bfhtheme()` check caches the result in package-private env to avoid repeated overhead.
- 4 new tests using `mockery` or `local_mocked_bindings()` to simulate missing/old BFHtheme.

## Impact

**Affected specs:**
- `package-config` — ADDED requirement: load-time and use-time BFHtheme guards

**Affected code:**
- `R/zzz.R` — `.onLoad()` packageStartupMessage on missing dep
- `R/utils_helpers.R` (or new `R/utils_dep_guards.R`) — `.ensure_bfhtheme()` helper
- `R/themes.R:38` — wrap with guard
- `R/plot_core.R:107` — wrap with guard
- `R/utils_add_right_labels_marquee.R:137, 160` — wrap with guard
- `tests/testthat/test-dep-guards.R` — new file
- `NEWS.md` — entry under `## Bug fixes` / `## Forbedringer`

**Breaking change scope:** None for correctly-installed users. Users who somehow had BFHcharts loaded without BFHtheme (was theoretically possible because Imports doesn't enforce runtime presence in all R versions) now receive a clear error instead of cryptic mid-plot failure.

## Cross-repo impact (biSPCharts)

**Verification:**
```bash
# In biSPCharts:
grep -rn "BFHtheme\|BFHcharts::" R/ | head -20
```

**Likely affected:** None. biSPCharts already declares both as Imports/Remotes. If biSPCharts has any code path that imports BFHcharts before BFHtheme, the new error will surface it cleanly.

**biSPCharts version bump:** PATCH (no change required unless cleanup desired).

## Related

- Source: BFHcharts code review 2026-04-30 (Claude finding #2)
- Pairs well with `2026-04-30-pin-remotes-to-tag` (future) — pinning Remotes ensures install-time presence
