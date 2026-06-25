---
name: create-feature-plan-adr
description: >-
  Guide the design-before-code phase for a new feature or architectural change.
  Gathers requirements via structured Q&A, researches prior art and alternatives,
  produces an ADR (Architecture Decision Record) with a feature implementation
  plan, then hands off to the project-card skill for epic/card creation. Use when
  starting a new feature, making an architectural decision, choosing between
  alternatives, or when asked to "plan this feature" or "write an ADR."
  Also use when asked to "read existing ADRs" or "revise a decision."
compatibility: Works with any codebase. Optional integration with beads CLI for card handoff via the project-card skill.
license: Apache-2.0
---

# Create Feature ADR

Drive the design phase before any code is written. Produces two things: an ADR (WHY this approach) and a feature plan (HOW to build it). The plan feeds into the project-card skill for epic/card creation; the ADR is what the project-ac-verify skill checks each card against.

**The pipeline:** ADR → Plan → Cards → TDD → Verify. This skill owns the first two steps.

## Mode Detection

Determine the mode from the user's request:

| User says | Mode |
|-----------|------|
| "plan this feature", "write an ADR", "design before code" | **Create** (default, below) |
| "show me existing ADRs", "why did we decide X", "what ADRs exist" | **Read** — list and read existing ADRs from `docs/adrs/` or `docs/decisions/` |
| "revise this decision", "supersede ADR", "this decision changed" | **Revise** — create a new ADR that supersedes an existing one |

## Phase 0: Understand the Codebase (BEFORE asking questions)

**Do NOT ask questions yet.** First, build understanding of the project so your questions are informed, not generic. Read in this order:

1. **Project identity** — read `README.md`, `CLAUDE.md`, `AGENTS.md`, or `GEMINI.md` for project overview, tech stack, and conventions
2. **Existing ADRs** — `ls docs/adrs/ docs/decisions/ 2>/dev/null` — read any existing ADRs to understand prior decisions and the format used. If an ADR already covers this topic, tell the user: "ADR-NNNN already addresses [topic]. Are you revising that decision, or is this a separate concern?"
3. **Existing plans** — `ls docs/plans/ docs/designs/ 2>/dev/null` — check for existing implementation plans, design docs, or feature specs. If a plan exists for this feature:
   - Read it completely
   - Tell the user: "There's already a plan for this at [path]. Should this ADR build on that plan, revise it, or is this separate work?"
   - If building on it, the ADR should reference the existing plan and the plan section should extend/update it, not start from scratch
4. **In-flight work** — check for existing cards/issues related to this feature:
   ```bash
   bd search "<feature keywords>" 2>/dev/null || echo "No beads board"
   git log --oneline -20 | grep -i "<feature keywords>" || echo "No recent commits"
   git branch -a | grep -i "<feature keywords>" || echo "No feature branches"
   ```
   If cards are found, **read them with `bd show <id>`** — don't just note they exist. Read the description, notes, and any linked research reports. If a card references a research document (e.g., `docs/research/...`), read that too. The goal is to understand what was already decided, researched, and concluded — not just that work exists.
5. **Architecture** — scan the directory structure to understand layers:
   ```bash
   find . -maxdepth 2 -type d | grep -v node_modules | grep -v .git | sort
   ```
6. **Tech stack** — read `package.json`, `Gemfile`, `go.mod`, `pyproject.toml`, `Cargo.toml` (whichever exists) to understand dependencies
7. **Test structure** — `ls spec/ test/ tests/ __tests__/ 2>/dev/null` to understand the testing approach
8. **API surface** — check for OpenAPI specs, GraphQL schemas, protobuf definitions, route files

**Summarize what you found** before asking questions:
> "This is a [Rails/Go/Node] project with [Vue/React/none] frontend, [N] existing ADRs, [N] existing plans, testing via [RSpec/pytest/vitest], and [API type]. [Existing work status: no prior work / existing plan at X / in-flight cards Y]. The feature you described would likely touch [layers]."

### Phase 0 Decision Gate

Based on what you found, route to the right path:

**If existing decision + research found (cards, reports, expert reviews):**
- Read the research reports and card descriptions completely — not just the titles
- Present what was decided, by whom, and what evidence supports it
- Ask the user:
  - "Formalize as ADR" → skip Phase 1 Q&A, go to Phase 3 and draft the ADR from the existing research. The decision is already made — the ADR captures it, not re-decides it.
  - "Revise the decision" → go to Phase 1 Q&A but pre-fill answers from the existing research. Focus questions on what changed.
  - "This is premature" → note the blocker, save context for later, stop.

**If existing plan but no decision:**
- The plan describes HOW but not WHY. The ADR adds the missing decision rationale.
- Go to Phase 1 Q&A but skip questions the plan already answers (scope, phases, files).
- Focus on: why this approach? what alternatives were rejected? what are the consequences?

**If no prior work found:**
- Clean slate. Go to Phase 1 Q&A with all questions.

## Phase 1: Gather Requirements (informed Q&A)

Now ask questions — tailored to what you learned in Phase 0.

**Question 1: What are you building?**
Describe the feature or change in one sentence. If the user already said it, confirm: "So we're building [X] — correct?"

**Question 2: Why is this needed?**
- What problem does this solve?
- Who benefits? (end users, developers, operations, compliance)
- What happens if we DON'T do this?

**Question 3: Which layers does this touch?**
Based on your Phase 0 codebase review, present what you found and ask the user to confirm or correct:
- "I see this project has [backend/API/frontend/database/infrastructure]. Which layers does this feature affect?"
- Present as structured options based on the actual project structure, not a generic list

**Question 4: What are the constraints?**
- Timeline (when does this need to ship?)
- Compatibility (what must it work with? what can it break?)
- Dependencies (what must exist before this can start?)
- Regulatory/compliance requirements (if any)

**Question 5: What alternatives exist?**
Before asking the user, **research alternatives yourself:**
- Search for how other projects solve this problem (web search, Context7 MCP)
- Check if a library/tool already does this
- Review existing ADRs — was this considered before?
- Consider the "do nothing" alternative

Present what you found: "I researched alternatives and found [A, B, C]. Are there others you've considered?"

For each alternative, document:
- What is the approach?
- What are its trade-offs (pros AND cons)?
- Is there prior art?

**Question 6: What's the recommended approach?**
- Which alternative do you recommend and why?
- What specifically makes it better than the others?
- What are you giving up by choosing this over the alternatives?

**Question 7: What's the scope?**
- **IN scope** — what this feature delivers (be specific)
- **OUT of scope** — what this feature explicitly does NOT cover (prevents scope creep)
- **Future work** — what might come later but is not part of this effort

**Question 8: How will you know it works?**
Based on the project's testing approach (from Phase 0):
- What does success look like?
- What commands verify the feature is correct? (suggest based on the project's test runner)
- What edge cases need testing?

## Phase 2: Deep Research

After gathering initial answers, research more deeply before drafting:

1. **Framework & ecosystem research** — before deciding HOW to build, check what the framework already provides:
   - Use Context7 MCP or web search to look up the framework's built-in mechanism for this feature
   - If the framework has a built-in way (e.g., `has_secure_token` in Rails, `Suspense` in React, middleware in Express), USE IT — don't build a custom version
   - If a well-maintained library solves this, prefer it over custom code
   - Document what you found in the ADR's Alternatives section

2. **Existing codebase patterns** — grep the codebase for how similar features are already implemented:
   ```bash
   # How does the codebase already handle [similar pattern]?
   grep -rn "pattern_keyword" app/ src/ lib/ --include="*.{rb,ts,py,go}" | head -20
   ```
   If an existing pattern covers this, the plan MUST follow it. If the pattern is wrong, fix the pattern first (separate card before the feature cards).

3. **Check existing ADRs and plans** — was this already decided or planned?
   ```bash
   ls docs/adrs/ docs/decisions/ docs/plans/ 2>/dev/null
   ```

4. **Research how other projects solve this** — major open-source projects in the same ecosystem are the best reference.

## Phase 3: Draft the ADR + Plan

Save to `docs/adrs/NNNN-feature-name.md` (create the directory if it doesn't exist). Use the next available number, or ask the user.

Read [references/adr-template.md](references/adr-template.md) for the full template. The ADR follows Michael Nygard's lightweight format, extended with an implementation plan and quality standards.

**ADR sections:**
1. **Context** — the problem, constraints, and forces (from Q&A questions 1-4)
2. **Decision** — the chosen approach and why (from Q&A question 6)
3. **Alternatives Considered** — each alternative with trade-offs, including framework built-ins and existing libraries (from Phase 2 research + Q&A question 5)
4. **Consequences** — what changes, what risks, what's easier/harder after this decision

**Implementation Plan sections:**
5. **Quality Standards** — established ONCE here, inherited by EVERY card (see below)
6. **Shared Abstractions** — what's common across phases, built first (DRY from design)
7. **Phases** — ordered by dependency, with files, ACs, verification per phase

### Quality Standards (baked into the plan, inherited by every card)

Before defining phases, establish these for the feature. Each becomes a constraint on every card the project-card skill creates from this plan.

**Framework-first:**
- What does the framework provide for this? Document it. Cards MUST use the built-in mechanism unless the ADR explicitly justifies a custom approach.
- What libraries does the project already use for similar needs? Cards MUST use existing dependencies, not add new ones without justification.

**Existing patterns:**
- What pattern does the codebase already use for [this type of feature]? Name the specific file/function. Cards MUST follow this pattern.
- If the existing pattern is wrong, create a "fix the pattern" card BEFORE the feature cards. Never build new features on broken patterns.

**DRY from design:**
- What's shared across multiple phases? (Components, helpers, utilities, types, test fixtures)
- These become Phase 1 cards — built and tested BEFORE any consuming cards. This prevents 3 cards from independently inventing the same abstraction.

**Test strategy per layer:**
- Backend/model changes → unit tests (what framework? what coverage tool?)
- API/controller changes → integration/request tests + contract tests if API schema exists
- Frontend/UI changes → component tests + visual verification (Playwright MCP or manual browser)
- Data migrations → before/after verification, rollback tested
- Do NOT leave test strategy to individual cards — define it here so every card follows the same approach.

**Security by design (concurrent, not a final gate):**
- Input validation at trust boundaries (user input, API params, file uploads)
- Auth/authz checks on every new endpoint or action
- No secrets in code, config, or logs
- OWASP top 10 reviewed against this feature's surface area
- These are ACs on the relevant cards, not a separate "security review" card at the end.

**Accessibility by design (if the feature has UI):**
- Keyboard navigable (tab order, focus management, keyboard shortcuts)
- ARIA labels on interactive elements
- Screen reader tested
- Color contrast meets WCAG AA
- These are ACs on UI cards, not a separate "a11y pass" at the end.

**Performance awareness:**
- Query count constraints (N+1 check on any new data fetching)
- Bundle size impact (if adding frontend dependencies)
- Load time budget (if adding to a critical path)
- State these as constraints in the plan; cards that violate them fail verification.

**Migration & data safety (if schema changes):**
- Migrations must be reversible
- Backfill strategy for existing data
- Rollback plan documented
- Zero-downtime deployment considerations

### Shared Abstractions (DRY from design)

Before listing phases, identify what's shared:

| Shared need | Used by | Card it as |
|-------------|---------|-----------|
| [New component/helper/type] | Phases N, M, P | Phase 1 foundation card |
| [New test fixture/factory] | All test cards | Phase 1 foundation card |
| [New API convention] | All API cards | Document in plan, reference from cards |

### Phases

Now define phases. Each phase becomes a card (or set of cards) via the project-card skill.

The implementation plan section is structured so the project-card skill can read it and create the epic + child cards directly from it. Every card inherits the Quality Standards above — they're not repeated per card, they're the plan's ground rules.

Show the draft to the user: "Here's the ADR. What's missing or wrong?"

## Phase 4: Finalize and Hand Off

1. Confirm the ADR status is "proposed" (becomes "accepted" after team review)
2. Save the file
3. Ask: "Ready to create cards from this plan? Invoke the project-card skill to create the epic and cards from the Implementation Plan section."

## Gotchas

- An ADR that says "we chose X" without listing alternatives is not an ADR — it's a post-hoc rationalization. Always document what was considered and rejected.
- The implementation plan must be specific enough for the project-card skill to create testable cards. "Implement the feature" is not a plan. "Phase 1: add the model migration + factory + request spec" is.
- ADRs are immutable once accepted. If a decision changes, create a new ADR that supersedes the old one — don't edit the original.
- The "do nothing" alternative is always valid. If the problem isn't worth solving, the ADR should say so.

## Related Skills

- project-card skill — creates epic + cards from the implementation plan section
- project-tdd skill — executes each card with quality gates
- project-ac-verify skill — verifies each card against the ADR's decision and plan
