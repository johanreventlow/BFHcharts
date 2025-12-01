# Implementation Tasks: remove-vignette-builder

Tracking: GitHub Issue #24

## Phase 1: Remove VignetteBuilder

- [ ] 1.1 Remove VignetteBuilder line from DESCRIPTION
  - Delete: `VignetteBuilder: knitr`
  - **File:** `DESCRIPTION`
  - **Validation:** Line no longer present

- [ ] 1.2 Review knitr/rmarkdown in Suggests
  - Check if knitr is used elsewhere in package
  - Check if rmarkdown is used elsewhere
  - If only used for vignettes: Remove from Suggests
  - If used elsewhere: Keep in Suggests
  - **File:** `DESCRIPTION`
  - **Validation:** Dependencies accurate

## Phase 2: Verify Clean Build

- [ ] 2.1 Run devtools::check()
  - Verify VignetteBuilder warning is gone
  - Verify no new warnings introduced
  - **Validation:** 0 errors, 0 warnings related to vignettes

- [ ] 2.2 Run devtools::document()
  - Ensure no documentation issues
  - **Validation:** Documentation generates cleanly

## Phase 3: Commit and Deploy

- [ ] 3.1 Commit changes
  - Commit message: `fix: remove unused VignetteBuilder from DESCRIPTION (#24)`
  - **Validation:** Clean git status

- [ ] 3.2 Push to remote
  - **Validation:** Changes visible on GitHub

- [ ] 3.3 Close GitHub issue #24
  - Add label: `openspec-deployed`
  - Add closing comment: "Removed VignetteBuilder. Vignettes can be added in future release (see #17)."
  - **Validation:** Issue closed

- [ ] 3.4 Archive OpenSpec change
  - Execute: `openspec archive remove-vignette-builder --yes`
  - **Validation:** Change archived

## Dependencies

**Sequential:** Phase 1 → Phase 2 → Phase 3

## Validation Criteria

**Phase 1 complete when:**
- VignetteBuilder line removed from DESCRIPTION
- Dependencies reviewed and updated if needed

**Phase 2 complete when:**
- R CMD CHECK passes without vignette warning
- No new issues introduced

**Phase 3 complete when:**
- Changes committed and pushed
- GitHub issue closed
- OpenSpec archived

## Effort Estimate

- Phase 1: 2 minutes
- Phase 2: 2 minutes
- Phase 3: 2 minutes
- **Total: ~5 minutes**

## Future Considerations

When public release is planned (issue #17):
1. Re-add `VignetteBuilder: knitr` to DESCRIPTION
2. Create `vignettes/` directory
3. Implement vignettes as documented in #17
4. Update this OpenSpec or create new one
