# BFHcharts Review-Tracker

Audit-trail for systematiske dual-review-cycles per `dual-review-cycle`-skill.

## Cycles

| # | Område | Status | PRs | Doc |
|---|--------|--------|-----|-----|
| 01 | Production-readiness (v0.17.0) | ⏳ Open PRs awaiting review/merge (CI grøn 10/10) | #341 E1, #342 E4, #343 E5, #344 E2, #345 S1, #346 S2, #347 S3, #348 E6, #349 E7, #350 E8, #351 audit-trail | [01-production-readiness-2026-05-10.md](01-production-readiness-2026-05-10.md) |

## Læringer

1. **Chained-validation-blindness (Cycle 01)**: Subagent-claims om validation-gaps skal verificeres mod hele validation-chain'en, ikke kun cited-line. `R/config_objects.R:132-135` validerede `target_value`-finiteness før `validate_target_for_unit()`-laget overhovedet blev tilgået — original E3-finding modbevist via Codex empirisk probe.

2. **Codex auto-loader truncates på store cleanup-diffs (Cycle 01)**: 260 file deletions i working-tree-state forårsagede Codex-context-overflow ved adversarial-review-mode. Workaround: `task --fresh`-mode med eksplicit prompt + `--scope working-tree` undgår fuld git-state-load.

3. **Heuristic-fix safer than scope-creep (Cycle 01)**: `value > 1.5` i `.normalize_percent_target` (mindste-diff) bryder ingen eksisterende tests og fixer både E1-stretch-target (1.05) + boundary-case (1.5) samtidig. Option B (propagér `multiply` igennem `bfh_build_analysis_context`-signature) ville krævet API-refactor uden ekstra correctness-gevinst.
