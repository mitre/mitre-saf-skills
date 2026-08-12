#!/usr/bin/env bash
# compare-skill-copies.sh — report divergence between the three copies of each skill.
#
# The skill collection lives in three places that drift apart:
#   installed  ${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}   what the agent actually loads
#   repo       ${SKILL_REPO_DIR:-<repo>/skills}             what is under version control
#   origin     ${SKILL_ORIGIN_REF:-origin/main}             what the public repo publishes
#
# This repository has no compiler and no linter, so "these two copies now agree" would
# otherwise be an eyeball claim. `--expect-clean <skill>` turns it into an exit code.
#
# Usage:
#   compare-skill-copies.sh                 print the matrix; always exits 0
#   compare-skill-copies.sh --expect-clean <skill>
#                                           exit 0 if installed and repo copies are
#                                           byte-identical, else exit 1 naming both paths
#
# Exit codes: 0 = the asserted condition holds (or a bare report was printed)
#             1 = NOT clean
#             2 = usage error
# Note 127 is bash's "script not found" and never comes from this script — callers that
# accept "any non-zero" cannot tell the two apart, which is how a missing control gets
# mistaken for a passing one.

set -uo pipefail

NOT_CLEAN=1
USAGE_ERROR=2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLED_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
REPO_SKILLS_DIR="${SKILL_REPO_DIR:-$SCRIPT_DIR/../skills}"
ORIGIN_REF="${SKILL_ORIGIN_REF:-origin/main}"

# The upstream column needs a git repo AND a resolvable ref. A fresh clone that has not
# fetched is a normal state, so absence degrades the report to two columns.
origin_available() {
    git -C "$SCRIPT_DIR" rev-parse --verify --quiet "$ORIGIN_REF" >/dev/null 2>&1
}

# Names of every skill present in ANY of the three locations, deduplicated and sorted.
# A skill missing from one location is exactly what the operator needs to see, so
# presence in any single location is enough to earn a row.
skill_names() {
    {
        for root in "$INSTALLED_DIR" "$REPO_SKILLS_DIR"; do
            [ -d "$root" ] || continue
            for d in "$root"/*/; do
                [ -f "$d/SKILL.md" ] && basename "$d"
            done
        done
        if origin_available; then
            git -C "$SCRIPT_DIR" ls-tree -r --name-only "$ORIGIN_REF" -- skills/ 2>/dev/null |
                sed -n 's|^skills/\([^/]*\)/SKILL\.md$|\1|p'
        fi
    } 2>/dev/null | sort -u
}

# Diff line count between two SKILL.md files; "-" when either side is absent.
delta() {
    [ -f "$1" ] && [ -f "$2" ] || { printf '%s' "-"; return; }
    diff "$1" "$2" 2>/dev/null | grep -c '^[<>]'
}

expect_clean() {
    skill="$1"
    installed="$INSTALLED_DIR/$skill/SKILL.md"
    repo="$REPO_SKILLS_DIR/$skill/SKILL.md"

    missing=""
    [ -f "$installed" ] || missing="$missing\n  absent (installed): $installed"
    [ -f "$repo" ]      || missing="$missing\n  absent (repo):      $repo"
    if [ -n "$missing" ]; then
        printf 'NOT CLEAN: %s is not present in both locations%b\n' "$skill" "$missing" >&2
        return "$NOT_CLEAN"
    fi

    if cmp -s "$installed" "$repo"; then
        printf 'clean: %s — installed and repo copies are byte-identical\n' "$skill"
        return 0
    fi

    n="$(delta "$installed" "$repo")"
    {
        printf 'NOT CLEAN: %s — the two copies differ by %s diff lines\n' "$skill" "$n"
        printf '  installed: %s\n' "$installed"
        printf '  repo:      %s\n' "$repo"
        printf '  diff with: diff %s %s\n' "$installed" "$repo"
    } >&2
    return "$NOT_CLEAN"
}

report() {
    if origin_available; then
        printf '%-30s %-10s %-8s %-8s %s\n' SKILL INSTALLED REPO ORIGIN 'INST<->REPO'
        printf '%-30s %-10s %-8s %-8s %s\n' ------ --------- ---- ------ -----------
    else
        printf '%-30s %-10s %-8s %s\n' SKILL INSTALLED REPO 'INST<->REPO'
        printf '%-30s %-10s %-8s %s\n' ------ --------- ---- -----------
        printf '(upstream ref %s is not available here — two-column report)\n\n' "$ORIGIN_REF"
    fi

    while IFS= read -r skill; do
        [ -n "$skill" ] || continue
        installed="$INSTALLED_DIR/$skill/SKILL.md"
        repo="$REPO_SKILLS_DIR/$skill/SKILL.md"
        i="-"; r="-"; o="-"
        [ -f "$installed" ] && i="yes"
        [ -f "$repo" ] && r="yes"
        if origin_available &&
           git -C "$SCRIPT_DIR" cat-file -e "$ORIGIN_REF:skills/$skill/SKILL.md" 2>/dev/null; then
            o="yes"
        fi
        d="$(delta "$installed" "$repo")"
        if origin_available; then
            printf '%-30s %-10s %-8s %-8s %s\n' "$skill" "$i" "$r" "$o" "$d"
        else
            printf '%-30s %-10s %-8s %s\n' "$skill" "$i" "$r" "$d"
        fi
    done <<EOF
$(skill_names)
EOF
}

case "${1:-}" in
    --expect-clean)
        if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
            printf 'usage: %s --expect-clean <skill>\n' "$(basename "$0")" >&2
            exit "$USAGE_ERROR"
        fi
        expect_clean "$2"
        exit $?
        ;;
    "")
        report
        exit 0
        ;;
    *)
        printf 'unknown argument: %s\n' "$1" >&2
        printf 'usage: %s [--expect-clean <skill>]\n' "$(basename "$0")" >&2
        exit "$USAGE_ERROR"
        ;;
esac
