#!/bin/bash
# SessionStart after compact: Load complete recovery context
# Output goes into Claude's context automatically

# Validate settings aren't corrupted
if [ -x "$HOME/.claude/hooks/validate-settings.sh" ]; then
  "$HOME/.claude/hooks/validate-settings.sh"
fi

# Only run in beads projects
if [ ! -d ".beads" ]; then
  exit 0
fi

echo "🔄 Restoring context from previous session..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Read recovery file if it exists
if [ -f ".beads/recovery-context.md" ]; then
  cat .beads/recovery-context.md
else
  echo "⚠️  No recovery file found (.beads/recovery-context.md)"
  echo ""
  echo "This might be:"
  echo "- First session after project setup"
  echo "- Recovery file was deleted"
  echo "- Fresh start"
  echo ""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 **Available Work:**"
echo ""

# Show ready work
bd ready 2>/dev/null | head -10 || echo "No tasks ready"

echo ""
echo "💡 **Next Steps:**"
echo "   • Run 'bd show <id>' for task details"
echo "   • Update status: bd update <id> --status in_progress"
echo "   • Review scope guard rails before starting work"
echo ""

# Run bd prime to ensure beads is ready
bd prime 2>/dev/null || true
