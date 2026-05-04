## MODIFIED Requirements

### Requirement: Caching documentation SHALL describe current cache topology

The package SHALL document the four active package-private caches
(`font`, `marquee_style`, `quarto`, `i18n`) and the canonical reset
helper in a single discoverable file (`docs/CACHING_SYSTEM.md` or
equivalent reference).

**Rationale:**
- New contributors need a one-page overview of caching strategy without
  reading every `R/cache_*.R` file.
- Current implementation: `.font_cache`, `.marquee_style_cache`,
  `.quarto_cache`, `.i18n_cache` (per `R/cache_reset.R::bfh_reset_caches()`).
- The legacy grob-cache was removed in v0.5.0; documentation SHALL
  reflect the simplified topology rather than retaining stale
  configuration references.

#### Scenario: Documentation lists active caches

- **GIVEN** the caching documentation file (currently
  `docs/CACHING_SYSTEM.md`)
- **WHEN** a contributor reads it
- **THEN** the file SHALL list all four package-private caches by name
  and purpose (`font`, `marquee_style`, `quarto`, `i18n`)
- **AND** the file SHALL NOT reference removed helpers
  (`configure_grob_cache()`, `clear_grob_cache()`)
- **AND** the file SHALL document `bfh_reset_caches()` as the canonical
  reset helper (internal API only)

## REMOVED Requirements

### Requirement: Cache configuration functions SHALL include global state warnings

**Reason:** No exported cache-configuration helpers exist in the package
since v0.5.0. The legacy `configure_grob_cache()` and
`clear_grob_cache()` were removed; the only remaining cache helper
(`bfh_reset_caches()`) is `@keywords internal @noRd` and not part of
the public API surface. A requirement governing user-facing cache
configuration warnings has no implementation target.

**Migration:** Internal cache state is now documented at the spec level
(see modified "Caching documentation SHALL describe current cache
topology" requirement) rather than in per-function Roxygen warnings.

### Requirement: Caching documentation SHALL include troubleshooting guide

**Reason:** Subsumed by the modified "Caching documentation SHALL
describe current cache topology" requirement, which sets a discovery
contract without prescribing a troubleshooting subsection. The previous
formulation referenced `docs/CACHING_SYSTEM.MD` as the canonical
location of a troubleshooting section that does not exist; rather than
mandate a specific subsection (which encourages stale documentation),
the modified requirement contracts on completeness of the cache list.
Future troubleshooting content can be added to the same file or
elsewhere as separate proposals dictate.
