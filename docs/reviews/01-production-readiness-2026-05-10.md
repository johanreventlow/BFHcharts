# Cycle 01 — Production-Readiness Review (BFHcharts v0.17.0)

**Dato:** 2026-05-10
**Reviewer:** Claude (dual-review-cycle skill)
**Trust-grænse:** Internt hospital-net + Posit Connect Cloud (multi-tenant, PHI)
**Konsumenter:** biSPCharts (Shiny app), programmatisk SPC-graf-generering
**Pakke-version:** 0.17.0

---

## Sammenfatning

**Verdict:** **APPROVE for produktion** med ét HIGH-finding (E1) anbefalet fixet før næste release. Overordnet posture er solid: 5000 tests pass, 0 fail; 0.16.1-hardening intact; biSPCharts API-contract stabil uden hidden-`:::`-dependencies.

| Niveau | Findings | Status |
|--------|----------|--------|
| HIGH | 1 (E1) | Recommended fix før release |
| MEDIUM | 3 (E2, E4, E5) | Validator-gap + locale + doc-drift |
| LOW | 6 (S1, S2, S3, E6, E7, E8) | Defense-in-depth, ingen exploit-path |

**Test-baseline:** `devtools::test()` → `[ FAIL 0 | WARN 6 | SKIP 57 | PASS 5000 ]`. Skipped tests er render-tests bag `BFHCHARTS_TEST_RENDER=true` flag (PDF-rendering kræver Quarto + Typst). Warnings er statistical-reliability + ggplot2-NA-row, ingen test-assertion-warnings.

**Hardening verificeret (NEWS 0.16.1, alle present i koden):**
- `restrict_template` type-validering før `isTRUE()` (`R/export_pdf.R:330-350`)
- `metadata$logo_path` path-traversal + metachar-validering (`R/utils_export_helpers.R:167-179`)
- Typst `--root <staged-tempdir>` confiner image/include-access (`R/utils_typst.R:355,478-482`)
- `KNOWN_TYPST_FLAGS` allowlist for `--root`-flag-shell-quoting

---

## API-stabilitet for biSPCharts

**13 exported funktioner**, alle med stabile signatures siden v0.10.0–v0.16.0. **Zero `:::`-calls** fra biSPCharts → BFHcharts (ren public API).

Eksporterede contract-points:
- `bfh_qic()` → S3 `bfh_qic_result`
- `bfh_get_plot()`, `is_bfh_qic_result()`, `new_bfh_qic_result()`
- `bfh_extract_spc_stats()` (S3 generic)
- `bfh_merge_metadata()`, `bfh_generate_details()`, `bfh_generate_analysis()`, `bfh_build_analysis_context()`
- `bfh_export_pdf()`, `bfh_export_png()`, `bfh_create_typst_document()`
- `bfh_create_export_session()` (+ S3 `print`/`close` methods)

**Breaking changes documented i NEWS:** v0.17.0 `get_plot()` → `bfh_get_plot()`; v0.16.0 `restrict_template = TRUE` default. Begge har migration-hints. **Ingen `lifecycle::deprecated()` markers** anvendes — anbefales tilføjet ved fremtidige API-ændringer (se R8 nedenfor).

---

## HIGH

### E1 — Percent-target-normalisering misfortolker stretch-targets > 100% på proportion-skalaen

**Lokation:** `R/spc_analysis.R:136-147`

```r
.normalize_percent_target <- function(value, display, y_axis_unit) {
  if (is.null(y_axis_unit) || !identical(y_axis_unit, "percent")) {
    return(value)
  }
  if (is.na(value) || !is.numeric(value)) {
    return(value)
  }
  # Normalise when display contains "%" OR value > 1
  should_normalize <- isTRUE(grepl("%", display, fixed = TRUE)) || isTRUE(value > 1)
  if (should_normalize) value / 100 else value
}
```

**Symptom:** `validate_target_for_unit()` (`utils_helpers.R:182-222`) tillader `target_value` op til `multiply * 1.5` for percent-charts (= 1.5 ved default `multiply=1`). En klinikers stretch-mål på 105% indtastet som `target_value=1.05` på proportion-skala (default `multiply=1`) passerer validatoren. Men `bfh_build_analysis_context()` kalder `.normalize_percent_target(1.05, "", "percent")` → heuristik `value > 1` triggers → divideres med 100 → **0.0105**.

**Empirisk verifikation (kørt 2026-05-10):**

```r
> BFHcharts:::.normalize_percent_target(value=1.05, display="", y_axis_unit="percent")
[1] 0.0105                       # FORKERT: 105% → 1.05% efter normalize
> BFHcharts:::.normalize_percent_target(value=105, display="", y_axis_unit="percent")
[1] 1.05                          # Korrekt for multiply=100-input
> BFHcharts:::resolve_target(1.05)
$value: 1.05; $display: ""        # numerisk input → tom display
> BFHcharts:::resolve_target(">= 90%")
$value: 90; $display: ">= 90%"    # text-input → display indeholder %
```

**Konsekvens:** `.evaluate_target_arm()` sammenligner centerline (på 0–1 proportion-skalaen, fx 0.5) med normalized_target=0.0105 → klassificerer "centerlinje over mål" når den faktisk ligger UNDER 105%-stretch-målet. Klinikers analyse-tekst i PDF eller `bfh_generate_analysis()`-output bliver semantisk forkert. **Charten selv er korrekt** (qicharts2 modtager target=1.05 direkte) — kun den genererede narrative tekst er forvrænget.

**Trigger-betingelser** (alle skal være sande):
1. `y_axis_unit = "percent"` (almindelig hospital-brug)
2. `multiply = 1` (default for biSPCharts)
3. `target_value` numerisk i (1, 1.5] (stretch-mål >100%)
4. Brugeren læser `bfh_generate_analysis()` eller PDF-analyse-tekst

**Frekvens:** Lav — de fleste brugere passer `target_text=">= 90%"` (string) som har display med "%" og normaliseres korrekt. Men silent semantic corruption-risiko er klinisk relevant.

**Foreslået fix:** Lås heuristikken til "value > 1.5" (matcher validatorens max-bound for `multiply=1`), eller anker normalisering på en eksplicit kontrakt:

```r
# Option A (minimal):
should_normalize <- isTRUE(grepl("%", display, fixed = TRUE)) || isTRUE(value > 1.5)

# Option B (robust): tjek mod multiply via context-arg
.normalize_percent_target <- function(value, display, y_axis_unit, multiply = 1) {
  ...
  has_percent_marker <- isTRUE(grepl("%", display, fixed = TRUE))
  is_percent_scale  <- isTRUE(value > multiply)   # multiply=1 → >1 = invalid; multiply=100 → >100 = invalid
  if (has_percent_marker || is_percent_scale) value / 100 else value
}
```

Option A er mindste-diff og bevarer eksisterende test-coverage. Option B kræver `bfh_build_analysis_context()` propagerer `multiply` fra `x$config`.

**Test-tilføjelse:**

```r
test_that("E1: stretch-target 1.05 with multiply=1 is preserved", {
  expect_equal(.normalize_percent_target(1.05, "", "percent"), 1.05)
})
```

---

## MEDIUM

### E2 — `cl = Inf` slipper forbi validatoren

**Lokation:** `R/utils_bfh_qic_helpers.R:447-450` + `R/utils_helpers.R:108-124`

```r
validate_numeric_parameter(cl, "cl", min = -Inf, max = Inf, allow_null = TRUE, len = 1)

# I validate_numeric_parameter:
if (!is.numeric(value) || any(is.na(value))) { stop(...) }
if (any(value < min) || any(value > max)) { stop(...) }
```

**Symptom:** `is.na(Inf) == FALSE`; `Inf < Inf == FALSE`; `Inf > Inf == FALSE`. Værdien passerer alle checks og flyder til `qicharts2::qic()` som producerer NaN-limits og forvrænget chart, mens `cl_user_supplied=TRUE`-warningen stadig udsendes som om alt er normalt.

**Foreslået fix:** Tilføj `is.finite()`-check i `validate_numeric_parameter()`:

```r
if (any(!is.finite(value))) {
  stop(sprintf("%s must be finite, got: %s", param_name, paste(value, collapse=", ")), call. = FALSE)
}
```

`target_value` er allerede korrekt guarded i `R/config_objects.R:132-136`. Apply same til `cl`.

---

### ~~E3 — DISMISSED af Codex 2026-05-10~~

Original claim modbevist empirisk: `R/config_objects.R:132-135` validerer allerede `target_value` for non-scalar / NA / NaN / Inf via `spc_plot_config()` (kaldt fra `bfh_qic` initialiseringen) før `validate_target_for_unit()` tilgås. Se reconcile-section nedenfor for detaljer.

---

### E4 — `format_target_value()` hardcoder dansk decimal-separator i engelsk analyse

**Lokation:** `R/spc_analysis.R:889-909`

```r
format_target_value <- function(x, y_axis_unit = NULL) {
  ...
  format(round(x, 2), decimal.mark = ",", nsmall = 1)
}
```

**Symptom:** `bfh_generate_analysis(..., language = "en")` producerer engelsk analyse-tekst der indeholder dansk-formaterede decimaler (`"1,5"` i stedet for `"1.5"`). Kaldes fra `.evaluate_target_arm()` (linje 740) og no-variation-grenen (linje 842).

**Foreslået fix:** Tråd `language` igennem helperen — samme pattern som `R/utils_y_axis_formatting.R:120` allerede anvender:

```r
format_target_value <- function(x, y_axis_unit = NULL, language = "da") {
  ...
  format(round(x, 2), decimal.mark = if (identical(language, "en")) "." else ",", nsmall = 1)
}
```

---

### E5 — Doc/code drift: `summary` documenteret som `tibble`, returneres som `data.frame`

**Lokation:** Doc i `R/bfh_qic_result.R:20,25,46`; impl i `R/utils_qic_summary.R:151,263,275,282`

```r
# bfh_qic_result.R doc:
#'   \item{summary}{tibble with summary statistics}

# utils_qic_summary.R:
formatted <- data.frame(..., stringsAsFactors = FALSE)
```

**Symptom:** Caller (incl. biSPCharts) der stoler på tibble-specifik adfærd — `[, "col"]` returnerer 1-col tibble, list-column-tolerance, `print()`-truncation — får plain `data.frame` hvor `[, "col"]` returnerer en vector. Future refactor der wrapper `tibble::as_tibble()` ville være en silent breaking change for downstream-kald.

**Konsekvens:** API-contract-ambiguitet for biSPCharts-integration. Verificeret i Explore-pass: biSPCharts bruger ikke `[`-subsetting på `$summary`, så ingen aktuel breakage. Men risikoen for fremtidig regression er reel.

**Foreslået fix:** Vælg én og dokumentér eksplicit:
- **Option A** (anbefalet): Opdater roxygen → `data.frame with summary statistics` (matcher impl, bevarer attr `cl_user_supplied` uden tibble-attr-stripping-risiko).
- **Option B**: Wrap impl i `tibble::as_tibble()` + verify `attr<-` overlever på tibble-objekter (nogle tibble-operationer dropper user-attrs).

A er mindste-diff og lavest-risiko.

---

## LOW (defense-in-depth, ingen exploit-path)

### S1 — TOCTOU mellem `dir.create()` og `Sys.chmod(0700)` i staging-tempdirs

**Lokation:** 3 sites — `R/utils_export_helpers.R:341-349`, `R/export_session.R:89-96`, `R/utils_typst.R:330-332`

```r
dir <- tempfile("bfh_tpl_")
dir.create(dir, recursive = TRUE)              # mode 0777 & ~umask -- typisk 0755
Sys.chmod(dir, mode = "0700", use_umask = FALSE)
```

**Symptom:** I vinduet mellem `dir.create()` og `Sys.chmod()` er dir verden-readable/searchable. På Connect Cloud er per-tenant `tempdir()` typisk `0700` på parent-niveau, så exploit-vindue kun materialiseres ved misconfigured host-tempdir. **Ingen exploit-path under nuværende deploy-konfiguration.**

**Foreslået fix:** Atomisk perms-set via `dir.create(..., mode = "0700")`:

```r
dir.create(dir, recursive = TRUE, mode = "0700")
Sys.chmod(dir, mode = "0700", use_umask = FALSE)  # belt-and-suspenders
```

---

### S2 — Information disclosure: fulde filsystem-paths i `stop()`/`warning()`-beskeder

**Lokation:** `R/utils_typst.R:117, 146-147, 283-284, 336-337, 429, 445` (pattern-wide)

```r
stop("Typst template not found at: ", src, "\n",
     "  This should not happen. Please reinstall BFHcharts.",
     call. = FALSE)
```

**Symptom:** Kun `.truncate_compile_output()` (`utils_typst.R:210-215`) redacter `tempdir()`. Andre paths returner raw absolute paths. Hvis biSPCharts viser `conditionMessage(e)` i UI eller logger til ekstern log-shipper, eksponeres home-dir-layout, R-library-install-path, og per-session tempdir-naming — useful reconnaissance for co-tenant.

**Foreslået fix:** Extract `.redact_paths()` helper fra `.truncate_compile_output()` og apply til alle user-visible errors. Eller brug `basename()` hvor full-path ikke tilfører diagnostisk værdi.

---

### S3 — `bfh_create_typst_document()` accepterer symlink-`chart_image`

**Lokation:** `R/utils_typst.R:37, 58-67, 156-161` (eksporteret funktion)

```r
#' @export
bfh_create_typst_document <- function(chart_image, output, metadata, ...) {
  validate_export_path(output)
  validate_export_path(chart_image)
  ...
  chart_image_norm <- normalizePath(chart_image, mustWork = TRUE)
  ...
  copy_success <- file.copy(chart_image, local_chart, overwrite = TRUE)
```

**Symptom:** `validate_export_path()` kører syntaktisk check, men `normalize=TRUE` sættes ikke. `file.copy()` følger symlinks for source-filer. Co-tenant kan plante `/tmp/co-staging/chart.png` som symlink → `/var/lib/connect/tenant-A/data/cached_qic.svg`. Hvis biSPCharts (eller anden caller) videreformidler en chart-image-path fra semi-trusted input, kan tenant-A's PHI-SVG ende i tenant-B's PDF.

**Mitigation:** Eksporteret som "trusted-caller"-API per vignette. Ingen aktuel exploit-path under biSPCharts' nuværende kontrol-flow (chart_image generes lokalt via `ggsave()`).

**Foreslået fix:** Re-validér efter `normalizePath`:

```r
chart_image_norm <- normalizePath(chart_image, mustWork = TRUE)
validate_export_path(chart_image_norm)  # confirm post-symlink-resolution path is also safe
```

Eller dokumentér eksplicit symlink-trust-kontrakten i `@section Security`.

---

### E6 — `format_qic_summary()` håndterer ikke tom `qic_data`

**Lokation:** `R/utils_qic_summary.R:91-138`

`bfh_qic()` blokerer `nrow(data) == 0` upstream (`utils_bfh_qic_helpers.R:310`), så bug trigger kun hvis qicharts2 selv returnerer empty (extrem `exclude`-konfiguration). Defensive-only.

**Foreslået fix:** Early-return tom skema-stub.

---

### E7 — `freeze = 1` accepteret på `nrow(data) = 1`

**Lokation:** `R/utils_bfh_qic_helpers.R:399-403`

```r
validate_position_indices(freeze, "freeze", nrow(data),
  ..., min = 1L, max = max(nrow(data) - 1L, 1L)
)
```

**Symptom:** `max(0, 1) = 1`, så `freeze=1` accepteres på 1-row data. qicharts2 producerer kryptisk fejl. Marginal frekvens (1-row clinical data er ekstremt sjælden).

**Foreslået fix:** Drop `max(..., 1L)` floor; lad valideringen fejle rent når `nrow - 1 < 1`.

---

### E8 — Negative `y` ikke valideret for count-charts (`c`, `g`, `t`)

**Lokation:** `R/utils_bfh_qic_helpers.R:341-352`

`bfh_qic(..., chart_type = "c", y = c(5, -1, 7))` accepteres og rendrer en statistisk meningsløs chart uden warning.

**Foreslået fix:** Chart-type-aware y-domain-check. Counts skal være ≥0.

---

## Verified safe (kort)

- **YAML deserialization** (`R/utils_i18n.R:36`): kun `system.file()`-paths efter `validate_language()` allowlist `c("da","en")`. Ingen user-controlled YAML.
- **commonmark+xml2 parser**: input strikt fra `commonmark::markdown_xml()`, ingen `DOCTYPE`/external entities. Ingen XXE-vektor.
- **Shell-injection**: `.safe_system2_capture()` (`R/utils_typst.R:383-395`) allowlister `KNOWN_TYPST_FLAGS` og `shQuote()`-er øvrige args. Binary-path valideret via `.validate_binary_path()` + `.check_metachars_binary()`.
- **Template-identifier injection**: regex `^[a-zA-Z][a-zA-Z0-9_-]*$` allowlist før string-interpolation (`R/utils_typst.R:546-550`).
- **Audit-log**: `getOption()`-only path, PHI-fri payload (kun `names(spc_result)` + metadata-keys, ingen values — `R/spc_analysis.R:501-511`).
- **Markdown→Typst escaping**: `escape_typst_text()` for raw HTML; `markdown_to_typst()` escaper `# $ @ _ * [ ] < > backtick ~ ^ \` i text-noder.
- **`--root`-confinement**: alle Typst `image()`/`read()`/`include`-reads bundet til staged template-tempdir, selv hvis fremtidig metadata-validering misses.
- **NSE column-name validator**: UTF-8 letter-class via `\p{L}`-regex; propagerer som `as.name()`-symbol til qicharts2 (`R/utils_bfh_qic_helpers.R:225-246`).
- **`validate_denominator_data()`**: korrekt fanger zero/negative/Inf-denominators, proportion-violations (y > n), missing `n_col`.
- **`add_anhoej_signal()`**: korrekt NA-fallback for kort serie.
- **`build_bfh_qic_return()`**: `attr(summary, "cl_user_supplied")` stamped consistent på både S3 og `return.data`-paths.
- **`.muffle_expected_warnings()`**: anchored regex; sluger ikke data-quality-warnings.
- **`tryCatch(..., NULL)`**: kun non-load-bearing concerns (font-lookup, dev-cleanup, optional Quarto-detection). Ingen silent error-swallowing på SPC-compute-path.

---

## Recommendations (prioriteret)

### Pre-release (anbefalet før næste tag)

1. **Fix E1** (HIGH): Tighten `value > 1` heuristik til `value > 1.5` eller propagér `multiply` til normaliseringen. Tilføj regression-test for stretch-target på proportion-skala.
2. **Fix E2** (MEDIUM): Tilføj `is.finite()`-check i `validate_numeric_parameter()` så `cl=Inf` fanges ved early validation med klar fejl-besked frem for at fejle nedstrøms i `yA_npc`-render-pathen. (E3 var dismissed af Codex — `config_objects.R:132-135` håndterer allerede `target_value`-finiteness.)
3. **Resolve E5** (MEDIUM): Opdater roxygen i `bfh_qic_result.R` til `data.frame` (mindste-diff, bevarer attr-flow). Verificér med biSPCharts-maintainer at ingen relier på tibble-methods.

### Næste sprint

4. **Fix E4** (MEDIUM): Tråd `language` igennem `format_target_value()` + alle call-sites.
5. **Fix E6–E8** (LOW): Defensive-programming PR. Bundlér.
6. **Fix S1** (LOW): One-line `mode = "0700"` på `dir.create()` (3 sites).
7. **Fix S2** (LOW): Extract `.redact_paths()` + apply til user-visible errors.
8. **Fix S3** (LOW): Re-validér post-symlink-resolution i `bfh_create_typst_document()`, eller dokumentér trust-kontrakten.

### Strategisk

R8. **Tilføj `lifecycle::deprecated()`-markers** ved fremtidige API-ændringer. Pakken har ingen aktuelle deprecations, men når næste breaking change kommer (post-1.0), giver `lifecycle::` brugbar runtime-feedback til biSPCharts.

R9. **Document public-contract-matrix** i ADR eller `vignettes/api-contract.Rmd`: hvilke felter af `bfh_qic_result$summary` er guaranteed stable, hvilke er internal qicharts2-passthrough?

R10. **Pin BFHcharts version-bound i biSPCharts DESCRIPTION** efter denne review's fixes: `BFHcharts (>= 0.17.1)` (eller hvilket version-bump end fixe E1).

R11. **Overvej 1.0-release-vej** per VERSIONING_POLICY.md §F når public API har været stabil i ≥3 måneder uden breaking changes (ser ud til at være tæt på allerede). Krav: ≥90% test-coverage på exports, fuld roxygen + `@examples`, deprecation-policy med ≥1 minor-warning før breaking removal.

---

## Audit-trail

- Test-baseline: 5000 PASS / 0 FAIL / 6 WARN / 57 SKIP (`devtools::test()` 2026-05-10)
- Hardening-claims i NEWS 0.16.1 verificeret in-code
- biSPCharts API-usage cross-checked: 0 `:::`-calls, 10 public-`::`-call-sites
- Empirisk repro for E1: dokumenteret ovenfor
- Threat-model: Posit Connect Cloud multi-tenant, PHI i charts

## Codex adversarial-review konsekvens (2026-05-10)

**Verdict:** approve med E1 + E4 fix før release; E2 + E5 kan inkluderes i samme cycle.

**Bekræftet (verified empirisk af Codex):**
- **E1** (HIGH): `.normalize_percent_target(1.05, "", "percent") -> 0.0105` reproduceret. Eksisterende tests `test-spc_analysis.R:655-694` bestod alle under `value > 1.5`-fix uden regressions.
- **E4** (MEDIUM): `format_target_value(1.5, "count") -> "1,5"` direkte reproduceret. `bfh_generate_analysis(..., language="en")` producerede tekst med `"1,5"`.
- **E5** (MEDIUM): biSPCharts grep fandt kun `$summary`-access ved `utils_export_analysis_metadata.R:43-47`; ingen tibble-style `[, "col"]`-subscripting. Doc-update er low-risk.

**Recalibreret:**
- **E2** (MEDIUM, fastholdt): Validator-gap (`is.na(Inf)==FALSE`, bounds slipper `Inf` igennem) bekræftet. Codex empirisk probe viser dog at `cl=Inf` IKKE producerer NaN-limits eller "non-sensical chart" som original-claim sagde — den fejler nedstrøms med `yA_npc must be finite` (efter custom-CL-warning er udsendt). Konsekvens: validator-besked vildledende, men ingen silent corruption. Behold MEDIUM på validator-fix-grundlag.

**Dismissed (empirisk modbevist af Codex — peer-review-laundering caught):**
- **E3** (var MEDIUM): `R/config_objects.R:132-135` validerer ALLEREDE `target_value` for non-scalar / NA / NaN / Inf før `validate_target_for_unit()` tilgås. Empirisk repro: `bfh_qic(..., target_value=NaN)` og `bfh_qic(..., target_value=c(1,2))` fejler begge med `target_value must be a single finite numeric value or NULL`. **Original code-analyzer-citat var en partial-view af validation-chain — config_objects-laget blev overset.** Selvstændigt verificeret 2026-05-10. Finding fjernet.

**Læring (memory-encode):**
1. **Chained-validation-blindness**: Subagent kan citere én lag i en multi-lag valideringschain og misse upstream-checks. Reproduktion-rule (skill Rule 1) skal anvendes på hver MEDIUM+ finding, ikke kun HIGH. Codex's empirisk-først-tilgang fangede E3 fordi den kørte `bfh_qic(...)` end-to-end frem for at læse koden statisk.
2. **Heuristic-fix safer than scope-creep**: Fix Option A (`value > 1.5`) er mindste-diff og brydder ingen tests. Option B (propagér multiply) ville krævet refactor af `bfh_build_analysis_context`-signature; gemmes til evt. fremtidig 1.0-API-rendering hvor multiply explicitly ekspones i public contract.

**Codex impact-bucketing (verified savings):**
- Hard runtime-saves: 0
- Semantic/silent-corruption-saves: 1 (E1 — wrong narrative for clinicians)
- False-confidence/process-saves: 1 (E2 — misleading validator)
- Locale/cleanup: 1 (E4)
- Doc-drift: 1 (E5)
- Dismissed (peer-review-laundering caught): 1 (E3)
