# ADR-005: Distribution Strategy -- GitHub-Only with r-universe as Secondary Mirror

Status: Accepted

Date: 2026-06-12

## Context

BFHcharts is a production-quality SPC chart rendering package for healthcare
quality improvement. As the package approaches pre-1.0 maturity, a deliberate
distribution strategy is needed to balance discoverability, install friction,
and CRAN eligibility constraints.

### Current install path

```r
pak::pkg_install("johanreventlow/BFHcharts")
# or
remotes::install_github("johanreventlow/BFHcharts")
```

`DESCRIPTION` carries a `Remotes:` field pinning `BFHtheme`:

```
Remotes: johanreventlow/BFHtheme
```

This works for GitHub-aware installers (`pak`, `remotes`) but is explicitly
disallowed on CRAN.

### Why CRAN is not currently feasible

Four independent blockers prevent CRAN submission in the near term:

1. **`SystemRequirements: Quarto CLI`** -- BFHcharts uses Quarto for
   vignette rendering and (optionally) for document generation. CRAN does
   not allow non-standard system requirements that cannot be satisfied on
   CRAN's build fleet. Quarto would need to be moved to `Suggests` (with
   graceful degradation) before CRAN submission is possible.

2. **`BFHtheme` private dependency** -- `BFHtheme` is a hospital-branding
   package distributed exclusively via GitHub. CRAN requires all recursive
   `Imports` to be on CRAN. Submitting BFHcharts first would require
   BFHtheme to be submitted simultaneously or in advance, which is not
   currently planned.

3. **Proprietary Mari fonts referenced in templates** -- The Typst template
   references the proprietary hospital font Mari (see ADR-001). Although
   Mari is not required at install time (open-font fallback is the default),
   the font is referenced by name in shipped template source. CRAN policies
   around proprietary assets are conservative and this reference would
   require additional justification or removal.

4. **Pre-1.0 API churn** -- The public API (especially `bfh_qic()` parameter
   names and the `bfh_qic_result` object schema) has had MINOR breaking
   changes in every release cycle since v0.10 (see VERSIONING_POLICY.md §A).
   Submitting to CRAN before the API stabilizes imposes a deprecation-cycle
   overhead that is not warranted for a pre-1.0 package with a single primary
   consumer (biSPCharts).

### r-universe as low-friction mirror

[r-universe.dev](https://r-universe.dev) provides a CRAN-compatible binary
mirror of GitHub packages with no submission overhead: adding a
`packages.json` entry to the `johanreventlow.r-universe.dev` universe is
sufficient. r-universe builds macOS/Windows/Linux binaries automatically and
exposes a standard `repos =` install URL:

```r
install.packages("BFHcharts",
  repos = c("https://johanreventlow.r-universe.dev", getOption("repos")))
```

This eliminates the need for `remotes`/`pak` for users who only need binary
installs, without any of the CRAN submission constraints.

## Decision

**GitHub releases remain the primary distribution channel.** r-universe is
adopted as a secondary mirror when it offers tangible benefit to downstream
consumers (binary install convenience, no `remotes` dependency required).

No CRAN submission is planned until all four blockers listed above are
resolved.

### Rationale

- The primary downstream consumer (biSPCharts on Posit Connect Cloud) uses
  `pak` and resolves GitHub dependencies natively. GitHub distribution has
  zero friction for this use case.
- r-universe costs nothing operationally and reduces install friction for
  users who cannot or prefer not to use `pak`/`remotes`. It is worth
  enabling as a background improvement.
- CRAN submission before the API stabilizes would impose deprecation-cycle
  bureaucracy on every MINOR release. The cost is not justified pre-1.0.
- BFHtheme shows no current intent to pursue CRAN distribution; gating
  BFHcharts on a BFHtheme CRAN submission would delay unnecessarily.

### When to revisit

Revisit this decision when **all** of the following hold:

- [ ] Package is post-1.0 (public API stable for >= 3 months without
      breaking changes).
- [ ] BFHtheme is CRAN-eligible (either submitted to CRAN, or BFHcharts
      has decoupled the hard `Imports` dependency to `Suggests` with a
      fallback rendering path).
- [ ] Quarto dependency moved to `Suggests` with graceful degradation when
      Quarto CLI is absent (vignettes built conditionally; PDF-export path
      documents the requirement clearly).
- [ ] Mari font references either removed from shipped template source or
      confirmed acceptable under CRAN's proprietary-asset policies.

## Consequences

### Positive

- No CRAN submission overhead during active pre-1.0 development.
- r-universe binary mirror provides one-liner install without `pak`/`remotes`
  for users on standard R setups.
- Distribution strategy is explicit and documented; the blockers to CRAN are
  enumerated, making the path forward clear when the API matures.

### Negative

- BFHcharts does not appear in CRAN search results or `available.packages()`.
  Discoverability for users outside the Region H ecosystem is limited.
- Users unfamiliar with `pak` or `remotes` must use the r-universe mirror
  or follow a slightly longer install instruction.
- The `Remotes:` field in `DESCRIPTION` means `R CMD check --as-cran` emits
  a NOTE. This is accepted and documented.

### Trade-offs considered

- *Submit BFHtheme + BFHcharts to CRAN simultaneously*: rejected because the
  Mari font reference and Quarto `SystemRequirements` blockers remain
  independent of BFHtheme's CRAN status, and pre-1.0 API churn makes the
  submission timing poor regardless.
- *Decouple BFHtheme to `Suggests` now to unblock CRAN*: rejected because
  BFHtheme provides the hospital theme layer that is central to the package's
  purpose. A graceful-degradation path exists in principle but is not
  implemented and would require non-trivial design work.
- *r-universe only, no GitHub releases*: rejected because GitHub releases
  provide signed, tagged artifacts with release notes and are already
  integrated into the biSPCharts deploy pipeline.

## References

- ADR-001 (PDF asset policy -- Mari font handling)
- `VERSIONING_POLICY.md` §A (pre-1.0 MINOR breaking allowed) and §F
  (pre-1.0 to 1.0 criteria)
- `DESCRIPTION` `Remotes:` field
- r-universe documentation: https://ropensci.org/r-universe/
