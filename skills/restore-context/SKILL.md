---
name: restore-context
description: >-
  Restore full session context after compaction or time away. Use when starting a new
  session, after context compaction, after a long break, or when context feels thin. Also triggers
  on "restore context", "where was I", "what was I working on last session", "resume work",
  "pick up where I left off".
compatibility: Requires beads (bd) CLI for task tracking. Git for version control state.
license: Apache-2.0
---

# Restore Context

Reconstruct complete strategic context from persistent storage after context compaction or time away. Reads recovery files, syncs the beads board, loads memories, verifies git state, and presents a summary with available work.

## Mode Detection

Determine the mode from the user's request:

| User says | Mode |
|-----------|------|
| (invoked with no arguments) | **Full** — read all context, skim archive, present summary, wait for task selection |
| "continue" | **Continue** — full restore, then immediately resume last in-progress task without asking |
| "overview" | **Overview** — read context, present summary only. No task selection or work |
| "deep" | **Deep** — full restore PLUS read complete previous session archive for maximum context |
| Any other text | **Focused** — treat as filter (e.g., "focus on auth epic" → emphasize that work) |

## Principle: Board Is the Shared Truth — Recovery Files Are Local Bonus

**Beads cards + memories** (synced via Dolt) are how all developers share context.
**Recovery files** are local session state for YOUR agent instance — a convenience, not required.

If no recovery file exists (new machine, new developer, or files cleaned up), that's fine. The board has everything needed: `bd dolt pull` → `bd ready` → `bd show <task>` → work.

## Step 0: Read Recovery Prompt

Read `.beads/recovery-prompt.md` for quick orientation. If it doesn't exist, skip to Step 2.

## Step 1: Read Recovery File

Read `.beads/recovery-context.md` — the full file, not just the first few lines.

**What to absorb:**
- Current epic and success criteria (the big picture)
- Scope guard rails (what to avoid)
- Key decisions and why (context for future choices)
- Current challenges and attempted solutions
- Exact state of in-progress work
- Beads card IDs for active tasks

## Step 1b: Read Strategy Documents

Search for project-level strategy docs that constrain all work:

```bash
ls docs/*/*.md docs/*.md 2>/dev/null | sort
ls ARCHITECTURE.md ROADMAP.md STRATEGY.md VISION.md 2>/dev/null
```

Read the most relevant docs for the current work. Absorb: vision, goals, non-goals, guiding principles, key architectural decisions, current sprint focus.

**These decisions are NOT open for re-evaluation unless the user explicitly asks.** If `bd memories` says "Use X not Y" and a strategy doc explains why, do not suggest Y.

## Step 1c: Read Prior Session Archive

Check what session history is available:

```bash
ls -t .beads/archive/recovery-context-*.md 2>/dev/null | head -6
```

**Default/Full mode:** Read only the first ~30 lines of the most recent archive (header + progress status). This gives trajectory at minimal context cost.

**Deep mode:** Read the FULL most recent archive — complete previous session including Research & Findings, Key Decisions, and Scope Guard Rails. Valuable after long breaks.

**If no recovery-context.md exists but archives do:** Use the most recent archive AS the primary recovery source.

## Step 2: Sync Beads and Load Memories

### A. Sync State + Load Memories

```bash
bd dolt pull 2>/dev/null || true
bd memories
```

Read all memories carefully. These contain critical decisions that constrain your work. Do NOT contradict stored memories without discussing with the user first.

### B. Review Current Epic

```bash
bd list | grep -E "P0.*epic"
bd show <epic-id>
```

### C. Review Available Work

```bash
bd ready
bd list --status open
```

### D. Review Recent Progress

```bash
bd list --status closed --limit 5
```

## Step 3: Verify Git State

```bash
git status
git log --oneline -5
git branch --show-current
```

Verify: branch matches recovery file, uncommitted changes align with "in progress" section, recent commits match "completed this session."

## Step 4: Review Strategic Context

From the recovery file, extract and confirm:

**Current Epic Scope** — end goal, success criteria, on track?

**Scope Guard Rails** — what's explicitly OUT of scope? What rabbit holes to avoid?

**Key Decisions Context** — what choices were made and why? What alternatives were considered? Can decisions be revisited or are they permanent?

This context guides ALL decisions during the session.

## Step 5: Present Summary and Get Direction

```markdown
## Context Restored

### Current Epic
**[Epic name]** (Week [N] of [M])
- Goal: [brief description]
- Success: [1-2 key criteria]

### Last Session Completed
- [Major accomplishment 1]
- [Major accomplishment 2]

### Prior Session (from archive)
- [1-line summary of what n-1 session accomplished, if archive was read]

### Current Challenges
- [Critical blocker if any]
- [Active challenge]

### Available Work (bd ready)
1. **[task-id]** - [Title] (P[priority])
2. **[task-id]** - [Title] (P[priority])

### Git State
- Branch: [branch]
- Uncommitted: [X files or clean]

### Scope Reminder
Focus on: [primary goal]
Avoid: [main scope creep risk]

### Session History
[N] archived sessions available in `.beads/archive/`
Latest: [filename of most recent archive]

---

**Which task would you like to work on?**
```

**Mode-specific behavior:**
- **Continue** → skip the question, immediately start the last in-progress task
- **Overview** → stop here, do not proceed to Steps 6-7
- **All other modes** → wait for user response

## Step 6: Beads Maintenance (if needed)

Quick cleanup based on user direction:

```bash
bd list --status open          # Check for stale tasks
bd update <task-id> -p [N]     # Update priorities
bd close <task-id>             # Close irrelevant tasks
bd create "New task" -p 0      # Create new high-priority tasks
```

## Step 7: Begin Work with Full Context

Once user selects a task:

```bash
bd show <task-id>
bd update <task-id> --status in_progress
```

Before starting implementation:
- Task aligns with current epic
- Not a scope creep risk
- Fits within guard rails
- User confirmed priority

Then work with confidence.

Read [references/no-recovery-fallback.md](references/no-recovery-fallback.md) when no `.beads/recovery-context.md` exists (new machine, new developer, or files cleaned up) — it has the board-first restore procedure.

Read [references/guard-rails.md](references/guard-rails.md) when you need to check whether a task is in scope for the current epic — it has the scope-check decision table.

## Gotchas

- **Read the FULL recovery file** — skimming misses scope guard rails and key decisions that prevent wasted effort.
- **Memories override assumptions** — if `bd memories` says a decision was made, respect it unless the user explicitly wants to revisit.
- **Archives are local-only** — not git-tracked, not shared with other devs. They're YOUR session history on this machine.
- **Board-first if no recovery file** — the shared board is always authoritative. Recovery files just make YOUR restore faster.

## Related Skills

- **prepare-compact** — the counterpart: saves context before compaction
- **create-beads-board** — sets up the beads infrastructure this skill depends on
