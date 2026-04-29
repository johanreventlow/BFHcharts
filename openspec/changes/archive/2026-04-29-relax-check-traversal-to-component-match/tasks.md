## 1. Implementation

- [ ] 1.1 Replace `.check_traversal()` body with `strsplit` + `any(parts == "..")` logic
- [ ] 1.2 Handle both `/` and `\\` separators for cross-platform
- [ ] 1.3 Preserve error message format and class

## 2. Tests

- [ ] 2.1 Add positive tests in `tests/testthat/test-path-policy.R`:
  - `report..v2.pdf` → accepted
  - `..hidden.pdf` → accepted
  - `data..backup.csv` → accepted
  - `analyse..final.pdf` → accepted
- [ ] 2.2 Verify negative tests still reject:
  - `../etc/passwd` → rejected
  - `output/../secret.pdf` → rejected
  - `../../sensitive.pdf` → rejected
  - `subdir/..` → rejected
  - `subdir/../child.pdf` → rejected
- [ ] 2.3 Cross-platform: test with `\\` separators (Windows-style paths)

## 3. Documentation

- [ ] 3.1 Update `.check_traversal` Roxygen
- [ ] 3.2 NEWS entry under `## Bug fixes`

## 4. Release

- [ ] 4.1 PATCH bump
- [ ] 4.2 Tests pass
- [ ] 4.3 No new WARN/ERROR

Tracking: GitHub Issue #214
