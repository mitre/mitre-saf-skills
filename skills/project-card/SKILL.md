---
name: project-card
description: Create and fix beads cards following the MANDATORY card template (Phase 0 preamble + 12 standard sections). Invoke EVERY time before running bd create or when fixing non-compliant cards.
compatibility: Requires beads CLI (bd)
license: Apache-2.0
---

# Project Card Creation & Repair

**INVOKE THIS SKILL before every `bd create` call and when fixing non-compliant cards.** No exceptions.

## The Template (Phase 0 preamble + 12 standard sections)

Every card MUST have the Phase 0 preamble plus ALL 12 standard sections.

```
## Phase 0 — MANDATORY REMINDER (read before every card)
**CORRECTNESS IS THE ONLY PRIORITY.** Best practices, standards, DRY, maintainable code — always. No shortcuts, no hacks, no workarounds. Card-close velocity is NOT a metric. Speed is NOT a goal. If an AC requires research, DO THE RESEARCH. If an AC requires a specific format (XLSX, YAML, etc.), implement THAT FORMAT — do not substitute. Read the ADR section referenced below BEFORE writing code. Every AC gets evidence before close. The `/project-ac-verify` gate blocks `bd close` mechanically — an independent reviewer checks your work.

---

Title: [Verb] [what] — [context]

Description:
[What this card delivers and why it matters. 2-3 sentences.]
Design doc: [link §section if applicable]

Files:
- Create: [exact paths of new files]
- Modify: [exact paths of files to change]
- Test: [exact paths of test files]

First failing test:
[The exact test to write first — TDD starting point]

Acceptance criteria:
- [ ] [Specific testable condition 1]
- [ ] [Specific testable condition 2]
- [ ] [Specific testable condition 3]
- [ ] All work via TDD (failing test first)
- [ ] No regressions on existing tests
- [ ] Live tested against running app — method matches the layer changed:
  - Backend/model → `rails runner` with real data
  - API/controller response → `curl` or `rails runner` against running server
  - HAML prop shape → `rails runner` to verify data + Playwright if it affects rendering
  - Vue/CSS/HAML visual → Playwright screenshot (light + dark mode)
  - Proof pasted in card notes before closing

Verification:
[exact test command] && [compiler check command — e.g., npx tsc --noEmit]

Decision points:
- [Situations where Claude MUST stop and ask before proceeding]

Anti-patterns:
- [Specific things NOT to do — no hacks, no shortcuts, no guessing]

NOT in scope:
- [What this card explicitly does NOT cover]
- [Adjacent work that belongs on a separate card]

Before closing:
- [ ] Re-read the Phase 0 preamble — correctness is the only priority
- [ ] **EVERY AC checkbox verified with evidence — NO EXCEPTIONS, NO DEFERRALS**
- [ ] Re-read Anti-patterns — confirm none violated
- [ ] Run the exact Verification command — paste output
- [ ] Live test proof pasted in card notes — method matches layer changed
- [ ] AC verification gate resolved with evidence (never `--force` to bypass)
- [ ] git diff shows ONLY files listed in Files section
- [ ] If closing 2+ cards in a row: STOP. Are you rushing? Verify each one fully.

Story points: [sp:N]
Estimate: [minutes, Claude-pace]
```

## Hard Gate — Count Sections Before Creating

Before running `bd create`, verify the Phase 0 preamble plus ALL 12 standard sections are present:

0. **Phase 0 preamble** — the correctness-over-speed block at the top (always the same text)
1. **Title** — starts with a verb (Extract, Fix, Add, Test, Cover, Refactor)
2. **Description** — 2-3 sentences + design doc link
3. **Files** — Create / Modify / Test with exact file paths (use "none" not omit)
4. **First failing test** — exact test name. For epics: "See child cards"
5. **Acceptance criteria** — 3+ specific checkboxes + TDD + no regressions
6. **Verification** — exact command (e.g., `bundle exec rspec`, `yarn vitest run`, `go test ./...`)
7. **Decision points** — at least one, or "none" explicitly
8. **Anti-patterns** — at least one "Do NOT...", MUST include "Do NOT optimize for card-close velocity or speed"
9. **NOT in scope** — at least one exclusion
10. **Before closing** — the standard checkboxes including `/project-ac-verify` gate
11. **Story points** — sp:1 through sp:13 (Fibonacci)
12. **Estimate** — Claude-pace minutes

**If ANY section is missing (including Phase 0): STOP. Do not run `bd create`. Add the missing section first.**

## TDD Integration

Every card's AC MUST include: `All work via TDD (failing test first)`

When EXECUTING a card, follow the TDD skill before writing any code. The card template defines WHAT to build; the TDD skill defines HOW to build it.

## You Find It You Fix It

When working a card, if you encounter ANY issue — test failure, lint warning, design system violation, broken dark mode — fix it in the same card. Do NOT call it "pre-existing" or card it for later. We own ALL the code.

## Design System Check

If your project has an established design system, every card that touches UI components or CSS MUST include this AC:
`- [ ] Design system compliance verified (project design tokens, shared layout components, global defaults)`

Check your project's design system documentation before writing CSS. If the system provides a variable or component for what you need, USE IT. Examples: CSS custom properties (`var(--project-primary)`), shared layout components, global component defaults.

## Never Blindly Follow Analysis

Agent reviews, expert analyses, Copilot suggestions, and automated tool recommendations are SIGNALS, not instructions. Before implementing ANY recommendation:

1. **Verify the claim** — read the actual docs for the tool/framework
2. **Test locally** — run the suggested change and check for warnings
3. **Question the framing** — is it solving the right problem?

If you can't cite documentation confirming a recommendation is correct, do NOT implement it. "The agent said to" is never justification.

## Best-of-Breed Merge

When rebasing or merging concurrent work from multiple collaborators on the same branch, NEVER blindly take one side. Review BOTH implementations and cherry-pick the best code, tests, and patterns from either side. Compare both versions, keep the better tests regardless of author, use the better pattern regardless of who wrote it. "Ours" or "theirs" as a default is lazy and loses good work.

## Correct Solutions Only — No Shortcuts

Every card's Anti-patterns section must include shortcuts that were considered and rejected. Every Decision points section must identify where a "simpler" approach exists and why it's wrong. When writing a card, if two approaches exist, the card MUST specify the correct one and explicitly call out the shortcut as an anti-pattern. "Option B is simpler" is never justification — "Option A is architecturally correct" always wins. This applies to every card, every decision, every implementation.

## AC Completeness — ABSOLUTE RULE, ALL Work

**A card with ANY unchecked AC is 0% closeable.** There is no "lower priority" exception, no "deferred to follow-up," no "WARNING-level gap documented in notes." If the AC is on the card, it gets done or the card does not close.

**Before running `bd close`:**
1. Run `bd show <card-id>` and re-read every `- [ ]` line
2. For each AC, verify you can paste evidence it's done
3. If ANY AC is unimplemented — do the work, then try again
4. Run `/project-ac-verify <card-id>` — independent agent reviews all ACs against the diff and the referenced design doc section. The bd gate created at card start blocks `bd close` until this passes.

**Why this exists:** In a prior incident, cards were closed with "deferred" ACs documented in notes. THAT BREAKS TRUST. Documenting what was skipped is transparent laziness — still laziness. The root cause was optimizing for card-close velocity instead of AC completeness. Speed is not a goal. Correctness is the only goal.

**Every card's Anti-patterns section MUST include:**
- `- Do NOT close this card with any AC unchecked — no deferrals, no "lower priority" exceptions`

## API Contract Changes Must Propagate Atomically — ALL Work

**If your project maintains an API schema (OpenAPI, protobuf, GraphQL, JSON Schema), every response-shape change must update all downstream layers in the same commit.** The number of layers varies by project, but the principle is absolute: partial updates leave the contract inconsistent.

**Example layers (adapt to your project):**
1. Serializer/presenter — add/modify the field
2. Route — add/modify if new endpoint
3. Request/integration spec — test with specific expected values
4. API schema — update the schema definition for affected response types
5. Contract test — validate real response matches the updated schema
6. Schema validation — run your schema linter/bundler (e.g., `openapi:bundle`, `buf lint`, `graphql-inspector`)
7. Live test — curl/httpie against the running dev server with real data

In **Acceptance criteria** (if your project has an API schema):
- `- [ ] API schema updated for every affected response type`
- `- [ ] Contract test validates real response matches schema`
- `- [ ] Schema validation passes`
- `- [ ] Live tested with real request — output pasted in card notes`

In **Anti-patterns**:
- `- Do NOT change a response shape without updating the API schema in the same commit`
- `- Do NOT close without live test output pasted in card notes`

**Why this exists:** In a prior incident, a new field was added to two serializers (layers 1-3) but the API schema, contract tests, and live test (layers 4-7) were not done. The card was closed as "done." Rule: if you change one layer, you must update all downstream layers. LIVE TEST WITH REAL DATA.

## No Linter Disables as Shortcuts — ALL Work

**Every card's Anti-patterns section MUST include:**
- `- Do NOT add rubocop:disable/eslint-disable to work around warnings — fix the root cause`

**Every card's Before closing section MUST verify:**
- `- [ ] Zero new linter disable comments in the diff`

**Why this exists:** In a prior incident, a linter disable was added to bypass a validation-skipping warning. But the fields were already in the model's audit-exception list — the standard save path was the correct call with no warnings. The disable hid a failure to read the existing code.

## Cross-Layer Callback Validation — ALL Work That Touches save/update

**When a card's Files section includes a controller that calls save/update on a model, the card MUST include these in its AC:**
- `- [ ] All model callbacks traced for save/update calls — no callback-conflicts-endpoint bugs`
- `- [ ] All enum values tested for fields that trigger callbacks`

**And this in Anti-patterns:**
- `- Do NOT assume a model callback is harmless — trace it through every controller action that triggers it`

**Why this exists:** In a prior incident, a `before_save` callback silently undid what a controller action explicitly set. The endpoint cleared a timestamp field; the callback re-set it because a status field was in a terminal state. The user saw success but the database reverted. Tests missed it because they only tested one enum value out of five. This class of bug — ORM lifecycle hook fights controller — is invisible to single-layer tests and applies to any stack with lifecycle hooks (Rails callbacks, Django signals, Sequelize hooks).

## Source Verification — ALL Work

**BEFORE starting ANY card, READ the source files listed in the Files section.** This applies to code, docs, tests — everything. Never work from memory of what a file contains.

- Code card? Read the files you're modifying and the tests you're extending.
- Docs card? Read the source code the docs describe. The project-docs skill enforces this.
- Test card? Read the production code you're testing.
- Refactor card? Read the current implementation before planning changes.

**The rule:** If you haven't run `Read` on a source file in this conversation, you cannot write code or docs that depend on knowing what's in it. "I remember" is never sufficient — code changes between sessions.

---

## How to Create Cards

Write the full 12-section template to a file (e.g. `/tmp/card-desc.md`), then feed it to `bd create` with `--body-file` and `--validate`.

- **`--body-file <file>`** (alias `--stdin` reads from `-`) — pass the description via the native flag, NOT a shell `--description="$(cat …)"`. The template is full of backticks, `$refs`, quotes, and `[ ]`; routing it through a shell substitution is a quoting minefield where one stray backtick or `$` silently corrupts the card. `--body-file` reads the file directly and sidesteps all of it.
- **`--validate`** — mechanically checks the description contains the required sections for the issue type (a backstop for the Hard Gate above; a malformed card fails to create instead of landing broken).
- **`-f/--file <markdown>`** — create *multiple* issues from one markdown file in a single call; handy for a set of sibling cards.

### Task/Bug Cards (children of an epic)

```bash
cat > /tmp/card-desc.md <<'CARD'
[Full 12-section template content]
CARD

bd create \
  --title="Verb what — context" \
  --body-file /tmp/card-desc.md \
  --validate \
  --type=task \
  --priority=1 \
  --parent=<epic-id> \
  --labels sp:2 \
  --estimate 12

rm /tmp/card-desc.md
```

Key flags:
- `--body-file <file>` — read the description from a file (never `--description="$(cat …)"`; alias `--stdin` for `-`)
- `--validate` — fail the create if the description is missing required sections
- `--parent=<epic-id>` — links card as child of the epic (REQUIRED for cards in an epic)
- `--labels sp:N` — story points as a label
- `--estimate N` — Claude-pace minutes
- `--deps <id1>,<id2>` — blocking dependencies (card depends on id1 and id2)
- `--type=task|bug|feature` — issue type

### Epic Cards

```bash
bd create \
  --title="[EPIC] Verb what — context" \
  --body-file /tmp/card-desc.md \
  --validate \
  --type=epic \
  --priority=1 \
  --labels sp:8
```

Epic differences:
- First failing test: "See child cards"
- Description includes: child card count, total estimate
- No `--parent` (epics are top-level)

### Adding Dependencies After Creation

```bash
# child depends on (is blocked by) blocker
bd dep add <child-id> <blocker-id>

# reparent an existing card
bd update <card-id> --parent=<epic-id>
```

---

## How to Fix Non-Compliant Cards

When a card exists but doesn't follow the 12-section template:

### Step 1: Audit the card

```bash
bd show <card-id>
```

Check the description against the 12-section checklist. Note which sections are missing.

### Step 2: Fix the description

Write the corrected full 12-section description to `/tmp/card-desc.md`, then update:

```bash
cat > /tmp/card-desc.md <<'CARD'
[Full corrected 12-section template]
CARD

bd update <card-id> \
  --body-file /tmp/card-desc.md

rm /tmp/card-desc.md
```

### Step 3: Fix structural metadata

```bash
bd update <card-id> --parent=<epic-id>      # Add missing parent link
bd label add <card-id> sp:N                  # Add missing story point label
bd update <card-id> --estimate N             # Set missing estimate
bd dep add <card-id> <blocker-id>            # Add missing dependencies
```

### Fix Checklist

After fixing a card, verify:
- [ ] Title starts with a verb and has `— context`
- [ ] Description has Phase 0 preamble + all 12 standard sections
- [ ] `--parent` is set (if child of an epic)
- [ ] `sp:N` label exists
- [ ] `--estimate` is set in minutes
- [ ] Dependencies are linked (`bd dep list` shows correct blockers)

---

## Linking Checklist

After creating ALL cards in an epic, verify:
- [ ] Every child has `--parent=<epic-id>` set
- [ ] Cards with ordering requirements have `bd dep add` between them
- [ ] Cross-epic dependencies are set
- [ ] `bd children <epic-id>` shows all expected children

---

## Estimation (Claude-pace, latest calibration)

| sp | Claude-pace | Task shape | Calibrated actual |
|---|---|---|---|
| 1 | 4-8 min | One-line edit, rename, config tweak | avg 5.3m (3 cards) |
| 2 | 5-8 min | Single-file refactor + test | avg 6.7m (6 cards) |
| 3 | 10-12 min | Multi-file change + new component | avg 11.3m (3 cards) |
| 5 | 15-20 min | Cross-package refactor, spec split | avg 18m (1 card) |
| 8 | 30-60 min | New service with external integration | (no data yet) |
| 13 | 60-120 min | Full feature with TDD across packages | (extrapolated from sp:3-5 trend) |

Estimates run ~30% high vs actuals. When in doubt, use the lower end of the range.
See `estimation-calibration.md` in this skill directory for raw data and patterns.

## Time Tracking (on close)

When closing a card via `bd close`, always include actual vs estimated time in the reason:

```bash
bd close <id> --reason "Done. Estimated ~12 min, actual ~4 min. [summary of what was done]"
```

This calibrates future estimates. Over time, patterns emerge:
- sp:1 cards consistently take 3 min? Lower the estimate range.
- sp:5 cards consistently take 50 min? Raise it.
- A card took 3x the estimate? Note why — scope was wrong, or blocked by unexpected complexity.

## Suggest Next Card (on close) — MANDATORY

Every card close ends with a concrete next-card recommendation — the workflow
never stalls on "what now?". Pick via `bd ready` / `bd close <id>
--suggest-next`, preferring: same-phase same-epic (momentum) > newly unblocked
by this close > highest-priority fit for the session focus. Present ONE line:
`Next: <id> — <title> (<sp>, ~<est>) — <reason>`. Two options max when truly
ambiguous, with a recommendation. Full procedure: project-tdd "Suggest Next
Card".
