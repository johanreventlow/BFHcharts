## ADDED Requirements

### Requirement: BFHcharts SHALL guard BFHtheme dependency at first-use sites

All `BFHtheme::` calls within `BFHcharts` SHALL be guarded by an internal helper `.ensure_bfhtheme()` that:

1. Calls `requireNamespace("BFHtheme", quietly = TRUE)` and errors if FALSE
2. Calls `utils::packageVersion("BFHtheme")` and errors if `< 0.5.0`
3. Caches a positive result in a package-private environment to avoid repeated overhead

The error message format SHALL be:
```
BFHcharts requires BFHtheme >= 0.5.0; install with
remotes::install_github('johanreventlow/BFHtheme@v0.5.0')
```

Additionally, `R/zzz.R` `.onLoad()` SHALL emit a `packageStartupMessage()` (not an error) when BFHtheme is absent or too old, so users see the issue at library-load time rather than only at first plot.

**Rationale:**
- `BFHtheme` lives in `Remotes:`, not CRAN; install-time enforcement is bypassed by users who do not use `pak::pkg_install()` or `remotes::install_github()`
- Cryptic mid-plot failures (`could not find function "bfh_cols"`) do not connect to the dependency contract from the user's perspective
- Caching prevents per-plot namespace overhead
- Startup message is non-blocking so partial functionality (e.g., reading documentation) remains available

**Wired sites (minimum):**
- `R/themes.R` (`apply_spc_theme`)
- `R/plot_core.R` (color caching)
- `R/utils_add_right_labels_marquee.R` (color + marquee style)
- Any future site introducing a `BFHtheme::` reference

#### Scenario: BFHtheme missing produces clear error at first plot

- **GIVEN** an environment where `requireNamespace("BFHtheme")` returns FALSE
- **WHEN** the user calls `bfh_qic(data, x, y)` for the first time
- **THEN** an error SHALL be raised
- **AND** the message SHALL contain "BFHtheme >= 0.5.0"
- **AND** the message SHALL contain a `remotes::install_github(...)` install hint

#### Scenario: BFHtheme version too low produces version-specific error

- **GIVEN** `utils::packageVersion("BFHtheme")` returns `"0.4.9"`
- **WHEN** `bfh_qic()` is called
- **THEN** the error message SHALL identify the required minimum version (`0.5.0`)
- **AND** SHALL identify the installed version (`0.4.9`)

#### Scenario: Subsequent calls skip the namespace check

- **GIVEN** `bfh_qic()` succeeded once with BFHtheme present
- **WHEN** `bfh_qic()` is called a second time in the same R session
- **THEN** `requireNamespace("BFHtheme")` SHALL not be re-invoked (cached positive result)

#### Scenario: Load-time startup message on missing dep

- **GIVEN** an environment where BFHtheme is missing
- **WHEN** `library(BFHcharts)` is invoked
- **THEN** a `packageStartupMessage()` SHALL be emitted mentioning the missing dependency
- **AND** the package SHALL continue loading (no error at load — only at first use)
