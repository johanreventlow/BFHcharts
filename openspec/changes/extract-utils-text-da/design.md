## Context

`R/spc_analysis.R` (~929 lines) is the package's largest single file. It hosts four concerns that grew there organically:

1. Target resolution (`resolve_target()` and friends)
2. **Danish text-formatting utilities** ← target of this proposal
3. Analysis-context construction
4. Fallback-narrative generation (target of sibling proposal `decompose-fallback-analysis`)

The Danish text helpers are pure string-manipulation functions with no dependency on SPC concepts. They were placed in `spc_analysis.R` because that's where the first caller appeared during early development. Today they're called from multiple sites in the file and could potentially be reused from other label-formatting sites — but their current location buries them under the SPC pipeline filename.

Constraints:

- **Behavior must not change.** Existing tests covering `pluralize_da()`, `pick_text()`, etc. (in `tests/testthat/test-spc_analysis.R`) must continue to pass without modification.
- **All five helpers are `@keywords internal @noRd`** — no public-API impact.
- **R loads files alphabetically from `R/`**. New file `utils_text_da.R` sorts before `spc_analysis.R`, which is fine since helpers are referenced after package load is complete.

## Goals / Non-Goals

**Goals:**

- Move five Danish text-formatting helpers from `R/spc_analysis.R` to new file `R/utils_text_da.R`.
- Preserve all signatures, internals, roxygen, and `@noRd` annotations exactly.
- Pair-aware with `decompose-fallback-analysis`: if both land, `spc_analysis.R` shrinks by ~250+ lines.
- Zero behavioral change. Existing tests pass without modification.

**Non-Goals:**

- Refactoring the helpers themselves.
- Changing helper signatures or making any of them public.
- Moving the test file (`tests/testthat/test-spc_analysis.R` continues to host tests for the relocated helpers).
- Restructuring i18n infrastructure (`inst/i18n/`).
- Creating a new English-text counterpart (`utils_text_en.R`) — premature; revisit only when actual reuse from English-only paths appears.

## Decisions

### Decision 1: New file is `R/utils_text_da.R`, not `R/text_utils.R`

**Choice:** File name is `R/utils_text_da.R` per package naming convention (`utils_*.R` prefix; `_da` suffix denotes Danish-specific scope).

**Rationale:** Existing files use the `utils_*` prefix consistently (`utils_audit.R`, `utils_helpers.R`, `utils_label_helpers.R`, etc.). The `_da` suffix telegraphs that the helpers are language-specific (vs `utils_path_policy.R` which is language-agnostic). Future English-specific text helpers (if ever needed) would land in `utils_text_en.R` symmetrically.

**Alternative considered:** `R/text_utils.R` (no prefix). Rejected: breaks the existing convention; reduces grep-friendliness.

### Decision 2: Helpers move as a single unit

**Choice:** All five helpers move in one commit. Tests stay where they are.

**Rationale:** Five small helpers with no inter-helper dependency or external dependency. Splitting into multiple commits adds review friction for no benefit.

**Alternative considered:** Per-helper commits. Rejected: serial commits would each touch the same two files; review noise outweighs bisect benefit.

### Decision 3: Tests stay in `test-spc_analysis.R`

**Choice:** Tests for the relocated helpers continue to live in `tests/testthat/test-spc_analysis.R`.

**Rationale:** The helpers are still called from `spc_analysis.R` and the tests exercise that integration path. Splitting tests across files would lose the integration coverage. If the helpers grow new callers in other files, those callers' tests would naturally exercise them; no need to pre-emptively split.

**Alternative considered:** Move tests to new `test-utils_text_da.R`. Deferred: revisit after first non-spc-analysis caller appears.

### Decision 4: roxygen annotations preserved verbatim

**Choice:** Each helper's `#'` block, `@param`, `@return`, `@keywords internal`, and `@noRd` lines move verbatim. No reformatting.

**Rationale:** Pure relocation. Diff hygiene matters for review. Any roxygen polish is a separate concern.

## Risks / Trade-offs

- **[Risk] Helper invoked from a place we missed.** → Mitigation: pre-flight `grep -rn "pluralize_da\|pick_text\|substitute_placeholders\|pad_to_minimum\|ensure_within_max" R/ tests/` to enumerate all call sites before extraction; verify all callers continue to resolve correctly via `BFHcharts:::` namespace lookup after relocation.

- **[Risk] R-CMD-check warning about file-load ordering.** → Negligible: helpers are not referenced at package-load time (no `.onLoad()` use), only at runtime. R's lazy-load handles this transparently.

- **[Trade-off] Adding a new file vs growing an existing utility file.** → Acceptable: `R/utils_helpers.R` is already a catch-all (audit-flagged in original review); creating a focused `utils_text_da.R` avoids worsening the catch-all.

## Migration Plan

This is a pure relocation. No deployment migration needed.

**Implementation sequence:**

1. Branch: `refactor/extract-utils-text-da` from current develop.
2. Single commit:
   - Create `R/utils_text_da.R` with all five helpers + their roxygen blocks
   - Delete the helpers from `R/spc_analysis.R`
   - Verify `grep -rn "pluralize_da\|pick_text\|substitute_placeholders\|pad_to_minimum\|ensure_within_max" R/ tests/` shows callers unchanged
   - Run `Rscript -e 'devtools::load_all(); devtools::test()'`
3. Update NEWS.md under next version's `## Internal changes`.
4. Open PR. CI must pass.

**Rollback strategy:** `git revert <merge-sha>`.

## Open Questions

- Should this proposal be merged before, after, or simultaneously with `decompose-fallback-analysis`? Both touch `R/spc_analysis.R` but in non-overlapping regions; either order is fine. Recommend landing this one first since it is smaller and lower-risk.
