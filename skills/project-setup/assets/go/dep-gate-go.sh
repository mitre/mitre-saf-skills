#!/usr/bin/env bash
# dep-gate-go.sh — Go module dependency gate: resolve, evaluate, then verify.
#
# Installed in a repo as scripts/dep-gate-go.sh and reached through the
# dispatcher scripts/dep-gate.sh. Copied verbatim from the project-setup
# skill's assets/go/; do not hand-edit in the repo.
#
# Usage:
#   scripts/dep-gate-go.sh add <module>[@<version>] [...] [-C <module-dir>]
#       Run "go get" in the module directory (default: the current module, or
#       the repo root), which updates go.mod and go.sum and downloads module
#       zips but never builds or executes anything. Evaluate every module that
#       is new in go.sum. On FAIL restore go.mod and go.sum. On PASS run
#       "go mod verify".
#   scripts/dep-gate-go.sh check [<base-ref>]
#       Evaluate every module@version present in any go.sum of the workspace
#       but absent from the base ref's go.sum files. For CI.
#   scripts/dep-gate-go.sh evaluate <module@version> [...]
#       Evaluate explicit modules without touching go.mod or go.sum.
#
# Checks per new module@version:
#   AGE        proxy publish time at least DEP_GATE_MIN_AGE_DAYS days ago (3).
#   SUMDB      checksum database verification is on (GOSUMDB not off, GOFLAGS
#              without -mod=mod or -insecure, GONOSUMDB/GOINSECURE unset) and
#              the module is not excluded from it. This is Go's provenance.
#   VULNS      OSV reports no known vulnerabilities (ecosystem Go).
#   HIPCHECK   hc verdict Pass with no errored analyses, run with -t repo on the
#              module's repository: github.com paths directly, otherwise the
#              proxy's Origin URL, otherwise the go-import meta tag.
# Go has no install scripts, so there is no SCRIPTS check: a module's code
# runs only when built or tested, which the sandbox bounds.
#
# Exceptions: .dep-gate/exceptions, "<module>@<version> <CHECK> <justification>".
# Exit 1 on any FAIL, 2 on usage or tooling errors, 0 otherwise. Fails closed:
# a changed go.sum with no identified new module aborts and restores, and a
# go.sum with lines the parser cannot read aborts in every mode.
# DEP_GATE_LIST_ONLY=1 prints the new modules and stops.
# Requires bash 3.2+, git, curl, jq, go, hc. Reads .env for HC_* variables.
set -uo pipefail

REPO=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO" || exit 2
MIN_AGE_DAYS="${DEP_GATE_MIN_AGE_DAYS:-3}"
EXCEPTIONS_FILE=".dep-gate/exceptions"
PROXY="${GOPROXY_PRIMARY:-https://proxy.golang.org}"
OSV="${DEP_GATE_OSV_API:-https://api.osv.dev/v1/querybatch}"
HC_POLICY="${HC_POLICY:-.hipcheck/Hipcheck.kdl}"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/dep-gate-go.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

if [ -f .env ]; then set -a; . ./.env; set +a; fi
export HC_CONFIG="${HC_CONFIG:-$REPO/.hipcheck}" HC_CACHE="${HC_CACHE:-$REPO/.hipcheck-cache}"
export HC_VERBOSITY="${HC_VERBOSITY:-quiet}" HC_COLOR="${HC_COLOR:-never}"
if [ -z "${HC_GITHUB_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
  HC_GITHUB_TOKEN=$(gh auth token 2>/dev/null || true); export HC_GITHUB_TOKEN
fi

die() { echo "dep-gate-go: $*" >&2; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "required tool not found: $1"; }
for t in git curl jq go hc; do need "$t"; done

ANY_FAIL=0
report() { printf '%-50s %-9s %-9s %s\n' "$1" "$2" "$3" "$4"; [ "$3" = "FAIL" ] && ANY_FAIL=1; return 0; }
exception() {
  [ -f "$EXCEPTIONS_FILE" ] || return 1
  awk -v p="$1" -v c="$2" '$1 == p && $2 == c { $1=""; $2=""; sub(/^  */, ""); print; found=1 } END { exit !found }' "$EXCEPTIONS_FILE"
}
verdict() {
  local pkg="$1" check="$2" ok="$3" detail="$4" just
  if [ "$ok" -eq 0 ]; then report "$pkg" "$check" PASS "$detail"; return; fi
  if just=$(exception "$pkg" "$check"); then report "$pkg" "$check" ACCEPTED "$detail; exception: $just"; return; fi
  report "$pkg" "$check" FAIL "$detail"
}
read_lines() { NEW=(); local l; while IFS= read -r l; do [ -n "$l" ] && NEW+=("$l"); done < "$1"; }

# sum_modules <go.sum...> : module@version for entries with a full hash (not /go.mod)
sum_modules() { cat "$@" 2>/dev/null | awk 'NF == 3 && $2 !~ /\/go\.mod$/ { print $1 "@" $2 }' | sort -u; }

# assert_parser <go.sum> : every non-empty line must be "module version hash";
# anything else means the file is not what the parser expects, and a diff built
# on it would pass silently. Fail closed.
assert_parser() {
  local bad raw parsed
  bad=$(awk 'NF && !(NF == 3 && $3 ~ /^h1:/) { c++ } END { print c + 0 }' "$1")
  [ "$bad" -eq 0 ] || die "go.sum parser failure: $bad line(s) in $1 are not 'module version h1:hash'; refusing to evaluate"
  # The parser must read every full-hash line it is given; a regression that
  # reads fewer would make a diff pass silently.
  raw=$(awk 'NF == 3 && $2 !~ /\/go\.mod$/' "$1" | sort -u | grep -c .)
  parsed=$(sum_modules "$1" | grep -c .)
  [ "$raw" -eq "$parsed" ] || die "go.sum parser failure: read $parsed of $raw module lines in $1; refusing to evaluate"
}

# all_gosums : every go.sum in the workspace (root go.mod and go.work use entries)
all_gosums() {
  [ -f go.sum ] && echo go.sum
  if [ -f go.work ]; then
    sed -e 's|//.*$||' go.work | awk '/^[[:space:]]*use[[:space:]]*\(/ {b=1;next} b && /^[[:space:]]*\)/ {b=0;next} b {print $1;next} /^[[:space:]]*use[[:space:]]+/ {print $2}' \
      | sed -e 's/^"//' -e 's/"$//' -e 's|^\./||' | while read -r u; do [ -n "$u" ] && [ -f "$u/go.sum" ] && echo "$u/go.sum"; done
  fi
}

epoch_of() { local ts="${1%%.*}"; ts="${ts%Z}"; date -u -d "$ts" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%S' "$ts" +%s 2>/dev/null; }

# proxy_escape <module path> : uppercase letters become !lowercase per the proxy
# protocol. awk only: BSD sed has no \L and accepts the GNU form silently.
proxy_escape() { printf '%s' "$1" | awk '{ s=""; for (i=1;i<=length($0);i++){ c=substr($0,i,1); if (c ~ /[A-Z]/) s=s "!" tolower(c); else s=s c } printf "%s", s }'; }

# repo_url <module path> <info-json> : https URL to clone for hipcheck
repo_url() {
  local mod="$1" info="$2" u
  u=$(printf '%s' "$info" | jq -r '.Origin.URL // empty')
  if [ -z "$u" ]; then
    case "$mod" in
      github.com/*|gitlab.com/*|bitbucket.org/*) u="https://$(printf '%s' "$mod" | cut -d/ -f1-3)" ;;
      *) u=$(curl -sfL "https://$mod?go-get=1" | grep -o '<meta name="go-import" content="[^"]*"' | head -1 | sed -E 's/.*content="[^ ]+ [^ ]+ ([^"]+)".*/\1/') ;;
    esac
  fi
  u="${u%.git}"
  case "$u" in https://*) printf '%s' "$u" ;; http://*) printf 'https://%s' "${u#http://}" ;; esac
}

osv_batch() {
  local q="[]" p name ver
  for p in "$@"; do name="${p%@*}"; ver="${p##*@}"; q=$(printf '%s' "$q" | jq --arg n "$name" --arg v "$ver" '. + [{package: {name: $n, ecosystem: "Go"}, version: $v}]'); done
  printf '%s' "$q" | jq '{queries: .}' > "$WORK/osv-q.json"
  curl -sf --http1.1 -X POST "$OSV" -H 'Content-Type: application/json' --data-binary @"$WORK/osv-q.json" > "$WORK/osv.json" 2>/dev/null \
    || { echo "dep-gate-go: OSV query failed; treating as FAIL for every module" >&2; echo '{"results":null}' > "$WORK/osv.json"; }
}

sumdb_env_ok() {  # SUMDB verification active for this environment (exclusion patterns are judged per module)
  local sumdb flags insecure
  sumdb=$(go env GOSUMDB); flags=$(go env GOFLAGS); insecure=$(go env GOINSECURE)
  [ "$sumdb" != "off" ] || { echo "GOSUMDB=off"; return 1; }
  case " $flags " in *" -mod=mod "*|*" -insecure "*) echo "GOFLAGS=$flags"; return 1 ;; esac
  [ -z "$insecure" ] || { echo "GOINSECURE=$insecure"; return 1; }
  return 0
}

# excluded_from_sumdb <module> : prints "<label> pattern <p>" if a GONOSUMDB or
# GOPRIVATE pattern matches the module path (go env reports GOPRIVATE's value
# as GONOSUMDB when the latter is unset). Go matches patterns against leading
# path elements, so "example.internal" also matches "example.internal/x/y".
excluded_from_sumdb() {
  local mod="$1" nosum private label p
  nosum=$(go env GONOSUMDB); private=$(go env GOPRIVATE)
  [ -n "$nosum" ] || return 1
  if [ "$nosum" = "$private" ]; then label=GOPRIVATE; else label=GONOSUMDB; fi
  while IFS= read -r p; do   # read, not a for-loop: a pattern like * must not glob against the filesystem
    [ -n "$p" ] || continue
    # shellcheck disable=SC2053  # p is a glob pattern by design
    if [[ "$mod" == $p ]] || [[ "$mod" == $p/* ]]; then printf '%s pattern %s' "$label" "$p"; return 0; fi
  done <<EOF_PATS
$(printf '%s' "$nosum" | tr ',' '\n')
EOF_PATS
  return 1
}

hipcheck_run() {
  hc check --policy "$HC_POLICY" -t "$1" --format json "$2" > "$WORK/hc.json" 2> "$WORK/hc.err"
  if jq -e '.Error' "$WORK/hc.json" >/dev/null 2>&1 && grep -qi 'spawn attempts' "$WORK/hc.json"; then
    sleep 2; hc check --policy "$HC_POLICY" -t "$1" --format json "$2" > "$WORK/hc.json" 2> "$WORK/hc.err"
  fi
}

evaluate_one() {
  local idx="$1" pkg="$2" mod ver esc info published age_days why url
  mod="${pkg%@*}"; ver="${pkg##*@}"; esc=$(proxy_escape "$mod")
  info=$(curl -sf "$PROXY/$esc/@v/$ver.info") || { report "$pkg" PROXY FAIL "no version info at $PROXY"; return; }

  published=$(printf '%s' "$info" | jq -r '.Time // empty')
  if [ -z "$published" ]; then verdict "$pkg" AGE 1 "no publish time from the proxy"
  else
    age_days=$(( ( $(date -u +%s) - $(epoch_of "$published") ) / 86400 ))
    if [ "$age_days" -ge "$MIN_AGE_DAYS" ]; then verdict "$pkg" AGE 0 "published $age_days days ago (minimum $MIN_AGE_DAYS)"
    else verdict "$pkg" AGE 1 "published $age_days days ago, minimum is $MIN_AGE_DAYS (cooldown)"; fi
  fi

  if why=$(sumdb_env_ok); then
    if why=$(excluded_from_sumdb "$mod"); then verdict "$pkg" SUMDB 1 "module is excluded from checksum verification by $why"
    else verdict "$pkg" SUMDB 0 "checksum database verification active (GOSUMDB=$(go env GOSUMDB))"; fi
  else
    verdict "$pkg" SUMDB 1 "checksum verification disabled in this environment: $why"
  fi

  local vcount vids
  if [ "$(jq -r '.results' "$WORK/osv.json")" = "null" ]; then verdict "$pkg" VULNS 1 "OSV query failed"
  else
    vcount=$(jq -r --argjson i "$idx" '.results[$i].vulns // [] | length' "$WORK/osv.json")
    if [ "$vcount" -eq 0 ]; then verdict "$pkg" VULNS 0 "no known vulnerabilities (OSV)"
    else vids=$(jq -r --argjson i "$idx" '[.results[$i].vulns[].id] | join(",")' "$WORK/osv.json"); verdict "$pkg" VULNS 1 "$vcount known vulnerabilities: $vids"; fi
  fi

  url=$(repo_url "$mod" "$info")
  if [ -z "$url" ]; then verdict "$pkg" HIPCHECK 1 "could not resolve a repository URL for $mod"; return; fi
  hipcheck_run repo "$url"
  if jq -e '.Error' "$WORK/hc.json" >/dev/null 2>&1; then
    verdict "$pkg" HIPCHECK 1 "hc error on $url: $(jq -r '.Error.message' "$WORK/hc.json" | head -c 160)"
  elif ! jq -e '.recommendation.kind' "$WORK/hc.json" >/dev/null 2>&1; then
    verdict "$pkg" HIPCHECK 1 "hc produced no verdict for $url: $(head -c 160 "$WORK/hc.err" | tr '\n' ' ')"
  else
    local kind nerr nfail errs fails
    kind=$(jq -r '.recommendation.kind' "$WORK/hc.json"); nerr=$(jq -r '.errored | length' "$WORK/hc.json"); nfail=$(jq -r '.failing | length' "$WORK/hc.json")
    errs=$(jq -r '[.errored[].analysis] | join(",")' "$WORK/hc.json"); fails=$(jq -r '[.failing[].policy_expr] | join("; ")' "$WORK/hc.json")
    if [ "$kind" = "Pass" ] && [ "$nerr" -eq 0 ]; then verdict "$pkg" HIPCHECK 0 "Pass on $url, $nfail failing, 0 errored"
    elif [ "$kind" = "Pass" ]; then verdict "$pkg" HIPCHECK 1 "Pass on $url but $nerr errored analyses ($errs): unexamined is not cleared"
    else verdict "$pkg" HIPCHECK 1 "$kind on $url: failing [$fails]; errored [$errs]"; fi
  fi
}

evaluate_all() {
  [ $# -gt 0 ] || { echo "dep-gate-go: nothing new to evaluate"; return 0; }
  # DEP_GATE_LIST_ONLY=1 prints what would be evaluated and stops (CI debugging; tests without network).
  if [ "${DEP_GATE_LIST_ONLY:-0}" = "1" ]; then printf '%s\n' "$@"; return 0; fi
  echo "dep-gate-go: evaluating $# new module(s): $*"
  osv_batch "$@"
  local i=0 p; for p in "$@"; do evaluate_one "$i" "$p"; i=$((i + 1)); done
  if [ "$ANY_FAIL" -eq 1 ]; then echo "dep-gate-go: FAIL"; return 1; fi
  echo "dep-gate-go: PASS"; return 0
}

cmd="${1:-}"; shift || true
case "$cmd" in
  add)
    [ "${DEP_GATE_LIST_ONLY:-0}" = "1" ] && die "DEP_GATE_LIST_ONLY is not valid with add: add evaluates and then changes the module graph; use check or evaluate to list"
    MODDIR="."; ARGS=()
    while [ $# -gt 0 ]; do case "$1" in -C) MODDIR="$2"; shift 2 ;; *) ARGS+=("$1"); shift ;; esac; done
    [ ${#ARGS[@]} -gt 0 ] || die "add: name a module"
    [ -f "$MODDIR/go.mod" ] || die "no go.mod in $MODDIR (use -C <module-dir> in a workspace)"
    [ -f "$MODDIR/go.sum" ] || : > "$MODDIR/go.sum"
    cp "$MODDIR/go.mod" "$WORK/go.mod.bak"; cp "$MODDIR/go.sum" "$WORK/go.sum.bak"
    assert_parser "$MODDIR/go.sum"; sum_modules "$MODDIR/go.sum" > "$WORK/before.txt"
    ( cd "$MODDIR" && GOFLAGS="${GOFLAGS:-}" go get "${ARGS[@]}" ) || { cp "$WORK/go.mod.bak" "$MODDIR/go.mod"; cp "$WORK/go.sum.bak" "$MODDIR/go.sum"; die "go get failed for ${ARGS[*]}"; }
    assert_parser "$MODDIR/go.sum"; sum_modules "$MODDIR/go.sum" > "$WORK/after.txt"
    comm -13 "$WORK/before.txt" "$WORK/after.txt" > "$WORK/new.txt" || die "could not diff go.sum"
    read_lines "$WORK/new.txt"
    if ! cmp -s "$WORK/go.sum.bak" "$MODDIR/go.sum" && [ ${#NEW[@]} -eq 0 ]; then
      cp "$WORK/go.mod.bak" "$MODDIR/go.mod"; cp "$WORK/go.sum.bak" "$MODDIR/go.sum"
      die "go.sum changed but no new modules were identified; restored"
    fi
    if evaluate_all "${NEW[@]+"${NEW[@]}"}"; then
      ( cd "$MODDIR" && go mod verify ) || die "go mod verify failed after evaluation passed"
      echo "dep-gate-go: verified. Commit $MODDIR/go.mod and $MODDIR/go.sum."
    else
      cp "$WORK/go.mod.bak" "$MODDIR/go.mod"; cp "$WORK/go.sum.bak" "$MODDIR/go.sum"
      echo "dep-gate-go: go.mod and go.sum restored." >&2; exit 1
    fi ;;
  check)
    base="${1:-${DEP_GATE_BASE_REF:-}}"
    [ -z "$base" ] && [ -n "${GITHUB_BASE_REF:-}" ] && base="origin/$GITHUB_BASE_REF"
    [ -z "$base" ] && base=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo HEAD~1)
    : > "$WORK/before.txt"; : > "$WORK/after.txt"
    for f in $(all_gosums); do
      assert_parser "$f"
      git show "$base:$f" > "$WORK/base.sum" 2>/dev/null || : > "$WORK/base.sum"
      [ -s "$WORK/base.sum" ] && assert_parser "$WORK/base.sum"
      sum_modules "$WORK/base.sum" >> "$WORK/before.txt"
      sum_modules "$f" >> "$WORK/after.txt"
    done
    sort -u "$WORK/before.txt" -o "$WORK/before.txt"; sort -u "$WORK/after.txt" -o "$WORK/after.txt"
    comm -13 "$WORK/before.txt" "$WORK/after.txt" > "$WORK/new.txt" || die "could not diff go.sum files"
    read_lines "$WORK/new.txt"
    echo "dep-gate-go: comparing $(all_gosums | tr '\n' ' ') against $base"
    evaluate_all "${NEW[@]+"${NEW[@]}"}" ;;
  evaluate)
    [ $# -gt 0 ] || die "evaluate: name modules as path@version"
    evaluate_all "$@" ;;
  --help|-h|help) sed -n '2,/^set -uo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) sed -n '2,/^set -uo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
