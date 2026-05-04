## 1. Slice 1 -- `caching-system` refit

- [ ] 1.1 Inspicer `R/cache_marquee_styles.R` for at dokumentere
      faktisk cache-API (cache-key beregning, invalidation, eksport-
      status). Identificer invarianter der skal kontraktes (e.g.
      idempotent get/set, no-op clear paa empty cache, thread-safety
      antagelser).
- [ ] 1.2 Opdater `openspec/specs/caching-system/spec.md`:
      - Erstat Purpose section med beskrivelse af marquee-cache som
        primaer caching-mekanisme (label-rendering hot path).
      - Fjern alle requirements der refererer til
        `configure_grob_cache()` / `clear_grob_cache()`.
      - Bevar requirements der dokumenterer principper (hvis nogen
        er saa generiske at de stadig holder, e.g. "package SHALL
        document caching strategy").
      - Tilfoej minimum 1 Scenario block per resterende requirement.
- [ ] 1.3 Opret delta-spec
      `openspec/changes/cleanup-stale-spec-issues/specs/caching-system/spec.md`
      med `## REMOVED Requirements` for grob-cache-references og
      `## MODIFIED Requirements` / `## ADDED Requirements` for
      marquee-cache contracts.

## 2. Slice 2 -- `code-organization` #7 line-cap fjernes

- [ ] 2.1 Inspicer `R/utils_add_right_labels_marquee.R` for at
      verificere faktisk struktur (orchestrator + named helpers +
      cleanup-closures). Notér helper-listen for at sikre at den
      omformulerede requirement matcher.
- [ ] 2.2 Opret delta-spec
      `openspec/changes/cleanup-stale-spec-issues/specs/code-organization/spec.md`
      med `## MODIFIED Requirements` for "Label-pipeline orchestrators
      SHALL follow 3-layer decomposition":
      - Fjern hard 220-line cap.
      - Beholdn krav om named helpers, isolation-testbarhed,
        cleanup-closures.
      - Tilfoej eksplicit guidance: orchestrator-rolle handler om
        _ansvar_, ikke linje-tal.
      - Tilfoej Scenario for "orchestrator SHALL NOT contain inline
        device-acquisition" (kvalitativ test).

## 3. Slice 3 -- spec-boundary praecisering

- [ ] 3.1 Identificer overlap mellem `public-api` og `spc-analysis-api`:
      - `bfh_extract_spc_stats()` signatur (begge specs).
      - `bfh_merge_metadata()` signatur (begge specs).
      - `cl_user_supplied`-attribute (begge specs efter 0.16.0
        sync).
      - Anhoej-signal-interpretation (`public-api` har "what" --
        `spc-analysis-api` har "how").
- [ ] 3.2 Opdater `public-api` Purpose: "ejer af user-facing API
      contracts (signaturer, eksport-status, return-types,
      attribute-existence)".
- [ ] 3.3 Opdater `spc-analysis-api` Purpose: "ejer af internal
      signal-detection logic (Anhoej rules, fallback-narrative
      dispatch, threshold semantics)".
- [ ] 3.4 Fjern duplikeret indhold:
      - I `spc-analysis-api`: fjern signatur-detaljer for
        `bfh_extract_spc_stats()` og `bfh_merge_metadata()` --
        erstat med "See public-api Requirement: X for signature".
      - I `public-api`: fjern Anhoej-signal-tolkning-detaljer --
        erstat med "See spc-analysis-api Requirement: Y for
        interpretation".
- [ ] 3.5 Opret delta-specs:
      - `openspec/changes/cleanup-stale-spec-issues/specs/public-api/spec.md`
      - `openspec/changes/cleanup-stale-spec-issues/specs/spc-analysis-api/spec.md`
      med `## MODIFIED Requirements` for Purpose + de praeciserede
      requirements.

## 4. Validation

- [ ] 4.1 `openspec validate cleanup-stale-spec-issues --strict` skal
      vaere green.
- [ ] 4.2 Sync delta-specs til main specs (haandholdt eller via
      openspec-sync-specs skill).
- [ ] 4.3 `openspec validate --specs --strict` skal vaere 7/7
      green efter sync.

## 5. Documentation

- [ ] 5.1 NEWS.md (development): tilfoej kort entry under
      `## Interne aendringer`:
      "Spec-cleanup: refit caching-system til marquee-cache only,
      fjern arbitraer 220-line target i code-organization #7,
      praeciseret boundary mellem public-api og spc-analysis-api
      ejerskab."
- [ ] 5.2 Ingen ADR -- aendringer er rent dokumentations-cleanup uden
      arkitekturelle beslutninger der kraever permanent record.

## 6. Out-of-scope follow-up

- [ ] 6.1 Phase 1 #14 (pdf-smoke.yaml comment refresh) -- pre-tool-use
      hook blokerer; manuel opgave for maintainer.
- [ ] 6.2 Verify implementation matches new code-organization #7
      kontrakt for `add_right_labels_marquee.R` (kvalitativ review
      af helpers, ej i scope for spec-aendringen).
