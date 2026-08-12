#!/usr/bin/env bash
# Credit accounting for AC-gate self-resolutions.
#
# WHAT THIS IS. The AC gate lets the model resolve its own close gate only while
# it holds credit. The quantity is NOT "self-resolutions ever made" — it is
# "self-resolutions OUTSTANDING, not yet audited by Aaron". That is a credit
# scheme in the RFC 9113 §5.2.1 sense: capacity is granted by the receiver (the
# auditor), and only the receiver's acknowledgement returns it. Time does not
# return credit, because time cannot discharge an audit obligation.
#
# WHY IT EXISTS (2026-08-11). The gate previously counted `wc -l` over a ledger
# keyed on the Claude session_id, with no drain of any kind:
#   * `wc -l` measures |emitted|, never |emitted - audited| — there was no
#     decrement path at all. Redis names the counter half of this a leaked key
#     (INCR whose EXPIRE never runs); in concurrency terms it is a permit leak
#     (cf. spring-projects/spring-framework#35708, where a permit taken but
#     never released blocked all later work permanently).
#   * session_id has no documented lifetime. In practice it survives compaction
#     and calendar rollover, so the "per session" budget never reset — CWE-613,
#     Insufficient Session Expiration. Five approvals made on 08-10 still
#     blocked work on 08-11, hours after Aaron had audited them.
#
# WHY NOT A TIME WINDOW. A per-day key or a rolling window or a token bucket
# would all have unblocked the work — and all three make the same category
# error: they let the clock discharge an obligation only a human can discharge.
# A midnight rollover would hand the model five fresh approvals nobody reviewed,
# and a day boundary re-imports the burst problem (five at 23:59 plus five at
# 00:01). Correct algorithm, wrong invariant. Mature credit systems pair the
# acknowledgement with a backstop against wedging (pam_faillock: `faillock
# --reset` plus fail_interval; systemd: `systemctl reset-failed` plus
# StartLimitIntervalSec; TCP: window updates plus the persist timer). Here the
# backstop is deliberately NOT auto-forgiveness: it is that the denial is
# actionable — it names this script's `ack` command and lists exactly what is
# outstanding, so a wedge is always one informed command from cleared.
#
# USAGE
#   ac-audit-ledger.sh key                       -> <repo>@<branch> for cwd
#   ac-audit-ledger.sh count  <key>              -> outstanding (unaudited) count
#   ac-audit-ledger.sh list   <key>              -> the outstanding entries
#   ac-audit-ledger.sh record <key> "<fields>"   -> append one self-resolution
#   ac-audit-ledger.sh ack    <key>              -> Aaron: "I have audited these"
#
# STATE. $AC_REVIEW_STATE_DIR (tests override it) else ~/.claude/state/ac-review
#   ledger-<key>.log      append-only, one line per self-resolution,
#                         leading field an ISO-8601 UTC timestamp
#   watermark-<key>.txt   ISO-8601 UTC instant of the last audit
# Outstanding = ledger lines whose timestamp sorts strictly after the watermark.
# Fixed-width UTC timestamps make that a plain string comparison — no date math,
# so no GNU-vs-BSD `date -d` portability trap in an enforcement path.

set -uo pipefail

STATE_DIR="${AC_REVIEW_STATE_DIR:-${HOME}/.claude/state/ac-review}"
ISO_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Keep the key usable as a filename without collapsing distinct keys together.
# '/' is the only character that must go (it would create directories); '@' is
# kept because the key's readable form is <repo>@<branch>.
safe_key() { printf '%s' "$1" | tr '/' '_' | tr -c 'A-Za-z0-9._@-' '_'; }

ledger_path()   { printf '%s/ledger-%s.log'     "$STATE_DIR" "$(safe_key "$1")"; }
watermark_path() { printf '%s/watermark-%s.txt' "$STATE_DIR" "$(safe_key "$1")"; }

# The durable identity the audit is ABOUT: the checkout and the branch whose
# work is being self-approved. Deliberately not session_id — see the header.
derive_key() {
  local root branch repo
  root="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$root" ]; then
    printf 'norepo@%s' "$(basename "$PWD")"
    return 0
  fi
  repo="$(basename "$root")"
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  [ -z "$branch" ] && branch="detached"
  printf '%s@%s' "$repo" "$branch"
}

# The watermark line, verbatim, or empty if absent.
read_watermark() {
  local wm_file
  wm_file="$(watermark_path "$1")"
  [ -f "$wm_file" ] || return 0
  head -1 "$wm_file" 2>/dev/null
}

# Outstanding entries — the credit still owed. Two watermark forms are honoured:
#
#   `<iso> count=<n>`  what `ack` writes. EXACT: the first n entries are audited.
#                      A count is used rather than the instant alone because
#                      `date` gives whole seconds (BSD has no %N), so a resolve
#                      landing in the same second as the ack would otherwise be
#                      silently forgiven — free credit from a rounding edge.
#   `<iso>`            a bare instant, e.g. hand-written during an incident.
#                      Entries at or before it are audited.
#
# Anything else — truncated, corrupt, empty — is treated as "no audit has
# happened" and every entry counts. A malformed file must never buy credit.
# A line whose first field is not a timestamp counts as outstanding for the
# same reason.
outstanding() {
  local key="$1" lg wm n ts
  lg="$(ledger_path "$key")"
  [ -f "$lg" ] || return 0
  wm="$(read_watermark "$key")"

  n="$(printf '%s' "$wm" | grep -Eo 'count=[0-9]+' | head -1 | cut -d= -f2)"
  if [ -n "$n" ]; then
    awk -v n="$n" 'NF { i++; if (i > n) print }' "$lg"
    return 0
  fi

  ts="$(printf '%s' "$wm" | awk '{print $1}' | tr -d '[:space:]')"
  if printf '%s' "$ts" | grep -Eq "$ISO_RE"; then
    awk -v wm="$ts" -v iso="$ISO_RE" 'NF { if ($1 !~ iso || $1 > wm) print }' "$lg"
    return 0
  fi

  awk 'NF' "$lg"
}

CMD="${1:-}"
[ $# -gt 0 ] && shift

case "$CMD" in
  key)
    derive_key
    printf '\n'
    ;;
  count)
    [ $# -ge 1 ] || { echo "usage: ac-audit-ledger.sh count <key>" >&2; exit 2; }
    outstanding "$1" | grep -c . || true
    ;;
  list)
    [ $# -ge 1 ] || { echo "usage: ac-audit-ledger.sh list <key>" >&2; exit 2; }
    outstanding "$1"
    ;;
  record)
    [ $# -ge 1 ] || { echo "usage: ac-audit-ledger.sh record <key> [fields]" >&2; exit 2; }
    key="$1"; shift
    mkdir -p "$STATE_DIR"
    printf '%s %s\n' "$(now)" "$*" >> "$(ledger_path "$key")"
    ;;
  marker)
    # Did the project-ac-verify SKILL actually run for this card? gate22-mark-skill.sh
    # records every real invocation as "<iso> <args>" in a per-session .invoked file.
    #
    # This is EVIDENCE, NOT A GATE, and must never become one: the marker is written in
    # response to the model's own action, so proof-of-invocation is not proof-of-review
    # and no marker the model can trigger ever could be (gate22-mark-skill.sh, 2026-08-09,
    # which is why enforcement was moved off it). What it is good for is the audit: an
    # allowed self-resolution carrying no recorded invocation is an anomaly worth seeing.
    # The gate records this answer in the ledger line so the auditor reads one file
    # instead of hand-joining session-keyed markers to a repo-keyed ledger.
    [ $# -ge 1 ] || { echo "usage: ac-audit-ledger.sh marker <card>" >&2; exit 2; }
    mdir="${AC_VERIFY_MARKER_DIR:-${HOME}/.claude/state/ac-verify}"
    if [ -d "$mdir" ] && awk -v c="$1" '
          { for (i = 2; i <= NF; i++) if ($i == c) found = 1 }
          END { exit !found }
        ' "$mdir"/*.invoked 2>/dev/null; then
      printf 'yes\n'
    else
      printf 'no\n'
    fi
    ;;
  ack)
    [ $# -ge 1 ] || { echo "usage: ac-audit-ledger.sh ack <key>" >&2; exit 2; }
    mkdir -p "$STATE_DIR"
    stamp="$(now)"
    lg="$(ledger_path "$1")"
    audited=0
    [ -f "$lg" ] && audited="$(grep -c . "$lg" 2>/dev/null || echo 0)"
    printf '%s count=%s\n' "$stamp" "$audited" > "$(watermark_path "$1")"
    printf 'audited %s entries through %s for %s — credit restored\n' \
      "$audited" "$stamp" "$1"
    ;;
  *)
    cat >&2 <<'USAGE'
ac-audit-ledger.sh — credit accounting for AC-gate self-resolutions

  key                       print <repo>@<branch> for the current directory
  count  <key>              how many self-resolutions await audit
  list   <key>              show them
  record <key> "<fields>"   append one (the gate calls this)
  ack    <key>              record that they have been audited (Aaron)
  marker <card>             yes|no — did the project-ac-verify SKILL run for it?
                            (evidence recorded in the ledger, never a gate)
USAGE
    exit 2
    ;;
esac
