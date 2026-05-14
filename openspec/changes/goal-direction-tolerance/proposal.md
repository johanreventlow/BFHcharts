## Why

`.evaluate_target_arm()` har i dag **to grene** med inkonsistent
tæt-på-håndtering:

**Path A** — `target_direction = NULL` (numerisk target uden operator):
```r
# Tre-vejs cascade (indført i at-target-tolerance-process-variation):
if delta <= 3*sigma_hat   → at_target  ✓
elif delta <= sd(y)       → at_target  ✓
elif delta < 1e-9         → at_target  ✓ (degenereret)
elif centerline > target  → over_target
else                      → under_target
```

**Path B** — `target_direction ∈ {"higher","lower"}` (operator target som
`>= 90%`, `<= 5%`):
```r
# Binær strikt sammenligning — INGEN tolerance:
if direction == "higher" and CL >= target  → goal_met
elif direction == "lower" and CL <= target → goal_met
else                                       → goal_not_met
```

Konsekvens: For operator-targets bliver et lille afstand til målet
fejlagtigt klassificeret som "ikke opfyldt", selv når forskellen er
statistisk umulig at adskille fra målet.

Konkret reproduktion:
- `target = ">= 90%"` (target_direction = "higher", target_value = 0.90)
- `centerline = 0.895` (89.5%), `sigma_hat = 0.02`
- `delta = 0.005`, `3*sigma_hat = 0.06`
- Pt: `0.895 < 0.90` → `goal_not_met` ❌
- Forventet: `delta <= 3*sigma_hat` → klinisk ækvivalent med målet

Brugere har rapporteret at output "lyder dumt" når CL er klinisk
indistinguishable fra target.

Issue 2 (separat, additive change i samme cycle): Tilføj
`majority_at_centerline`-stability-kategori for data hvor >= 50% af
punkterne ligger præcis på centerlinjen — typisk symptom på grov måle-
skala eller diskret rapportering der forringer SPC-tolkningen.

## What Changes

**Slice 1 — Direction-aware "tæt på"-klassifikation**

Udvid Path B i `.evaluate_target_arm()` med samme proces-variation-
cascade som Path A. Når `delta <= 3*sigma_hat` (eller `sd(y)`-fallback),
klassificeres tilstanden som "near_target" — uanset om strikt
direction-condition er opfyldt.

Beslutningstræ:
```
1. delta <= 3*sigma_hat (eller sd(y))  → near_target
2. elif strict direction-condition     → goal_met
3. ellers                               → goal_not_met
```

Tolerance rangerer foran strikt comparison. Dette afspejler statistisk
ækvivalens: hvis CL ligger inden for proces-støj fra target, er
opfyldelses-status ikke afgørbar med tilgængelig data.

**Slice 2 — Ny target/action-arm-tekst**

Tilføj `near_target` til `analysis.target` (parallelt til
`at_target`/`over_target`/`under_target`).

Tilføj `stable_near_target` og `unstable_near_target` til
`analysis.action`. YAML-templates bruger `{level_direction}`-placeholder
til at rendere "lige under målet" (higher-direction, CL < target) eller
"lige over målet" (lower-direction, CL > target).

**Slice 3 — Edge case: "majority at centerline"-stability (additive)**

Tilføj ny stability-key `majority_at_centerline` der vælges når
≥50% af punkterne ligger præcis på centerlinjen (eksakt-match,
`|y - cl| < 1e-9`), uden at alle punkter er identiske (`no_variation`
har fortrinsret).

`no_variation > majority_at_centerline > .select_stability_key(flags)`.

## Impact

**Behavior change (Slice 1+2):** Scenarier hvor `delta <= 3*sigma_hat`
flipper fra `goal_not_met` → `near_target`. Tests der antager strikt
direction-comparison må opdateres.

**Action-arm ændring (Slice 2):** Action-arm `stable_goal_not_met` /
`unstable_goal_not_met` rammes færre scenarier. Ny key
`stable_near_target` / `unstable_near_target` overtager mellem-state.

**Additive (Slice 3):** Ny stability-key er rent additive. Eksisterende
scenarier urørte. Tekster flagger data-kvalitetsproblemer
(rounding/binning) der ellers gemte sig under `no_signals`/regular signal-
detection.

**i18n:** Begge YAML-filer (`da.yaml` + `en.yaml`) får nye keys.

**Tests:** Eksisterende `goal_met`/`goal_not_met`-tests må udvides med
process-variation-aware-assertions. Nye tests for `near_target` og
`majority_at_centerline`.

**Versionering:** MINOR-bump (pre-1.0 — strider ikke mod stabilitets-
forpligtelse). Markér tydeligt i NEWS som potentiel breaking change i
downstream-tests.
