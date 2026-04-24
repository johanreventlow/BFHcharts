## 1. Specification

- [x] 1.1 Beskriv helper-opdelingen for `bfh_qic()` i `code-organization`
- [x] 1.2 Dokumentér ansvar og input/output for signal-helper og
  return-helper i design-noten

## 2. Implementation

- [x] 2.1 Ekstraher Anhøj signal-postprocessering til en intern helper
- [x] 2.2 Ekstraher legacy return-routing til en intern helper
- [x] 2.3 Opdater `bfh_qic()` til at orkestrere kald til helpers uden
  adfærdsændring

## 3. Verification

- [x] 3.1 Tilføj målrettede tests for signal-helperen
- [x] 3.2 Tilføj målrettede tests for `return.data` / `print.summary`
  kombinationerne via return-helperen
- [x] 3.3 Kør relevante `bfh_qic()` tests
- [x] 3.4 Kør `openspec validate refactor-extract-bfh-qic-helpers --strict`

Tracking: GitHub Issue #117
