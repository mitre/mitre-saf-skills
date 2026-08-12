#!/usr/bin/env bash
# declare-write-target.sh — record a write target for one session, unblocking
# write-target-guard.sh for that target. A write target is a (root path,
# branch) pair, rendered everywhere as:  <path> @ <branch>
#
# This is deliberately a separate, explicit act. The guard denies the first
# write into any git working tree; clearing that denial requires naming the
# target out loud, in a command whose output the user can see. A declaration
# made on the user's cited words is still visible — that visibility is the
# audit (guard contract, 2026-08-10).
#
# The session id is not guessed. It is supplied by the guard's denial message,
# so a declaration can never land in a different concurrently-running session.
#
# Usage:
#   declare-write-target.sh --session <id> [--cite "<user's words>"] <path> [<path> ...]
#   declare-write-target.sh --session <id> --list
#   declare-write-target.sh --help
#
# --cite records WHY the declaration was made — the user's own words directing
# work into this tree. Required conversationally when the model declares on the
# user's explicit direction (guard CASE 1); the citation appears in the banner
# and in the session's declaration log. Without a citation, the declaration
# must follow the user's answer to a stated ask (guard CASE 2).
#
# Formerly declare-worktree-target.sh (renamed 2026-08-10, Aaron's direction).
#
# Exit codes: 0 recorded (or already present) · 2 usage error · 3 not a git worktree

set -uo pipefail

STATE_DIR="${HOME}/.claude/state/write-target"

usage() {
  sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

SESSION=""
LIST=0
CITE=""
PATHS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --session) SESSION="${2:-}"; shift 2 || true ;;
    --session=*) SESSION="${1#*=}"; shift ;;
    --cite) CITE="${2:-}"; shift 2 || true ;;
    --cite=*) CITE="${1#*=}"; shift ;;
    --list) LIST=1; shift ;;
    -h|--help) usage 0 ;;
    -*) printf 'error: unknown option %s\n' "$1" >&2; usage 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done

if [ -z "$SESSION" ]; then
  cat >&2 <<'EOF'
error: --session is required.

Use the exact command printed in the guard's denial message — it carries the
session id. Do not invent one: a wrong id declares a target for a different
session and leaves this one still blocked.
EOF
  exit 2
fi

STATE_FILE="${STATE_DIR}/${SESSION}.tsv"
mkdir -p "$STATE_DIR"

if [ "$LIST" -eq 1 ]; then
  if [ -s "$STATE_FILE" ]; then
    printf 'Declared write targets for this session:\n'
    while IFS=$'\t' read -r top branch; do
      printf '  %s @ %s\n' "$top" "$branch"
    done < "$STATE_FILE"
  else
    printf 'No write targets declared for this session.\n'
  fi
  exit 0
fi

if [ "${#PATHS[@]}" -eq 0 ]; then
  printf 'error: no path given\n' >&2
  usage 2
fi

EXIT=0

for raw in "${PATHS[@]}"; do
  dir="$raw"
  [ -d "$dir" ] || dir="$(dirname "$dir")"

  if ! top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || [ -z "$top" ]; then
    printf 'error: not inside a git working tree: %s\n' "$raw" >&2
    EXIT=3
    continue
  fi

  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    branch="detached@$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  fi

  entry="${top}"$'\t'"${branch}"

  if grep -qxF "$entry" "$STATE_FILE" 2>/dev/null; then
    printf 'already declared: %s @ %s\n' "$top" "$branch"
    continue
  fi

  # Adding a second distinct repository to one session is legitimate, but it
  # is exactly the shape of accidental drift — so it is never silent.
  existing_repos=""
  if [ -s "$STATE_FILE" ]; then
    existing_repos="$(cut -f1 "$STATE_FILE" | grep -vxF "$top" | sort -u | paste -sd ', ' -)"
  fi

  printf '%s\n' "$entry" >> "$STATE_FILE"
  printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$top" "$branch" "${CITE:-"(no citation given)"}" >> "${STATE_DIR}/${SESSION}.log"

  printf '\n'
  printf '=== WRITE TARGET DECLARED ==========================================\n'
  printf '  target : %s @ %s\n' "$top" "$branch"
  if [ -n "$CITE" ]; then
    printf '  cited  : "%s"\n' "$CITE"
  fi
  if [ -n "$existing_repos" ]; then
    printf '  NOTE   : this session already targets %s\n' "$existing_repos"
    printf '           writes are now permitted in ALL of them.\n'
  fi
  printf '====================================================================\n'
  printf '\n'
done

exit "$EXIT"
