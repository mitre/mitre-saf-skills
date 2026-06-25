#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
SKILL_DIR="${1:?Usage: audit-precheck.sh <skill-directory>}"

if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
  echo "ERROR: No SKILL.md found in $SKILL_DIR"
  exit 1
fi

PASS=0
WARN=0
FAIL=0

check() {
  local severity="$1" dim="$2" name="$3" result="$4" evidence="$5"
  if [ "$result" = "PASS" ]; then
    PASS=$((PASS + 1))
    printf "  PASS  [%s] %s\n" "$dim" "$name"
  elif [ "$result" = "WARN" ]; then
    WARN=$((WARN + 1))
    printf "  WARN  [%s] %s — %s\n" "$dim" "$name" "$evidence"
  else
    FAIL=$((FAIL + 1))
    printf "  FAIL  [%s] %s — %s\n" "$dim" "$name" "$evidence"
  fi
}

echo "=== Skill Audit Pre-Check: $SKILL_DIR ==="
echo ""

# --- D1: Spec Compliance ---
echo "--- D1: Spec Compliance ---"

dir_name=$(basename "$SKILL_DIR")
skill_name=$(grep '^name:' "$SKILL_DIR/SKILL.md" | head -1 | sed 's/name: *//')
if [ "$dir_name" = "$skill_name" ]; then
  check FAIL D1 "name matches directory" PASS ""
else
  check FAIL D1 "name matches directory" FAIL "dir=$dir_name, name=$skill_name"
fi

line_count=$(wc -l < "$SKILL_DIR/SKILL.md")
if [ "$line_count" -le 500 ]; then
  check WARN D1 "SKILL.md under 500 lines" PASS "$line_count lines"
else
  check WARN D1 "SKILL.md under 500 lines" WARN "$line_count lines (over 500)"
fi

desc=$(grep '^description:' "$SKILL_DIR/SKILL.md" | head -1)
if [ -n "$desc" ]; then
  check FAIL D1 "description present" PASS ""
else
  check FAIL D1 "description present" FAIL "no description field"
fi

abs_paths=$(grep -rn '/Users/\|/home/' "$SKILL_DIR" 2>/dev/null | grep -v '.git/' || true)
if [ -z "$abs_paths" ]; then
  check FAIL D1 "no absolute paths" PASS ""
else
  hit_count=$(echo "$abs_paths" | wc -l | tr -d ' ')
  check FAIL D1 "no absolute paths" FAIL "$hit_count hits — CLASSIFY BY CONTEXT"
  echo "$abs_paths" | head -5 | sed 's/^/         /'
fi

# --- D4: Portability ---
echo ""
echo "--- D4: Portability ---"

skill_dir_var=$(grep -rn 'SKILL_DIR\|SKILLS_HOME' "$SKILL_DIR" 2>/dev/null | grep -v '.git/' | grep -v 'audit-precheck.sh' || true)
if [ -z "$skill_dir_var" ]; then
  check FAIL D4 "no SKILL_DIR/SKILLS_HOME" PASS ""
else
  hit_count=$(echo "$skill_dir_var" | wc -l | tr -d ' ')
  check FAIL D4 "no SKILL_DIR/SKILLS_HOME" FAIL "$hit_count hits"
  echo "$skill_dir_var" | head -5 | sed 's/^/         /'
fi

tool_specific=$(grep -rn 'TodoWrite\|TaskCreate\|AskUserQuestion\|\.claude/hooks/\|\.claude/settings\.json\|\.claude/agents/\|context: fork\|Agent tool\|runSubagent' "$SKILL_DIR" 2>/dev/null | grep -v '.git/' | grep -v 'audit-precheck.sh' || true)
if [ -z "$tool_specific" ]; then
  check WARN D4 "no tool-specific mechanisms" PASS ""
else
  hit_count=$(echo "$tool_specific" | wc -l | tr -d ' ')
  check WARN D4 "no tool-specific mechanisms" WARN "$hit_count hits — CLASSIFY BY CONTEXT"
  echo "$tool_specific" | head -5 | sed 's/^/         /'
fi

slash_cmds=$(grep -rn '/[a-z][a-z-]*-[a-z]' "$SKILL_DIR" 2>/dev/null | grep -v '.git/' | grep -v '.beads/' | grep -v 'audit-precheck.sh' | grep -v 'references/' | grep -v '/dev/null' || true)
if [ -z "$slash_cmds" ]; then
  check WARN D4 "no slash-command references" PASS ""
else
  hit_count=$(echo "$slash_cmds" | wc -l | tr -d ' ')
  check WARN D4 "no slash-command references" WARN "$hit_count hits — CLASSIFY BY CONTEXT"
  echo "$slash_cmds" | head -5 | sed 's/^/         /'
fi

wikilinks=$(grep -rn '\[\[' "$SKILL_DIR" 2>/dev/null | grep -v '.git/' | grep -v 'audit-precheck.sh' || true)
if [ -z "$wikilinks" ]; then
  check WARN D4 "no wikilinks" PASS ""
else
  hit_count=$(echo "$wikilinks" | wc -l | tr -d ' ')
  check WARN D4 "no wikilinks" WARN "$hit_count hits — CLASSIFY BY CONTEXT"
  echo "$wikilinks" | head -5 | sed 's/^/         /'
fi

home_paths=$(grep -rn '~/\.claude/\|~/\.cursor/\|~/\.agents/' "$SKILL_DIR" 2>/dev/null | grep -v '.git/' | grep -v 'audit-precheck.sh' || true)
if [ -z "$home_paths" ]; then
  check FAIL D4 "no tool-specific install paths" PASS ""
else
  hit_count=$(echo "$home_paths" | wc -l | tr -d ' ')
  check FAIL D4 "no tool-specific install paths" FAIL "$hit_count hits — CLASSIFY BY CONTEXT"
  echo "$home_paths" | head -5 | sed 's/^/         /'
fi

# --- D5: Content Quality ---
echo ""
echo "--- D5: Content Quality ---"

person_names=$(grep -rni 'Aaron\|Lippold' "$SKILL_DIR" 2>/dev/null | grep -v '.git/' | grep -v 'audit-precheck.sh' || true)
if [ -z "$person_names" ]; then
  check FAIL D5 "no person names" PASS ""
else
  hit_count=$(echo "$person_names" | wc -l | tr -d ' ')
  check FAIL D5 "no person names" FAIL "$hit_count hits — CLASSIFY BY CONTEXT"
  echo "$person_names" | head -5 | sed 's/^/         /'
fi

dated_incidents=$(grep -rn 'On 2026-\|On 2025-\|On 2024-' "$SKILL_DIR" 2>/dev/null | grep -v '.git/' | grep -v 'audit-precheck.sh' || true)
if [ -z "$dated_incidents" ]; then
  check FAIL D5 "no dated incidents" PASS ""
else
  hit_count=$(echo "$dated_incidents" | wc -l | tr -d ' ')
  check FAIL D5 "no dated incidents" FAIL "$hit_count hits — CLASSIFY BY CONTEXT"
  echo "$dated_incidents" | head -5 | sed 's/^/         /'
fi

marketing=$(grep -rci 'comprehensive\|robust\|enterprise-grade\|production-ready\|seamless' "$SKILL_DIR" 2>/dev/null | grep -v ':0$' | grep -v '.git/' | grep -v 'audit-precheck.sh' || true)
if [ -z "$marketing" ]; then
  check FAIL D5 "no marketing words" PASS ""
else
  check FAIL D5 "no marketing words" FAIL "hits found — CLASSIFY BY CONTEXT"
  echo "$marketing" | sed 's/^/         /'
fi

# --- D6: Security ---
echo ""
echo "--- D6: Security ---"

cred_files=$(find "$SKILL_DIR" -name '*credential*' -o -name '*.key' -o -name '*.pem' 2>/dev/null | grep -v '.git/' || true)
if [ -z "$cred_files" ]; then
  check FAIL D6 "no credential files" PASS ""
else
  check FAIL D6 "no credential files" FAIL "found: $cred_files"
fi

git_dirs=$(find "$SKILL_DIR" -name '.git' -type d 2>/dev/null || true)
if [ -z "$git_dirs" ]; then
  check FAIL D6 "no embedded .git" PASS ""
else
  check FAIL D6 "no embedded .git" FAIL "found: $git_dirs"
fi

hostnames=$(grep -rn '\.local\b\|192\.168\.\|10\.0\.' "$SKILL_DIR" 2>/dev/null | grep -v '.git/' | grep -v 'audit-precheck.sh' || true)
if [ -z "$hostnames" ]; then
  check FAIL D6 "no internal hostnames" PASS ""
else
  hit_count=$(echo "$hostnames" | wc -l | tr -d ' ')
  check FAIL D6 "no internal hostnames" FAIL "$hit_count hits — CLASSIFY BY CONTEXT"
  echo "$hostnames" | head -5 | sed 's/^/         /'
fi

if [ -d "$SKILL_DIR/scripts" ]; then
  hardcoded=$(grep -rni 'api_key\|token\|password\|secret' "$SKILL_DIR/scripts/" 2>/dev/null | grep -v 'environ\|getenv\|process\.env\|os\.getenv' | grep -v 'audit-precheck.sh' || true)
  if [ -z "$hardcoded" ]; then
    check FAIL D6 "no hardcoded credentials in scripts" PASS ""
  else
    hit_count=$(echo "$hardcoded" | wc -l | tr -d ' ')
    check FAIL D6 "no hardcoded credentials in scripts" FAIL "$hit_count hits — CLASSIFY BY CONTEXT"
    echo "$hardcoded" | head -5 | sed 's/^/         /'
  fi
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  WARN: $WARN"
echo "  FAIL: $FAIL"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "  Status: NEEDS REVIEW — $FAIL FAIL findings require context classification"
elif [ "$WARN" -gt 0 ]; then
  echo "  Status: NEEDS REVIEW — $WARN WARN findings require context classification"
else
  echo "  Status: PRE-CHECK CLEAN — proceed to agent review for non-greppable dimensions"
fi
echo ""
echo "  Note: Hits marked 'CLASSIFY BY CONTEXT' need agent review."
echo "  The script catches patterns; the agent classifies whether they are real findings or false positives."
