#!/bin/bash
# PreCompact: Reminder + cleanup only
# File writing handled by /prepare-compact skill — DO NOT write recovery files here

if [ ! -d ".beads" ]; then
  exit 0
fi

# Clean up any beads worktrees that block git operations
if [ -d ".git/beads-worktrees/main" ]; then
  git worktree remove .git/beads-worktrees/main 2>/dev/null || true
  git worktree prune 2>/dev/null || true
fi

echo "⚠️  REMINDER: Run /prepare-compact before compacting!"
echo "   • Closes completed tasks, updates in-progress cards"
echo "   • Saves full strategic recovery context"
echo "   • Updates MEMORY.md with learnings"

if [ -f ".beads/recovery-context.md" ] && [ "$(wc -l < .beads/recovery-context.md)" -gt 20 ]; then
  echo ""
  echo "✅ Detailed recovery-context.md found ($(wc -l < .beads/recovery-context.md) lines) — looks good."
else
  echo ""
  echo "❌ No detailed recovery-context.md found — run /prepare-compact NOW before compacting!"
fi
