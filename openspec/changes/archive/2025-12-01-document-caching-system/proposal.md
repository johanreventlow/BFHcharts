# document-caching-system

## Why

**Problem:** Caching system i `utils_label_placement.R` bruger global state mutations uden klar dokumentation af thread safety, lifecycle og limitations.

**Current situation:**
- `.grob_cache_env` og `.panel_cache_env` bruger package-level global state
- Caching er disabled by default (opt-in), men konsekvenser er ikke dokumenteret
- Ingen Roxygen warnings om side effects
- `docs/CACHING_SYSTEM.MD` eksisterer men mangler vigtige sektioner

**Impact:**
- Brugere kan aktivere caching uden at forstå konsekvenserne
- Potentielle concurrency issues i Shiny apps
- Uklart hvordan cache lifecycle fungerer
- Manglende troubleshooting guidance

## What Changes

**Udvid dokumentation på 3 områder:**

1. **Tilføj Roxygen warnings til cache-funktioner**
   - `configure_grob_cache()` får `@details` sektion med warnings
   - `configure_panel_cache()` får tilsvarende warnings
   - Nævner: "NOT thread-safe", "session-level persistence", "manual cleanup required"

2. **Udvid `docs/CACHING_SYSTEM.MD`**
   - Ny sektion: "Global State & Limitations"
   - Ny sektion: "Thread Safety"
   - Ny sektion: "Troubleshooting"
   - Klare warnings om hvornår caching IKKE bør bruges

3. **Tilføj inline comments i kode**
   - Marker `.grob_cache_env` og `.panel_cache_env` med WARNING comments
   - Dokumentér cleanup responsibility

## Impact

**Affected specs:**
- `caching-system` (documentation requirements)

**Affected code:**
- `R/utils_label_placement.R` - Roxygen comments for cache functions
- `docs/CACHING_SYSTEM.MD` - Udvid med nye sektioner

**User-visible changes:**
- ✅ Bedre documentation i `?configure_grob_cache`
- ✅ Klare warnings før brugere aktiverer caching
- ✅ Troubleshooting guide for common issues

**Breaking changes:**
- ⚠️ Ingen - dette er ren dokumentation

## Alternatives Considered

**Alternative 1: Fjern caching helt**
**Rejected because:**
- Caching kan være nyttigt for store datasets
- Allerede disabled by default
- Refactoring er out of scope (se issue #42)

**Alternative 2: Gør ingenting**
**Rejected because:**
- Brugere har ingen guidance om side effects
- Potentielle runtime issues uden forklaring
- Best practices kræver dokumentation af global state

**Chosen approach: Dokumentér grundigt**
- ✅ Minimal effort (1 time)
- ✅ Ingen kodeændringer
- ✅ Klar guidance til brugere
- ✅ Dækker alle edge cases

## Related

- GitHub Issue: [#23](https://github.com/johanreventlow/BFHcharts/issues/23)
- Existing docs: `docs/CACHING_SYSTEM.MD`
- Related issue: #42 (Cache system over-engineering)
