# Tasks: central-export-path-policy

## 1. Implementation

- [ ] 1.1 Opret `R/utils_path_policy.R` med `validate_export_path(path, extension, allow_root)` helper
- [ ] 1.2 Centraliser extension-whitelist (png, pdf, svg, typ)
- [ ] 1.3 Implementér path-normalization + traversal check (`..`, symlink-escape)
- [ ] 1.4 Implementér shell-metacharacter rejection
- [ ] 1.5 Refaktorér `R/export_png.R` til at bruge helper
- [ ] 1.6 Refaktorér `R/export_pdf.R` til at bruge helper
- [ ] 1.7 Refaktorér `R/utils_typst.R` path handling

## 2. Testing

- [ ] 2.1 Test: path traversal `../../etc/passwd` → rejected
- [ ] 2.2 Test: shell metacharacters `;`, `|`, `&`, backtick, `$()` → rejected
- [ ] 2.3 Test: wrong extension for export type → rejected med informativ fejl
- [ ] 2.4 Test: symlink-escape fra allowlist root → rejected
- [ ] 2.5 Test: legitim sti accepteres (normalized + returneret)
- [ ] 2.6 Fjern duplikeret validerings-kode i eksisterende tests

## 3. Documentation

- [ ] 3.1 Roxygen for helper
- [ ] 3.2 NEWS.md: security hardening — centraliseret path policy
