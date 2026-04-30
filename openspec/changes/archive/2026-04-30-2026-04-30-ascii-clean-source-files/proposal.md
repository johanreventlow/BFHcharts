## Why

`R CMD check --as-cran` produces a WARNING for non-ASCII characters in R source code, located in `R/utils_bfh_qic_helpers.R:8` (and potentially other files with Danish comments). Codex code review 2026-04-30 (finding #2) flagged this as a release-cleanliness blocker.

CRAN policy treats non-ASCII in code as actively warned-against. r-universe and other publication gates may inherit the same policy. A WARNING-clean check is a prerequisite for broader-organization or public distribution.

The package's coding convention (per `~/.claude/rules/R_STANDARDS.md`) already states "kommentarer: dansk" — but this conflicts with CRAN-clean source. The fix is to keep Danish in roxygen / NEWS / vignettes (allowed via UTF-8 declaration) but remove non-ASCII from `.R` source files (comments, strings, identifiers).

## What Changes

- **Build hygiene**: All `.R` files in `R/` SHALL be ASCII-clean. Non-ASCII content (æ, ø, å, ≥, ≤, etc.) is moved to:
  - Roxygen blocks (allowed because the `Encoding: UTF-8` field in DESCRIPTION covers documentation)
  - i18n YAML files (`inst/i18n/da.yaml`)
  - String constants escaped via `æ`, `ø`, `å`, `≥`, `≤` etc.
- New CI guard: a lightweight test `tests/testthat/test-source-ascii.R` that scans `R/*.R` and fails on non-ASCII bytes.
- Pre-existing comments in Danish are converted as follows:
  - Comments documenting *clinical* meaning move to roxygen (`@details`) where escaped Unicode is fine
  - Comments documenting *implementation* are translated to English
  - Comments containing operator symbols (≥, ≤) use ASCII (>=, <=) inline
- No public-API change. No semantic change.

## Impact

**Affected specs:**
- `package-config` — ADDED requirement: source code ASCII-cleanliness

**Affected code:**
- `R/utils_bfh_qic_helpers.R:8` — confirmed locus per Codex
- All other `R/*.R` files — sweep for non-ASCII (script-driven)
- `tests/testthat/test-source-ascii.R` — new test
- `NEWS.md` — entry under `## Interne ændringer`

**Sweep mechanism (one-shot):**
```bash
grep -rn -P '[^\x00-\x7F]' R/ --include='*.R'
```

**Breaking change scope:** None. Internal cleanup only.

## Cross-repo impact (biSPCharts)

None. biSPCharts handles its own source cleanliness independently.

## Related

- Source: Codex code review 2026-04-30 (finding #2)
- Enables: future `--as-cran` warning-clean releases, r-universe distribution
