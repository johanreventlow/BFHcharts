# Proposal: Security Hardening for PDF Export

**Status:** draft
**Created:** 2025-12-01
**Priority:** Critical
**Tracking:** GitHub Issue #65
**Source:** Security Code Review (automated agent analysis)

## Summary

Security review identified multiple vulnerabilities in `R/export_pdf.R` that could allow path traversal attacks, command injection, and DoS via malicious input. These issues require immediate attention before production deployment in clinical environments.

## Motivation

The PDF export functionality handles user-provided file paths and metadata that are used in:
1. File system operations (write to arbitrary paths)
2. External command execution (Quarto CLI)
3. Generated document content (Typst templates)

In a clinical context, these vulnerabilities could:
- Allow unauthorized file access/modification (HIPAA/GDPR violations)
- Enable code execution on the server
- Cause denial of service through resource exhaustion

## Proposed Changes

### 1. Path Traversal Prevention (CRITICAL)

**Problem:** User-provided `output` path is not validated for `..` sequences.

**Attack:** `bfh_export_pdf(chart, "../../etc/cron.d/malicious.pdf")`

**Fix:** Add validation in `bfh_export_pdf()`:
```r
if (grepl("\\.\\.", output, fixed = TRUE)) {
  stop("output path cannot contain '..' (path traversal attempt)", call. = FALSE)
}
```

### 2. Shell Metacharacter Validation (CRITICAL)

**Problem:** File paths passed to `system2()` could contain shell metacharacters.

**Fix:** Validate paths before `system2()` call in `bfh_compile_typst()`:
```r
shell_metachars <- c(";", "|", "&", "$", "`", "(", ")", "{", "}", "<", ">", "\n")
if (any(sapply(shell_metachars, function(c) grepl(c, output, fixed = TRUE)))) {
  stop("output path contains unsafe characters", call. = FALSE)
}
```

### 3. Metadata Validation (HIGH)

**Problem:** Metadata list contents not validated - could cause DoS or injection.

**Fix:** Add validation for:
- String length limits (max 10,000 characters)
- Type checking for each field
- Warning for unknown fields

### 4. Template Path Symlink Resolution (HIGH)

**Problem:** Template path could be symlink to sensitive file.

**Fix:** Resolve symlinks and validate real path:
```r
real_path <- normalizePath(template_path, mustWork = TRUE)
```

### 5. Temp Directory Security (MEDIUM)

**Problem:** Race condition in temp directory creation.

**Fix:** Set restrictive permissions and verify ownership.

## Impact

- **Security:** Closes critical attack vectors
- **Compatibility:** No API changes - only stricter validation
- **Clinical:** Required for HIPAA/GDPR compliance

## Testing Requirements

- Add security test suite (`test-security-export-pdf.R`)
- Test path traversal rejection
- Test shell metacharacter rejection
- Test metadata length limits

## References

- Security Code Review (2025-12-01)
- OWASP Path Traversal: https://owasp.org/www-community/attacks/Path_Traversal
