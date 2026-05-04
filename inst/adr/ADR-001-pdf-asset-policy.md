# ADR-001: PDF Asset Policy -- Option A (Open-Fallback Default)

Status: Accepted

## Context

The production Typst template (`inst/templates/typst/bfh-template/bfh-template.typ`)
references fonts and images that are NOT tracked in the public git repository:

- `fonts/Mari*.otf` / `fonts/Mari*.ttf` -- proprietary hospital font (gitignored)
- `images/Hospital_Maerke_RGB_A1_str.png` -- hospital logo (untracked)

A `git archive HEAD` tarball (same content as GitHub tarball and r-universe build)
therefore produces a package that cannot render a production PDF without a companion
package injecting assets at runtime.

This was identified as the highest-severity deploy risk in two independent code reviews
(Claude K1, Codex K1 -- 2026-05-01).

Three policies were evaluated:

- **Option A (open-fallback):** Production template uses only open/system fonts as
  default; Mari and logos are companion-supplied via `inject_assets` hook.
- **Option B (companion-only template):** Remove production template from public package;
  BFHcharts ships only a neutral fallback template.
- **Option C (bundle open placeholder assets):** Bundle Roboto + placeholder logo.

## Decision

**Option A is selected.**

### Font chain

The template font stack `("Mari", "Roboto", "Arial", "Helvetica", "sans-serif")`
is PRESERVED unchanged. Typst falls through to the next available font automatically,
so:

- Systems with companion-injected Mari (via `BFHchartsAssets::inject_bfh_assets()`)
  render with hospital branding.
- Systems without Mari render with Roboto (if system-installed) or Helvetica/Arial/
  sans-serif. This is acceptable fallback behaviour for Connect Cloud deployments.

The font stack is NOT modified because:
1. Mari remains first priority -- companion-injectied assets get precedence.
2. Roboto, Arial, Helvetica are widely available on Ubuntu/macOS/Windows CI and
   Connect Cloud runners, so fallback rendering succeeds in practice.
3. Bundling Roboto fonts requires explicit licence validation (Apache 2.0 confirmed
   acceptable, but bundle size and ongoing update burden weigh against it pre-1.0).

### Image

The hospital logo reference (`images/Hospital_Maerke_RGB_A1_str.png`) remains in
the template for now. The `images/` directory is untracked and must be supplied by
the deploying organisation (or companion package). Smoke tests that test the
no-inject_assets path skip automatically when the images directory is absent.

This is a **known remaining gap** -- a placeholder SVG or conditional image rendering
should be addressed in a follow-up (see GitHub issue tracker).

### Auto-detect staged fonts

`bfh_compile_typst()` is updated to detect a `fonts/` subdirectory in the staged
template tempdir and automatically pass `--font-path` when the caller has not
supplied `font_path` explicitly. This ensures companion-injected fonts are discovered
without requiring callers to thread `font_path` through their code.

## Consequences

### Positive
- `pak::pkg_install("johanreventlow/BFHcharts")` on a system with Roboto/Arial
  produces a valid PDF out of the box without Mari.
- Companion packages can supply Mari + logos transparently via `inject_assets`.
- No proprietary fonts committed to the public repository.

### Negative / Remaining gaps
- ~~The `images/` directory is still untracked. Render without companion assets on a
  clean install will fail if the images/ dir is absent.~~ **Closed by change
  `add-conditional-template-image` (BFHcharts 0.15.1):** the Typst template now
  exposes a `logo_path: none` parameter and the foreground logo is rendered only
  when `logo_path` is supplied. R-side `compose_typst_document()` auto-detects a
  staged logo at `bfh-template/images/Hospital_Maerke_RGB_A1_str.png` mirroring
  the `--font-path` auto-detect pattern. PDFs now render successfully without
  companion-injected assets (logo slot stays empty); companion-injected logos
  are picked up automatically without caller intervention.
- No open fonts bundled (Roboto not bundled). Systems with neither Roboto nor
  Helvetica/Arial will fall through to a generic sans-serif; this is cosmetically
  acceptable but not identical to the branding spec.

## Cross-repo impact

biSPCharts on Posit Connect Cloud will get production PDFs without needing Mari
configured at the platform level. Existing Region H internal deployments with Mari
are unaffected (font chain gives Mari priority when present).

biSPCharts DESCRIPTION lower-bound remains unchanged (no breaking API change).

Dato: 2026-05-01
