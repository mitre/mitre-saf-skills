#!/usr/bin/env bash
# Keep chezmoi's copy of ~/.claude current, and say when it needs committing.
#
# WHY THIS EXISTS (2026-08-12). ~/.claude config and per-project agent memory are
# versioned with chezmoi so they survive a lost machine and sync across several
# working machines. Config is edited by a human occasionally; MEMORY IS WRITTEN BY
# THE AGENT, constantly — 346 files that change most sessions. A copy-based scheme
# with no automation therefore rots by default: the repo silently falls behind the
# thing it is supposed to protect. That is not hypothetical. On 2026-08-12 an
# installed hook went stale within minutes of its source being edited, and a stale
# copy of a different hook was found still carrying behavior removed months earlier.
#
# WHAT IT DOES, AND DELIBERATELY DOES NOT DO
#   --capture   bring chezmoi's SOURCE up to date with the live files:
#               `chezmoi re-add` for managed files that changed, `chezmoi add` for
#               memory files that did not exist yet. Source only. No git.
#   --report    say whether the dotfiles repo has uncommitted or unpushed work.
#   (no args)   capture, then report. This is what the hooks call.
#
# It NEVER commits and NEVER pushes. Committing agent-written memory automatically,
# on three machines that each append to the same files, manufactures conflicts
# nobody authored — and a commit is the owner's decision, like a push. Capture is
# the part that must be automatic, because losing memory is the failure that cannot
# be undone; committing can always happen later from a clean source.
#
# It NEVER blocks a session. Every failure path exits 0. A sync helper that can
# stop work is worse than one that occasionally misses a file.

set -uo pipefail

CHEZMOI="$(command -v chezmoi 2>/dev/null || true)"
[ -z "$CHEZMOI" ] && exit 0          # not this machine's setup — silently fine

SOURCE_DIR="$("$CHEZMOI" source-path 2>/dev/null || true)"
[ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ] && exit 0

MEMORY_GLOB="${HOME}/.claude/projects"

capture() {
  # Managed files whose live copy changed. re-add touches only what chezmoi
  # already knows, so it cannot pull in anything the ignore rules exclude.
  "$CHEZMOI" re-add >/dev/null 2>&1 || true

  # New memory files. re-add ignores unknown paths, so a brand-new project's
  # memory would never be captured without this. The ignore rules still apply,
  # which is what keeps transcripts and the stray .jsonl out.
  [ -d "$MEMORY_GLOB" ] || return 0
  for mem in "$MEMORY_GLOB"/*/memory; do
    [ -d "$mem" ] || continue          # skips slugs without memory
    [ -L "$mem" ] && continue          # symlinked memory dirs are stored as links
    "$CHEZMOI" add "$mem" >/dev/null 2>&1 || true
  done
}

report() {
  git -C "$SOURCE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local dirty ahead
  dirty="$(git -C "$SOURCE_DIR" status --porcelain 2>/dev/null | grep -c . || true)"
  ahead="$(git -C "$SOURCE_DIR" rev-list --count @{u}..HEAD 2>/dev/null || echo 0)"

  [ "${dirty:-0}" -eq 0 ] && [ "${ahead:-0}" -eq 0 ] && return 0

  echo "📎 dotfiles (~/.claude config + agent memory):"
  [ "${dirty:-0}" -gt 0 ] && \
    echo "   ${dirty} file(s) captured but not committed — chezmoi git add . && chezmoi git commit"
  [ "${ahead:-0}" -gt 0 ] && \
    echo "   ${ahead} commit(s) not pushed — the other machines cannot see them yet"
}

case "${1:-}" in
  --capture) capture ;;
  --report)  report ;;
  *)         capture; report ;;
esac

exit 0
