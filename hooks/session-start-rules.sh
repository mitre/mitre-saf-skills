#!/bin/bash
# Session start hook to display critical authorship rules
# These rules are from CLAUDE.md but need prominent display

cat << 'RULES'
# ⚠️ CRITICAL AUTHORSHIP RULES ⚠️

**NEVER add these to commits or PRs:**
- 🤖 Generated with [Claude Code]
- Co-Authored-By: Claude
- Any AI attribution

**ALWAYS use:**
- Authored by: Aaron Lippold<lippold@gmail.com>

**ORGANIZATION POLICY: Human authorship attribution ONLY**

---
RULES

# Also check for project CLAUDE.md and extract Git section if exists
if [ -f "CLAUDE.md" ]; then
    echo "Project CLAUDE.md detected - following project-specific rules"
fi
