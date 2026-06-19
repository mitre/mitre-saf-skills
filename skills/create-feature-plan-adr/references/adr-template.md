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
```

## Usage Notes

- The **Context** and **Decision** sections are for humans reading the ADR months or years later — they need to understand WHY without context from Slack or meetings.
- The **Implementation Plan** section is for the project-card skill — it reads this to create the epic and child cards. Make phases specific enough to be individual cards.
- ADRs are **immutable** once accepted. To change a decision, create a new ADR with status "supersedes ADR-NNNN."
- Number ADRs sequentially. Check `ls docs/adrs/` for the next available number.
