## 1. Branch + baseline verification

- [x] 1.1 Create branch `refactor/decompose-marquee-labels` from current develop (post-v0.14.3)
- [x] 1.2 Verify pre-push hook passes on develop baseline (`PREPUSH_MODE=full git push --dry-run`) so any later failure is attributable to refactor
- [x] 1.3 Capture baseline output: run `Rscript dev/preview_labels.R` and snapshot resulting PNGs to compare visually after refactor

## 2. Extract `.resolve_label_geometry()`

- [x] 2.1 Add private helper `.resolve_label_geometry()` in `R/utils_add_right_labels_marquee.R` containing scale_factor + config lookup + header_size + value_size + lineheight + gap_line + gap_labels + pad_top + pad_bot computation (current lines ~137-170)
- [x] 2.2 Replace inline block in `add_right_labels_marquee()` with call to `.resolve_label_geometry()`; bind returned list to local `geom`
- [x] 2.3 Update orchestrator to reference `geom$header_size`, `geom$value_size`, etc. instead of locally-bound names
- [x] 2.4 Add unit tests in `tests/testthat/test-utils_add_right_labels_marquee.R` (or extend existing test file) covering: pure-input → pure-output, no graphics-device side effect, config-injection seam works
- [x] 2.5 Run targeted tests: `Rscript -e 'devtools::test(filter = "utils_add_right_labels_marquee")'`. Must pass.

## 3. Extract `.measure_label_heights()`

- [x] 3.1 Add private helper `.measure_label_heights(textA, textB, style, panel_height_inches, device_size, marquee_height_estimator = estimate_label_heights_npc)` covering height_A + height_B + label_height_npc selection + empty-label fallback (current lines ~320-410)
- [x] 3.2 Replace inline block in `add_right_labels_marquee()` with call to `.measure_label_heights()`
- [x] 3.3 Verify the orchestrator threads `device_size` and `panel_height_inches` from the device-acquisition layer (still inline at this commit) into the new helper
- [x] 3.4 Add unit tests covering: empty textA, empty textB, both empty, both non-empty (max-selected), injected estimator returns mock heights
- [x] 3.5 Run targeted tests + visual regression: `Rscript -e 'Sys.setenv(NOT_CRAN="true"); devtools::test(filter = "(utils_add_right_labels_marquee|visual-regression)")'`. Zero `.new.svg` files allowed.

## 4. Extract `.acquire_device_for_measurement()` (critical commit)

- [x] 4.1 Add private helper `.acquire_device_for_measurement(viewport_width, viewport_height, panel_width_inches, fallback_width = 10, fallback_height = 7.5, verbose = FALSE)` covering viewport-vs-fallback strategy + device opening + panel-height measurement (current lines ~200-315)
- [x] 4.2 Helper returns named list `(device_size, panel_height_inches, temp_device_opened, cleanup_fn)` where `cleanup_fn` is a closure that closes any device opened by this call
- [x] 4.3 In orchestrator, replace inline block with: `dev_ctx <- .acquire_device_for_measurement(...); withr::defer(dev_ctx$cleanup_fn())`. Remove existing manual `dev.off()` patterns from the orchestrator.
- [x] 4.4 Add unit tests with mocked `grDevices::dev.cur()` / `grDevices::dev.size()` covering: viewport-available path (no device opened), viewport-unavailable path (fallback device opened + closed by cleanup_fn)
- [x] 4.5 Run **full** pre-push hook: `git push --dry-run` (or push to scratch branch). Visual regression must be byte-clean.
- [x] 4.6 Run device-leak smoke test: `Rscript -e 'devtools::test(); ls(tempdir())'`. No `Rplots.pdf` written by package code.

## 5. Final orchestrator simplification

- [x] 5.1 Remove dead inline comments in `add_right_labels_marquee()` that referred to extracted blocks
- [x] 5.2 Verify orchestrator is ≤120 lines (count via `awk 'NR==FNR{} END{print NR}' < <(sed -n '/^add_right_labels_marquee <- function/,/^}/p' R/utils_add_right_labels_marquee.R)`)
- [x] 5.3 Run `devtools::document()` if any roxygen changes were made to the helpers (each helper gets `@keywords internal @noRd`)
- [x] 5.4 Run `lintr::lint("R/utils_add_right_labels_marquee.R")`. Zero new lint issues vs baseline.
- [x] 5.5 Run `styler::style_file("R/utils_add_right_labels_marquee.R")` and inspect diff
- [x] 5.6 Update NEWS.md under next version's `## Internal changes` section: "Decompose `add_right_labels_marquee()` into orchestrator + 3 named helpers (`.resolve_label_geometry()`, `.acquire_device_for_measurement()`, `.measure_label_heights()`) following the 3-layer pattern from v0.13.0's `place_two_labels_npc()` refactor. Pure refactor: visual regression baselines unchanged."

## 6. Verification + PR

- [x] 6.1 Run full test suite with all gating env vars: `Rscript -e 'Sys.setenv(NOT_CRAN="true", BFHCHARTS_TEST_FULL="true"); devtools::test()'`. Zero failures.
- [x] 6.2 Run pre-push hook end-to-end via `git push -u origin refactor/decompose-marquee-labels` (no `SKIP_PREPUSH` allowed)
- [x] 6.3 Open PR `refactor/decompose-marquee-labels` → develop with link to OpenSpec change folder; reference proposal.md and design.md in PR body
- [x] 6.4 Verify CI green (R-CMD-check ubuntu/windows/oldrel, lint, pdf-smoke, git-archive-render)
- [x] 6.5 After merge, archive change: `/opsx:archive decompose-marquee-labels`
