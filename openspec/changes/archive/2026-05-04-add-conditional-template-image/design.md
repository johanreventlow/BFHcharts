## Context

BFHcharts ships a Typst template (`inst/templates/typst/bfh-template/bfh-template.typ`)
that compiles SPC-chart PDFs with hospital branding. The branding has
two asset categories:

1. **Fonts** -- proprietary Mari + open fallback chain (Roboto, Arial,
   Helvetica, sans-serif). Handled per ADR-001 Option A: font chain
   degrades automatically via Typst's built-in fallback when packaged
   fonts are absent. Companion package `BFHchartsAssets` injects Mari
   when available.

2. **Images** -- hospital logo
   (`images/Hospital_Maerke_RGB_A1_str.png`). Currently hard-coded as
   an unconditional `image()` call in the template. Companion package
   injects the file via `inject_assets` callback. Without companion,
   Typst compile fails:
   ```
   error: file not found (searched at images/Hospital_Maerke_RGB_A1_str.png)
   ```

The font path was solved structurally (Typst's font-fallback semantics).
The image path needs an explicit conditional because Typst's `image()`
function has no built-in graceful-degradation semantics -- a missing
file is a hard error.

ADR-001 acknowledges this gap explicitly:

> The `images/` directory is still untracked. Render without companion
> assets on a clean install will fail if the images/ dir is absent. A
> future PR should add a conditional image reference or a placeholder
> asset.

This change is that future PR.

## Goals / Non-Goals

**Goals:**
- `bfh_export_pdf()` succeeds on a clean install without `inject_assets`
  callback. PDF renders without the hospital logo.
- `bfh_export_pdf()` continues to render WITH the logo when assets are
  injected (via callback or explicit `metadata$logo_path`).
- Behaviour matches the font-fallback contract: companion-injected
  branding takes precedence, fallback gives a working but unbranded
  result.
- No companion-package update required (auto-detect picks up
  `<staged-template>/images/` if the callback creates it).

**Non-Goals:**
- Bundling a placeholder logo (license + maintenance burden; separate
  decision).
- Changing the `images/` directory structure or filename convention.
- Expanding to multiple logos (e.g. region-specific). One logo slot;
  organizations swap via callback.
- Refactoring the foreground `place()` block to use a different
  positioning strategy (header bar uses fixed offsets that already
  ignore the foreground image -- see "Visual layout decision" below).

## Decisions

### D1 -- Parameter-driven conditional, not file-existence check

Two options were evaluated:

**Option A (chosen):** Add a `logo_path: none` parameter to the
template. R-side decides whether to populate it. Conditional in
template wraps the `place(image())` call.

```typst
foreground: if logo_path != none {
  place(
    image(logo_path, height: 19.8mm),
    dy: 39.6mm, dx: 0mm
  )
} else { none }
```

**Option B (rejected):** Use Typst's hypothetical `if file-exists(...)`
construct. Typst does NOT have a `file-exists()` function in stable
versions (>= 0.13). Even if added later, it couples template to runtime
filesystem state in a way that's harder to test deterministically.

**Rationale:** Option A puts the decision in R (single source of
truth), keeps Typst code simple, and is symmetric with how `font_path`
is handled (R decides, passes path or `none`).

### D2 -- Auto-detect logo file in staged template

R-side helper `.detect_packaged_logo()` mirrors the existing
`.detect_packaged_fonts()` pattern in `R/utils_typst.R`:

```r
.detect_packaged_logo <- function(typst_file) {
  staged_logo <- file.path(
    dirname(typst_file), "bfh-template", "images",
    "Hospital_Maerke_RGB_A1_str.png"
  )
  if (file.exists(staged_logo)) staged_logo else NULL
}
```

Filename is **deterministic** (not glob). Companion packages
(`BFHchartsAssets`) ship the file at this exact path. A glob-based
detection (`*.png` in `images/`) would tempt callers to drop arbitrary
images expecting them to render -- explicitness avoids that confusion.

If callers want to use a different logo, they pass it explicitly via
`metadata$logo_path`, which overrides auto-detect.

### D3 -- Layout: foreground slot empty when logo absent

The foreground `place()` block sits at `dy: 39.6mm, dx: 0mm`. The
header bar (blue block with hospital + department text) starts at
`(top, 52.8mm, 26.4mm rows)` -- separate `grid()` block, NOT
positioned relative to the foreground image.

Verification: removing the foreground block in a test render leaves
the header bar at its original position. The image was decorative, not
load-bearing for layout.

If a future requirement needs the slot collapsed (header bar slides
up), that's a layout-level change distinct from the
graceful-degradation goal of this change. Out of scope here.

### D4 -- Error semantics for invalid `logo_path`

Three sub-cases:

1. `logo_path = NULL` (default): no logo rendered. Success.
2. `logo_path = "/path/to/existing.png"`: logo rendered. Success.
3. `logo_path = "/path/that/does/not/exist.png"`: Typst compile
   surfaces the file-not-found error verbatim. Caller gets clear
   diagnostic.

R-side does NOT pre-validate the path's existence. Rationale:
- Pre-validation duplicates Typst's error.
- Path may be relative to staged-template-dir at compile time, not at
  validation time -- file existence check on the R side would have a
  TOCTOU window.
- Companion packages may write the file in their `inject_assets`
  callback after `metadata$logo_path` is set; pre-validation would
  reject valid paths.

R-side DOES validate `logo_path` as a single character string (length
1, not NA, not empty) to give a clearer error than a Typst parse
failure when the value is malformed.

### D5 -- Backward compatibility for callers using `inject_assets` only

Current flow (callers of `inject_assets` callback):
1. `bfh_export_pdf(inject_assets = MyAssets::inject_logo)`
2. Callback creates `<staged-template>/images/Hospital_Maerke_...png`
3. Template's hard-coded `image("images/Hospital_Maerke_...png")`
   resolves to the staged file.

After this change:
1. `bfh_export_pdf(inject_assets = MyAssets::inject_logo)`
2. Callback creates `<staged-template>/images/Hospital_Maerke_...png`
   (unchanged)
3. R wrapper auto-detects the staged file via `.detect_packaged_logo()`
4. Auto-populates `metadata$logo_path` to the staged path
5. Template's `if logo_path != none { ... }` branch fires with the
   path. Logo renders identically.

Companion-package consumers do nothing. Their callback continues to
work. The logo just renders via the new code path.

### D6 -- Test gating with `BFHCHARTS_TEST_RENDER`

The new tests in `test-template-image-conditional.R` invoke a real
Quarto+Typst compile. They MUST be gated by the
`BFHCHARTS_TEST_RENDER` env var (matches existing
`test-production-template-renders.R` pattern). Without the gate, the
tests skip (regular `R CMD check` is not blocked on Quarto
availability).

## Risks / Trade-offs

**Risk 1: Layout regression.**
The foreground image was sized at 19.8mm tall. Removing it leaves
empty space. If any downstream consumer relied on the visual presence
of the logo for layout cues (e.g. visual rhythm), they'll see an
unbranded gap.
*Mitigation:* Smoke-test renders with + without logo; manual visual
inspection. The header bar starts immediately below the foreground
slot; emptiness in that region was already the no-companion behaviour
(it just compiled-error'd before instead of rendering empty).

**Risk 2: Companion package coupling.**
If `BFHchartsAssets` ever changes the staged filename or directory,
auto-detect breaks silently. Caller would see no logo without
diagnostic.
*Mitigation:* Document the auto-detect contract in
`R/utils_typst.R::.detect_packaged_logo()` Roxygen. Companion-package
README notes the filename convention. Acceptable risk: filename has
been stable since first release.

**Risk 3: Future multi-logo requirement.**
If hospitals want region-specific logos, the single `logo_path` slot
limits flexibility. Would need a list-based approach.
*Mitigation:* Out of scope; revisit if the requirement materializes.
The current single-slot design matches the existing template's single
foreground image.

**Trade-off: Simplicity vs flexibility.**
A more flexible design would expose the entire `place()` arguments
(coordinates, dimensions) as Typst parameters. Decided against:
calibrated coordinates are template-design decisions, not
caller-decisions. Callers swap the image, not the layout.

## Migration Plan

1. Land this change in a feature branch:
   `feat/conditional-template-image`.
2. Open PR; verify CI passes (including PDF render gate when
   `BFHCHARTS_TEST_RENDER=true`).
3. Manual verification: clean install in fresh R session +
   `bfh_export_pdf()` produces logo-less PDF without errors.
4. Manual verification: install with `BFHchartsAssets` companion +
   `bfh_export_pdf()` produces logo-bearing PDF (visual diff vs
   pre-change baseline).
5. NEWS entry under next PATCH release header.
6. After merge, mark `2026-05-01-fix-pdf-template-asset-contract`
   task 2.5 complete and archive that change.

## Open Questions

- **Q1:** Should the auto-detect log a debug message when it finds /
  doesn't find a packaged logo? Helps companion-package authors debug
  staging issues.
  *Tentative answer:* Yes, behind
  `getOption("BFHcharts.debug.label_placement")` or a new equivalent
  flag (`BFHcharts.debug.template_assets`). Defer to implementation
  judgment.

- **Q2:** Should `bfh_create_typst_document()` (exported) also accept
  `logo_path` directly as a top-level parameter for advanced callers
  who don't go through `bfh_export_pdf()`?
  *Tentative answer:* Yes, but via the existing `metadata` argument --
  no new top-level parameter. Keeps API surface small.
