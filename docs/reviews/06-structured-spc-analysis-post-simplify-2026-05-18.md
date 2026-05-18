# Cycle 06 — Post-/simplify Hygiene Review

**Område:** `feat/structured-spc-analysis` branch state post cycle 04+05+/simplify cleanup.
**Trigger:** Bruger-anmodet `/dual-review-cycle` efter `/simplify`-commit.
**Reviewer:** Claude (Explore + code-analyzer subagents, parallel Phase 1).
**Verdict:** approve-with-cleanup.

---

## Scope

Verificer at /simplify cleanup (`16282a0`) ej introducerede regressioner. Identificer eventuelle hygiene-issues missed af tidligere review-cycles.

**Diff:** `develop..HEAD` (4 commits, 1e8096c~1..HEAD).

**Coverage tjekket:**
1. Helper-extraction substituering (`.has_centerline`, `.has_finite_spread`)
2. Atomic Anhoej-signal-detectors (`.has_runs_signal`, `.has_crossings_signal`, `.has_outliers_signal`)
3. `LOW_CONFIDENCE_REASONS`-konstant brug
4. `chart_class` hoist order-of-operations
5. `skip_tautological()` regression-coverage
6. `.compose_modifier_sentence` dispatch-completeness
7. Cycle 04+05 finding-fixes intakte

---

## Findings

### M1 [LOW] — Schema-validator enforcer ej `low_confidence_reason`-enum

**Lokation:** `R/bfh_spc_analysis_class.R:125-204` (`validate_bfh_spc_analysis`).

**Symptom:** Konstanten `LOW_CONFIDENCE_REASONS = c("few_obs", "no_centerline", "no_spread")` findes i `R/globals.R:199` og dispatch-er korrekt i `R/spc_render.R:388` (med safety-fallback til `"few_obs"`). Men validatoren tjekker KUN `confidence_tier %in% c("low","medium","high")` -- ej `low_confidence_reason`.

**Verifikation (kode-citat):**

```r
# R/bfh_spc_analysis_class.R:191-201
if (!is.null(x$features$confidence_tier) &&
  !x$features$confidence_tier %in% c("low", "medium", "high")) {
  stop("confidence_tier ej i tilladt enum-set", call. = FALSE)
}
# ... low_confidence_reason check MISSING
```

**Konsekvens:** Eksterne consumers (biSPCharts UI, future audit-replay) der antager `low_confidence_reason` matcher dokumenteret enum kan modtage `NULL` eller garbage uden runtime-fejl. Currently safe fordi `.compute_low_confidence_reason()` aldrig producerer non-enum-værdier, men kontrakten er asymmetrisk: `confidence_tier` enforced strictly, `low_confidence_reason` ej.

**Foreslået fix (R-snippet, verified operator-precedence):**

```r
# Tilfoejes efter eksisterende confidence_tier-check
lcr <- x$features$low_confidence_reason
if (!is.null(lcr) && !is.na(lcr) && !lcr %in% LOW_CONFIDENCE_REASONS) {
  stop(
    sprintf(
      "low_confidence_reason ej i tilladt enum-set: '%s' (tilladte: %s)",
      lcr, paste(LOW_CONFIDENCE_REASONS, collapse = ", ")
    ),
    call. = FALSE
  )
}
```

R-quirk verifikation: `!lcr %in% LOW_CONFIDENCE_REASONS` parser som `!(lcr %in% LOW_CONFIDENCE_REASONS)` -- `!` har lavere precedence end `%in%` i R. Korrekt semantik bekræftet via `Rscript -e '!"x" %in% c("x")'` → `FALSE`.

---

### M2 [LOW] — Dead `has_signals`-state i `bfh_build_analysis_context()`

**Lokation:** `R/spc_analysis.R:270-287` (inline computation) + `:352` (list-entry).

**Symptom:** /simplify cleanup ekstraherede atomic detectors (`.has_runs_signal` osv.) men efterlod inline 18-linje `has_signals`-block i `bfh_build_analysis_context()`. Production-code reader ej -- kun tests:

**Verifikation:**

```r
# R/spc_analysis.R:271-287 (excerpt)
has_signals <- FALSE
if (!is.null(spc_stats$runs_actual) && ...
    spc_stats$runs_actual > spc_stats$runs_expected) {
  has_signals <- TRUE
}
# ... 15 lines af duplikeret logic
```

Greppet for `context$has_signals` viser KUN:
- `tests/testthat/test-spc_analysis.R:42,49` (sanity-check fields exist)
- `tests/testthat/helper-fixtures.R:259` (fixture-entry)

Ingen production-kode læser feltet. Cycle 05 finding #4 erstattede AI-path med atomic-detectors, men context-time block forblev.

**Konsekvens:** Behavior-neutral DRY-miss. Duplikeret logic skaber drift-risiko hvis fremtidig change i en path ej spejles. Tests + fixtures forventer fieldet eksisterer -- kan ej slettes uden test-cleanup.

**Foreslået fix:** Refactor inline-block til atomic-detector-kald (behold field-output, men brug helpers):

```r
# R/spc_analysis.R:270-287 replaced med:
has_signals <-
  .has_runs_signal(spc_stats$runs_actual, spc_stats$runs_expected) ||
  .has_crossings_signal(spc_stats$crossings_actual, spc_stats$crossings_expected) ||
  .has_outliers_signal(spc_stats$outliers_recent_count, spc_stats$outliers_actual)
```

Ingen test-changes; field-output bevares. -15 linjer dupliceret logic.

---

### M3 [LOW] — `cl_user_supplied`-substring-assertion låst bag `skip_tautological()`

**Lokation:** `tests/testthat/test-spc_parity_phase1.R:225-228`.

**Symptom:** Sub-corpus 7 (`parity: stable data, cl = 50`) indeholder en substring-assertion der IKKE er tautologisk:

```r
# tests/testthat/test-spc_parity_phase1.R:225-228
expect_semantic_text_equal(texts$new, texts$legacy)  # tautologisk
expect_match(texts$new, "midtlinje fastsat manuelt",  # IKKE tautologisk
  ignore.case = TRUE
)
```

Begge linjer er bag `skip_tautological()` i samme test-block. Den anden assertion verificerer at `cl_user_supplied`-caveat-prose rendres -- regression-værdi for Slice 9.

**Konsekvens:** Lille test-coverage gap. `test-spc_slice09_cl_disclosure.R` dækker sandsynligvis samme path (afhænger af test-design), men dette specifikke smoke-test af `bfh_generate_analysis()`-output mister regression-detect.

**Foreslået fix:** Enten:
1. Migrer substring-assertion til ny test_that-block som IKKE skipper, eller
2. Defer til Phase 99.1.2 snapshot-baseline implementation (allerede i file-header).

Severity LOW: andre tests dækker functionality.

---

## Sammenfatning

| ID | Severity | Type | Status |
|----|----------|------|--------|
| M1 | LOW | Contract asymmetry (validator-enum) | Verified |
| M2 | LOW | Dead code / DRY-miss | Verified (test-coverage prevents delete) |
| M3 | LOW | Test-coverage gap | Verified |

**Verdict foreloebig:** approve-with-cleanup. Ingen HIGH/MEDIUM. /simplify-cleanup behaviour-neutral; 3 mindre hygiene-issues identificeret.

---

## Codex trigger-decision

**Triggers tjekket:**
- [x] Executable R-snippet (M1 validator-recipe)
- [ ] Cross-package contract-claim
- [ ] CI-gate ændring
- [ ] Empirisk claim
- [ ] Repeated failure pattern
- [ ] Clinical-data semantics
- [ ] Severity-vurdering driver implementation-scope

**Beslutning: SKIP Codex.**

Rationale:
- Alle 3 fund LOW severity
- M1 R-snippet er 3-linjer + matcher eksisterende validator-pattern i samme fil (lavt risiko for operator-precedence-fejl, allerede verificeret med R-session)
- M2 er behavior-neutral refactor
- M3 er test-cleanup
- /simplify cleanup brugte allerede 3-agent parallel review (reuse + quality + efficiency) — Codex pass marginal ROI

Per skill-konstant: "Codex-skip threshold: Ingen executable-recipes + ingen contracts" — M1 har en mini-recipe, men under kalibreret threat-model med independent R-session-verifikation er separat Codex-pass overkill.

---

## Pending implementations

Anvendes i samme PR-batch som cleanup-commit:
- M1: tilføj `low_confidence_reason`-enum-check til validator
- M2: refactor inline `has_signals`-block til atomic-detectors
- M3: lift `cl_user_supplied`-substring-assertion ud af skipped block (separate test_that)

Estimeret samlet diff: ~25 linjer (+10 net).
