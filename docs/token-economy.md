# Token Economy for Skill-Driven Workflows — lessons learned

A field report from running the full card workflow (project-card → project-tdd
→ project-ac-verify) on a metered flagship model, after a week in which the
process itself — not the work — consumed most of a weekly token budget.
Measured findings, then the fixes now encoded in these skills.

## What actually costs money

1. **Context re-sends dominate everything.** Every tool call re-sends the
   session's full resident context. In the measured period, ~98.7% of tokens
   were context re-sends, not new work. Anything that lives in resident
   context (skill bodies, memory dumps, long instructions) is not a one-time
   cost — it is a per-call tax for the rest of the session.

2. **Reasoning effort is output tokens.** A session left at a high reasoning
   effort spends thousands of thinking tokens per turn on routine mechanics
   (observed: 5 minutes / 16k thinking tokens on a ceremony step). Output
   tokens cost several times input tokens. Effort level is the single biggest
   dial an operator controls.

3. **Session-start injections compound.** A memory system that pushes every
   stored fact at session start (observed: 140KB+) taxes every subsequent
   call. Retrieval-based memory — one-line index entries, bodies fetched on
   demand — delivers the same recall at a fraction of the resident cost.

4. **Subagents are cheap where the main loop is expensive** — when spawned on
   an unmetered tier with explicit per-spawn model and effort. Independent
   review agents cost real tokens, but on the right tier they do not touch
   the metered budget; only the spawn/collect turns do.

## The fixes encoded in these skills

- **Operative text only in SKILL.md** (create-skill Phase 2b + Phase 3
  checklist): rules, steps, and checks stay inline; incident histories and
  research citations move to `references/` files loaded on demand, each
  replaced by a one-line anchor. project-tdd and project-card now follow
  this (`references/gate-incidents.md`, `references/card-incidents.md`).
  Honest expectation: this trims skills whose bulk is narrative; skills whose
  bulk is genuinely operative rule text shrink less (~8% here) — do not cut
  rules to chase a number.

- **Effort tiering** (project-tdd Verification Economy): mechanical work →
  medium, standard card execution → high, xhigh reserved for hard design
  rounds. Genuinely mechanical skills may declare `effort:` frontmatter — it
  overrides the session level while the skill is active, then reverts.
  Precedence: `CLAUDE_CODE_EFFORT_LEVEL` env var → skill/subagent frontmatter
  while active → session `/effort` → model default. The session-level flip
  is always the operator's.

- **Verification economy** (project-tdd): one combined verification command
  per card; multi-package suites chained into ONE background command (one
  wake-up); batch independent tool calls into one message; batch small
  mechanical items into one cycle. Economy changes the PACKAGING of
  verification, never its content.

- **Model-tier pairing** (project-tdd Gate 0): the card-start line states
  `session model X, card is mechanical|judgment-tier` once — a mechanical
  epic on a metered flagship is a mismatch the operator may want to fix by
  relaunching on an unmetered tier, or pre-tiering the session with the
  effort env var.

## What NOT to do

- Do not trim evidence, gates, suites, or review coverage to save tokens —
  quality bars are untouchable; economy is about packaging.
- Do not curate what an independent reviewer sees. Cut spawn configuration,
  never review content.
- Do not delete rationale outright — a rule with no WHY becomes brittle.
  One sentence stays; the full story moves to `references/`.
- Do not let an agent narrate its own context state or self-diagnose
  degradation as a cost measure; the architectural backstops (fresh-context
  review, external memory) are the mitigation.
