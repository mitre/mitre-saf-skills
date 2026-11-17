#!/usr/bin/env bash
# dep-gate.sh — dispatcher for the per-language dependency gates.
#
# Installed in a repo as scripts/dep-gate.sh (from the project-setup skill's
# assets/common/). It picks the language gate and passes everything through:
#
#   scripts/dep-gate.sh [--lang javascript|go] add <package>[@version] [...]
#   scripts/dep-gate.sh [--lang javascript|go] check [<base-ref>]
#   scripts/dep-gate.sh [--lang javascript|go] evaluate <name@version> [...]
#   scripts/dep-gate.sh check-all [<base-ref>]      run check for every installed gate
#
# Language detection when --lang is not given: a single installed gate is
# used; with several, "add" and "evaluate" look at the first package argument
# (a Go module path has a dotted host as its first segment, like
# github.com/x/y; an npm name does not), and "check" runs every gate. If the
# choice is ambiguous the dispatcher says so and exits 2 rather than guessing.
#
# Gates: scripts/dep-gate-javascript.sh, scripts/dep-gate-go.sh. Each is copied
# verbatim from the skill's assets/<language>/ and verified byte-for-byte by
# the verifier (G-04).
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
LANG_ARG=""
if [ "${1:-}" = "--lang" ]; then LANG_ARG="${2:-}"; shift 2 || { echo "dep-gate: --lang needs a value" >&2; exit 2; }; fi
cmd="${1:-}"

installed() { local l; for l in javascript go; do [ -f "$HERE/dep-gate-$l.sh" ] && echo "$l"; done; }

if [ "$cmd" = "check-all" ]; then
  shift; rc=0
  for l in $(installed); do bash "$HERE/dep-gate-$l.sh" check "$@" || rc=1; done
  exit "$rc"
fi

if [ -n "$LANG_ARG" ]; then
  [ -f "$HERE/dep-gate-$LANG_ARG.sh" ] || { echo "dep-gate: no gate installed for $LANG_ARG (expected $HERE/dep-gate-$LANG_ARG.sh)" >&2; exit 2; }
  exec bash "$HERE/dep-gate-$LANG_ARG.sh" "$@"
fi

set -- "$@"
gates=$(installed)
count=$(printf '%s\n' "$gates" | grep -c .)
case "$count" in
  0) echo "dep-gate: no language gate installed under $HERE; copy the skill's assets/<language>/dep-gate-<language>.sh" >&2; exit 2 ;;
  1) exec bash "$HERE/dep-gate-$gates.sh" "$@" ;;
esac

case "$cmd" in
  check)
    shift; rc=0
    for l in $gates; do bash "$HERE/dep-gate-$l.sh" check "$@" || rc=1; done
    exit "$rc" ;;
  add|evaluate)
    first="${2:-}"
    case "$first" in
      -*|"") ;;
      *)
        head="${first%%/*}"
        case "$head" in
          *.*) lang=go ;;                 # github.com/..., golang.org/..., example.com/...
          *) lang=javascript ;;           # left-pad, @scope/name
        esac
        [ -f "$HERE/dep-gate-$lang.sh" ] && exec bash "$HERE/dep-gate-$lang.sh" "$@" ;;
    esac ;;
esac
echo "dep-gate: several gates are installed ($(printf '%s' "$gates" | tr '\n' ' ')); say which with --lang <language>" >&2
exit 2
# local edit
