#!/bin/bash
# Validate .claude/settings.local.json isn't corrupted
# Returns 0 if valid, 1 if corrupted

if [ ! -f ".claude/settings.local.json" ]; then
  exit 0  # No settings file, nothing to validate
fi

# Check if JSON is well-formed
if ! python3 -m json.tool .claude/settings.local.json > /dev/null 2>&1; then
  echo "❌ ERROR: .claude/settings.local.json is corrupted (invalid JSON)"
  exit 1
fi

# Check for heredoc patterns (indicators of corruption)
if grep -q "<<'EOF'" .claude/settings.local.json 2>/dev/null; then
  echo "❌ ERROR: .claude/settings.local.json contains heredoc patterns"
  echo "   This indicates bd commands were run with heredocs directly."
  echo "   See global CLAUDE.md 'Beads Command Safety' section for fix."
  exit 1
fi

# Check for invalid :* patterns (not at end)
if grep -q '":.*:' .claude/settings.local.json 2>/dev/null; then
  echo "⚠️  WARNING: settings.local.json may have invalid :* patterns"
  echo "   Check that all :* patterns are at the end of permission strings."
fi

exit 0
