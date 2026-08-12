#!/usr/bin/env bash
# write-target-guard.sh — PreToolUse guard.
#
# THE RULE IT ENFORCES
#   No file may be mutated inside a git working tree, and no mutating git
#   command may run in one, until that tree has been declared a WRITE TARGET
#   for the current session. A write target is a (root path, branch) pair —
#   rendered everywhere as:  <path> @ <branch>
#
# WHY IT EXISTS
#   A shell's working directory is not a statement of intent. It drifts — a
#   subshell, a tool that resets it, a session resumed somewhere else — and an
#   agent that reads its location as its assignment will silently do correct
#   work on the wrong branch. Repositories with multiple checkouts (git
#   worktrees) make this worse: several directories share one history, each on
#   a different branch, and nothing in a task description names which one it
#   belongs to. That is why the target is the CHECKOUT ROOT, not the
#   repository: two worktrees of one repo are two distinct targets.
#
#   Prose in a workflow document cannot prevent this, because the failure is
#   precisely that the document is never consulted — the location was never
#   questioned, so no check was reached. The guard converts an assumption into
#   an explicit, visible decision at the moment of the first write.
#
# WHAT IT COVERS
#   Write / Edit / NotebookEdit   — the file_path is a structured field, so the
#                                   target is resolved exactly, never parsed.
#   Bash                          — mutating git verbs only (commit, add, push,
#                                   checkout, rebase, ...). Read-only git is
#                                   untouched; checking where you are must
#                                   never be blocked.
#
# WHAT IT DOES NOT COVER (stated plainly rather than implied)
#   * In-place edits through a shell (perl -i, tee, output redirection).
#     Detecting those means parsing arbitrary shell, which produces false
#     denials — and a guard that blocks legitimate work gets disabled.
#   * Whether the task at hand BELONGS on the declared branch. The guard
#     enforces that a target was chosen deliberately, not that it was chosen
#     correctly. A task from an unrelated subsystem, worked on a branch that
#     was legitimately declared for other work, passes this guard.
#
# FAILURE POSTURE
#   Fails OPEN on infrastructure problems (no jq, no git, unparseable input).
#   A guard that blocks every write because of its own bug is worse than the
#   drift it prevents. It fails CLOSED only on the check itself.
#
# CONTRACT REVISION (2026-08-10, Aaron's direction)
#   The original contract demanded ask-and-wait for EVERY new tree, including
#   trees the user had just explicitly named — pure ceremony that re-asked
#   questions already answered. The revised contract distinguishes evidence:
#   a tree the user named in the current exchange may be declared by the model
#   itself WITH a --cite of the user's words (visible banner + session log =
#   the audit); a tree reached by location, precedent, or inference still
#   requires ask-and-wait. The incident this guard exists for — silent drift
#   into the wrong checkout — cannot produce a citation, because nobody said
#   it. Same tiered principle as ac-gate-tiered.sh: evidence-conditional
#   autonomy, hard stop without evidence.
#
# NAMING (2026-08-10, Aaron's direction): formerly worktree-target-guard.sh.
#   "Write target" names the function — where writes may land — and stays true
#   for a plain clone, a git worktree, or a CI runner's detached checkout
#   (rendered detached@<sha>). "Worktree" survives only in the multi-checkout
#   rationale above.

set -uo pipefail

INPUT="$(cat)"

# --- fail open if the environment cannot support the check -------------------
command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0
[ -n "$INPUT" ] || exit 0

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
SESSION="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"

[ -n "$TOOL" ] || exit 0
[ -n "$SESSION" ] || exit 0

STATE_DIR="${HOME}/.claude/state/write-target"
STATE_FILE="${STATE_DIR}/${SESSION}.tsv"

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

# Absolute-ise a possibly-relative path against the session cwd.
absolutise() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s' "${CWD:-$PWD}/$1" ;;
  esac
}

# Walk up to the nearest directory that exists — a Write may create several
# levels of new directories, none of which are on disk yet.
nearest_existing_dir() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ ! -d "$d" ]; do
    d="$(dirname "$d")"
  done
  printf '%s' "$d"
}

# Resolve a location to "<checkout-root><TAB><branch>", or empty if it is not
# inside a git working tree. Linked worktrees resolve to themselves, so two
# checkouts of one repository are two distinct targets — which is the point.
resolve_target() {
  local dir="$1" top branch
  [ -n "$dir" ] || return 1
  top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 1
  [ -n "$top" ] || return 1
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    branch="detached@$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  fi
  printf '%s\t%s' "$top" "$branch"
}

already_declared() {
  [ -s "$STATE_FILE" ] || return 1
  grep -qxF "$1" "$STATE_FILE" 2>/dev/null
}

refuse() {
  # $1 = "<root>\t<branch>", $2 = what was about to happen
  local target="$1" action="$2" top branch declared
  top="${target%%$'\t'*}"
  branch="${target##*$'\t'}"

  if [ -s "$STATE_FILE" ]; then
    declared="$(sed 's/\t/ @ /' "$STATE_FILE" | paste -sd '; ' -)"
  else
    declared="(nothing declared in this session)"
  fi

  deny "BLOCKED — undeclared write target.

${action}
  target : ${top} @ ${branch}

This session's declared write targets: ${declared}

Your shell's location is not authorisation — the USER'S EXPLICIT DIRECTION is.
Two cases, decided by what was actually said (contract revised 2026-08-10):

CASE 1 — the user named this tree in the current exchange: an instruction to
write, fix, or place something here, in their words ('put it in <dir>', 'fix
the hook', 'card it there'). Declare it YOURSELF, citing those words — the
banner is the audit trail:

  bash ${BASH_SOURCE[0]%/*}/declare-write-target.sh --session ${SESSION} --cite \"<their words>\" '${top}'

CASE 2 — nothing the user said names this tree: you are here through shell
location, precedent, or inference. State ONE line and WAIT for their answer:

  <what you are doing> → target ${top} @ ${branch} — go?

Never promote inference to case 1. 'The user probably wants this here' is
case 2 by definition. Drift is never user-named — that asymmetry is what makes
this contract safe: the incident this guard exists for (work landing in the
wrong checkout because the shell happened to be there) cannot produce a
citation, because no one said it."
}

# ---------------------------------------------------------------------------
# File-mutating tools: the path is structured, so resolution is exact.
# ---------------------------------------------------------------------------
case "$TOOL" in
  Write|Edit|NotebookEdit)
    FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"
    [ -n "$FILE" ] || exit 0

    FILE="$(absolutise "$FILE")"
    case "$FILE" in */.git/*) exit 0 ;; esac

    DIR="$(nearest_existing_dir "$(dirname "$FILE")")"
    TARGET="$(resolve_target "$DIR")" || exit 0
    [ -n "$TARGET" ] || exit 0

    already_declared "$TARGET" && exit 0
    refuse "$TARGET" "About to write: ${FILE}"
    ;;

  Bash)
    RAW="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
    [ -n "$RAW" ] || exit 0

    # Strip quoted segments before matching, so a git verb quoted inside an
    # argument (a commit message, a note, a card description) is not mistaken
    # for an actual invocation.
    CMD="$(printf '%s' "$RAW" | perl -pe "s/'[^']*'//g; s/\"[^\"]*\"//g" 2>/dev/null)" || exit 0

    # Extract "<subcommand><TAB><next-token>" for every real git invocation,
    # skipping git's global flags so `git -C <path> commit` is seen as commit.
    VERBS="$(printf '%s\n' "$CMD" | perl -ne '
      while (/\bgit\b((?:\s+(?:-C\s+\S+|-c\s+\S+|--no-pager|--paginate|--git-dir=\S+|--work-tree=\S+|--exec-path=\S+))*)\s+([a-z][a-z-]*)(?:\s+(\S+))?/g) {
        printf("%s\t%s\n", $2, defined $3 ? $3 : "");
      }' 2>/dev/null)" || exit 0
    [ -n "$VERBS" ] || exit 0

    MUTATING=0
    while IFS=$'\t' read -r verb next; do
      case "$verb" in
        add|commit|push|merge|rebase|reset|revert|cherry-pick|restore|checkout|switch|am|apply|clean|rm|mv)
          MUTATING=1 ;;
        stash)
          # `stash list` / `stash show` are read-only; every other form writes.
          case "$next" in list|show) ;; *) MUTATING=1 ;; esac ;;
      esac
    done <<< "$VERBS"

    [ "$MUTATING" -eq 1 ] || exit 0

    # Locate it: an explicit `-C <path>` wins, otherwise the session cwd.
    GIT_C="$(printf '%s\n' "$CMD" | perl -ne 'print "$1\n" if /\bgit\s+-C\s+(\S+)/' 2>/dev/null | head -1)"
    LOCATION="$(absolutise "${GIT_C:-${CWD:-$PWD}}")"
    DIR="$(nearest_existing_dir "$LOCATION")"

    TARGET="$(resolve_target "$DIR")" || exit 0
    [ -n "$TARGET" ] || exit 0

    already_declared "$TARGET" && exit 0
    refuse "$TARGET" "About to run a mutating git command:
  ${RAW}"
    ;;
esac

exit 0
