#!/usr/bin/env bash
# Gate 22 — PostToolUse(Skill). AUDIT LOG ONLY as of 2026-08-09.
#
# Records that the project-ac-verify SKILL was invoked, and for which card.
#
# NOTHING READS THIS MARKER ANY MORE. It used to gate `bd gate resolve` via
# gate22-require-skill.sh; that scheme was retired because this hook fires when
# the skill LOADS, not when a review completes. On 2026-08-09 a Skill call that
# was interrupted one second later still wrote a valid marker, leaving a gate
# unlockable with no review having happened. Proof-of-invocation is not
# proof-of-review, and no marker the model can trigger ever could be.
#
# Enforcement now lives in ac-gate-human-only.sh (Bash) and
# ac-review-agent-block.sh (subagent): AC gates are resolved by Aaron, never by
# the model. This file is kept only as a timestamped record of when the skill
# ran, which is useful when reconstructing a session after the fact.

set -uo pipefail

INPUT="$(cat)"
SKILL="$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)"
ARGS="$(printf '%s' "$INPUT" | jq -r '.tool_input.args // empty' 2>/dev/null)"
SESSION="$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null)"

case "$SKILL" in
  project-ac-verify|*:project-ac-verify) ;;
  *) exit 0 ;;
esac

MARKER_DIR="${HOME}/.claude/state/ac-verify"
mkdir -p "$MARKER_DIR"
printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ARGS" >> "${MARKER_DIR}/${SESSION}.invoked"

exit 0
