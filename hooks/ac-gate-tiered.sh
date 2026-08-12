#!/usr/bin/env bash
# AC-verify gate enforcement, TIERED — PreToolUse(Bash).
#
# CONTRACT (2026-08-10, Aaron's ruling, replacing 2026-08-09's human-only rule):
#   The 2026-08-09 incident was too-broad SELF-approval; the human-only remedy
#   overcorrected into zero autonomy and made Aaron a rubber stamp — typing
#   resolves on the model's say-so adds friction, not assurance. This hook
#   implements the researched middle ground (graduated oversight: arXiv
#   2606.22484; tiered autonomy per the agent-guardrail literature; GitHub
#   auto-merge-on-green as the software-native precedent):
#
#   TIER 2 — evidence-conditional self-resolution (normal full-mode cards):
#     the model may resolve an AC gate ONLY when this hook can verify, without
#     trusting the model, that the canonical reviewer ran against the CURRENT
#     tree and recorded PASS: a verdict artifact exists, names this card, says
#     PASS, and its embedded hashes match hashes THIS HOOK re-derives by
#     re-running the canonical generator at resolve time. Code changed since
#     review => hashes differ => stale => denied. Every self-resolution is
#     appended to a session ledger for Aaron's audit.
#
#   TIER 1 — Aaron's key, always (his terminal, where hooks do not run):
#     * the card carries the `human-gate` label (applied at carding for
#       security-sensitive, outward-facing, and release work)
#     * the card FLAPPED: >= FLAP_LIMIT recorded FAIL verdicts (momentum
#       failure — repeated fix-until-it-passes needs human eyes)
#     * the CREDIT is spent: >= UNAUDITED_BUDGET self-resolutions on this
#       <repo>@<branch> are still awaiting Aaron's audit (structural
#       anti-momentum brake — a hot streak pauses for audit no matter how good
#       it feels). Credit is returned by his audit, never by the clock:
#       `ac-audit-ledger.sh ack '<repo>@<branch>'`. Corrected 2026-08-11 —
#       this was a bare line count over a session_id-keyed ledger with no drain
#       at all, so a spent budget outlived the audit that should have cleared
#       it and wedged the next day's work. See ac-audit-ledger.sh.
#     * anything this hook cannot positively verify (fail closed)
#
#   STATED HONESTLY: the verdict artifact is written by the reviewer subagent,
#   and no in-process scheme can cryptographically distinguish its writes from
#   the model's — a deliberate multi-step fabrication remains possible. The
#   countermeasures are detection, not impossibility: the ledger records every
#   self-resolution with the evidence it relied on, gate22-mark-skill.sh
#   independently timestamps skill invocations for cross-checking, and Aaron
#   audits the ledger. Honest-path cheap, bypass auditable — the same
#   philosophy as bd close --force being blocked rather than hidden.
#
# Board hygiene is preserved: the guard engages only on gates whose stored
# description carries the AC-verify reason written at card start by project-tdd
# Gate 0. Orphaned gates, probe gates and formula gates resolve normally.

set -uo pipefail

UNAUDITED_BUDGET=5 # Aaron, 2026-08-10: self-resolutions outstanding before he must audit
FLAP_LIMIT=2       # recorded FAIL verdicts on a card before it needs his eyes

# AC_REVIEW_STATE_DIR exists so the behavioral tests can run against a scratch
# state directory instead of the real one. Untested enforcement is how the
# credit defect survived: the committed suite pointed at this hook's deleted
# predecessor, so every DENY case silently reported ALLOW.
STATE_DIR="${AC_REVIEW_STATE_DIR:-${HOME}/.claude/state/ac-review}"
# Siblings are resolved relative to THIS script so the repo copy is self-consistent
# and the installed symlink resolves to the same files.
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$HOOK_DIR/ac-review-prompt.sh"
LEDGERER="$HOOK_DIR/ac-audit-ledger.sh"

INPUT="$(cat)"
RAW_COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
SESSION="$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null)"

[ -z "$RAW_COMMAND" ] && exit 0

# Match only REAL invocations, not the phrase appearing inside a quoted
# argument. Without this, `bd remember "... denies bd gate resolve ..."`
# self-blocks (observed 2026-08-09). A genuine command sits outside quotes.
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

# --- bd close --force : never automatic --------------------------------------
if printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])bd[[:space:]]+close([[:space:]]|$)' \
   && printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])--force([[:space:]]|$)'; then
  deny "BLOCKED: 'bd close --force' bypasses an unsatisfied gate. That is Aaron's call, not yours. Report the card as ready and stop."
fi

# --- collect candidate issue IDs from gate-touching commands ------------------
CANDIDATES=""
MODE=""

if printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])bd[[:space:]]+gate[[:space:]]+resolve([[:space:]]|$)'; then
  MODE="resolve"
  CANDIDATES="$(printf '%s' "$COMMAND" \
    | sed -E 's/.*bd[[:space:]]+gate[[:space:]]+resolve[[:space:]]+//' \
    | tr ' ' '\n' | grep -E '^[A-Za-z0-9][A-Za-z0-9._-]*$' | head -10)"
  if [ -z "$CANDIDATES" ]; then
    deny "BLOCKED: could not determine which gate 'bd gate resolve' targets, so it cannot be checked against the AC-verify guard. Ask Aaron to resolve it."
  fi
elif printf '%s' "$COMMAND" | grep -Eq '(^|[[:space:]])bd[[:space:]]+close([[:space:]]|$)'; then
  MODE="close"
  CANDIDATES="$(printf '%s' "$COMMAND" \
    | sed -E 's/.*bd[[:space:]]+close[[:space:]]+//' \
    | tr ' ' '\n' | grep -E '^[A-Za-z0-9][A-Za-z0-9._-]*$' | head -10)"
else
  exit 0
fi

for ID in $CANDIDATES; do
  DETAIL="$(bd show "$ID" 2>/dev/null)"
  [ -z "$DETAIL" ] && continue

  printf '%s' "$DETAIL" | grep -Eq 'Type:[[:space:]]*gate' || continue
  printf '%s' "$DETAIL" | grep -Eqi 'AC verification required|project-ac-verify' || continue

  # Closing a gate directly skips every check below — resolution is the ONE path.
  if [ "$MODE" = "close" ]; then
    deny "BLOCKED: ${ID} is an AC-verify gate. Gates are resolved ('bd gate resolve ${ID}'), not closed — the resolve path is where the evidence checks run."
  fi

  BLOCKED_CARD="$(printf '%s' "$DETAIL" | grep -Eo 'blocking[[:space:]]+[A-Za-z0-9._-]+' | awk '{print $2}' | head -1)"
  if [ -z "$BLOCKED_CARD" ]; then
    deny "BLOCKED: ${ID} is an AC-verify gate but the card it blocks could not be determined. Failing closed — ask Aaron to resolve it."
  fi

  SAFE="$(printf '%s' "$BLOCKED_CARD" | tr -c 'A-Za-z0-9._-' '_')"
  VERDICT_FILE="$STATE_DIR/$SAFE.verdict.json"
  VERDICT_LOG="$STATE_DIR/$SAFE.verdicts.log"
  KEY="$([ -x "$LEDGERER" ] && "$LEDGERER" key 2>/dev/null || echo "unknown@unknown")"

  # ---- TIER 1: Aaron's key required ----------------------------------------
  if bd label list "$BLOCKED_CARD" 2>/dev/null | grep -q 'human-gate'; then
    deny "TIER 1: ${BLOCKED_CARD} carries the human-gate label (security-sensitive, outward-facing, or release work). Aaron resolves this one himself: bd gate resolve ${ID} --reason \"...\". Report the card as ready with its evidence."
  fi

  if [ -f "$VERDICT_LOG" ]; then
    FAILS="$(grep -c '^FAIL' "$VERDICT_LOG" 2>/dev/null || true)"
    if [ "${FAILS:-0}" -ge "$FLAP_LIMIT" ]; then
      deny "TIER 1 (flap): ${BLOCKED_CARD} has ${FAILS} recorded FAIL verdicts — repeated fix-until-green needs human eyes. Aaron resolves: bd gate resolve ${ID} --reason \"...\"."
    fi
  fi

  # Credit, not a clock. USED is self-resolutions OUTSTANDING — emitted minus
  # audited — so Aaron's audit is what returns capacity. Keyed on <repo>@<branch>,
  # the durable thing the audit is about, NOT on session_id (whose lifetime is
  # undocumented and in practice spans compaction and days: on 2026-08-11 a spent
  # day-old budget blocked work Aaron had already audited). Rationale, precedent
  # and the rejected time-window designs: ac-audit-ledger.sh header.
  USED=0
  if [ -x "$LEDGERER" ]; then
    USED="$("$LEDGERER" count "$KEY" 2>/dev/null || echo 0)"
  else
    deny "TIER 1: the audit ledger helper is missing at ${LEDGERER}, so outstanding-credit cannot be counted. Failing closed — ask Aaron to resolve ${ID} and restore the helper."
  fi
  if [ "${USED:-0}" -ge "$UNAUDITED_BUDGET" ]; then
    OUTSTANDING="$("$LEDGERER" list "$KEY" 2>/dev/null | sed 's/^/    /')"
    deny "TIER 1 (credit): ${USED}/${UNAUDITED_BUDGET} self-resolutions on ${KEY} are awaiting your audit, so the model has no credit left. Time does not restore it — your audit does.
Outstanding:
${OUTSTANDING}
When you have reviewed them:  ${LEDGERER} ack '${KEY}'
Then this resolves normally. To sign this one yourself instead: bd gate resolve ${ID} --reason \"...\"."
  fi

  # ---- TIER 2: evidence verification ---------------------------------------
  if [ ! -f "$VERDICT_FILE" ]; then
    deny "DENIED (no evidence): no reviewer verdict exists for ${BLOCKED_CARD}. Run /project-ac-verify ${BLOCKED_CARD} — the canonical reviewer writes the verdict artifact this gate checks."
  fi

  V_CARD="$(jq -r '.card_id // ""' "$VERDICT_FILE" 2>/dev/null)"
  V_VERDICT="$(jq -r '.overall_verdict // ""' "$VERDICT_FILE" 2>/dev/null)"
  V_CRIT="$(jq -r '.criteria_sha256 // ""' "$VERDICT_FILE" 2>/dev/null)"
  V_DIFF="$(jq -r '.diff_sha256 // ""' "$VERDICT_FILE" 2>/dev/null)"

  if [ "$V_CARD" != "$BLOCKED_CARD" ]; then
    deny "DENIED: the verdict artifact names '${V_CARD}', not ${BLOCKED_CARD}. Re-run /project-ac-verify ${BLOCKED_CARD}."
  fi
  if [ "$V_VERDICT" != "PASS" ]; then
    deny "DENIED: the recorded verdict for ${BLOCKED_CARD} is '${V_VERDICT}', not PASS. Fix the findings and re-run /project-ac-verify ${BLOCKED_CARD}."
  fi
  if [ -z "$V_CRIT" ] || [ -z "$V_DIFF" ]; then
    deny "DENIED: the verdict artifact for ${BLOCKED_CARD} carries no artifact hashes, so freshness cannot be verified. Re-run /project-ac-verify ${BLOCKED_CARD} with the current generator."
  fi

  # Freshness: re-derive the hashes from the CURRENT tree via the canonical
  # generator. Any code or card change since the review changes a hash and the
  # PASS no longer applies. This is the check that makes self-resolution safe
  # to allow at all.
  if ! "$GEN" "$BLOCKED_CARD" >/dev/null 2>"$STATE_DIR/.gen_err_$SAFE"; then
    GERR="$(head -3 "$STATE_DIR/.gen_err_$SAFE" 2>/dev/null | tr '\n' ' ')"
    rm -f "$STATE_DIR/.gen_err_$SAFE"
    deny "DENIED: could not re-derive the review artifact for ${BLOCKED_CARD} (${GERR}). Without regeneration, freshness cannot be checked. Ask Aaron if this persists."
  fi
  rm -f "$STATE_DIR/.gen_err_$SAFE"

  NOW_CRIT="$(shasum -a 256 < "$STATE_DIR/$SAFE.criteria.md" 2>/dev/null | cut -d' ' -f1)"
  NOW_DIFF="$(shasum -a 256 < "$STATE_DIR/$SAFE.diff" 2>/dev/null | cut -d' ' -f1)"

  if [ "$NOW_CRIT" != "$V_CRIT" ] || [ "$NOW_DIFF" != "$V_DIFF" ]; then
    deny "DENIED (stale): the tree or the card changed since the reviewer's PASS for ${BLOCKED_CARD} (criteria $([ "$NOW_CRIT" = "$V_CRIT" ] && echo ok || echo CHANGED), diff $([ "$NOW_DIFF" = "$V_DIFF" ] && echo ok || echo CHANGED)). Re-run /project-ac-verify ${BLOCKED_CARD} against the current state."
  fi

  # ---- TIER 2 satisfied: allow, and take one credit until Aaron audits -----
  # session= is recorded for forensics but is deliberately NOT the key.
  "$LEDGERER" record "$KEY" \
    "gate=$ID card=$BLOCKED_CARD diff_sha=$V_DIFF crit_sha=$V_CRIT session=$SESSION"
  exit 0
done

exit 0
