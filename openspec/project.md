# Project Context

## Purpose
[Describe your project's purpose and goals]

## Tech Stack
- [List your primary technologies]
- [e.g., TypeScript, React, Node.js]

## Project Conventions

### Code Style
[Describe your code style preferences, formatting rules, and naming conventions]

### Architecture Patterns
[Document your architectural decisions and patterns]

### Testing Strategy
[Explain your testing approach and requirements]

### Git Workflow
[Describe your branching strategy and commit conventions]

## Domain Context
[Add domain-specific knowledge that AI assistants need to understand]

## Important Constraints
[List any technical, business, or regulatory constraints]

## External Dependencies
[Document key external services, APIs, or systems]

## GitHub Integration

### OpenSpec + GitHub Issues

This project uses a **complementary approach** where OpenSpec changes are tracked via both `tasks.md` files (source of truth for implementation details) and GitHub issues (high-level tracking and visibility).

**Rationale:**
- Preserves OpenSpec workflow (offline-first, structured validation)
- Gains GitHub visibility (project boards, search, notifications, cross-references)
- Enables automation via slash commands

### Label System

**OpenSpec-specific labels:**
- `openspec-proposal` - Change in proposal phase (yellow)
- `openspec-implementing` - Change being implemented (blue)
- `openspec-deployed` - Change archived/deployed (green)

**Type labels (existing):**
- `enhancement`, `bug`, `documentation`, `technical-debt`, `performance`, `testing`

### Automated Workflow

**Stage 1: Proposal** (`/openspec:proposal`)
```bash
# Automatically creates GitHub issue with:
gh issue create --title "[OpenSpec] add-feature" \
  --body "$(cat openspec/changes/add-feature/proposal.md)" \
  --label "openspec-proposal,enhancement"

# Issue reference added to proposal.md:
## Related
- GitHub Issue: #142
```

**Stage 2: Implementation** (`/openspec:apply`)
```bash
# Updates issue label and adds comment:
gh issue edit 142 --add-label "openspec-implementing" --remove-label "openspec-proposal"
gh issue comment 142 --body "Implementation started"
```

**Stage 3: Archive** (`/openspec:archive`)
```bash
# Updates label, closes issue with timestamp:
gh issue edit 142 --add-label "openspec-deployed" --remove-label "openspec-implementing"
gh issue close 142 --comment "Deployed via openspec archive on $(date +%Y-%m-%d)"
```

### Linking Pattern

**In proposal.md:**
```markdown
## Why
[Problem description]

## What Changes
- [Change list]

## Impact
- Affected specs: [capabilities]
- Affected code: [files]

## Related
- GitHub Issue: #142
```

**In tasks.md:**
```markdown
## 1. Implementation
- [ ] 1.1 Create schema (see #142)
- [ ] 1.2 Write tests (see #142)
- [ ] 1.3 Deploy (see #142)

Tracking: GitHub Issue #142
```

### Manual Operations

If automatic GitHub integration fails or needs manual intervention:

```bash
# Create issue manually
gh issue create --title "[OpenSpec] add-feature" \
  --body "$(cat openspec/changes/add-feature/proposal.md)" \
  --label "openspec-proposal,enhancement"

# Update labels manually during implementation
gh issue edit 142 --add-label "openspec-implementing" --remove-label "openspec-proposal"

# Close manually after deployment
gh issue close 142 --comment "Deployed via openspec archive on 2025-11-02"
```

### Best Practices

**Do:**
- ✅ Create GitHub issue for every OpenSpec change (automatic via `/openspec:proposal`)
- ✅ Reference issue in commit messages (`fixes #142`, `relates to #142`)
- ✅ Keep tasks.md as source of truth for implementation details
- ✅ Use GitHub issue for discussions and stakeholder visibility
- ✅ Update issue labels as workflow progresses (automatic via slash commands)

**Don't:**
- ❌ Skip GitHub issue creation
- ❌ Update tasks.md via GitHub (tasks.md is authoritative, sync is one-way)
- ❌ Close issues before archiving change (use `/openspec:archive` workflow)
- ❌ Use GitHub issues for implementation checklists (that's tasks.md's role)
