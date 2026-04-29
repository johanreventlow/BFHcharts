## Why

Codex finding #7: `bfh_create_export_session()` shares a single `temp_dir` across all `bfh_export_pdf()` calls in batch mode. Each export writes fixed filenames `chart.svg` and `document.typ` to the same directory:

```r
# R/export_pdf.R:367
on.exit(
  {
    unlink(file.path(temp_dir, "chart.svg"))
    unlink(file.path(temp_dir, "document.typ"))
  },
  add = TRUE
)
```

**Documented limitation:** "Sessions are single-threaded sequential only — do not share across parallel workers" (`R/export_session.R:32`).

**Risks:**
1. **Parallel race**: if user violates the documentation and calls `bfh_export_pdf()` from `future_lapply()`, two exports overwrite each other's `chart.svg`/`document.typ` → corrupt PDFs
2. **Sequential ambiguity**: even sequential reuse risks orphan cleanup if one export crashes mid-render
3. **No enforcement**: nothing prevents parallel use; documentation alone is insufficient

Sequential safety is also weaker than it could be — adding per-export unique filenames eliminates the race entirely without adding overhead.

## What Changes

- **NON-BREAKING**: replace fixed `chart.svg` / `document.typ` filenames with per-export unique names (`chart-<rand>.svg`, `document-<rand>.typ`) using `tempfile(tmpdir = temp_dir, fileext = ".svg")`
- Update cleanup logic to reference the actual generated filenames (track via local variables, not hardcoded names)
- Add lock file mechanism (optional, defer to discussion): `flock`-style PID-based lock on `temp_dir` prevents accidental parallel use
- Add `reg.finalizer()` on session object as backup cleanup if user forgets `close()`
- New tests:
  - Sequential 5x batch → all PDFs unique and valid
  - Concurrent (intentional) batch via `future`/`parallel` → either succeeds with isolated artifacts OR fails fast with clear error
  - Crash mid-export → cleanup correctly removes only that export's files
- Document race-safety guarantees explicitly in `bfh_create_export_session()` Roxygen

## Impact

**Affected specs:**
- `pdf-export` — MODIFIED requirement: batch session SHALL use per-export unique filenames

**Affected code:**
- `R/export_pdf.R:367-371, 431, 461` — replace fixed filenames with unique
- `R/export_session.R` — add `reg.finalizer()`, expand Roxygen on safety guarantees
- `tests/testthat/test-export-session.R` — extend with concurrency tests (using parallel package or simulated)
- NEWS entry under `## Bug fixes` or `## Forbedringer`

**Non-breaking:**
- Public API unchanged
- Sequential semantics unchanged
- Just removes possibility of fixed-name collision

## Cross-repo impact (biSPCharts)

biSPCharts likely uses `bfh_create_export_session()` in dashboard batch flows. No code change required — but biSPCharts can now safely consider parallelism if needed.

## Related

- GitHub Issue: #213
- Source: BFHcharts code review 2026-04-27 (Codex #7)
