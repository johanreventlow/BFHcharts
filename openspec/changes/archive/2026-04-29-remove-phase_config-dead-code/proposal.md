## Why

`phase_config()` (`R/config_objects.R:280-300`) was scaffolded as a "reserved" config object for future phase configuration. It has 6 dedicated tests in `tests/testthat/test-config_objects.R` and a `print.phase_config` S3 method registered in NAMESPACE.

**Verification of dead code status:**
- `grep -n "phase_config" R/` outside `R/config_objects.R` → 0 production hits
- `bfh_spc_plot(phase = NULL)` parameter (`R/plot_core.R:85`) accepts a phase_config object but the function body NEVER reads it
- No call site in `bfh_qic()`, `bfh_export_pdf()`, or any other production path

The function is reserved infrastructure that was never wired in. Codex finding #10 flagged it as "API noise" and recommended slet/arkivér or document som internal future API.

## What Changes

- **NON-BREAKING (internal-only)**: remove `phase_config()` constructor and `print.phase_config` method
- Remove dead `phase = NULL` parameter from `bfh_spc_plot()` (internal function, no public-API impact)
- Remove `tests/testthat/test-config_objects.R` tests for phase_config (lines ~285-340)
- Remove `S3method(print,phase_config)` from NAMESPACE (regenerated via `devtools::document()`)
- Update `R/config_objects.R` Roxygen to reflect removal

## Impact

**Affected specs:**
- `code-organization` — REMOVED requirement: phase_config (if any spec referenced it; otherwise no spec impact)

**Affected code:**
- `R/config_objects.R` — remove `phase_config()` and `print.phase_config()` (~50 LOC)
- `R/plot_core.R:85` — remove `phase = NULL` parameter
- `tests/testthat/test-config_objects.R` — remove ~6 tests
- NAMESPACE — auto-regenerated, removes `S3method(print,phase_config)`
- NEWS entry under `## Interne ændringer`

**Non-breaking:**
- `phase_config()` was internal (not in NAMESPACE export list)
- `print.phase_config` registered but unused
- No external callers possible

## Cross-repo impact (biSPCharts)

Verification:
```bash
grep -rn "phase_config\|::phase_config\|:::phase_config" R/
```

Expected: 0 hits. If any: must be removed as part of biSPCharts cleanup PR.

## Alternative considered

**Keep phase_config and document as internal future API:** rejected because:
- 50 LOC + 6 tests carrying weight without delivering value
- "Future API" without active development tends to drift from current codebase patterns
- Easier to re-add when actually needed than to maintain dead code

## Related

- GitHub Issue: #216
- Source: BFHcharts code review 2026-04-27 (Codex finding #10)
