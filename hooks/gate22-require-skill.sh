#!/usr/bin/env bash
# Gate 22 enforcement — PreToolUse(Bash).
#
# Why this exists: on 2026-08-09 the AC-verify gate was "satisfied" twice by a
# hand-written reviewer agent instead of the /project-ac-verify skill, and the
# bd gate was then resolved by hand. Prose in the skill did not prevent it.
# This makes the bypass mechanically unavailable.
#
# Blocks:
#   * `bd gate resolve ...`  unless the project-ac-verify SKILL ran this session
#                            for the card that gate blocks
#   * `bd close ... --force` always (auditable escape hatch -> ask the user)
#
# The marker is written only by gate22-mark-skill.sh, which fires on
# PostToolUse(Skill). Nothing the model types can forge it.

set -uo pipefail

INPUT="$(cat)"
RAW_COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
SESSION="$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null)"

[ -z "$RAW_COMMAND" ] && exit 0

# Match only REAL invocations, not the phrase appearing inside a quoted argument.
# Without this, `bd remember "... denies bd gate resolve ..."` self-blocks (observed
# 2026-08-09). Strip single- and double-quoted segments before pattern matching; a
# genuine `bd gate resolve` sits outside quotes and survives.
COMMAND="$(printf '%s' "$RAW_COMMAND" | perl -pe "s/'[^']*'//g; s/\"[^\"]*\"//g")"

deny() {
  jq -nc --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# --- bd close --force : never automatic -------------------------------------
if printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])bd[[:space:]]+close([[:space:]]|$)' \
   && printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])--force([[:space:]]|$)'; then
  deny "BLOCKED: 'bd close --force' bypasses the AC-verify gate. That is the user's call, not yours. Ask Aaron explicitly, or satisfy the gate by invoking the /project-ac-verify skill."
fi

# --- bd gate resolve : only a CLAIMED AC-VERIFY PASS needs the skill --------
# Narrowed 2026-08-09: the first version blocked EVERY `bd gate resolve`, which
# also blocked legitimate board hygiene — cleaning up orphaned gates, cancelling
# a gate on an abandoned card, removing a probe. That makes a stale board
# unfixable, the opposite of the intent. The property actually worth enforcing
# is that you cannot CLAIM a verified pass without having run the skill; a
# resolution that makes no such claim is ordinary maintenance.
if ! printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])bd[[:space:]]+gate[[:space:]]+resolve([[:space:]]|$)'; then
  exit 0
fi

# The claim lives in --reason, which IS quoted — so check the RAW command here,
# not the quote-stripped one.
if ! printf '%s' "$RAW_COMMAND" | grep -Eqi 'AC-VERIFY[[:space:]]+PASS'; then
  exit 0
fi

MARKER_DIR="${HOME}/.claude/state/ac-verify"
MARKER="${MARKER_DIR}/${SESSION}.invoked"

if [ ! -s "$MARKER" ]; then
  deny "BLOCKED: no /project-ac-verify skill invocation recorded in this session. Gate 22 is satisfied ONLY by an actual Skill tool call to project-ac-verify — a self-written reviewer Agent does NOT count, no matter how thorough. Invoke the skill, then resolve the gate."
fi

# Which card does this gate block? Map gate id -> card id via bd, then require
# that the skill was invoked for THAT card (not merely for some other card).
GATE_ID="$(printf '%s' "$COMMAND" \
  | grep -Eo 'bd[[:space:]]+gate[[:space:]]+resolve[[:space:]]+[^[:space:]]+' \
  | awk '{print $4}')"

if [ -n "$GATE_ID" ]; then
  CARD="$(bd show "$GATE_ID" 2>/dev/null | grep -Eo 'blocking[[:space:]]+[A-Za-z0-9._-]+' | awk '{print $2}' | head -1)"
  if [ -n "$CARD" ] && ! grep -qF "$CARD" "$MARKER"; then
    deny "BLOCKED: gate ${GATE_ID} blocks ${CARD}, but /project-ac-verify was never invoked for ${CARD} in this session (marker holds: $(tr '\n' ' ' < "$MARKER")). Invoke the skill for ${CARD} first."
  fi
fi

exit 0
