# ADR Template

Based on Michael Nygard's lightweight ADR format, extended with an implementation plan for the project-card skill pipeline.

## Template

```markdown
# ADR-NNNN: [Decision Title]

**Date:** YYYY-MM-DD
**Status:** proposed | accepted | deprecated | superseded by ADR-NNNN
**Deciders:** [who was involved in the decision]

## Context

[What is the problem or situation that motivates this decision? What constraints and forces are at play? 2-5 sentences describing the landscape.]

## Decision

[What is the change that we're proposing and/or doing? State it clearly in 1-2 sentences, then explain the reasoning.]

## Alternatives Considered

### Alternative A: [Name]
[Description of the approach]
- **Pros:** [what's good about it]
- **Cons:** [what's bad about it]
- **Why rejected:** [specific reason this wasn't chosen]

### Alternative B: [Name]
[Same structure]

### Alternative C: Do Nothing
[What happens if we don't make this change? Sometimes this is the right answer.]

## Consequences

**What becomes easier:**
- [Benefit 1]
- [Benefit 2]

**What becomes harder:**
- [Trade-off 1]
- [Trade-off 2]

**Risks:**
- [Risk 1 and mitigation]
- [Risk 2 and mitigation]

## Implementation Plan

### Scope

**IN scope:**
- [Deliverable 1]
- [Deliverable 2]

**OUT of scope:**
- [Explicitly excluded item 1]
- [Explicitly excluded item 2]

### Phases

#### Phase 1: [Theme] (unblocked — start here)
**Files:**
- Create: [exact paths]
- Modify: [exact paths]
- Test: [exact paths]

**Acceptance criteria:**
- [ ] [Specific testable condition]
- [ ] [Specific testable condition]

**Verification:** [exact command]

#### Phase 2: [Theme] (blocked by Phase 1)
[Same structure]

### Verification Strategy
- [How to verify the feature end-to-end]
- [Edge cases to test]
- [Performance/security considerations]

## First Implementation Step

**Before any code is written, decompose this ADR into a tracked series of steps.**
The Implementation Plan above is the input to that decomposition, not a substitute
for it — it has no work items, nothing is assignable or reservable, its phase
ordering is prose rather than real dependency edges, and nobody else can see what
is in flight.

Create the work items in whatever tracker this repository actually uses — a GitHub
project, a Jira epic, a beads board, or something else. Determine which by reading
the repository's own context first: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`,
`.beads/`, issue templates under `.github/`, and any tracker referenced in recent
commits or PR descriptions. Do not assume; check.

Then, in the tracker: one parent item for this ADR, one child per phase, with the
dependency edges the Phases section describes, and the per-phase acceptance
criteria carried across verbatim. Use the project-card skill for the shape of the tracker items.

- [ ] Tracker identified (name it here: __________)
- [ ] Parent item created for this ADR
- [ ] One child item per phase, with dependencies linked
- [ ] Phase acceptance criteria carried into the child items
```

## Usage Notes

- The **Context** and **Decision** sections are for humans reading the ADR months or years later — they need to understand WHY without context from Slack or meetings.
- The **Implementation Plan** section is for whatever creates the work items — the project-card skill, or a human filing issues. Make phases specific enough to be individual cards.
- The **First Implementation Step** section is deliberately the last thing in the document, because it is the first thing to act on. A well-specified plan reads like a card set and tempts a reader straight into code; this section is what stops that, so keep it in even when the plan looks complete enough to work from directly.
- ADRs are **immutable** once accepted. To change a decision, create a new ADR with status "supersedes ADR-NNNN."
- Number ADRs sequentially. Check `ls docs/adrs/` for the next available number.
