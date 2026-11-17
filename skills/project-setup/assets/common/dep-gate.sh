#!/usr/bin/env bash
# dep-gate.sh — dispatcher for the per-language dependency gates.
#
# Installed in a repo as scripts/dep-gate.sh (from the project-setup skill's
# assets/common/). It picks the language gate and passes everything through.
#
# Usage:
#   scripts/dep-gate.sh [--lang javascript|go] add <package>[@version] [...]
#   scripts/dep-gate.sh [--lang javascript|go] check [<base-ref>]
#   scripts/dep-gate.sh [--lang javascript|go] evaluate <name@version> [...]
#   scripts/dep-gate.sh check-all [<base-ref>]      run check for every installed gate
#   scripts/dep-gate.sh --help                      this text (add --lang for a gate's own help)
#
# Language detection when --lang is not given: a single installed gate takes
# everything; with several, "add" and "evaluate" look at the first argument that
# is not a flag or a flag's value (-C/--dir/-F/--filter take one). A Go module
# path has a dotted host as its first segment and a slash after it
# (github.com/x/y); an npm name has no slash unless it is @scope/name, and a
# local path (./pkg) is npm. So socket.io is npm and github.com/socket/io is
# Go. "check" runs every gate.
# If the choice is still ambiguous the dispatcher says so and exits 2 rather
# than guessing.
#
# Gates: scripts/dep-gate-javascript.sh, scripts/dep-gate-go.sh. Each is copied
# verbatim from the skill's assets/<language>/ and verified byte-for-byte by
# the verifier (G-04), as is this file.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
usage() { sed -n '2,/^set -uo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }

LANG_ARG=""
if [ "${1:-}" = "--lang" ]; then LANG_ARG="${2:-}"; [ -n "$LANG_ARG" ] || { echo "dep-gate: --lang needs a value" >&2; exit 2; }; shift 2; fi
cmd="${1:-}"

installed() { local l; for l in javascript go; do [ -f "$HERE/dep-gate-$l.sh" ] && echo "$l"; done; }

case "$cmd" in
  --help|-h|help|"")
    if [ -n "$LANG_ARG" ] && [ -f "$HERE/dep-gate-$LANG_ARG.sh" ]; then exec bash "$HERE/dep-gate-$LANG_ARG.sh" --help; fi
    usage; [ -n "$cmd" ] && exit 0; exit 2 ;;
  check-all)
    shift; rc=0
    for l in $(installed); do bash "$HERE/dep-gate-$l.sh" check "$@" || rc=1; done
    exit "$rc" ;;
esac

if [ -n "$LANG_ARG" ]; then
  [ -f "$HERE/dep-gate-$LANG_ARG.sh" ] || { echo "dep-gate: no gate installed for $LANG_ARG (expected $HERE/dep-gate-$LANG_ARG.sh)" >&2; exit 2; }
  exec bash "$HERE/dep-gate-$LANG_ARG.sh" "$@"
fi

gates=$(installed)
count=$(printf '%s\n' "$gates" | grep -c .)
case "$count" in
  0) echo "dep-gate: no language gate installed under $HERE; copy the skill's assets/<language>/dep-gate-<language>.sh" >&2; exit 2 ;;
  1) exec bash "$HERE/dep-gate-$gates.sh" "$@" ;;
esac

# first_package <args...> : the first argument that is neither a flag nor a flag's value
first_package() {
  local skip=0 a
  for a in "$@"; do
    if [ "$skip" -eq 1 ]; then skip=0; continue; fi
    case "$a" in
      -C|--dir|-F|--filter|--prefix|-w|--workspace) skip=1 ;;
      -*) ;;
      *) printf '%s' "$a"; return 0 ;;
    esac
  done
  return 1
}

case "$cmd" in
  check)
    shift; rc=0
    for l in $gates; do bash "$HERE/dep-gate-$l.sh" check "$@" || rc=1; done
    exit "$rc" ;;
  add|evaluate)
    shift
    if first="$(first_package "$@")"; then
      head="${first%%/*}"
      case "$first" in
        @*|./*|../*|/*) lang=javascript ;;          # @scope/name, or a local path (pnpm link)
        */*) case "$head" in *.*) lang=go ;; *) lang=javascript ;; esac ;;   # host.tld/... is a module path
        *) lang=javascript ;;                       # no slash: an npm name, dots included
      esac
      [ -f "$HERE/dep-gate-$lang.sh" ] && exec bash "$HERE/dep-gate-$lang.sh" "$cmd" "$@"
    fi ;;
esac
echo "dep-gate: several gates are installed ($(printf '%s' "$gates" | tr '\n' ' ')); say which with --lang <language>" >&2
exit 2
