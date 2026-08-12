#!/usr/bin/env bash
# AC-verify enforcement, part 2 — PreToolUse(Task|Agent).
#
# CONTRACT (rewritten 2026-08-09 against external prior art, at Aaron's direction):
#   An AC review may run, but the model may not WRITE it. The reviewer's prompt
#   must be the mechanically generated one, byte-for-byte. This hook regenerates
#   it independently and refuses anything else.
#
# WHY THE CONTRACT CHANGED. The previous version denied every review-shaped
# subagent outright. Its diagnosis was right — "the model authors the prompt,
# picks the evidence handed to the reviewer, and transcribes the verdict; that
# is self-certification with extra steps" — but the remedy deadlocked the
# workflow: /project-tdd Gate 22 requires a review before close, so with the
# review unrunnable NO full-mode card could ever close. Observed live on
# beads-board-b7i.14.5, which sat finished, green, and unclosable.
#
# The external prior art solves the same problem without the deadlock:
#   - Cross-Context Review (arXiv 2603.12123) measured that the benefit comes
#     from CONTEXT SEPARATION, not from reviewing twice: give the reviewer
#     "only the final artifact, with no production history", because "the
#     generator cannot curate what the reviewer sees". Same-session self-review
#     scored worse (F1 24.6% vs 28.6%, p=0.008).
#   - Augment Code's maker-checker guide: the checker gets "fresh context: only
#     diff plus criteria", holds zero write authority, and humans keep merge
#     eligibility.
# Both target the CURATION channel, not the act of invocation. So does this.
#
# WHAT REMAINS THE MODEL'S, AND WHAT DOES NOT:
#   May:     run the generator, spawn the reviewer with its exact output,
#            report the verdict verbatim, fix what the review finds.
#   May NOT: write or edit the reviewer's prompt, choose the evidence, or
#            resolve the gate. Gate resolution stays Aaron's, unchanged, in
#            ac-gate-human-only.sh — the prior art's human checkpoint.
#
# Tool-name and schema independent by design: the subagent tool is documented as
# "Task" and presented as "Agent" in some builds, and the field holding the
# prompt is not documented, so this matches the ENTIRE serialized tool_input.

set -uo pipefail

INPUT="$(cat)"
GEN="$HOME/.claude/hooks/ac-review-prompt.sh"

# Every string value carried anywhere in tool_input, UNESCAPED, joined.
#
# This was `.tool_input | tostring`, which returns JSON-ENCODED text, and that
# single choice broke the hook two ways at once (both observed 2026-08-09 on
# beads-board-b7i.14.5):
#   1. A prompt's newlines arrive as the two characters \ and n, so the card id
#      at the start of a line reads as "nbeads-board-b7i.14.5" — the extraction
#      below then regenerated the canonical prompt for a card that does not
#      exist, and denied the CORRECT prompt.
#   2. The canonical text (real newlines) can never be found inside escaped
#      text, so the containment check could not have passed even with the right
#      card id.
# `.. | strings` also keeps the original property of being schema-independent:
# it does not care which field name carries the prompt.
TEXT="$(printf '%s' "$INPUT" | jq -r '[(.tool_input // {}) | .. | strings] | join("\n")' 2>/dev/null)"
[ -z "$TEXT" ] && exit 0

PAYLOAD="$(printf '%s' "$TEXT" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ')"

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

# Is this an AC review at all? Same two-signal test as before, so ordinary
# implementation agents that merely carry a card's text are not caught.
IS_REVIEW=0
printf '%s' "$PAYLOAD" | grep -Eq 'project-ac-verify|ac-verify|ac verification|gate 22|gate22' && IS_REVIEW=1
SUBJECT='acceptance criteri|acceptance-criteri|each ac\b|per ac\b|all acs|ac reviewer'
INTENT='verdict|pass or fail|pass/fail|independent review|independently verify|verify whether each|reviewer.*no investment|default to fail'
if printf '%s' "$PAYLOAD" | grep -Eq "$SUBJECT" && printf '%s' "$PAYLOAD" | grep -Eq "$INTENT"; then
  IS_REVIEW=1
fi
[ "$IS_REVIEW" -eq 0 ] && exit 0

# From here on this IS a review. It is allowed only if its prompt is exactly the
# generated one for the card it names.
if [ ! -x "$GEN" ]; then
  deny "BLOCKED: an AC review must use the generated prompt (ac-review-prompt.sh), but the generator is missing or not executable at $GEN. Fix the generator; do not hand-write the review."
fi

# The card id must come from the prompt itself, not from anything the model
# asserts separately.
#
# PROJECT-AGNOSTIC. The previous version scraped the id with a regex hardcoded
# to beads-board's prefix (`-b7i`), so it could not see dtb-igf.2, heimdall2-e25
# or any other project's ids — every review outside that one repo was denied for
# "names no card id". Worse, a free-text scrape can match mid-word: that is how
# "nbeads-board-b7i.14.5" got through and regenerated a prompt for a card that
# does not exist.
#
# The generator ALWAYS ends its output with the required verdict JSON carrying
# "card_id": "<id>" (ac-review-prompt.sh, final heredoc line). That marker is
# structural, unique, and identical in every project — so read that, and only
# that. If it is absent, the prompt did not come from the generator, which is
# itself the thing being checked.
CARD="$(printf '%s' "$TEXT" \
  | grep -oE '"card_id"[[:space:]]*:[[:space:]]*"[^"]+"' \
  | head -1 \
  | sed -E 's/.*"card_id"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
if [ -z "$CARD" ]; then
  deny "BLOCKED: this looks like an AC review but names no card id, so the canonical prompt cannot be regenerated to check it. Generate the prompt with: ac-review-prompt.sh <card-id>"
fi

EXPECTED="$($GEN "$CARD" 2>/dev/null)"
if [ -z "$EXPECTED" ]; then
  deny "BLOCKED: could not generate the canonical review prompt for $CARD (card missing, or not in a git repo). Run ac-review-prompt.sh $CARD to see the error."
fi

# Compare on collapsed whitespace: transport may re-wrap, but no word may differ,
# be added, or be dropped.
norm() { tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'; }

# CONTAINMENT VIA FILES, NOT ARGV. This was `grep -qF "$(... | norm)"`, which
# passes the whole canonical prompt — ~129 KB — as a single command-line
# argument. BSD grep answers that with "grep: out of memory" and a non-zero
# exit, which the `if` then reads as "the prompt does not match". The hook
# therefore DENIED THE CORRECT PROMPT, with both hashes identical in its own
# debug line (observed 2026-08-09 on dtb-igf.2: canonical=384f9499…
# given=384f9499…). Every project would have deadlocked exactly as before, and
# the failure is silent — grep's message goes to stderr, which nothing reads.
#
# perl index() over slurped files has no argv limit and no pattern compilation,
# so size is irrelevant.
# Explicit XXXXXX template: `mktemp -t name` is accepted by BSD mktemp but
# rejected by GNU coreutils ("too few X's in template"), which returns an empty
# path and makes every later read fail silently.
CANON_FILE="$(mktemp "${TMPDIR:-/tmp}/acreview-canon.XXXXXX")" || exit 0
GIVEN_FILE="$(mktemp "${TMPDIR:-/tmp}/acreview-given.XXXXXX")" || exit 0
trap 'rm -f "$CANON_FILE" "$GIVEN_FILE"' EXIT

printf '%s' "$EXPECTED" | norm > "$CANON_FILE"
printf '%s' "$TEXT"     | norm > "$GIVEN_FILE"

GOT_HASH="$(shasum -a 256 < "$GIVEN_FILE" | cut -d' ' -f1)"
EXP_HASH="$(shasum -a 256 < "$CANON_FILE" | cut -d' ' -f1)"

# The tool_input carries the prompt plus sibling fields (model, description...),
# so an exact whole-payload match is not expected — require CONTAINMENT of the
# canonical text instead, and forbid material additions to it.
if perl -e '
    local $/;
    open my $c, "<", $ARGV[0] or exit 2;  my $canon = <$c>;
    open my $g, "<", $ARGV[1] or exit 2;  my $given = <$g>;
    exit(index($given, $canon) >= 0 ? 0 : 1);
  ' "$CANON_FILE" "$GIVEN_FILE"; then
  EXTRA=$(( $(wc -c < "$GIVEN_FILE") - $(wc -c < "$CANON_FILE") ))
  if [ "$EXTRA" -gt 400 ]; then
    deny "BLOCKED: the reviewer prompt contains the canonical text plus $EXTRA extra characters. Framing added around a generated prompt is still framing the model chose. Pass the generator's output unmodified."
  fi
  exit 0
fi

deny "BLOCKED: this AC review's prompt is not the generated one for $CARD, so it is a review the model wrote for itself — the curation channel the gate exists to close (Cross-Context Review: 'the generator cannot curate what the reviewer sees'). Do this instead:
  ac-review-prompt.sh $CARD
and pass that output VERBATIM as the subagent prompt. Do not summarise the card, choose the diff, or add framing. Gate resolution remains Aaron's either way.
[debug] canonical=$EXP_HASH given=$GOT_HASH"
