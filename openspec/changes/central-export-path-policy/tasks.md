# Tasks: central-export-path-policy

## 1. Implementation

- [x] 1.1 Opret `R/utils_path_policy.R` med `validate_export_path(path, extension, allow_root)` helper
- [x] 1.2 Centraliser extension-whitelist (png, pdf, svg, typ)
- [x] 1.3 Implementér path-normalization + traversal check (`..`, symlink-escape)
- [x] 1.4 Implementér shell-metacharacter rejection
- [x] 1.5 Refaktorér `R/export_png.R` til at bruge helper
- [x] 1.6 Refaktorér `R/export_pdf.R` til at bruge helper
- [x] 1.7 Refaktorér `R/utils_typst.R` path handling

## 2. Testing

- [x] 2.1 Test: path traversal `../../etc/passwd` → rejected
- [x] 2.2 Test: shell metacharacters `;`, `|`, `&`, backtick, `$()` → rejected
- [x] 2.3 Test: wrong extension for export type → rejected med informativ fejl
- [x] 2.4 Test: symlink-escape fra allowlist root → rejected
- [x] 2.5 Test: legitim sti accepteres (normalized + returneret)
- [x] 2.6 Fjern duplikeret validerings-kode i eksisterende tests

## 3. Documentation

- [x] 3.1 Roxygen for helper
- [x] 3.2 NEWS.md: security hardening — centraliseret path policy
