# central-export-path-policy

## Why

Sti-validering er gentaget i PNG-eksport (`R/export_png.R`), PDF-eksport
(`R/export_pdf.R`) og Typst-utilities (`R/utils_typst.R`). Det giver:

- Duplikeret validerings-kode (DRY-brud)
- Risiko for inkonsekvente sikkerhedsregler mellem formater
- Output-directories oprettes rekursivt fra brugerinput uden policy-root/allowlist
- Fejlbeskeder fra Quarto kan lække lokale paths og systemdetaljer

Én central path-policy-helper giver konsistent håndhævelse af:
- Path-traversal checks (`..`, absolute paths uden for allowlist)
- Shell metacharacter rejection
- Extension whitelist
- Output-root enforcement

## What Changes

- Opret `R/utils_path_policy.R` med `validate_export_path()` helper
- Helper returnerer normaliseret, validated path eller raiser informativ fejl
- Refaktorér PNG/PDF/Typst call sites til at bruge helperen
- Centraliseret allowlist-config for extensions og output-roots
- Tests: path-traversal, shell-injection, extension-mismatch, symlink-escape

## Impact

**Affected specs:**
- `pdf-export`

**Affected code:**
- `R/utils_path_policy.R` (ny)
- `R/export_png.R` (refaktorér til at bruge helper)
- `R/export_pdf.R` (refaktorér)
- `R/utils_typst.R` (refaktorér)
- `tests/testthat/test-path-policy.R` (ny)

**User-visible changes:**
- Ingen signaturændringer
- Potentielt mere restriktive fejlbeskeder ved tidligere tilladte edge-cases (dokumentér i NEWS)

## Related

- Codex review (path validation duplikation + policy-root)
