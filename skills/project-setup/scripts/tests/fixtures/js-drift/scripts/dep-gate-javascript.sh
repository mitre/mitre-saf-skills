#!/usr/bin/env bash
# dep-gate.sh — JavaScript (pnpm) dependency gate: resolve, evaluate, then install.
#
# Installed in a repo as scripts/dep-gate.sh. Copied verbatim from the
# project-setup skill's assets/javascript/; do not hand-edit in the repo.
#
# Usage:
#   scripts/dep-gate.sh add <pkg>[@<range>] [...] [pnpm add flags]
#       Resolve the addition with --lockfile-only (no download, no scripts),
#       evaluate every package that is new in the lockfile, and only on PASS
#       install with --frozen-lockfile. On FAIL the manifest and lockfile are
#       restored and nothing is installed.
#   scripts/dep-gate.sh check [<base-ref>]
#       Evaluate every package present in pnpm-lock.yaml but absent from the
#       base ref's lockfile. For CI. Base defaults to DEP_GATE_BASE_REF, then
#       origin/$GITHUB_BASE_REF, then the merge-base with origin/main.
#   scripts/dep-gate.sh evaluate <name@version> [...]
#       Evaluate explicit packages without touching the lockfile.
#
# Checks per new name@version (each prints one line: PASS, FAIL, ACCEPTED, INFO):
#   AGE        published at least DEP_GATE_MIN_AGE_DAYS days ago (default 3).
#   SCRIPTS    declares no preinstall/install/postinstall, or is listed under
#              onlyBuiltDependencies in pnpm-workspace.yaml.
#   SIGNATURE  the registry's ECDSA signature over "name@version:integrity"
#              verifies against the registry public key named by its keyid.
#   PROVENANCE a SLSA provenance attestation is present. INFO when absent,
#              FAIL when absent and DEP_GATE_REQUIRE_PROVENANCE=1.
#   VULNS      OSV reports no known vulnerabilities (querybatch).
#   HIPCHECK   hc verdict is Pass with no errored analyses. Investigate fails;
#              an errored analysis fails (an unexamined item is not cleared).
#              If the package's repository URL is ssh-only, hc is retried with
#              -t repo and the https form.
#
# Exceptions: .dep-gate/exceptions, one per line:
#   <name>@<version> <CHECK> <justification...>
# A listed check that would FAIL is reported ACCEPTED with the justification.
# Exceptions are exact-version and per-check; they are how a reviewed
# Investigate verdict is recorded without loosening the policy.
#
# Exit 1 on any FAIL, 2 on usage or tooling errors, 0 otherwise. Any error in
# the resolve or diff steps aborts before installing: the gate fails closed.
# Requires bash, git, curl, jq, openssl, pnpm (10.16+ for minimumReleaseAge),
# and hc. Reads .env for HC_* variables. HC_GITHUB_TOKEN falls back to
# `gh auth token` when gh is available.
set -uo pipefail

REPO=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO" || exit 2
LOCK="pnpm-lock.yaml"
MIN_AGE_DAYS="${DEP_GATE_MIN_AGE_DAYS:-3}"
REQUIRE_PROVENANCE="${DEP_GATE_REQUIRE_PROVENANCE:-0}"
EXCEPTIONS_FILE=".dep-gate/exceptions"
REGISTRY="${DEP_GATE_REGISTRY:-https://registry.npmjs.org}"
OSV="${DEP_GATE_OSV_API:-https://api.osv.dev/v1/querybatch}"
HC_POLICY="${HC_POLICY:-.hipcheck/Hipcheck.kdl}"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/dep-gate.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

if [ -f .env ]; then set -a; . ./.env; set +a; fi
# .env is gitignored, so CI has none: default to the in-repo locations.
export HC_CONFIG="${HC_CONFIG:-$REPO/.hipcheck}" HC_CACHE="${HC_CACHE:-$REPO/.hipcheck-cache}"
export HC_VERBOSITY="${HC_VERBOSITY:-quiet}" HC_COLOR="${HC_COLOR:-never}"
if [ -z "${HC_GITHUB_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
  HC_GITHUB_TOKEN=$(gh auth token 2>/dev/null || true); export HC_GITHUB_TOKEN
fi

die() { echo "dep-gate: $*" >&2; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "required tool not found: $1"; }
for t in git curl jq openssl pnpm hc; do need "$t"; done

ANY_FAIL=0
report() {  # report <name@version> <CHECK> <STATUS> <detail>
  printf '%-40s %-11s %-9s %s\n' "$1" "$2" "$3" "$4"
  [ "$3" = "FAIL" ] && ANY_FAIL=1
  return 0
}

# exception <name@version> <CHECK> : prints justification if listed
exception() {
  [ -f "$EXCEPTIONS_FILE" ] || return 1
  awk -v p="$1" -v c="$2" '$1 == p && $2 == c { $1=""; $2=""; sub(/^  */, ""); print; found=1 } END { exit !found }' "$EXCEPTIONS_FILE"
}

# verdict <pkg> <CHECK> <ok:0|1> <detail> : PASS, or FAIL unless excepted
verdict() {
  local pkg="$1" check="$2" ok="$3" detail="$4" just
  if [ "$ok" -eq 0 ]; then report "$pkg" "$check" PASS "$detail"; return; fi
  if just=$(exception "$pkg" "$check"); then report "$pkg" "$check" ACCEPTED "$detail; exception: $just"; return; fi
  report "$pkg" "$check" FAIL "$detail"
}

# read_lines <file> : fill the NEW array from a file, one entry per line.
# (bash 3.2 on macOS has no mapfile.)
read_lines() {
  NEW=()
  local l
  while IFS= read -r l; do [ -n "$l" ] && NEW+=("$l"); done < "$1"
}

# lock_packages <lockfile> : name@version per line from the packages: section
lock_packages() {
  awk '/^packages:/ { p = 1; next } /^[^ ]/ { p = 0 } p && /^  [^ ].*:$/ { sub(/^  /, ""); sub(/:$/, ""); gsub(/^'"'"'|'"'"'$/, ""); print }' "$1" | sort -u
}

url_encode_name() { printf '%s' "$1" | sed 's|/|%2F|g'; }

# epoch_of <iso8601> : seconds since epoch, GNU or BSD date
epoch_of() {
  local ts="${1%%.*}"; ts="${ts%Z}"
  date -u -d "$ts" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%S' "$ts" +%s 2>/dev/null
}

# https_repo <repository url> : https form, or empty
https_repo() {
  local u="$1"
  u="${u#git+}"; u="${u%.git}"
  case "$u" in
    ssh://git@*) u="https://${u#ssh://git@}" ;;
    git@*:*) u="https://${u#git@}"; u="${u/:/\/}" ;;
    git://*) u="https://${u#git://}" ;;
    http://*) u="https://${u#http://}" ;;
  esac
  case "$u" in https://*) printf '%s' "$u" ;; esac
}

REGISTRY_KEYS=""
registry_keys() {
  [ -n "$REGISTRY_KEYS" ] || REGISTRY_KEYS=$(curl -sf "$REGISTRY/-/npm/v1/keys") || die "could not fetch registry signing keys"
  printf '%s' "$REGISTRY_KEYS"
}

# allowed_build <name> : listed under onlyBuiltDependencies in pnpm-workspace.yaml
allowed_build() {
  [ -f pnpm-workspace.yaml ] || return 1
  awk -v n="$1" '
    /^onlyBuiltDependencies:/ { inlist = 1; next }
    inlist && /^[^[:space:]-]/ { inlist = 0 }
    inlist && /^[[:space:]]*-[[:space:]]*/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); gsub(/^["'"'"']|["'"'"']$/, ""); if ($0 == n) found = 1 }
    END { exit !found }' pnpm-workspace.yaml
}

# osv_batch <name@version...> : writes $WORK/osv.json with results in order
osv_batch() {
  local q="[]" p name ver
  for p in "$@"; do
    name="${p%@*}"; ver="${p##*@}"
    q=$(printf '%s' "$q" | jq --arg n "$name" --arg v "$ver" '. + [{package: {name: $n, ecosystem: "npm"}, version: $v}]')
  done
  printf '%s' "$q" | jq '{queries: .}' > "$WORK/osv-q.json"
  curl -sf --http1.1 -X POST "$OSV" -H 'Content-Type: application/json' --data-binary @"$WORK/osv-q.json" > "$WORK/osv.json" 2>/dev/null \
    || { echo "dep-gate: OSV query failed; treating as FAIL for every package" >&2; echo '{"results":null}' > "$WORK/osv.json"; }
}

hipcheck_run() {  # hipcheck_run <target-type> <target> -> writes $WORK/hc.json
  hc check --policy "$HC_POLICY" -t "$1" --format json "$2" > "$WORK/hc.json" 2> "$WORK/hc.err"
  # Plugin start-up can fail on a cold machine; one retry clears it.
  if jq -e '.Error' "$WORK/hc.json" >/dev/null 2>&1 && grep -qi 'spawn attempts' "$WORK/hc.json"; then
    sleep 2
    hc check --policy "$HC_POLICY" -t "$1" --format json "$2" > "$WORK/hc.json" 2> "$WORK/hc.err"
  fi
}

evaluate_one() {  # evaluate_one <index> <name@version>
  local idx="$1" pkg="$2" name ver enc vdoc pdoc published age_days has_scripts keyid sig integ key just repo_url
  name="${pkg%@*}"; ver="${pkg##*@}"; enc=$(url_encode_name "$name")

  vdoc=$(curl -sf "$REGISTRY/$enc/$ver") || { report "$pkg" REGISTRY FAIL "version document not found at $REGISTRY"; return; }
  pdoc=$(curl -sf "$REGISTRY/$enc") || { report "$pkg" REGISTRY FAIL "package document not found at $REGISTRY"; return; }

  # AGE
  published=$(printf '%s' "$pdoc" | jq -r --arg v "$ver" '.time[$v] // empty')
  if [ -z "$published" ]; then
    verdict "$pkg" AGE 1 "no publish time in registry metadata"
  else
    age_days=$(( ( $(date -u +%s) - $(epoch_of "$published") ) / 86400 ))
    if [ "$age_days" -ge "$MIN_AGE_DAYS" ]; then verdict "$pkg" AGE 0 "published $age_days days ago (minimum $MIN_AGE_DAYS)"
    else verdict "$pkg" AGE 1 "published $age_days days ago, minimum is $MIN_AGE_DAYS (cooldown)"; fi
  fi

  # SCRIPTS
  has_scripts=$(printf '%s' "$vdoc" | jq -r '(.scripts // {}) | [has("preinstall"), has("install"), has("postinstall")] | any')
  if [ "$has_scripts" = "true" ]; then
    if allowed_build "$name"; then verdict "$pkg" SCRIPTS 0 "declares install scripts; listed in onlyBuiltDependencies"
    else verdict "$pkg" SCRIPTS 1 "declares install scripts and is not in onlyBuiltDependencies"; fi
  else
    verdict "$pkg" SCRIPTS 0 "no install scripts"
  fi

  # SIGNATURE
  integ=$(printf '%s' "$vdoc" | jq -r '.dist.integrity // empty')
  keyid=$(printf '%s' "$vdoc" | jq -r '.dist.signatures[0].keyid // empty')
  sig=$(printf '%s' "$vdoc" | jq -r '.dist.signatures[0].sig // empty')
  if [ -z "$integ" ] || [ -z "$keyid" ] || [ -z "$sig" ]; then
    verdict "$pkg" SIGNATURE 1 "no registry signature or integrity in metadata"
  else
    key=$(registry_keys | jq -r --arg k "$keyid" '.keys[] | select(.keyid == $k) | .key' | head -1)
    if [ -z "$key" ]; then
      verdict "$pkg" SIGNATURE 1 "signature keyid $keyid is not a published registry key"
    else
      { echo "-----BEGIN PUBLIC KEY-----"; printf '%s\n' "$key" | fold -w 64; echo "-----END PUBLIC KEY-----"; } > "$WORK/key.pem"
      printf '%s' "$sig" | base64 -d > "$WORK/sig.der" 2>/dev/null
      printf '%s' "$pkg:$integ" > "$WORK/msg.txt"
      if openssl dgst -sha256 -verify "$WORK/key.pem" -signature "$WORK/sig.der" "$WORK/msg.txt" >/dev/null 2>&1; then
        verdict "$pkg" SIGNATURE 0 "registry signature verifies (key $keyid)"
      else
        verdict "$pkg" SIGNATURE 1 "registry signature does NOT verify against key $keyid"
      fi
    fi
  fi

  # PROVENANCE
  if [ "$(printf '%s' "$vdoc" | jq -r '.dist.attestations.provenance.predicateType // empty')" != "" ]; then
    verdict "$pkg" PROVENANCE 0 "SLSA provenance attestation present"
  elif [ "$REQUIRE_PROVENANCE" = "1" ]; then
    verdict "$pkg" PROVENANCE 1 "no provenance attestation (required by DEP_GATE_REQUIRE_PROVENANCE=1)"
  else
    report "$pkg" PROVENANCE INFO "no provenance attestation; registry signature only"
  fi

  # VULNS (from the batch query)
  local vcount vids
  if [ "$(jq -r '.results' "$WORK/osv.json")" = "null" ]; then
    verdict "$pkg" VULNS 1 "OSV query failed"
  else
    vcount=$(jq -r --argjson i "$idx" '.results[$i].vulns // [] | length' "$WORK/osv.json")
    if [ "$vcount" -eq 0 ]; then verdict "$pkg" VULNS 0 "no known vulnerabilities (OSV)"
    else vids=$(jq -r --argjson i "$idx" '[.results[$i].vulns[].id] | join(",")' "$WORK/osv.json"); verdict "$pkg" VULNS 1 "$vcount known vulnerabilities: $vids"; fi
  fi

  # HIPCHECK
  hipcheck_run npm "$pkg"
  if jq -e '.Error' "$WORK/hc.json" >/dev/null 2>&1 && grep -qi 'ssh' "$WORK/hc.json"; then
    repo_url=$(https_repo "$(printf '%s' "$vdoc" | jq -r '.repository.url // .repository // empty')")
    if [ -n "$repo_url" ]; then hipcheck_run repo "$repo_url"; fi
  fi
  if jq -e '.Error' "$WORK/hc.json" >/dev/null 2>&1; then
    verdict "$pkg" HIPCHECK 1 "hc error: $(jq -r '.Error.message' "$WORK/hc.json" | head -c 160)"
  elif ! jq -e '.recommendation.kind' "$WORK/hc.json" >/dev/null 2>&1; then
    verdict "$pkg" HIPCHECK 1 "hc produced no verdict: $(head -c 160 "$WORK/hc.err" | tr '\n' ' ')"
  else
    local kind nerr nfail errs fails
    kind=$(jq -r '.recommendation.kind' "$WORK/hc.json")
    nerr=$(jq -r '.errored | length' "$WORK/hc.json"); nfail=$(jq -r '.failing | length' "$WORK/hc.json")
    errs=$(jq -r '[.errored[].analysis] | join(",")' "$WORK/hc.json"); fails=$(jq -r '[.failing[].policy_expr] | join("; ")' "$WORK/hc.json")
    if [ "$kind" = "Pass" ] && [ "$nerr" -eq 0 ]; then
      verdict "$pkg" HIPCHECK 0 "Pass, $nfail failing, 0 errored"
    elif [ "$kind" = "Pass" ]; then
      verdict "$pkg" HIPCHECK 1 "Pass but $nerr errored analyses ($errs): unexamined is not cleared"
    else
      verdict "$pkg" HIPCHECK 1 "$kind: failing [$fails]; errored [$errs]"
    fi
  fi
}

evaluate_all() {  # evaluate_all <name@version...>
  [ $# -gt 0 ] || { echo "dep-gate: nothing new to evaluate"; return 0; }
  echo "dep-gate: evaluating $# new package(s): $*"
  osv_batch "$@"
  local i=0 p
  for p in "$@"; do evaluate_one "$i" "$p"; i=$((i + 1)); done
  if [ "$ANY_FAIL" -eq 1 ]; then echo "dep-gate: FAIL"; return 1; fi
  echo "dep-gate: PASS"; return 0
}

cmd="${1:-}"; shift || true
case "$cmd" in
  add)
    [ $# -gt 0 ] || die "add: name a package"
    [ -f "$LOCK" ] || die "no $LOCK; run pnpm install --lockfile-only first and commit it"
    cp package.json "$WORK/package.json.bak"; cp "$LOCK" "$WORK/lock.bak"
    lock_packages "$LOCK" > "$WORK/before.txt"
    pnpm add --lockfile-only "$@" || { cp "$WORK/package.json.bak" package.json; cp "$WORK/lock.bak" "$LOCK"; die "pnpm could not resolve $*"; }
    lock_packages "$LOCK" > "$WORK/after.txt"
    comm -13 "$WORK/before.txt" "$WORK/after.txt" > "$WORK/new.txt" || die "could not diff lockfiles"
    read_lines "$WORK/new.txt"
    # Fail closed: a changed lockfile with no identified new packages means the
    # diff did not work, and nothing may be installed on the strength of it.
    if ! cmp -s "$WORK/lock.bak" "$LOCK" && [ ${#NEW[@]} -eq 0 ]; then
      cp "$WORK/package.json.bak" package.json; cp "$WORK/lock.bak" "$LOCK"
      die "lockfile changed but no new packages were identified; restored, nothing installed"
    fi
    if evaluate_all "${NEW[@]+"${NEW[@]}"}"; then
      pnpm install --frozen-lockfile || die "install failed after evaluation passed"
      echo "dep-gate: installed. Commit package.json and $LOCK."
    else
      cp "$WORK/package.json.bak" package.json; cp "$WORK/lock.bak" "$LOCK"
      echo "dep-gate: manifest and lockfile restored; nothing installed." >&2
      exit 1
    fi ;;
  check)
    base="${1:-${DEP_GATE_BASE_REF:-}}"
    if [ -z "$base" ] && [ -n "${GITHUB_BASE_REF:-}" ]; then base="origin/$GITHUB_BASE_REF"; fi
    if [ -z "$base" ]; then base=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null || echo HEAD~1); fi
    git show "$base:$LOCK" > "$WORK/base-lock.yaml" 2>/dev/null || : > "$WORK/base-lock.yaml"
    lock_packages "$WORK/base-lock.yaml" > "$WORK/before.txt"; lock_packages "$LOCK" > "$WORK/after.txt"
    comm -13 "$WORK/before.txt" "$WORK/after.txt" > "$WORK/new.txt" || die "could not diff lockfiles"
    read_lines "$WORK/new.txt"
    echo "dep-gate: comparing $LOCK against $base"
    evaluate_all "${NEW[@]+"${NEW[@]}"}" ;;
  evaluate)
    [ $# -gt 0 ] || die "evaluate: name packages as name@version"
    evaluate_all "$@" ;;
  --help|-h|help)
    sed -n '2,47p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)
    sed -n '2,47p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
# local edit: this line makes the copy drift from the template
