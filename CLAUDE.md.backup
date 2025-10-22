# Claude Instruktioner – SPC App

## 1) Projektoversigt

R Shiny applikation til **Statistical Process Control (SPC)**. Anvendes i klinisk kvalitetsarbejde med krav om stabilitet, forståelighed og dansk sprog.

**Udviklingsstatus:** Industristandard mønstre med test-driven development, centraliseret state management, robust error handling og moden build-/deploy-automation.

---

## 2) Udviklingsprincipper

### 2.1 Test-First Development (TDD)

✅ **OBLIGATORISK:** Al udvikling følger TDD:

1. Skriv tests først
2. Kør tests kontinuerligt – skal altid bestå
3. Refactor med test-sikkerhed
4. Ingen breaking changes uden eksplicit godkendelse

**Test-kommandoer:**
```r
# Alle tests
R -e "library(SPCify); testthat::test_dir('tests/testthat')"

# Specifik test-fil
R -e "source('global.R'); testthat::test_file('tests/testthat/test-*.R')"

# Performance benchmark
R -e "microbenchmark::microbenchmark(package = library(SPCify), source = source('global.R'), times = 5)"
```

### 2.2 Defensive Programming

* **Input validation** ved entry points
* **Error handling** via `safe_operation()` og eksplicit `tryCatch()`
* **Scope guards** med `exists()` checks
* **Graceful degradation** med fallback-mønstre
* **State consistency** gennem centraliseret `app_state`

### 2.3 Git Workflow (OBLIGATORISK)

✅ **KRITISKE REGLER:**

1. **ALDRIG merge til master uden eksplicit godkendelse**
2. **ALDRIG push til remote uden anmodning**
3. **STOP efter feature branch commit – vent på instruktioner**
4. **Do NOT add Claude co-authorship footer to commits**

**Workflow:**
```bash
git checkout -b fix/feature-name
# ... arbejd og commit ...
git commit -m "beskrivelse"
# STOP - vent på instruktion
```

**VIGTIGT:** Commit messages skal IKKE indeholde:
- ❌ "🤖 Generated with [Claude Code]"
- ❌ "Co-Authored-By: Claude <noreply@anthropic.com>"
- ❌ Andre Claude attribution footers

Undtagelse: Simple operationer (`git status`, `git diff`, `git log`)

### 2.4 Issue Tracking

✅ **OBLIGATORISK:** Alle fejl, rettelser, todo-emner og forbedringsforslag skal dokumenteres som GitHub Issues.

**Issue workflow:**
```bash
# Opret issue via gh CLI
gh issue create --title "Beskrivelse af problem/feature" --body "Detaljeret beskrivelse"

# Link commit til issue
git commit -m "fix: kort beskrivelse (fixes #123)"

# Vis aktive issues
gh issue list
```

**Issue labels:**
* `bug` - Fejl der skal rettes
* `enhancement` - Forbedringer og nye features
* `documentation` - Dokumentationsændringer
* `technical-debt` - Refaktorering og code quality
* `performance` - Performance-relaterede issues
* `testing` - Test coverage og test-relaterede opgaver

**Best practices:**
* Opret issue før arbejde påbegyndes på større features
* Reference issue nummer i commits (`fixes #123`, `relates to #456`)
* Luk issues automatisk via commit messages (`fixes`, `closes`, `resolves`)
* Hold issues opdaterede med status og blokeringer

### 2.5 Observability & Debugging

**Struktureret logging:**
* Brug centralt logger-API: `log_debug()`, `log_info()`, `log_warn()`, `log_error()`
* Angiv `component`-felt (fx `[APP_SERVER]`, `[FILE_UPLOAD]`)
* Tilføj data i `details` som named list
* ALDRIG rå `cat()`-kald

```r
log_debug(
  component = "[APP_SERVER]",
  message = "Initialiserer data-upload observer",
  details = list(session_id = session$token)
)
```

### 2.6 Modularity & Architecture

* **Single Responsibility** – én opgave pr. funktion
* **Immutable data flow** – returnér nye objekter
* **Centralized state management** via `app_state`
* **Event-driven patterns** gennem event-bus
* **Dependency injection** som funktionsargumenter

---

## 3) Tekniske Best Practices

### 3.1 Shiny Best Practices

**Unified Event Architecture:**
```r
# ✅ Korrekt: Consolidated event-bus
emit$data_updated(context = "upload")     # Erstatter data_loaded + data_changed
emit$auto_detection_completed()
emit$ui_sync_requested()

observeEvent(app_state$events$data_updated, ignoreInit = TRUE,
  priority = OBSERVER_PRIORITIES$HIGH, {
  handle_data_update()
})

# ❌ Forkert: Ad-hoc reactiveVal triggers
legacy_trigger <- reactiveVal(NULL)
```

**Event Infrastructure:**
* Events defineres i `global.R` (`app_state$events`)
* Emit-funktioner i `create_emit_api()`
* Lyttere i `R/utils_event_system.R` via `setup_event_listeners()`

**Unified State Management:**
```r
# ✅ App state som single source of truth
app_state$data$current_data <- new_data
app_state$columns$mappings$x_column <- detected_column

# ❌ Forkert: Lokale reactiveVal
values$some_data <- data
```

**Reactive Patterns:**
* Event-baserede triggere med `priority = OBSERVER_PRIORITIES$HIGH/MEDIUM/LOW`
* `req()` og `validate()` før logik
* `isolate()` kun i reaktive kontekster
* Wrap komplekse reactives i `safe_operation()`

**Performance:**
* Package loading primary: `library(SPCify)` (~50-100ms)
* Source loading sekundært: `options(spc.debug.source_loading = TRUE)` (~400ms+)
* Lazy loading af tunge komponenter

### 3.1.1 Race Condition Prevention

**Hybrid Anti-Race Strategy** (5 lag):

1. **Event Architecture** – Prioriterede centraliserede listeners
2. **State Atomicity** – Atomiske opdateringer via `safe_operation()`
3. **Functional Guards** – Guard conditions forhindrer overlap
4. **UI Atomicity** – Sikre wrappere for UI-opdateringer
5. **Input Debouncing** – Standard 800ms delay på hyppige events

```r
# Guard pattern
update_column_choices_unified() {
  if (app_state$data$updating_table ||
      app_state$columns$auto_detect$in_progress) {
    return()  # Skip hvis anden operation kører
  }
  # ... sikker opdatering
}
```

**Feature Implementation Checklist:**
1. Emit via event-bus
2. Observer i `setup_event_listeners()` med korrekt prioritet
3. Guard conditions først
4. Atomisk state update
5. UI opdatering gennem sikker wrapper
6. Debounce hyppige inputs

### 3.2 R Code Quality

* Danske kommentarer, engelske funktionsnavne
* snake_case for logik, camelCase for UI
* Type safety: `is.numeric()`, `is.character()` før beregninger
* `lintr` via `devtools::lint()` før commits

---

## 4) Workflow & Integration

### 4.1 Development Lifecycle

1. Problem definition (én linje)
2. Test design
3. Minimal implementation
4. Test verification
5. Integration testing
6. Commit preparation
7. Code review

### 4.2 Testing Strategy

* **Unit tests** – Pure functions og service-lag
* **Integration tests** – Reactive chains, event-bus, state transitions
* **Snapshot tests** – `shinytest2::AppDriver` til UI-regression
* **Performance tests** – `profvis`, `bench::mark`

**Coverage-mål:**
* 100% på kritiske stier (data load, plot generation, state sync)
* ≥90% samlet coverage
* Edge cases (null, tomme datasæt, fejl, store filer)

### 4.3 Version Control

* Atomic commits (én logisk ændring)
* Conventional commits (dansk) – se sektion 9.2
* Tests før commit
* Feature flags: `TEST_MODE_*`, `FEATURE_FLAG_*`
* CI/CD med `devtools::check()`, tests, `lintr`

---

## 5) Configuration & Environment

### 5.1 Miljøkonfiguration

**Golem-baseret:**
```r
# Læsning
config_value <- golem::get_golem_options("test_mode_auto_load", default = FALSE)

# Initialisering
Sys.setenv(GOLEM_CONFIG_ACTIVE = "dev")  # dev/test/prod
```

**Standardindstillinger:**
* **DEV:** `test_mode_auto_load = TRUE`, `logging.level = "debug"`
* **TEST:** `test_mode_auto_load = TRUE`, `logging.level = "info"`
* **PROD:** `test_mode_auto_load = FALSE`, `logging.level = "warn"`

### 5.2 Dependencies & Data

* **`renv`** – Version locking
* **`pak::pkg_install()`** – Deterministisk installation
* **Namespace calls** – `pkg::fun()` fremfor `library()`
* **Data integrity** – Bevar CSV encoding, delimiter, BOM uændret

### 5.3 External Package Ownership

✅ **VIGTIGT:** Project maintainer har fuld kontrol over følgende pakker:

* **BFHcharts** – SPC chart rendering og visualisering
* **BFHthemes** – Hospital branding, themes og fonts

**Konsekvens for SPCify udvikling:**

❌ **ALDRIG implementer funktionalitet i SPCify som hører hjemme i BFHcharts eller BFHthemes**

✅ **I STEDET:**
1. Identificer manglende funktionalitet i ekstern pakke
2. Dokumentér behovet (issue, ADR, eller docs/)
3. Informér maintainer om feature request
4. Implementér midlertidig workaround i SPCify HVIS kritisk (marker tydeligt som temporary)
5. Fjern workaround når funktionalitet er tilgængelig i ekstern pakke

**Eksempler:**
* Target line rendering → BFHcharts ansvar (ikke SPCify)
* Font fallback logic → BFHthemes ansvar (ikke SPCify)
* Hospital branding colors → BFHthemes ansvar (ikke SPCify)
* Chart styling defaults → BFHcharts ansvar (ikke SPCify)

**Integration Pattern:**
* SPCify er **integration layer** og **business logic**
* BFHcharts er **visualization engine**
* BFHthemes er **styling framework**
* Bevar klar separation of concerns

### 5.4 BFHcharts + qicharts2 Hybrid Architecture

✅ **VIGTIGT:** SPCify bruger hybrid arkitektur for SPC beregninger og visualisering.

**Architecture Decision (2025-10-18):**

SPCify anvender **både BFHcharts OG qicharts2** i en permanent hybrid løsning:

| Komponent | Ansvar | Package | Rationale |
|-----------|--------|---------|-----------|
| **SPC Plotting** | Chart rendering, visual theming, plot layers | BFHcharts | Modern ggplot2-based rendering med BFH branding |
| **Anhøj Rules** | Serielængde, antal kryds, special cause detection | qicharts2 | Valideret implementation, klinisk accepteret |

**Implementation Details:**

```r
# BFHcharts: Primary plotting engine
plot <- BFHcharts::create_spc_chart(
  data = data,
  x = x_var,
  y = y_var,
  chart_type = chart_type,
  notes_column = notes_column,
  ...
)

# qicharts2: Anhøj rules metadata extraction (UI value boxes)
qic_result <- qicharts2::qic(
  x = x_data,
  y = y_data,
  chart = chart_type,
  return.data = TRUE
)
anhoej_metadata <- extract_anhoej_metadata(qic_result)
```

**Files Involved:**

* `R/fct_spc_bfh_service.R` - BFHcharts service layer + qicharts2 Anhøj rules call
* `R/utils_qic_preparation.R` - qicharts2 input preparation
* `R/utils_qic_caching.R` - Anhøj rules caching
* `R/utils_qic_debug_logging.R` - qicharts2 debug logging
* `R/utils_qic_cache_invalidation.R` - Cache invalidation logik

**Important Constraints:**

❌ **qicharts2 må KUN bruges til:**
- Anhøj rules beregning (serielængde, antal kryds)
- Metadata ekstraktion til UI value boxes

✅ **BFHcharts skal bruges til:**
- Alle plot rendering opgaver
- Chart type handling
- Visual theming og styling
- Notes/kommentarer rendering
- Target lines og freezing

**Dependency Management:**

```r
# DESCRIPTION
Imports:
  BFHcharts (>= 0.1.0)  # Primary plotting
Suggests:
  qicharts2 (>= 0.7.0)  # Anhøj rules only
```

**Rationale for Hybrid:**

1. **BFHcharts** - Hospital-specific branding, moderne ggplot2 implementation
2. **qicharts2** - Klinisk valideret Anhøj rules, ikke planlagt til re-implementation
3. **Separation of concerns** - Plotting vs statistical rules beregning
4. **Maintenance burden** - Undgå duplikering af kompleks statistisk logik

**Future Consideration:**

Hvis BFHcharts implementerer Anhøj rules i fremtiden, kan qicharts2 dependency fjernes. Indtil da er hybrid arkitekturen permanent.

### Cross-Repository Coordination

Se omfattende koordinationsdokumentation:

**Primær guide:**
* `docs/CROSS_REPO_COORDINATION.md` - Fuld koordinationsguide med workflows, versioning, tests, og eksempler

**Quick references:**
* `.claude/ISSUE_ESCALATION_DECISION_TREE.md` - Beslutningsdiagram for issue eskalering
* `.github/ISSUE_TEMPLATE/bfhchart-feature-request.md` - Issue template til BFHcharts eskalering

**Hvornår eskalere til BFHcharts:**
* Core chart rendering bugs
* Statistiske beregningsfejl
* Manglende chart types eller features
* BFHcharts API design limitations
* Performance issues i BFHcharts algoritmer

**Hvornår fixe i SPCify:**
* Parameter mapping (qicharts2 → BFHcharts)
* UI integration og Shiny reaktivitet
* Data preprocessing og validering
* Fejlbeskeder og dansk lokalisering
* SPCify-specifik caching

Se decision tree for detaljeret guidance.

---

## 6) Architecture

### 6.1 File Organization (Golem Conventions)

**Flad struktur i `/R/`:**
* `mod_*.R` – Shiny modules
* `utils_server_*.R` – Server utilities
* `utils_ui_*.R` – UI utilities
* `fct_*.R` – Business logic
* `app_*.R` – Core app komponenter
* `config_*.R` – Configuration
* `state_management.R` – Centralized app state

### 6.2 Constraints

* Ingen automatiske commits uden aftale
* Ingen stor refaktorering uden godkendelse
* Ingen ændringer af `brand.yml`
* Ingen nye dependencies uden godkendelse
* **ALDRIG ændre NAMESPACE** uden explicit godkendelse

---

## 7) Quality Assurance

### 7.1 Pre-Commit Checklist

- [ ] Tests kørt og bestået
- [ ] Manual functionality test
- [ ] Logging valideret (strukturerede logs)
- [ ] Error handling verificeret
- [ ] Performance vurderet
- [ ] Dokumentation opdateret
- [ ] Package loading verificeret
- [ ] `lintr`/`styler` kørt
- [ ] NAMESPACE opdateret (`devtools::document()`)

### 7.2 Code Review Criteria

* **Correctness** – Logik, edge cases, reaktive afhængigheder
* **Readability** – Selvforklarende struktur, korte funktioner
* **Maintainability** – Ingen sideeffekter, solid testdækning
* **Performance** – Effektive operationer, caching
* **Consistency** – Genbrug af utils og event-bus

### 7.3 Production Readiness

* Zero failing tests
* Performance benchmarks under tærskler
* Error monitoring aktiveret
* Rollback plan dokumenteret
* User acceptance godkendt

---

## 8) Troubleshooting

### 8.1 Debugging Methodology

1. Reproducer med minimal reproduktion
2. Isolér komponent
3. Analyser strukturerede logs
4. Test antagelser
5. Instrumentér med `log_debug()`
6. Binary search (deaktiver dele)
7. Dokumentér i tests eller `docs/KNOWN_ISSUES.md`

### 8.2 Common Issues

**Reactive chains:**
* Infinite loops → Cirkulære event-afhængigheder
* Race conditions → Hybrid Anti-Race Strategy (3.1.1)
* State inconsistency → Atomiske `app_state` opdateringer

**Performance:**
* Memory leaks → `profvis`, ryd ved `session$onSessionEnded`
* Slow reactives → Debounce/throttle, cache
* UI blocking → Baggrundsjobs

**Data:**
* CSV parsing → `readr::problems()`
* Missing values → Eksplicit NA-håndtering
* Type conversion → `col_types` validering

---

## 9) Kommunikation & Dokumentation

### 9.1 Udviklerkommunikation

* Præcise action items: "Gør X i fil Y, linje Z"
* Marker manuelle skridt: **[MANUELT TRIN]**
* Faktuel rapportering
* ADR'er i `docs/adr/` (se Appendix C)

### 9.2 Commit Message Format

```
type(scope): kort handle-orienteret beskrivelse

Fritekst med kontekst, testresultater og rationale.

- Bullet points for flere ændringer
- Breaking changes markeres eksplicit
```

**Typer:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `arch`

### 9.3 Branch Protection

**Pre-commit hook blokerer direkte commits på master**

```bash
# 1. Feature branch
git checkout -b fix/feature-name
git commit -m "fix: beskrivelse"

# 2. Merge (KUN efter code review)
git checkout master
git merge fix/feature-name
git branch -d fix/feature-name
```

**Branch naming:** `fix/`, `feat/`, `refactor/`, `docs/`, `test/`

---

## 10) Advanced Patterns

### 10.1 State Management

**App State Structure** (se Appendix D for fuldt schema):
```r
app_state$events         # Event triggers
app_state$data           # Current/original data
app_state$columns        # Hierarchical: auto_detect, mappings, ui_sync
app_state$session        # Session state
```

**Event-Driven Pattern:**
```r
handle_data_upload <- function(new_data, emit) {
  safe_operation("Data upload state update", {
    app_state$data$current_data <- new_data
    emit$data_loaded()
  })
}

observeEvent(app_state$events$data_loaded, ignoreInit = TRUE,
  priority = OBSERVER_PRIORITIES$HIGH, {
  req(app_state$data$current_data)
  emit$auto_detection_started()
})
```

### 10.2 Hierarchical State Access

```r
# ✅ Korrekt
app_state$columns$auto_detect$results
app_state$columns$mappings$x_column
app_state$columns$ui_sync$needed

# ❌ Forkert (legacy)
app_state$columns$auto_detected_columns  # Brug auto_detect$results
app_state$columns$x_column               # Brug mappings$x_column
```

### 10.3 Extension Points

1. Start med tests
2. Implementér inkrementelt
3. Følg eksisterende patterns (event-bus, `app_state`, logging)
4. Dokumentér (ADR, inline-kommentarer)
5. Monitorér performance

---

## 11) Development Philosophy & Goals

**Philosophy:**
* Quality over speed – klinisk software kræver robusthed
* Test-driven confidence
* Observability først
* User-focused design for danske klinikere
* Continuous improvement via ADR'er

**Goals:**
* Stabilitet og driftsikkerhed
* Maintainability
* Performance
* Dansk language support
* Best practice compliance

---

## 12) Samtale Guidelines

**Kerneprincipper:**
* Intellektuel ærlighed – vær direkte om begrænsninger og trade-offs
* Kritisk engagement – stil spørgsmål ved vigtige overvejelser
* Balanceret evaluering – undgå tomme komplimenter
* Retningsklarhed – fokusér på projektets langsigtede kvalitet

**Succeskriterium:** Fremmer dette produktiv tænkning eller standser det?

---

## 13) Large Codebase Analysis with Gemini CLI

### 13.1 Hvornår Brug Gemini CLI

Brug `gemini -p` når du skal:

* **Analysere hele R- eller Shiny-kodebaser** på tværs af mange filer
* **Forstå sammenhængen mellem moduler, reaktive kæder og helpers**
* **Finde duplikerede mønstre eller anti-patterns** (fx ukontrollerede `observe()`-kald)
* Arbejde med **mange filer (>100 KB samlet)** eller **komplekse Shiny-projekter**
* **Sammenligne implementeringer** (fx ny vs. gammel logging, caching, theme-pakke)
* **Verificere arkitektur, moduler og funktionalitet** på tværs af hele projektet
* **Få et overblik over afhængigheder, imports og pakke-struktur**

Gemini har et **meget stort kontekstvindue** og kan håndtere **hele R-pakker eller Shiny-apps** der ville overstige andre modellers grænser.

### 13.2 Basis Kommando og Fil-inklusion

**Basis kommando:**
```bash
gemini -p "din prompt her"
```

**`@`-syntaks til fil-inklusion:**
Brug `@` til at inkludere filer eller mapper direkte i prompten. Stier skal være relative til arbejdsmappen.

**Enkeltfil-analyse:**
```bash
gemini -p "@app.R Forklar hvordan denne Shiny-app er struktureret og hvilke reaktive elementer den indeholder"
```

**Flere filer:**
```bash
gemini -p "@R/server.R @R/ui.R Beskriv hvordan input, reaktive udtryk og outputs hænger sammen"
```

**Hele pakken eller appen:**
```bash
gemini -p "@R/ @inst/ Summarize the architecture and modular structure of this Shiny package"
```

**Inkluder tests og hjælpefiler:**
```bash
gemini -p "@R/ @tests/testthat/ Analyze unit test coverage and identify missing test areas"
```

**Analyse af hele projektet:**
```bash
gemini -p "@./ Give me an overview of this R Shiny project – main modules, dependencies, and architecture"

# Alternativt:
gemini --all_files -p "Analyze project structure, dependencies, and logging implementation"
```

### 13.3 Implementerings-tjek Eksempler

**Tjek om specifikke features er implementeret:**
```bash
gemini -p "@R/ @modules/ Has the new SPC chart export feature been implemented? Show relevant functions and files"
```

**Verificér logging:**
```bash
gemini -p "@R/utils_logging.R @server.R Is structured logging (using lgr or similar) implemented consistently across modules?"
```

**Reaktivitet og performance:**
```bash
gemini -p "@R/ Is reactive chain management handled properly to avoid circular dependencies or redundant computations?"
```

**Fejlhåndtering:**
```bash
gemini -p "@R/ Are tryCatch or safe_call used consistently to handle runtime errors in Shiny observers and reactives?"
```

**Caching og datalagring:**
```bash
gemini -p "@R/ @data/ Is any caching mechanism (e.g. memoise or duckdb caching) implemented for heavy computations?"
```

**Testdækning:**
```bash
gemini -p "@tests/ @R/ Are critical modules like data transformation and SPC chart rendering covered by unit tests?"
```

**Sikkerhed:**
```bash
gemini -p "@app.R @R/ Check for potential security issues – are user inputs validated and sanitized before database operations?"
```

### 13.4 Avancerede Analyse Prompts

**Dependency graph:**
```bash
gemini -p "@R/ @modules/ @tests/ Create a dependency graph of all modules and explain their interrelations"
```

**Helper functions oversigt:**
```bash
gemini -p "@R/utils/ Summarize all helper functions and classify them by purpose (logging, data, plotting, etc.)"
```

**Code quality evaluering:**
```bash
gemini -p "@R/ @inst/theme/ Evaluate code quality and naming consistency for this custom ggplot theme package"
```

**Data flow mapping:**
```bash
gemini -p "@R/ @data/ Identify where SPC data is loaded, transformed, and visualized; map out the data flow"
```

**Detect unused code:**
```bash
gemini -p "@R/ Detect unused or redundant functions in the codebase"
```

### 13.5 Vigtige Noter

* `@`-stier er **relative til din aktuelle arbejdsmappe** når du kører `gemini`
* CLI'en **indsætter filindhold direkte i konteksten**
* Du behøver **ikke** `--yolo`-flag for læse-analyse
* Gemini's kontekstvindue kan håndtere **hele R-pakker eller Shiny-apps**
* **Vær præcis** i prompten for at få brugbare resultater

### 13.6 Integration med SPCify Workflow

Brug Gemini CLI til:

1. **Arkitektur verification** før større refaktorering
2. **Code review** på tværs af moduler
3. **Pattern detection** for at identificere inconsistencies
4. **Dependency analysis** før nye features
5. **Test coverage gaps** identifikation
6. **Security audit** af hele codebase

**Eksempel workflow:**
```bash
# 1. Analysér før refaktorering
gemini -p "@R/ Analyze current state management patterns and identify areas for centralization"

# 2. Verificér efter implementation
gemini -p "@R/state_management.R @R/utils_event_system.R Has centralized app_state been implemented consistently?"

# 3. Test coverage check
gemini -p "@tests/ @R/ Are all critical paths (data load, plot generation, state sync) covered by tests?"
```

---

## 📎 Appendix A: safe_operation()

```r
safe_operation <- function(operation_name, code, fallback = NULL, session = NULL, show_user = FALSE) {
  tryCatch({
    code
  }, error = function(e) {
    log_error(
      component = "[ERROR_HANDLER]",
      message = paste(operation_name, "fejlede"),
      details = list(error_message = e$message),
      session = session,
      show_user = show_user
    )
    return(fallback)
  })
}
```

---

## 📎 Appendix B: Performance Architecture

**Boot Strategy:**
* Production: `library(SPCify)` (~50-100ms)
* Development debug: `options(spc.debug.source_loading = TRUE)` (~400ms+)

**Lazy Loading:**
```r
LAZY_LOADING_CONFIG <- list(
  heavy_modules = list(
    file_operations = "R/fct_file_operations.R",
    advanced_debug = "R/utils_advanced_debug.R",
    performance_monitoring = "R/utils_performance.R",
    plot_generation = "R/fct_spc_plot_generation.R"
  )
)

ensure_module_loaded("file_operations")
```

**Cache System:**
* Hospital branding (TTL: 2h)
* Observer priorities (TTL: 1h)
* Chart types config (TTL: 1h)

**Performance Target:** Startup < 100ms (achieved: 55-57ms)

---

## 📎 Appendix C: ADR Template

```markdown
# ADR-001: [Navn på beslutning]

## Status
Accepted / Proposed / Deprecated / Superseded

## Kontekst
Beskriv baggrunden. Hvilket problem løses?

## Beslutning
Forklar arkitektonisk beslutning og hvorfor.

## Konsekvenser
Beskriv fordele, ulemper og nødvendige ændringer.

## Dato
[ÅÅÅÅ-MM-DD]
```

---

## 📎 Appendix D: App State Schema

```r
app_state <- new.env(parent = emptyenv())

app_state$events <- reactiveValues(
  data_loaded = 0L,
  auto_detection_started = 0L,
  auto_detection_completed = 0L,
  columns_detected = 0L,
  ui_sync_needed = 0L,
  ui_sync_completed = 0L,
  navigation_changed = 0L,
  session_reset = 0L,
  test_mode_ready = 0L
)

app_state$data <- reactiveValues(
  current_data = NULL,
  original_data = NULL,
  file_info = NULL,
  updating_table = FALSE,
  table_operation_in_progress = FALSE,
  table_version = 0
)

app_state$columns <- reactiveValues(
  # Hierarchical auto-detection sub-system
  auto_detect = reactiveValues(
    in_progress = FALSE,
    completed = FALSE,
    results = NULL,
    trigger = NULL,
    last_run = NULL,
    frozen_until_next_trigger = FALSE
  ),

  # Column mappings sub-system
  mappings = reactiveValues(
    x_column = NULL, y_column = NULL, n_column = NULL,
    cl_column = NULL, skift_column = NULL, frys_column = NULL,
    kommentar_column = NULL
  ),

  # UI synchronization sub-system
  ui_sync = reactiveValues(
    needed = FALSE,
    last_sync_time = NULL,
    pending_updates = list()
  )
)

app_state$session <- reactiveValues(
  auto_save_enabled = TRUE,
  restoring_session = FALSE,
  file_uploaded = FALSE,
  user_started_session = FALSE,
  last_save_time = NULL,
  file_name = NULL
)
```

---

## 📎 Appendix E: Configuration Quick Reference

**Se `docs/CONFIGURATION.md` for detaljeret guide.**

### Configuration Files Overview

| Fil | Ansvar | Typiske Use Cases |
|-----|--------|-------------------|
| **config_branding_getters.R** | Hospital branding (navn, logo, theme, farver) | Tilføj nyt hospital, ændre farver |
| **config_chart_types.R** | SPC chart type definitions (DA→EN mappings) | Tilføj ny chart type |
| **config_observer_priorities.R** | Observer priorities (race condition prevention) | Juster execution order |
| **config_spc_config.R** | SPC-specifikke konstanter (validation, colors) | Ændre SPC defaults, tilføj enheder |
| **config_log_contexts.R** | Centraliserede log context strings | Tilføj logging kategori |
| **config_label_placement.R** | Intelligent label placement (collision avoidance) | Tune label spacing |
| **config_system_config.R** | System constants (performance, timeouts, cache) | Juster debounce delays |
| **config_ui.R** | UI layout (widths, heights, font scaling) | Ændre UI spacing, fonts |
| **inst/golem-config.yml** | Environment-based config (dev/prod/test) | Miljø settings |

### Hvor skal nye configs?

**Beslutningsdiagram:**
```
Environment-specifikt (dev/prod/test)? → inst/golem-config.yml
UI layout/styling? → config_ui.R
SPC-specifikt (charts, colors, validation)? → config_spc_config.R / config_chart_types.R
Performance/timing (debounce, cache, timeouts)? → config_system_config.R
Logging context? → config_log_contexts.R
Branding (hospital navn, logo, farver)? → config_branding_getters.R / inst/config/brand.yml
Observer priorities? → config_observer_priorities.R
Plot label placement? → config_label_placement.R
```

### Naming Conventions

**Konstanter:**
```r
✅ SPC_COLORS <- list(...)        # ALL_CAPS
❌ spc_colors <- list(...)
```

**Funktioner:**
```r
✅ get_qic_chart_type()           # snake_case
❌ getQicChartType()
```

### Configuration Change Checklist

- [ ] Identificeret korrekt config-fil
- [ ] Fulgt naming conventions
- [ ] Tilføjet Roxygen docs med `@export`
- [ ] Opdateret relaterede tests
- [ ] Kørt `devtools::document()` hvis nødvendigt
- [ ] Manuel test i app
- [ ] Performance vurderet
- [ ] Opdateret `docs/CONFIGURATION.md` hvis major changes
