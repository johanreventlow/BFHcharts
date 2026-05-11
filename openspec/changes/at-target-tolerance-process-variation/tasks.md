## 1. Slice 1 — Statistical at_target rule

- [x] 1.1 Udvid `build_analysis_context()` ([R/spc_analysis.R:209](../../R/spc_analysis.R#L209)):
      - Filtrer `x$qic_data` til sidste fase (matcher eksisterende `centerline`-valg).
      - Beregn `sigma_hat` som `mean((qic_data$ucl - qic_data$lcl) / 6, na.rm = TRUE)`.
      - Beregn fallback `sigma_data` som `sd(qic_data$y, na.rm = TRUE)`.
      - Tilføj begge til returneret context-liste.
      - Håndtér run charts (ingen `ucl`/`lcl` kolonner) → `sigma_hat = NA_real_`.
- [x] 1.2 Erstat værdineutral gren i `.evaluate_target_arm()` ([R/spc_analysis.R:771-790](../../R/spc_analysis.R#L771-L790)):
      - Implementér tre-vejs cascade per design:
        1. `sigma_hat > 0` finite → `at_target ⟺ |CL − target| ≤ 3·sigma_hat`
        2. `sigma_data > 0` finite → `at_target ⟺ |CL − target| ≤ sigma_data`
        3. ellers → `at_target ⟺ |CL − target| < 1e-9`
      - Bevar `over_target` / `under_target`-grene som rent faktuelle
        (CL vs target uden tolerance).
      - Bevar retningsbevidst gren (linje 760-770) uændret.
- [x] 1.3 Verificer at unit tests for retningsbevidst gren (`goal_met` /
      `goal_not_met`) ikke berøres af ændringen.

## 2. Slice 2 — API deprecation

- [x] 2.1 Tilføj deprecation-warning i `bfh_generate_analysis()` når
      `target_tolerance` videregives eksplicit (via `missing()`-detektion).
      - **Afvigelse fra original plan:** `lifecycle` er ikke i `Imports` og
        ny dependency kræver brugerdiskussion. Brugte i stedet
        `rlang::warn()` (allerede i `Imports`) med
        `class = "lifecycle_warning_deprecated"` så lifecycle-aware
        tooling kan genkende den.
      - Meddelelse: "`target_tolerance` is deprecated. Classification now
        uses process variation (UCL/LCL or sd(y)); the argument is ignored."
- [x] 2.2 Verificeret: `lifecycle` er IKKE i `Imports`; bruger
      `rlang::warn()` med deprecation-class i stedet.
- [x] 2.3 Bevar parameter i signaturen (accepteres men ignoreres) for
      backward compatibility.

## 3. Slice 3 — i18n simplifikation

- [x] 3.1 Opdater `inst/i18n/da.yaml`:
      - `target.at_target.detailed` → `"Niveauet ligger tæt på målet ({target})."`
        (samme som `short` / `standard`).
- [x] 3.2 Opdater `inst/i18n/en.yaml`:
      - Tilsvarende simplifikation for engelsk variant.
- [x] 3.3 Verificer at i18n-cache invalideres (kør `bfh_reset_caches()` i
      test-setup hvis nødvendigt). YAML-fil-aendringer kraever pakke-reinstall
      for at traede i kraft i runtime; tests bruger custom texts_loader saa
      i18n-cache er ikke en bekymring der.

## 4. Tests

- [x] 4.1 Opdater eksisterende tests der nu fejler pga. ændret klassifikation:
      - `tests/testthat/test-spc_analysis.R`: identificer fixtures der nu
        klassificerer anderledes; verificer at ny klassifikation er statistisk
        korrekt; opdater forventede strenge.
      - `tests/testthat/test-summary-precision.R`: opdater hvis matchede
        strenge rammer ændret `action_key`.
- [x] 4.2 Tilføj nye tests for edge cases:
      - **Bug-reproducer:** target = 0.01, CL = 0.019, tight limits (UCL-LCL =
        0.005) → SKAL klassificere som `not_at_target` (specifikt
        `over_target`).
      - **Variable-n p-chart:** subgruppestørrelser fra 50 til 500; verificer
        at `sigma_hat = mean((UCL_i - LCL_i)/6)` over sidste fase.
      - **Run chart fallback:** chart_type = "run", target ≈ CL ± sd(y)/2 →
        `at_target = TRUE`; target ≈ CL ± 2·sd(y) → `at_target = FALSE`.
      - **Degenereret case (sd = 0):** konstant y, target = y → `at_target =
        TRUE`; target ≠ y → `at_target = FALSE`.
      - **Bounded chart (LCL censoreret til 0):** p-chart med CL = 0.02,
        UCL = 0.05, LCL = 0; verificer at sigma_hat ≈ (0.05-0)/6 = 0.0083 og
        klassifikation følger reglen.
      - **Target præcist på UCL:** verificer at boundary inkluderes
        (`≤`-konvention).
      - **Multi-phase (median split):** sigma_hat beregnes fra sidste fase
        alene, ikke fra hele serien.
- [x] 4.3 Tilføj deprecation-warning-test:
      - `expect_warning(bfh_generate_analysis(x, target_tolerance = 0.1),
        "deprecat")` → SHALL fyre advarsel.
      - `expect_silent(bfh_generate_analysis(x))` → default-værdi fyrer ikke.

## 5. Spec sync

- [x] 5.1 Opret delta-spec
      `openspec/changes/at-target-tolerance-process-variation/specs/spc-analysis-api/spec.md`:
      - **MODIFIED Requirement:** "build_fallback_analysis SHALL use direction-
        aware goal logic when target direction is known" — fjern reference
        til `target_tolerance` som tunable parameter i value-neutral gren.
      - **ADDED Requirement:** "Value-neutral at_target classification SHALL
        use process variation as tolerance scale" — dokumentér tre-vejs
        cascade.
      - **MODIFIED Requirement:** "bfh_generate_analysis SHALL produce
        analysis with graceful fallback" — opdatér `target_tolerance`-
        parameterbeskrivelse til at angive deprecation.
- [x] 5.2 Tilføj Scenario blocks for hver ny/ændret requirement
      (bug-reproducer, run chart fallback, deprecation warning).
- [ ] 5.3 Validér: `openspec validate at-target-tolerance-process-variation --strict`.
      (Blokeret: openspec CLI ikke installeret i Windows-miljoeet; retroaktiv
      validering naar/hvis CLI tilgaengelig.)

## 6. Validation

- [ ] 6.1 `devtools::test()` → alle tests green. **Blokeret i lokalt
      Windows-miljoe:** fs 2.0.1 installeret, devtools kraever >= 2.1.0,
      og CRAN-install ikke tilladt af IT/auto-mode policy. Erstattet med
      targeted smoke-test (10/10 PASS) der eksercerer alle nye logik-grene:
      bug-reproducer, vide graenser, run chart fallback, sd=0 degenereret,
      boundary inclusive, direction-aware uchanged, deprecation warning
      fyrer/fyrer-ikke. Skal koeres som `devtools::test()` i CI/anden
      maskine for fuld validering.
- [ ] 6.2 `devtools::check()` → 0 errors, 0 warnings. **Blokeret** som
      ovenfor. Anbefales koert i CI eller paa maskine med opdateret fs.
- [x] 6.3 Kør bug-reproducer manuelt: smoke-test #3 verificerede at
      target=0.01, CL=0.019 nu klassificeres som `over_target` i stedet for
      `at_target`, og at action-tekst skifter til "En målrettet indsats er
      nødvendig for at nå målet" (i.e. `stable_not_at_target` arm).

## 7. Documentation

- [x] 7.1 Tilføj NEWS.md-entry under næste minor version:
      - "Bug fix: `at_target`-klassifikation bruger nu processens variation
        som tolerance-skala i stedet for en relativ-til-target floor. Små
        targets (fx 1 %) der tidligere fejlagtigt blev klassificeret som
        'tæt på' når CL afveg signifikant, klassificeres nu korrekt som
        'over' eller 'under'. Berører output fra
        `bfh_generate_analysis()`."
      - "Deprecated: `target_tolerance`-parameter i `bfh_generate_analysis()`.
        Klassifikation er nu forankret i kontrolgrænserne og ikke længere
        konfigurerbar. Parameter fjernes endeligt i næste major release."
- [x] 7.2 Update roxygen for `bfh_generate_analysis()` (`@param
      target_tolerance`): marker som deprecated, henvis til NEWS.md.
- [ ] 7.3 Kør `devtools::document()` så `.Rd`-filer er synkrone.
      **Blokeret** lokalt (fs version-konflikt); skal koeres i CI eller paa
      maskine med opdateret fs. Roxygen er opdateret men `.Rd` ikke
      regenereret.
- [ ] 7.4 Sync delta-spec til main spec
      `openspec/specs/spc-analysis-api/spec.md` ved arkivering (efter merge).

## 8. Cross-repo coordination

- [ ] 8.1 Opret issue i biSPCharts-repoet om operator-stripping ved UI-input
      (out-of-scope for denne change, men opdaget under diagnose).
- [ ] 8.2 Notify biSPCharts-maintainer (Johan Reventlow) om output-ændring i
      `bfh_generate_analysis()` før release.
