---
name: project-ac-verify
description: Independent review of card acceptance criteria before close. REQUIRED before every bd close. Creates a bd gate on card start, resolves it only when all ACs pass independent review against the code diff AND the referenced design doc section.
compatibility: Requires beads CLI (bd)
license: Apache-2.0
---

# AC Verification Gate

**An independent review verifies every acceptance criterion against the actual code diff and the referenced design document before a card can be closed.**

This skill exists because in a prior incident, cards were closed with incomplete ACs — XLSX substituted with TSV, YAML skipped entirely, tests that asserted `typeof === 'function'` instead of verifying behavior. The implementing agent self-assessed "done" and was wrong. An independent reviewer would have caught every one of these.

## When to Use

- **MANDATORY before every `bd close`** — no exceptions
- Invoked automatically by project-tdd and project-card workflows
- Can be invoked standalone: `/project-ac-verify <card-id>`

## The Gate Lifecycle

### 1. Gate Creation (at card start — done by project-tdd Gate 0)

When starting a card, create the verification gate:

```bash
bd gate create --blocks <card-id> --type=human \
  --reason="AC verification required — run /project-ac-verify <card-id>"
```

This blocks `bd close <card-id>` until the gate is resolved. The gate is visible in `bd show <card-id>`.

**If you forget to create the gate at card start, create it before running this skill.** The skill checks for an open gate and creates one if missing.

### 2. Verification (when implementation is complete)

Run `/project-ac-verify <card-id>` after:
- All tests pass
- Build passes
- Live testing done (if applicable)
- You believe all ACs are met

### 3. Gate Resolution (only on PASS)

If all ACs pass review:
- Gate is resolved: `bd gate resolve <gate-id> --reason="[AC-VERIFY PASS] ..."`
- Verification note appended to card
- `bd close` is now unblocked

If any AC fails:
- Gate stays open
- Failures reported with specific evidence of what's missing
- Fix the issues and re-run `/project-ac-verify`

## The Verification Process

### Step 1: Gather Context

Read the card and extract what the reviewer needs:

```bash
# Read the full card
bd show <card-id>
```

From the card description, extract:
- **All acceptance criteria** (`- [ ]` lines)
- **Anti-patterns** section
- **Design doc reference** (e.g., "Design doc: docs/adr-001... §5.3")
- **Files** section (Create/Modify/Test paths)
- **Verification command**

### Step 2: Read the Design Doc Section

If the card references a design document section (e.g., `§5.3`, `§3.4.2`):

```bash
# Read the referenced section of the design doc
# Parse the section number and read that portion of the file
```

This is CRITICAL. The last session failed because the agent cherry-picked from card descriptions instead of reading the actual design doc sections. The reviewer MUST read the referenced section and compare the implementation against it.

### Step 3: Gather Evidence

```bash
# Get the diff of files listed in the card
git diff HEAD -- <files from card>
# For untracked new files:
git diff --no-index /dev/null <new-file>

# Get test output (should already be run — read from recent output)
# Get build output (should already be run)
```

### Step 4: Independent Review

Conduct a SINGLE independent review with this prompt structure. If your environment supports subagent delegation, run this as a separate agent session for full isolation. Otherwise, conduct the review in the current session — the key requirement is independence of judgment, not a separate process.

```
You are an independent AC reviewer. Your ONLY job is to verify whether 
each acceptance criterion is met by the actual code. You have no 
investment in closing this card. Default to FAIL when evidence is 
ambiguous.

## Card: <card-id> — <title>

## Acceptance Criteria
<paste all AC lines from card>

## Anti-Patterns
<paste anti-patterns section>

## Design Document Requirements
<paste the referenced ADR/design doc section>

## Code Diff
<paste git diff of card files>

## Test Output
<paste test results>

## Build Output  
<paste build results>

## Your Task

For EACH acceptance criterion, respond with:
- **AC**: <the criterion text>
- **Verdict**: PASS or FAIL
- **Evidence**: Cite the specific line in the diff, test name, or build 
  output that proves this AC is met. If FAIL, state exactly what is 
  missing or wrong.

Then check:
- **Anti-pattern violations**: List any anti-pattern from the card that 
  the diff violates. Cite the specific line.
- **Design doc gaps**: List any requirement in the design doc section 
  that the implementation does NOT cover. Be specific — quote the 
  requirement and state what's missing in the diff.
- **Type safety**: Any `as any`, `as unknown`, `// @ts-ignore`, or 
  type assertion that bypasses the type system? (Gate 3 violation)
- **Test quality**: Any test that would still pass if the code were 
  broken? (Gate 4 — e.g., `expect(typeof x).toBe('function')` tests 
  nothing about behavior)

## Final Verdict
PASS — all ACs met, no anti-pattern violations, no design doc gaps
FAIL — list every failing item
```

**Review constraints:**
- `schema` option with structured output (pass/fail per AC + overall verdict)
- No file editing permissions — read-only review
- Bounded: one focused task, no exploration

### Step 5: Process the Result

**If overall verdict is PASS:**

```bash
# Find the open gate for this card
bd gate list | grep <card-id>

# Resolve it with verification summary
bd gate resolve <gate-id> --reason="[AC-VERIFY PASS] <N>/<N> ACs verified against <ADR section>. Reviewer: independent review."

# Append verification note to card
bd update <card-id> --append-notes "[$(date +%Y-%m-%d\ %H:%M)] AC-VERIFY PASS: <N>/<N> ACs verified by independent review against <design doc section>. diff:<short-hash>"
```

**If overall verdict is FAIL:**

Report to the user (do NOT resolve the gate):

```
## AC Verification FAILED

Card: <card-id> — <title>

### Failing ACs:
- <AC text> — FAIL: <what's missing>
- <AC text> — FAIL: <what's missing>

### Anti-pattern violations:
- <violation description>

### Design doc gaps:
- <requirement> — not implemented

### Next steps:
Fix the issues above and re-run /project-ac-verify <card-id>
```

## Structured Output Schema

The review MUST produce structured output matching this schema:

```json
{
  "type": "object",
  "required": ["card_id", "overall_verdict", "ac_results", "anti_pattern_violations", "design_doc_gaps", "type_safety_issues", "weak_tests"],
  "properties": {
    "card_id": {"type": "string"},
    "overall_verdict": {"enum": ["PASS", "FAIL"]},
    "ac_results": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["criterion", "verdict", "evidence"],
        "properties": {
          "criterion": {"type": "string"},
          "verdict": {"enum": ["PASS", "FAIL"]},
          "evidence": {"type": "string"}
        }
      }
    },
    "anti_pattern_violations": {
      "type": "array",
      "items": {"type": "string"}
    },
    "design_doc_gaps": {
      "type": "array",
      "items": {"type": "string"}
    },
    "type_safety_issues": {
      "type": "array",
      "items": {"type": "string"}
    },
    "weak_tests": {
      "type": "array",
      "items": {"type": "string"}
    }
  }
}
```

## Integration with Other Skills

### project-tdd — Gate 0 addition

Add to Gate 0 (Epic Context), after presenting the execution summary:

```
6. Create AC verification gate:
   bd gate create --blocks <card-id> --type=human \
     --reason="AC verification required — run /project-ac-verify <card-id>"
```

### project-tdd — Gate 22: AC Verification

Integrated as the final gate in project-tdd:

```
### Gate 22: Independent AC Verification — MANDATORY

Before running `bd close`, invoke /project-ac-verify <card-id>.

The skill conducts an independent review that checks every AC against 
the code diff and the referenced design document section. The agent has 
no investment in closing the card — its only job is verification.

If the review returns FAIL, fix the issues and re-run. Do NOT use 
`bd close --force` to bypass the gate.

**Check:** Is there a resolved AC verification gate on this card?
```

### project-card — Before closing update

Add to the "Before closing" section template:

```
- [ ] /project-ac-verify <card-id> returned PASS — gate resolved
```

### bd close prevention

The gate created at card start blocks `bd close` mechanically:
- `bd close <card-id>` fails with "unsatisfied gate" error
- `bd close <card-id> --force` bypasses but is auditable
- Gate is visible in `bd show <card-id>` as a blocking dependency

## What This Catches

| Known failure mode | How the reviewer catches it |
|---|---|
| XLSX AC with TSV implementation | No `@e965/xlsx` import in diff → AC FAIL |
| YAML format skipped entirely | No yaml serializer in diff → AC FAIL |
| `typeof === 'function'` test | Assertion tests nothing specific → weak test flag |
| `as unknown` type cast | Type bypass in diff → type safety flag |
| ADR says O(1) index, code does O(n) scan | Design doc gap: "§5.3 requires indexed lookup" |
| Card closed without live test evidence | No test output matching AC → AC FAIL |

## What This Does NOT Replace

- **TDD** — the skill verifies ACs are met, not that TDD was followed
- **Live testing** — the skill reads test output, it doesn't run the app
- **Design review** — the skill checks implementation against an existing design doc, it doesn't evaluate whether the design is good
- **Code quality** — the skill checks AC compliance, not style or DRY

These are handled by other gates in project-tdd.
