#!/bin/bash
# Hook: Validate bd create calls have all 12 mandatory card sections
# Triggered by PreToolUse on Bash commands containing "bd create"
#
# Claude Code PreToolUse hooks receive JSON on stdin with tool_input.command
# Exits 0 to allow, exits 2 to block with message on stdout

INPUT=$(cat)

# Try both possible JSON paths for the command
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
# Try tool_input.command (documented format)
cmd = data.get('tool_input', {}).get('command', '')
if not cmd:
    # Try top-level command
    cmd = data.get('command', '')
if not cmd:
    # Try input.command
    cmd = data.get('input', {}).get('command', '')
print(cmd)
" 2>/dev/null)

# Only check actual `bd create` invocations.
#
# Parse the command line into shell tokens and look for command boundaries
# where 'bd' is followed by 'create'. This avoids false positives like:
#   - gh issue create --body "mentions bd create"
#   - cat > /tmp/notes.md <<EOF ... bd create ... EOF
#   - echo "running bd create"
#   - comments and string literals
INVOCATION=$(echo "$COMMAND" | python3 -c "
import sys, shlex
src = sys.stdin.read()
# Split on command separators that introduce a new command
# (;, &&, ||, |, & at end). Keep things simple: only inspect the first
# token of each segment to decide if it is 'bd'.
import re
segments = re.split(r'(?:;|&&|\|\||\||\n)', src)
hit = False
for seg in segments:
    seg = seg.strip()
    if not seg:
        continue
    # shlex.split with posix=True handles quoted strings correctly
    try:
        tokens = shlex.split(seg, posix=True, comments=True)
    except ValueError:
        # Unclosed quote (likely a heredoc fragment) — skip this segment
        continue
    if not tokens:
        continue
    # Skip leading env assignments like FOO=bar
    i = 0
    while i < len(tokens) and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', tokens[i]):
        i += 1
    if i >= len(tokens):
        continue
    cmd = tokens[i]
    # Accept either 'bd' as the first token, or paths ending in /bd
    if cmd == 'bd' or cmd.endswith('/bd'):
        # Next non-flag token must be 'create'
        for j in range(i + 1, len(tokens)):
            t = tokens[j]
            if t.startswith('-'):
                continue
            if t == 'create':
                hit = True
            break
print('yes' if hit else 'no')
" 2>/dev/null)

if [ "$INVOCATION" != "yes" ]; then
  exit 0
fi

# If the description is loaded from a file via $(cat /abs/path), read that file so the
# sections can be validated. Any ABSOLUTE path is accepted, not just /tmp: on macOS the
# per-session scratchpad is /private/tmp/... (and /tmp is merely a symlink to it), so a
# /tmp-only pattern silently failed to find the file and blocked fully compliant cards —
# pushing card bodies either into inline heredocs, which project-card forbids, or into a
# hard-coded directory. The path is only ever READ here. (2026-08-11)
DESC_FILE=$(echo "$COMMAND" | sed -n 's/.*cat \(\/[^) ]*\).*/\1/p' | head -1)
if [ -n "$DESC_FILE" ] && [ -f "$DESC_FILE" ]; then
  COMMAND="$COMMAND $(cat "$DESC_FILE")"
fi

# Required sections that must appear in the description
REQUIRED_SECTIONS=(
  "Description:"
  "Files:"
  "First failing test:"
  "Acceptance criteria:"
  "Verification:"
  "Decision points:"
  "Anti-patterns:"
  "NOT in scope:"
  "Before closing:"
  "Story points:"
  "Estimate:"
)

MISSING=()
for section in "${REQUIRED_SECTIONS[@]}"; do
  if ! echo "$COMMAND" | grep -qi "$section"; then
    MISSING+=("$section")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "BLOCKED: bd create missing required card sections:" >&2
  for m in "${MISSING[@]}"; do
    echo "  ✗ $m" >&2
  done
  echo "" >&2
  echo "Invoke the /project-card skill FIRST to build a compliant card." >&2
  echo "Every card MUST have all 12 sections. No exceptions." >&2
  exit 2
fi

exit 0
