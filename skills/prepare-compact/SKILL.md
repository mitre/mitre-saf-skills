---
name: prepare-compact
description: >-
  Save full session context before context compaction or loss. Use when context is
  getting low, before context compaction, before ending a long session, or when you want to
  checkpoint progress. Also triggers on "save context", "prepare for compact",
  "checkpoint session", "preserve session state".
compatibility: Requires beads (bd) CLI for task tracking. Git for version control state.
license: Apache-2.0
---

# Prepare for Context Compact

Save complete session context to persistent storage before context compaction destroys it. Produces two files: a strategic recovery context (detailed) and a recovery prompt (quick-start).

## Mode Detection

Determine the mode from the user's request:

| User says | Mode |
|-----------|------|
| (invoked with no arguments) | **Standard** — complete recovery file, update cards, update agent memory |
| "verbose", long/complex session hint | **Verbose** — expand Key Decisions, add Research & Findings section, more detail throughout |
| "quick" | **Quick** — git state, card sync, short recovery prompt only. Skip memory update |
| Any other text | **Custom** — treat as specific guidance (e.g., "capture our config-as-code research") |

## Persistence Model

Context survives through multiple layers, ordered by durability and sharing scope:

| Layer | Mechanism | Shared? | Survives |
|-------|-----------|---------|----------|
| 1 | `bd remember` — decision summaries | Yes (Dolt sync) | Account rotations, machine changes |
| 2 | Beads cards with notes | Yes (Dolt sync) | Account rotations, machine changes |
| 3 | `.beads/recovery-context.md` | No (local) | Compaction, new sessions |
| 4 | `.beads/recovery-prompt.md` | No (local) | Compaction, new sessions |
| 5 | Agent memory (e.g., MEMORY.md) | No (per-account) | Sessions on same account |
| 6 | `.beads/archive/` | No (local) | Historical record |

**Cards are the shared handoff.** Recovery files are local convenience. Write card notes as if a DIFFERENT developer's agent will pick up the work.

## Step 0: Load Existing Recovery Files

Before doing any work, read the existing recovery files so carry-forward content survives:

1. Read `.beads/recovery-context.md` (full file)
2. Read `.beads/recovery-prompt.md` (full file)

If either doesn't exist, that's fine — note it and continue.

**Carry-forward rule for each section below:**
- Already accurate → carry verbatim into new file
- Partially accurate → carry what's true, add deltas
- Missing or stale → drop or rewrite

## Step 1: Capture Git State

Run these in parallel:
- `git log --oneline -5`
- `git status --short`
- `git branch --show-current`

## Step 2: Update Beads Cards

Update beads state BEFORE compaction destroys context.

### A. Close Completed Tasks

```bash
bd list --status open
```

For each completed task:
```bash
bd update <task-id> --notes "[DATE] Completed: [what was done]. Files: [modified files]"
bd close <task-id>
```

If completion status is ambiguous for any task, list the cards you intend to close and confirm before closing.

### B. Update In-Progress Tasks

This is the PRIMARY handoff mechanism — cards sync via Dolt to all developers.

```bash
bd update <task-id> --append-notes "[DATE TIME] Current state: [exactly where you are]. Next: [immediate next step]. Files: [list files]"
```

Card notes must answer for ANY developer:
1. What's done?
2. What's the current state?
3. What's the immediate next step?
4. What gotchas or decisions were made?
5. Which files were modified?

### C. Create Tasks for New Work Discovered

Check if similar task exists before creating:
```bash
bd create "Task title" -p [0-3] --description "Why this exists and what needs doing"
```

### D. Verify Beads State

```bash
bd ready
bd list
```

## Step 3: Archive & Create Strategic Recovery File

### 3a. Archive existing recovery files

Move (not copy) current files to the archive with a timestamp. The Pre-Check read loaded content into working memory; `mv` clears the original path so Write creates a fresh file.

```bash
mkdir -p .beads/archive
TIMESTAMP=$(date +%Y%m%d-%H%M)
if [ -s .beads/recovery-context.md ]; then
  mv .beads/recovery-context.md ".beads/archive/recovery-context-${TIMESTAMP}.md"
fi
if [ -s .beads/recovery-prompt.md ]; then
  mv .beads/recovery-prompt.md ".beads/archive/recovery-prompt-${TIMESTAMP}.md"
fi
```

### 3b. Write new recovery file

Read [references/recovery-context-template.md](references/recovery-context-template.md) when writing the recovery file — it has the full section-by-section template with verbose mode additions.

Write `.beads/recovery-context.md` with COMPLETE strategic context. Fill in from this session's work, beads epic/task descriptions, user's stated goals, and problems encountered. A recovery file with placeholder text like "[Major accomplishment 1]" is worthless.

## Step 4: Update Agent Memory

**Skip if mode is `quick`.**

Write key LEARNINGS (not session state) to your agent's persistent memory system (e.g., `MEMORY.md` in Claude Code, project notes in other tools).

**Include:** Architectural patterns, solutions to recurring problems, file relationships, novel commands/patterns, common pitfalls.

**Exclude:** Current session state (recovery file), specific tasks (beads cards), temporary decisions, project rules (CLAUDE.md), duplicates.

## Step 5: Persist Key Decisions to Beads Memory

**Skip if mode is `quick` or no key decisions were made.**

```bash
bd memories "<keyword>"  # Check if similar memory exists
bd remember "<concise decision + rationale>" --key "<descriptive-key>"
```

Format: `"[Decision]: [rationale]. [What was rejected and why]."` Keep under 280 chars.

## Step 6: Sync Beads to Remote & Local Backup

```bash
bd dolt commit 2>/dev/null || true
bd dolt push 2>/dev/null || true
bd backup 2>/dev/null || true
```

If `bd dolt push` fails, the data is safe locally. It will sync on next push. Do not block compaction for this.

## Step 7: Save Recovery Prompt

Read [references/recovery-prompt-template.md](references/recovery-prompt-template.md) when writing the recovery prompt — it has the quick-start template with the section structure.

Write `.beads/recovery-prompt.md` with quick-start commands and a session summary. Fill in with actual session data.

## Step 8: Print Recovery Prompt

Print the recovery prompt to the terminal:

```
═══════════════════════════════════════════════════
RECOVERY PROMPT — paste after compaction or use restore-context skill
═══════════════════════════════════════════════════

cat .beads/recovery-context.md
bd ready

(Also saved to .beads/recovery-prompt.md)
(Previous version archived to .beads/archive/)

Quick summary:
- [1-line accomplishment 1]
- [1-line accomplishment 2]

Current epic: [Epic name]
Next: [Immediate next task]
Focus: [Primary goal] | Avoid: [Main scope creep risk]

═══════════════════════════════════════════════════
```

## Final Checklist

Before compaction, verify:
- [ ] Pre-Check: existing recovery files read in full (not truncated `cat | head`)
- [ ] Existing files archived to `.beads/archive/` via `mv`
- [ ] All completed beads tasks closed with notes
- [ ] In-progress tasks updated with exact state
- [ ] New tasks created for discovered work
- [ ] Key decisions saved via `bd remember`
- [ ] Beads synced: `bd dolt commit && bd dolt push`
- [ ] Local backup refreshed: `bd backup`
- [ ] Agent memory updated with learnings (not session state)
- [ ] Recovery file has complete strategic context
- [ ] Recovery prompt saved to `.beads/recovery-prompt.md`
- [ ] Recovery prompt printed to terminal

**Now you can safely compact with full context preservation.**

## Gotchas

- **`mv` not `cp` for archiving** — after `cp`, the original file still exists at the path, which can cause issues when the agent tries to write the new version. After `mv`, the path is clear for a fresh write.
- **Read before mv** — the Pre-Check read loads content into working memory. Once `mv` runs, the file is gone from the original path.
- **Fill in templates with ACTUAL data** — placeholder text like "[Major accomplishment 1]" defeats the entire purpose.
- **Card notes are the shared handoff** — recovery files are local convenience. Write card notes as if a different developer will pick up the work.
- **`bd dolt push` failures are non-blocking** — data is safe locally. Network issues resolve on next push.

## Related Skills

- **restore-context** — the counterpart: reads recovery files and reconstructs strategic context after compaction
- **project-tdd** — references prepare-compact in its close protocol
- **create-beads-board** — sets up the beads infrastructure this skill depends on
