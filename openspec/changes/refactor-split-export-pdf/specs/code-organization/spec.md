## ADDED Requirements

### Requirement: PDF export code SHALL be split by responsibility into dedicated modules

The PDF export implementation SHALL separate orchestration from reusable
utility APIs so that each module has a single primary responsibility.

**Rationale:**
- Reduces navigation and review cost in export-related code
- Makes public utility APIs discoverable outside the export pipeline
- Lowers regression risk when changing PDF orchestration versus shared helpers

#### Scenario: Shared utility APIs live outside export_pdf.R

**Given** the package source is inspected
**When** the implementations of `bfh_extract_spc_stats()` and
`bfh_merge_metadata()` are located
**Then** they SHALL live in dedicated `R/utils_*.R` files
**And** `R/export_pdf.R` SHALL NOT be the canonical implementation home for
those functions

#### Scenario: Details generation is isolated from PDF orchestration

**Given** the package source is inspected
**When** `bfh_generate_details()` and its helper formatting functions are
located
**Then** they SHALL live in a dedicated helper module separate from the main
PDF orchestration file

#### Scenario: Export pipeline calls canonical public utility names

**Given** `bfh_export_pdf()` needs SPC stats or merged metadata
**When** the orchestration code invokes those utilities
**Then** it SHALL call `bfh_extract_spc_stats()` and
`bfh_merge_metadata()` directly
**And** duplicate internal alias wrappers SHALL NOT remain
