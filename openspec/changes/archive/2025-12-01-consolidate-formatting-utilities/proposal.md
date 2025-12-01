# consolidate-formatting-utilities

## Why

**Problem:** Time og number formatting logic er dupliceret på tværs af multiple filer med næsten identiske implementeringer. Dette bryder DRY-princippet.

**Current situation:**

**Time Formatting (3 kopier):**
- `R/utils_helpers.R:154-181` - `format_time_value()`
- `R/utils_y_axis_formatting.R:214-241` - `format_time_with_unit()`
- `R/utils_label_formatting.R:97-134` - Time formatting embedded

**Number Formatting (2 kopier):**
- `R/utils_y_axis_formatting.R:93-108` - K/M/mia notation
- `R/utils_label_formatting.R:54-85` - K/M/mia notation

**Impact:**
- **Maintenance burden:** Bugs skal fixes på 3+ steder
- **Inconsistency risk:** Implementeringer kan diverge over tid
- **Violates DRY:** Ingen single source of truth
- **Testing complexity:** Samme logik testes multiple steder

## What Changes

**Konsolider til canonical implementations:**

1. **Opret `R/utils_time_formatting.R` (NY FIL)**
   - `format_time_danish()` - Canonical time formatting
   - `determine_time_unit()` - Unit selection logic
   - `scale_to_unit()` - Value scaling
   - `get_danish_time_label()` - Unit labels ("min", "timer", etc.)

2. **Opret `R/utils_number_formatting.R` (NY FIL)**
   - `format_count_danish()` - Canonical number formatting med K/M/mia
   - `format_with_big_mark()` - Thousand separator logic
   - `determine_magnitude()` - K/M/mia threshold detection

3. **Update eksisterende filer**
   - `R/utils_helpers.R` - Fjern `format_time_value()`, brug `format_time_danish()`
   - `R/utils_y_axis_formatting.R` - Fjern duplicates, import fra nye filer
   - `R/utils_label_formatting.R` - Fjern duplicates, import fra nye filer

4. **Update call sites**
   - Find alle steder der bruger de gamle funktioner
   - Erstat med calls til de nye canonical funktioner

## Impact

**Affected specs:**
- `code-organization` (DRY compliance)

**Affected code:**
- `R/utils_time_formatting.R` - NY FIL
- `R/utils_number_formatting.R` - NY FIL
- `R/utils_helpers.R` - Fjern duplicate
- `R/utils_y_axis_formatting.R` - Fjern duplicates
- `R/utils_label_formatting.R` - Fjern duplicates

**User-visible changes:**
- ✅ Ingen - intern refactoring
- ✅ Samme output, bedre maintenance

**Breaking changes:**
- ⚠️ Ingen for exported API
- ⚠️ Internal function names ændres (ikke exported)

## Alternatives Considered

**Alternative 1: Behold duplicates**
**Rejected because:**
- Maintenance nightmare
- Bug fixes kræver multiple edits
- Inconsistency risk over tid
- Code review finder det uacceptabelt

**Alternative 2: Konsolider til én eksisterende fil**
```r
# Alt i utils_helpers.R
```
**Rejected because:**
- utils_helpers.R er allerede stor
- Bedre separation of concerns med dedikerede filer
- Lettere at finde og teste

**Alternative 3: Lav wrapper functions der kalder én implementation**
```r
# I utils_y_axis_formatting.R:
format_time_with_unit <- function(...) {
  format_time_value(...)  # Delegate
}
```
**Rejected because:**
- Tilføjer indirection uden værdi
- Stadig ikke DRY - wrapper code er også duplication
- Forvirrende for maintainers

**Chosen approach: Nye dedikerede utility filer**
- ✅ Clear separation of concerns
- ✅ Single source of truth
- ✅ Easy to test
- ✅ Follows R package conventions

## Related

- GitHub Issue: [#40](https://github.com/johanreventlow/BFHcharts/issues/40)
- Detected by: Refactoring advisor agent, Tidyverse code reviewer
