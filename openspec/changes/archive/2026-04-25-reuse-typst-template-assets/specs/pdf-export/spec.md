## ADDED Requirements

### Requirement: Batch export SHALL support Typst template asset reuse

The package SHALL provide an opt-in batch-session mechanism that reuses the
Typst template directory across multiple PDF exports, avoiding repeated
recursive directory copy.

**Rationale:**
- Recursive asset copy per export is the dominant I/O cost for batch workflows
- Healthcare reports often require hundreds of exports (per-department)
- Repeated copy grows linearly with export count

**Session lifecycle:**
- `bfh_create_export_session()` creates one template-populated tmpdir + handle
- Passing handle as `batch_session` to `bfh_export_pdf()` reuses assets
- Closing the session (or `on.exit`) removes the tmpdir

#### Scenario: Batch session reuses template directory

**Given** a batch export session
**When** `bfh_export_pdf()` is called 10 times with the same `batch_session`
**Then** the Typst template directory SHALL be copied exactly once
**And** 10 PDFs SHALL be produced

```r
session <- bfh_create_export_session()
on.exit(close(session))
for (dept in departments) {
  bfh_export_pdf(results[[dept]], paste0(dept, ".pdf"),
                 batch_session = session)
}
# Template tmpdir populated once; ten PDFs generated
```

#### Scenario: Single export without session preserves legacy behavior

**Given** `bfh_export_pdf()` is called without `batch_session`
**When** export runs
**Then** the function SHALL copy the template, export, and tear down tmpdir
**And** behavior SHALL be identical to the pre-change implementation

#### Scenario: Session close cleans up tmpdir

**Given** an open batch session
**When** `close(session)` is called
**Then** the session tmpdir SHALL be removed
**And** subsequent use of the session SHALL raise an error
