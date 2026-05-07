# BFHcharts Code Review — 2026-05-07

Konsolideret rapport fra 8 parallelle review-agents på `develop` @ 8311bbb.

**Hovedindtryk:** Production-grade pakke. ASCII-policy ren. Ingen TODO/FIXME-spread. Test-suite omfattende (1191 `test_that` blocks). Typst PDF-pipeline security exceptionel. Hovedfund: enkelte CRAN-blockers, manglende input-validation på exporteret API, perf-flaskehalse i note-placement og curved-arrow-rendering.

---

## 🔴 HIGH — fix før release

### H1. `globalVariables` skjuler manglende namespace-prefix → CRAN warning
- **Files:** `R/globals.R:18`, `R/utils_date_formatting.R:67,78`
- **Issue:** `median`, `var`, `head`, `tail` kaldes uden `stats::` / `utils::` prefix. `globalVariables()` er kun til NSE column-bindings — bruges her til at skjule function-resolution NOTEs. Fejler `R CMD check --as-cran`.
- **Fix:** Erstat bare calls med `stats::median()`, `stats::var()`, `utils::head()`, `utils::tail()`. Fjern fra `globalVariables()`.

### H2. `get_plot()` bryder `bfh_*` naming + risiko namespace-collision
- **File:** `R/bfh_qic_result.R:134`
- **Issue:** Eksporteret med generisk navn brugt af ggplot2/plotly-økosystemet. Bryder stated arkitektur (alle exports `bfh_*`).
- **Fix:** Omdøb `bfh_get_plot()` ELLER fjern (result$plot dækker accessor-use-case; `plot.bfh_qic_result` dækker dispatch). Breaking change → NEWS-entry + version bump.

### H3. `validate_bfh_qic_inputs()` mangler `x`-kolonne validation
- **File:** `R/utils_bfh_qic_helpers.R:294-319`
- **Issue:** y-kolonne valideres (existence + class), x-kolonne IKKE. Typo i `x = manth` bobler op som kryptisk NSE-fejl fra qicharts2.
- **Fix:** Spejl y-blokken: assert `x_expr_char %in% names(data)`; reject character/factor x med samme class-hint som y.

### H4. `notes` length ej valideret vs `nrow(data)`
- **File:** `R/utils_bfh_qic_helpers.R:504`, kaldet fra `R/bfh_qic.R:606-607`
- **Issue:** Doc siger "same length as data" men ingen runtime-check. Length-mismatch giver silent misalignment med data-rows.
- **Fix:** Assert `is.null(notes) || (length(notes) == nrow(data))` + `is.null(notes) || is.character(notes)` med eksplicit fejl.

### H5. `target_text` ej type/length-valideret
- **File:** `R/bfh_qic.R:606`
- **Issue:** Passed direkte til `apply_spc_labels_to_export()` + `render_bfh_plot()`. Ikke-character el. length-N fejler dybt i marquee.
- **Fix:** Assert `is.null(target_text) || (is.character(target_text) && length(target_text) == 1L)` tidligt.

### H6. O(N·M·K) note-placement scoring
- **File:** `R/utils_note_placement.R:115-380`
- **Issue:** Triple-nested non-vectoriseret loop. 50-500ms per render w/ comments. Per-row `data.frame[i, ]` copies + `c()` growing.
- **Fix:**
  1. Vektorisér segment intersection: pre-compute `seg_dx`, evaluer alle `xc` med vektor-arithmetik
  2. Pre-allocér `x_checks` med fixed length 5 i.s.f. `c()` growing (linje 302-305)
  3. Konvertér `segments_norm` + `data_points_norm` fra data.frame til named numeric vectors
  4. Compute candidate matrix (20×2) én gang, score via matrix-ops

### H7. Per-row `geom_curve()` layer-add → O(N²)
- **File:** `R/plot_enhancements.R:255-271`
- **Issue:** `for (cr in seq_len(nrow(curved))) plot <- plot + geom_curve(data = curved[cr, ], curvature = curved$curvature[cr])`. Hver layer-append rebuilder ggplot internals + indexing-bug (`curved$curvature[cr]` hentet fra fuld vektor mens data er én række).
- **Fix:** Gruppér rows efter `curvature` (kun ±0.25 værdier eksisterer), emit max 2 layers via `purrr::reduce(unique_curvs, \(p, k) p + geom_curve(data = subset, curvature = k, ...), .init = plot)`.

### H8. `ifelse()` inde i `aes()` → recompute per draw
- **File:** `R/plot_core.R:217`
- **Issue:** `linetype = ifelse(is.na(anhoej.signal), FALSE, anhoej.signal)` evalueres ved hver plot-draw + tvinger NSE.
- **Fix:** Precompute før ggplot: `qic_data$anhoej.signal <- dplyr::coalesce(qic_data$anhoej.signal, FALSE)`, derefter `aes(linetype = anhoej.signal)`.

---

## 🟡 MEDIUM

### M1. TOCTOU på tempdir-permissions
- **Files:** `R/utils_export_helpers.R:341-349`, `R/export_session.R:89-96`, `R/utils_typst.R:330-332`
- **Issue:** `dir.create()` (default umask 0755) → `Sys.chmod(0700)` har race-window. På multi-tenant Linux/Connect: same-host attacker kan symlink-plante.
- **Fix:** `dir.create(temp_dir, recursive = TRUE, mode = "0700")` direkte.

### M2. Asymmetrisk extension validation
- **Files:** `R/export_png.R:91` (`ext_action = "warn"`) vs `R/utils_export_helpers.R:122` (`"stop"`)
- **Fix:** Sæt PNG-export til `"stop"` (eller dokumentér asymmetri).

### M3. Silent NULL-fallback skjuler template cache-failure
- **Files:** `R/utils_typst.R:110-115, 294-299`
- **Issue:** `tryCatch(.get_or_stage_template_cache(), error = function(e) system.file(...))` swallower fejl uden log.
- **Fix:** Emit `warning("Template cache unavailable: ", conditionMessage(e), " — falling back to package install path", call. = FALSE)` før fallback.

### M4. Danske `stop()`-strings i `R/*.R`
- **File:** `R/utils_panel_measurement.R:63, 67`
- **Fix:** Translatér til engelsk (R-package error standard).

### M5. Doc-completeness gaps (1.0-readiness)
- **`new_bfh_qic_result`** mangler `@examples` — `R/bfh_qic_result.R:61`
- **`close.bfh_export_session`, `print.bfh_export_session`** mangler `@method` tags + `@param`/`@return` — `R/export_session.R:142,147`
- **`is_bfh_qic_result`** mangler `@examples` — `R/bfh_qic_result.R:147`
- **`"_PACKAGE"` sentinel** har `@noRd` → `?BFHcharts` fejler — `R/BFHcharts-package.R:57`. Fjern `@noRd`.

### M6. S3 print-methods exporteret men constructors `@noRd`
- **Files:** `R/config_objects.R:170,243`
- **Issue:** `print.spc_plot_config` + `print.viewport_dims` exported men constructors internal. Inkonsistent — viser i `methods()` men kan ej oprettes.
- **Fix:** Tilføj `@method print spc_plot_config` + `@noRd` uden `@export`.

### M7. DRY — latest-part CL extraction triplikeret
- **Files:** `R/fct_add_spc_labels.R:167-179`, `R/plot_core.R:257-260`, `R/plot_enhancements.R:71-99`
- **Fix:** Extract til `R/utils_helpers.R::get_latest_part_cl(qic_data)` returnerende `list(value, row, latest_part)`.

### M8. DRY — first-non-NA target idiom
- **Files:** Same 3 filer som M7
- **Fix:** `get_first_target(qic_data)` helper.

### M9. DRY — Date/POSIXct-juggling 16+ steder
- **Files:** `plot_enhancements.R:53-65, 160-205`, `utils_add_right_labels_marquee.R:300-356`, `plot_core.R:319-322`
- **Fix:** `R/utils_x_type.R` modul med `is_temporal_x`, `to_numeric_x`, `restore_x_type`.

### M10. DRY — `c()`-growing i `build_typst_content` 4 steder
- **Files:** `R/utils_typst.R:567-582, 615-622, 646-649`
- **Fix:** `vapply()` el. `purrr::iwalk()` helper `assign_string_params(params, metadata, fields, formatter)`.

### M11. DRY — duplikeret integrity-check pattern
- **File:** `R/utils_typst.R:84-101, 161-178`
- **Fix:** `safe_copy_with_integrity(src, dest, label)` helper.

### M12. SRP-brud — `add_plot_enhancements` 264 linjer
- **File:** `R/plot_enhancements.R:30-293`
- **Fix:** Split: `add_extended_cl_target_lines` (L48-145), `add_comment_annotations` (L148-290) → `compute_comment_arrow_endpoints`, `add_arrow_layers`.

### M13. SRP-brud — `add_spc_labels` 311 linjer
- **File:** `R/fct_add_spc_labels.R:75-385`
- **Fix:** Extract pure `compute_label_pref_sides(npc_A, npc_B, threshold)` (L295-350); parameterisér magic threshold 0.30.

### M14. SRP-brud — `bfh_create_typst_document` 148 linjer
- **File:** `R/utils_typst.R:58-205`
- **Fix:** Split til `resolve_template_source()`, `stage_template_to_outdir()`, `stage_chart_image()`; orchestrator ~30 linjer.

### M15. SRP-brud — `validate_bfh_qic_inputs` 173 linjer
- **File:** `R/utils_bfh_qic_helpers.R:277-449`
- **Fix:** Extract `validate_plot_margin(plot_margin)` (L404-435) + `warn_phase_sizes(part, n_total)` (L347-371).

### M16. Test flakes — `Sys.Date()` direkte i tests
- **Files:** `tests/testthat/test-export_pdf.R:472,486`, `tests/testthat/test-chart_types.R:100`
- **Fix:** Fixed dates (`as.Date("2025-01-01")`).

### M17. Test flakes — `rnorm/rpois` uden `set.seed`
- **Files:** `tests/testthat/test-bfh_qic_edge_cases.R:46,61,75,91,108`, `tests/testthat/test-arrow-symbols.R:50,128`
- **Fix:** `set.seed(317)` (eller anden) i toppen af hver `test_that`-blok.

### M18. Manglende direkte unit-tests
- **Files mangler:** `test-utils_helpers.R`, `test-utils_typst.R` (AST-parser/escape-funcs adversarial input), `test-utils_export_helpers.R`, `test-utils_metadata.R`, `test-utils_quarto.R`, `test-utils_date_formatting.R`
- **Coverage indirect via integration-tests; direkte unit-tests mangler.**

### M19. Manglende edge-case tests
- n=1 row for p/u/c-charts
- All-NA y-column behavior
- Zero-denominator (n=0) for p/u-charts
- Non-integer counts for c-chart
- Zero-variance (alle y-værdier identiske) — divide-by-zero risk i I/MR
- Freeze period boundary cases
- DST-transitions / timezone-sensitive dates

### M20. Caching-muligheder
- **Memoise `qicharts2::qic()`** keyed på `digest::digest(data + args)` — 20-100ms savings repeat-calls
- **Cache panel-height** per (viewport+theme) signature — 50-150ms per chart
- **Threadle `.built_plot`** consistent gennem callers — undgå dobbelt `ggplot_build()` (30-80ms hver)

---

## 🟢 LOW

### L1. `bfh_merge_metadata` hardcoder hospitalsnavn
- **File:** `R/utils_metadata.R`
- **Fix:** `getOption("BFHcharts.default_hospital", "Bispebjerg og Frederiksberg Hospital")`.

### L2. Inkonsistent install-hint
- **Files:** `R/utils_dep_guards.R:41,56`, `R/zzz.R:89,100`, `R/BFHcharts-package.R:31`
- Vælg én: `pak::pkg_install` eller `remotes::install_github`.

### L3. Stale "moved to" breadcrumb-kommentarer
- `R/spc_analysis.R:150` — "pluralize_da() and ensure_within_max() are now in R/utils_text_da.R"
- `R/spc_analysis.R:915-919` — multi-line listing
- `R/utils_y_axis_formatting.R:258-267` — 10-line block
- **Fix:** Slet alle. Git-history er migration-rekord.

### L4. Stale file-refs i config-header
- **File:** `R/config_label_placement.R:14-16`
- Peger på `config_ui.R`, `fct_spc_plot_generation.R`, `docs/CONFIGURATION.md` — alle missing.
- **Fix:** Opdatér til `config_font_scaling.R`, `plot_core.R`, `fct_add_spc_labels.R` el. fjern blokken.

### L5. Dead code — `determine_time_unit()`
- **File:** `R/utils_time_formatting.R:24` (16 LOC inkl. roxygen)
- Eneste hit på tværs af repo = egen definition.
- **Fix:** Slet.

### L6. Repo-hygiene — stale binary artifacts i working tree
Gitignored men cluttery:
- `Rplots.pdf`, `FMK_analyse*.pdf`, `ventetid_*.pdf`, `BISPCHARTS*.png/xcf`, `BFHcharts.Rcheck/`
- **Fix:** `rm` fra working tree.

### L7. `.worktrees/chartjs-widget/` stale
- 1 måned idle. Indeholder `demo_test.R`, `demo_pdf_export.R`, `demo_performance_test.R`, `test_date_formatting_debug.R`, `CLAUDE.md.backup`.
- **Fix:** `git worktree remove` hvis branch død.

### L8. `Remotes:` blokerer CRAN-submission
- **File:** `DESCRIPTION`
- Hvis CRAN ej planlagt: dokumentér eksplicit i `BFHcharts-package.R` el. `DESCRIPTION` `Note:`.

### L9. Audit-log path uvalideret før `cat(file=...)`
- **File:** `R/utils_audit.R:68-79`
- Trust-boundary in-process (kræver kode-execution at sætte option), men misconfigured server kunne exfiltrere.
- **Fix:** Validér via `validate_export_path()` ved session-start.

### L10. `validate_export_path(extension=...)` default `ext_action = "none"`
- **File:** `R/utils_path_policy.R:130, 141-155`
- Default = ingen enforcement → regression-vector.
- **Fix:** Default `"stop"` el. `"warn"`.

---

## Sprint-plan

| Sprint | Indhold | Effort |
|--------|---------|--------|
| 1 | H1-H5 (release-blockers: CRAN, naming, validation) | M |
| 2 | H6-H8 (perf-flaskehalse — målbar render-speedup) | M |
| 3 | M7-M15 (DRY + SRP refactors) | L |
| 4 | M16-M19 (test-fixes + missing unit-tests + edge cases) | M |
| 5 | M1-M6, M20, L1-L10 (security medium, doc-fixes, cleanup) | S |

---

## Strengths

- **Typst-pipeline security exceptionel:** `restrict_template = TRUE` default, namespace-allowlisted `inject_assets`, Typst `--root` sandbox, `KNOWN_TYPST_FLAGS` allowlist, AST-baseret CommonMark→Typst escape, template-identifier regex-validation, `.check_traversal()` + `.check_metachars()` på alle external-facing paths
- **Centraliseret validation:** `validate_bfh_qic_inputs`, `validate_position_indices`, `validate_numeric_parameter` — strong DRY
- **Ingen kodelig:** Ingen TODO/FIXME/HACK/browser()/.Deprecated/commented-out kode
- **`bfh_qic.R:598-760`** exemplary pipeline orchestrator
- **`place_two_labels_npc`** allerede pænt dekomponeret
- **Konstanter velkonsoliderede** i `R/globals.R`
- **ASCII-policy ren** (verificeret via test-source-ascii.R)

---

**Kilder:** 8 parallel review-agents (r-package-code-reviewer, tidyverse-code-reviewer, security-reviewer, performance-optimizer, test-coverage-analyzer, refactoring-advisor, error-handling-reviewer, legacy-code-detector).
