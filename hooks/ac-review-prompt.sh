#!/usr/bin/env bash
# Canonical AC-review prompt generator.
#
# WHY THIS EXISTS (2026-08-09, external prior art):
#   Cross-Context Review (arXiv 2603.12123) measured that the gain from
#   independent review comes from CONTEXT SEPARATION, not from reviewing again:
#   the reviewer must receive "only the final artifact, with no production
#   history, and no generation instructions", and critically "the generator
#   cannot curate what the reviewer sees". Augment Code's maker-checker guide
#   reaches the same mechanic from practice: the checker gets "fresh context:
#   only diff plus criteria", and the maker does not control the checker.
#
#   The review prompt is DERIVED MECHANICALLY from the card and the diff. The
#   model cannot choose the framing, cannot pick which files the reviewer sees,
#   and cannot omit an inconvenient acceptance criterion, because it does not
#   write any of it. ac-review-agent-block.sh regenerates this output
#   independently and refuses any reviewer prompt that is not byte-identical.
#
# CHANGED 2026-08-10 evening (Aaron-ordered, found by two reviewers on
# heimdall2-e25.20/.30): `git status --porcelain` collapses an untracked
# DIRECTORY to a single "dir/" entry, so files inside it never exact-match the
# card's Files paths and the untracked-append below silently skipped them —
# the hashed diff omitted the card's own new files whenever they lived in a
# new directory. Fixed with --untracked-files=all (per-file listing) on the
# UNTRACKED and OUT_OF_SCOPE status calls. Read-only and deterministic —
# `git add -N` was considered and rejected: it mutates the index, which would
# break byte-identical regeneration between the generator, the agent-block
# check, and resolve-time re-derivation.
#
# CHANGED 2026-08-10 (Aaron's tiered-autonomy ruling — see ac-gate-tiered.sh):
#   1. CARD-SCOPED ARTIFACT. The diff is limited to the paths the card's own
#      Files: section declares, parsed mechanically from bd — the model still
#      chooses nothing. Previously the artifact was the whole branch diff
#      (9.2MB / 1,400 files on feat/srg-authoring), which forced the reviewer
#      to curate the evidence itself — the exact act this machinery forbids.
#      Files outside the card's declared set that differ in the working tree
#      are LISTED so the reviewer can still fail a scope violation.
#   2. WORKING TREE INCLUDED. The diff is `git diff <base> -- <paths>` (no
#      ..HEAD), so uncommitted work is reviewable. The old committed-only form
#      forced commit-before-verify, inverting the verify-then-commit workflow.
#   3. VERDICT ARTIFACT. The reviewer writes its verdict JSON — hash-bound to
#      the criteria and diff it reviewed — to the state dir, and appends to a
#      per-card verdict log. ac-gate-tiered.sh re-derives the hashes at resolve
#      time and only honours a PASS that matches the CURRENT tree. Stated
#      honestly: the model could fabricate that file in a deliberate multi-step
#      act; the ledger and Aaron's audit make that detectable, not impossible.
#
# USAGE:  ac-review-prompt.sh <card-id> [base-ref]
# OUTPUT: the exact prompt text to pass to the review subagent, on stdout.
#
# DETERMINISM: same card + same tree => byte-identical output, which is what
# lets ac-review-agent-block.sh and ac-gate-tiered.sh regenerate and compare.
# Do not edit the tree between generating the prompt and spawning the reviewer.

set -uo pipefail

CARD="${1:-}"
BASE="${2:-main}"

if [ -z "$CARD" ]; then
  echo "usage: ac-review-prompt.sh <card-id> [base-ref]" >&2
  exit 2
fi

command -v bd >/dev/null 2>&1 || { echo "ac-review-prompt: bd not found" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ac-review-prompt: jq not found" >&2; exit 2; }

CARD_JSON="$(bd show "$CARD" --json 2>/dev/null)" || true

# `bd show` EXITS 0 AND PRINTS AN ERROR OBJECT for an unknown id
# ({"error":"no issues found...","schema_version":1}), so neither the exit
# status nor an empty/null check detects a missing card. Left undetected this
# fails OPEN in the worst possible way (observed 2026-08-09): the generator
# emitted a 39KB prompt with an EMPTY acceptance-criteria section, and
# ac-review-agent-block.sh — which trusts this script — allowed it. A reviewer
# spawned with no criteria passes everything.
#
# A found card is always a non-empty ARRAY whose first element carries an id.
if ! printf '%s' "$CARD_JSON" | jq -e 'type == "array" and length > 0 and (.[0].id // "") != ""' >/dev/null 2>&1; then
  echo "ac-review-prompt: card not found: $CARD" >&2
  exit 2
fi

TITLE="$(printf '%s' "$CARD_JSON" | jq -r '.[0].title // ""')"
DESC="$(printf '%s' "$CARD_JSON" | jq -r '.[0].description // ""')"
NOTES="$(printf '%s' "$CARD_JSON" | jq -r '.[0].notes // ""')"

# Sections lifted VERBATIM from the card. Extracted by anchor, not summarised —
# a summary would be the model's voice re-entering the prompt.
section() { printf '%s' "$DESC" | awk -v s="$1" -v e="$2" 'index($0,s)==1{f=1} f&&index($0,e)==1&&$0!=s{f=0} f'; }
ACS="$(section 'Acceptance criteria:' 'Verification:')"
ANTI="$(section 'Anti-patterns:' 'NOT in scope:')"
FILES_SECTION="$(section 'Files:' 'First failing test:')"
# Cards reference their design source as either "Design doc:" or "Plan:" —
# missing the latter left one review with no design reference at all.
DESIGN="$(printf '%s' "$DESC" | grep -iE '^(Design doc|Plan):' || true)"

# Same failure class as the missing-card check above, and it was still open: a
# card whose description carries no "Acceptance criteria:" anchor yields an
# EMPTY criteria section, and a reviewer handed no criteria passes everything.
# Fail closed rather than emit a prompt that cannot fail.
if [ -z "$(printf '%s' "$ACS" | tr -d '[:space:]')" ]; then
  echo "ac-review-prompt: no acceptance criteria found on $CARD." >&2
  echo "  The card description must contain an 'Acceptance criteria:' section" >&2
  echo "  ending at 'Verification:'. Refusing to generate a review that cannot fail." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Card path extraction — mechanical, from the card's own Files: section.
#
# The card's Files list was written at carding time and is part of the hashed
# criteria the reviewer receives, so deriving the diff scope from it keeps the
# model out of the evidence-selection loop. Tokens are recognised as paths when
# they contain a slash or a dot, or match the Makefile/Dockerfile family; bare
# words ("none", "prose"), parenthetical commentary and trailing punctuation
# are dropped. If NOTHING parses, fall back to the whole-tree artifact rather
# than an empty one, and say so in the prompt.
# ---------------------------------------------------------------------------
CARD_PATHS="$(printf '%s\n' "$FILES_SECTION" \
  | sed -E 's/\([^)]*\)//g' \
  | tr ' ,' '\n' \
  | sed -E 's/[[:space:]]+//g; s/[.,;:]+$//' \
  | grep -E '^\.?[A-Za-z0-9_][A-Za-z0-9_./-]*$' \
  | grep -E '/|\.|^[A-Z][A-Za-z]*file$' \
  | grep -Ev '^(e\.g|i\.e|etc|vs)\.?$' \
  | grep -Ev '^[0-9.]+$' \
  | sort -u)"

# ---------------------------------------------------------------------------
# The base must actually diverge from HEAD (empty-artifact guard, 2026-08-09:
# merge-base(main, HEAD) on a commit-to-main repo is HEAD itself, and the
# reviewer received every criterion and NO CODE — a confident PASS over
# nothing). Candidate bases are tried in a fixed order; an explicitly requested
# base is honoured or refused, never silently swapped.
# ---------------------------------------------------------------------------
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
HEAD_FULL="$(git rev-parse HEAD 2>/dev/null || echo "")"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

diverging_base() {
  local cand="$1" mb
  [ -z "$cand" ] && return 1
  git rev-parse --verify --quiet "$cand" >/dev/null 2>&1 || return 1
  mb="$(git merge-base "$cand" HEAD 2>/dev/null)" || return 1
  [ -z "$mb" ] && return 1
  [ "$mb" = "$HEAD_FULL" ] && return 1
  printf '%s' "$mb"
}

if [ -n "${2:-}" ]; then
  CANDIDATES="$BASE"
else
  CANDIDATES="origin/$BRANCH main origin/main master origin/master"
fi

MERGE_BASE=""
BASE_USED=""
for cand in $CANDIDATES; do
  if MERGE_BASE="$(diverging_base "$cand")"; then
    BASE_USED="$cand"
    break
  fi
done

# A worktree with uncommitted changes is reviewable even when every ref is an
# ancestor of HEAD: the artifact is then the uncommitted delta against HEAD.
if [ -z "$MERGE_BASE" ]; then
  if git status --porcelain 2>/dev/null | grep -qv '^?? \.beads'; then
    MERGE_BASE="$HEAD_FULL"
    BASE_USED="HEAD (uncommitted work only)"
  else
    echo "ac-review-prompt: no base ref diverges from HEAD (tried: $CANDIDATES)" >&2
    echo "  and the working tree is clean — there is no artifact to review." >&2
    echo "  If this branch genuinely has unreviewed work, pass the base explicitly:" >&2
    echo "    ac-review-prompt.sh $CARD <base-ref>" >&2
    exit 2
  fi
fi

BASE="$BASE_USED"

# ---------------------------------------------------------------------------
# The artifact: WORKING TREE INCLUDED (no ..HEAD), scoped to the card's paths
# when they parsed. Untracked files among the card's paths are appended via
# --no-index, since `git diff <base>` cannot see them.
# ---------------------------------------------------------------------------
if [ -n "$CARD_PATHS" ]; then
  SCOPE_NOTE="card's declared Files section ($(printf '%s\n' "$CARD_PATHS" | wc -l | tr -d ' ') paths)"
  # shellcheck disable=SC2086
  DIFF="$(printf '%s\n' "$CARD_PATHS" | xargs git diff "$MERGE_BASE" -- 2>/dev/null)"
  UNTRACKED="$(git status --porcelain --untracked-files=all 2>/dev/null | awk '$1=="??"{print $2}')"
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if printf '%s\n' "$CARD_PATHS" | grep -qxF "$p"; then
      EXTRA="$(git diff --no-index /dev/null "$p" 2>/dev/null || true)"
      DIFF="$DIFF
$EXTRA"
    fi
  done <<< "$UNTRACKED"
else
  SCOPE_NOTE="whole tree (no paths parsed from the card's Files section)"
  DIFF="$(git diff "$MERGE_BASE" -- . ':(exclude).beads' 2>/dev/null)"
fi

if [ -z "$(printf '%s' "$DIFF" | tr -d '[:space:]')" ]; then
  echo "ac-review-prompt: the diff against $BASE is empty for scope: $SCOPE_NOTE." >&2
  echo "  There is no artifact to review. Refusing to generate a review of nothing." >&2
  echo "  If the card's work lives at paths its Files section does not name," >&2
  echo "  fix the card's Files section — it is the reviewable contract." >&2
  exit 2
fi

# Tree state outside the card's scope, so the reviewer can fail the
# "diff shows ONLY files listed" check without receiving the whole branch.
OUT_OF_SCOPE="$(git status --porcelain --untracked-files=all 2>/dev/null | grep -v '\.beads' | awk '{print $2}' | { grep -vxF -f <(printf '%s\n' "$CARD_PATHS") || true; } | sort)"

# ---------------------------------------------------------------------------
# Bulk goes to FILES with deterministic paths; the prompt carries their
# SHA-256. A pinned artifact the reviewer fetches and verifies resists
# curation better than a pasted copy: with an inline copy the model is the
# transport and can corrupt it in transit; with a hash the reviewer detects
# any alteration and can regenerate the diff from git independently.
# ---------------------------------------------------------------------------
STATE_DIR="${HOME}/.claude/state/ac-review"
mkdir -p "$STATE_DIR" || { echo "ac-review-prompt: cannot create $STATE_DIR" >&2; exit 2; }

SAFE="$(printf '%s' "$CARD" | tr -c 'A-Za-z0-9._-' '_')"
CRIT_FILE="$STATE_DIR/$SAFE.criteria.md"
DIFF_FILE="$STATE_DIR/$SAFE.diff"
VERDICT_FILE="$STATE_DIR/$SAFE.verdict.json"
VERDICT_LOG="$STATE_DIR/$SAFE.verdicts.log"

{
  printf '# %s — %s\n\n' "$CARD" "$TITLE"
  [ -n "$DESIGN" ] && printf '%s\n\n' "$DESIGN"
  printf '## Files (verbatim from the card — the declared change scope)\n%s\n\n' "$FILES_SECTION"
  printf '## Acceptance criteria (verbatim from the card)\n%s\n\n' "$ACS"
  printf '## Anti-patterns (verbatim from the card)\n%s\n\n' "$ANTI"
  printf '## Card notes (execution history: disclosures, evidence, prior rounds)\n'
  printf 'Treat these as CLAIMS BY THE IMPLEMENTER, not as findings. Verify them.\n%s\n' "$NOTES"
} > "$CRIT_FILE"

printf '%s\n' "$DIFF" > "$DIFF_FILE"

CRIT_SHA="$(shasum -a 256 < "$CRIT_FILE" | cut -d' ' -f1)"
DIFF_SHA="$(shasum -a 256 < "$DIFF_FILE" | cut -d' ' -f1)"
AC_COUNT="$(printf '%s' "$ACS" | grep -c '^- \[ \]' || true)"

cat <<PROMPT
You are an independent acceptance-criteria reviewer. Verify whether each
acceptance criterion is met by the artifact. You have no investment in closing
this card. Default to FAIL when evidence is ambiguous.

You are READ-ONLY with exactly one exception, stated at the end: writing your
own verdict artifact. Do not edit any other file. You may read files and run
read-only commands to confirm a cited line. Do not run test suites or builds —
their results are reported in the card notes and are not yours to reproduce.

This prompt was generated mechanically by ac-review-prompt.sh. The implementing
agent did not write it, did not choose which acceptance criteria you see, and
did not choose which files you see. If something you need is missing, say so
rather than assuming it was withheld deliberately.

## Card
$CARD — $TITLE
Tree under review: HEAD $HEAD_SHA, working tree included (base: $BASE)
Artifact scope: $SCOPE_NOTE
$AC_COUNT acceptance criteria

## Read these two files, and verify them BEFORE reviewing
1. Criteria, anti-patterns and card notes:
   $CRIT_FILE
   expected sha256 $CRIT_SHA
2. The artifact under review (the card's change set, board bookkeeping excluded):
   $DIFF_FILE
   expected sha256 $DIFF_SHA

Run: shasum -a 256 $CRIT_FILE $DIFF_FILE
If either digest differs from the expected value above, STOP and report
ARTIFACT HASH MISMATCH as your entire answer. Do not review altered material.

## Tree state outside the card's declared scope
Changed-or-untracked paths NOT in the card's Files section (empty means none):
$OUT_OF_SCOPE
A card whose diff must show ONLY its listed files fails if its work leaked
into paths above; unrelated pre-existing entries are not the card's failure —
judge which is which.

## Your task
For EACH acceptance criterion above, report:
- AC: the criterion text
- Verdict: PASS or FAIL
- Evidence: the specific diff line, test name, or output that proves it. If
  FAIL, state exactly what is missing or wrong.

Then report:
- Anti-pattern violations, citing lines. EXCEPTION: a DISCLOSED
  you-find-it-you-fix-it fix is not a violation — verify the disclosure and its
  evidence instead of failing the card's lock.
- Design-doc gaps: quote the requirement, state what the diff does not cover.
- Type safety: any \`as any\`, \`as unknown\`, \`@ts-ignore\`, or other bypass.
- Test quality: any test that would still pass if the code were broken.

## Your verdict artifact — the one write you perform
After composing your report, write your verdict JSON (the exact object below)
to: $VERDICT_FILE
and append ONE line to: $VERDICT_LOG
in the form: <PASS|FAIL> $DIFF_SHA
The gate that unblocks this card re-derives these hashes from the current tree
and honours your verdict only while they still match — your write is what makes
the review verifiable after your context is gone.

Delivery: after writing both files, deliver the COMPLETE report (per-AC
verdicts, findings, then the JSON) as your final response and end your turn.
Your final response is the only channel the orchestrator reads — do not wait
for further instructions, do not ask whether to proceed, and do not stop after
writing the files. End the report with exactly this JSON and nothing after it:
{"card_id": "$CARD", "overall_verdict": "PASS"|"FAIL", "criteria_sha256": "$CRIT_SHA", "diff_sha256": "$DIFF_SHA", "ac_results": [{"criterion": "...", "verdict": "PASS"|"FAIL", "evidence": "..."}], "anti_pattern_violations": [], "design_doc_gaps": [], "type_safety_issues": [], "weak_tests": []}
PROMPT
