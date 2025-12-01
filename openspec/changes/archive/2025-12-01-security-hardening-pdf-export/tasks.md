# Tasks: Security Hardening for PDF Export

**Status:** pending
**Priority:** Critical
**Tracking:** GitHub Issue #65

## Phase 1: Critical Path Validation

- [ ] 1.1 Add path traversal check in `bfh_export_pdf()` for output parameter
- [ ] 1.2 Add path traversal check for `template_path` parameter
- [ ] 1.3 Add shell metacharacter validation before `system2()` calls
- [ ] 1.4 Add tests for path traversal rejection
- [ ] 1.5 Add tests for shell metacharacter rejection

## Phase 2: Input Validation Strengthening

- [ ] 2.1 Add metadata field type validation
- [ ] 2.2 Add metadata string length limits (max 10,000 chars)
- [ ] 2.3 Add warning for unknown metadata fields
- [ ] 2.4 Add template path symlink resolution
- [ ] 2.5 Add tests for metadata validation

## Phase 3: Defense in Depth

- [ ] 3.1 Set restrictive permissions on temp directory (mode 0700)
- [ ] 3.2 Verify temp directory ownership on Unix systems
- [ ] 3.3 Add file copy integrity verification (size check)
- [ ] 3.4 Sanitize paths in error messages (don't expose full paths)

## Phase 4: Documentation and Release

- [ ] 4.1 Add security test file `tests/testthat/test-security-export-pdf.R`
- [ ] 4.2 Run `devtools::check()` - no new warnings
- [ ] 4.3 Update NEWS.md with security notes
- [ ] 4.4 Bump version to 0.3.3

## Critical Files

### Modified
1. `R/export_pdf.R` - Add validation logic
2. `tests/testthat/test-security-export-pdf.R` - New security tests
3. `NEWS.md` - Security release notes
4. `DESCRIPTION` - Version bump

## Severity Mapping

| Issue | Severity | Phase |
|-------|----------|-------|
| Path traversal in output | CRITICAL | 1 |
| Shell metacharacters | CRITICAL | 1 |
| Metadata validation | HIGH | 2 |
| Symlink resolution | HIGH | 2 |
| Temp dir permissions | MEDIUM | 3 |
