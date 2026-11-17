#!/usr/bin/env bash
# verify-setup.sh — check a repository against the project-setup checklist.
#
# Prints one line per checklist ID (one per ID per detected language for the
# language-specific IDs):
#   <ID> <PASS|FAIL|SKIP> <reason>
# Exit code is 1 if any line is FAIL, 0 otherwise. SKIP never fails.
#
# Workspaces: a repo is one or more units per language. JavaScript units are
# the root package.json plus every package listed by pnpm-workspace.yaml; Go
# units are the root go.mod (if any) plus every module in go.work. Language
# checks run per unit and tag the line [language:path]; root-scoped lines are
# tagged [language]. --list-units prints the units so the enumeration can be
# inspected and tested on its own.
#
# Requires only bash, coreutils, git, and grep. Language checks are added by
# defining functions named check_<language>_<id-with-no-dash>, for example
# check_javascript_G01. Dispatch contract:
#   check_<lang>_<ID>       runs once per unit; $1 is the unit path relative
#                           to the repo ("." for the root) and CUR_TAG is the
#                           tag to pass to result(): "<lang>" for the root,
#                           "<lang>:<path>" otherwise.
#   check_<lang>_<ID>_root  runs once per repo with $1="." and CUR_TAG="<lang>";
#                           use it for items judged at the workspace root such
#                           as the lockfile or the package manager config.
# If both exist the _root form wins. VERIFY_SETUP_CHECKS_FILE names an extra
# file of check functions to source; the test suite uses it to prove the
# contract, and a repo can use it for local checks. An ID with no function for a detected language is a
# FAIL: the item was not checked, so it cannot be reported as satisfied, and
# the exit code must say so until the check exists. SKIP is used only when no
# language was detected at all. An ID that genuinely does not apply to a
# toolchain is a PASS with a reason inside that language's check function.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SKILL_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

usage() {
  cat <<USAGE
Usage: verify-setup.sh [--json | --list-units] [REPO]

Check REPO (default: current directory) against the project-setup checklist
G-01 through G-11 defined in $SKILL_ROOT/SKILL.md.

Options:
  --json         Emit a JSON array of {id, language, path, status, reason}
  --list-units   Print "<language> <path>" for every unit (root package.json,
                 pnpm workspace packages, root go.mod, go.work modules) and exit
  --help         Show this help

Output: one line per ID in text mode: "<ID> <PASS|FAIL|SKIP> <reason>".
Language-specific IDs print one line per detected language, or one per unit
tagged [language:path] when a check is unit-scoped.
Detection: package.json or pnpm-workspace.yaml -> javascript; go.mod or go.work
-> go. A go.work module without go.mod is a G-02 FAIL naming the path.
Exit code: 1 if any FAIL, 0 otherwise.
SKIP appears only when no language is detected and never fails. A detected
language with no check for an ID is a FAIL, not a SKIP.
Missing tools are reported as FAIL, never PASS.
USAGE
}

JSON=0
LIST_UNITS=0
REPO="."
while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --list-units) LIST_UNITS=1 ;;
    --help|-h) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) REPO="$1" ;;
  esac
  shift
done

if [ ! -d "$REPO" ]; then
  echo "not a directory: $REPO" >&2
  exit 2
fi
REPO=$(cd "$REPO" && pwd)

# ---------------------------------------------------------------------------
# Result collection
# ---------------------------------------------------------------------------
RESULT_IDS=()
RESULT_LANGS=()
RESULT_STATUSES=()
RESULT_REASONS=()
ANY_FAIL=0

# result <id> <language-or-"-"> <PASS|FAIL|SKIP> <reason>
result() {
  RESULT_IDS+=("$1")
  RESULT_LANGS+=("$2")
  RESULT_STATUSES+=("$3")
  RESULT_REASONS+=("$4")
  [ "$3" = "FAIL" ] && ANY_FAIL=1
  return 0
}

# ---------------------------------------------------------------------------
# Language detection (keep in sync with the table in SKILL.md Step 1)
# ---------------------------------------------------------------------------
LANGUAGES=()
{ [ -f "$REPO/package.json" ] || [ -f "$REPO/pnpm-workspace.yaml" ]; } && LANGUAGES+=("javascript")
{ [ -f "$REPO/go.mod" ] || [ -f "$REPO/go.work" ]; } && LANGUAGES+=("go")
{ [ -f "$REPO/pyproject.toml" ] || [ -f "$REPO/requirements.txt" ]; } && LANGUAGES+=("python")
[ -f "$REPO/Gemfile" ] && LANGUAGES+=("ruby")
[ -f "$REPO/Cargo.toml" ] && LANGUAGES+=("rust")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
# env_value <KEY> : value of KEY from <repo>/.env, empty if unset
env_value() {
  [ -f "$REPO/.env" ] || return 0
  grep -E "^[[:space:]]*$1=" "$REPO/.env" | tail -1 | sed -e "s/^[[:space:]]*$1=//" -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

# path_in_repo <path> : true if path (relative or absolute) resolves inside REPO
path_in_repo() {
  local p="$1"
  case "$p" in
    "") return 1 ;;
    /*) case "$p" in "$REPO"/*) return 0 ;; *) return 1 ;; esac ;;
    "~"*|'$HOME'*) return 1 ;;
    ..*) return 1 ;;
    *) case "$p" in */..*) return 1 ;; *) return 0 ;; esac ;;
  esac
}

gitignore_has() {
  [ -f "$REPO/.gitignore" ] || return 1
  grep -qxE "[[:space:]]*/?$1/?[[:space:]]*" "$REPO/.gitignore"
}

# normalize_rel <path> : strip leading ./ and trailing /, "." for root
normalize_rel() {
  local p="$1"
  p="${p#./}"; p="${p%/}"
  [ -z "$p" ] && p="."
  printf '%s' "$p"
}

# ---------------------------------------------------------------------------
# Unit enumeration. Each units_<language> function prints one unit path per
# line, relative to REPO. Files are parsed directly; no package manager or
# language toolchain is invoked.
# ---------------------------------------------------------------------------

# go.work "use" entries: both the block form and single-line form, comments
# stripped, quotes removed. A listed module is a unit even if its go.mod is
# missing; the integrity check reports that separately.
go_work_uses() {
  [ -f "$REPO/go.work" ] || return 0
  sed -e 's|//.*$||' "$REPO/go.work" | awk '
    /^[[:space:]]*use[[:space:]]*\(/ { inblock = 1; next }
    inblock && /^[[:space:]]*\)/ { inblock = 0; next }
    inblock { print $1; next }
    /^[[:space:]]*use[[:space:]]+/ { print $2 }
  ' | sed -e 's/^"//' -e 's/"$//' | while read -r u; do
    [ -n "$u" ] && normalize_rel "$u" && printf '\n'
  done
}

units_go() {
  [ -f "$REPO/go.mod" ] && echo "."
  go_work_uses
}

# pnpm-workspace.yaml "packages" list. Entries are globs relative to the root;
# entries starting with ! exclude. A directory is a package only if it holds a
# package.json, which is how pnpm itself decides.
pnpm_workspace_patterns() {
  [ -f "$REPO/pnpm-workspace.yaml" ] || return 0
  # flow style on one line: packages: ["a/*", "b"]
  if grep -qE '^packages:[[:space:]]*\[' "$REPO/pnpm-workspace.yaml"; then
    grep -E '^packages:[[:space:]]*\[' "$REPO/pnpm-workspace.yaml" | head -1 \
      | sed -e 's/^packages:[[:space:]]*\[//' -e 's/\][[:space:]]*\(#.*\)\{0,1\}$//' \
      | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e "s/^[\"']//" -e "s/[\"']\$//" \
      | awk 'length'
    return 0
  fi
  awk '
    /^packages:[[:space:]]*$/ { inlist = 1; next }
    inlist && /^[^[:space:]-]/ { inlist = 0 }
    inlist && /^[[:space:]]*-[[:space:]]*/ {
      sub(/^[[:space:]]*-[[:space:]]*/, ""); sub(/[[:space:]]*(#.*)?$/, "")
      gsub(/^["'"'"']|["'"'"']$/, ""); if (length($0)) print
    }
  ' "$REPO/pnpm-workspace.yaml"
}

units_javascript() {
  [ -f "$REPO/package.json" ] && echo "."
  [ -f "$REPO/pnpm-workspace.yaml" ] || return 0
  local pat includes=() excludes=() d rel ex skip
  while IFS= read -r pat; do
    case "$pat" in
      '!'*) excludes+=("${pat#!}") ;;
      *) includes+=("$pat") ;;
    esac
  done < <(pnpm_workspace_patterns)
  for pat in "${includes[@]+"${includes[@]}"}"; do
    pat=$(normalize_rel "$pat")
    if [ "$pat" = "." ]; then continue; fi
    case "$pat" in
      *'**'*)
        # recursive glob: every package.json below the fixed prefix
        local prefix="${pat%%\*\**}"; prefix="${prefix%/}"
        [ -d "$REPO/$prefix" ] || continue
        while IFS= read -r d; do
          echo "$(normalize_rel "${d#"$REPO/"}")"
        done < <(find "$REPO/$prefix" -name package.json -not -path '*/node_modules/*' -exec dirname {} \; | sort)
        ;;
      *)
        ( shopt -s nullglob; cd "$REPO" && for d in $pat; do [ -f "$d/package.json" ] && echo "$(normalize_rel "$d")"; done )
        ;;
    esac
  done | sort -u | while IFS= read -r rel; do
    skip=0
    for ex in "${excludes[@]+"${excludes[@]}"}"; do
      ex=$(normalize_rel "$ex")
      # shellcheck disable=SC2053  # ex is a glob pattern by design
      [[ "$rel" == $ex ]] && skip=1
    done
    [ "$skip" -eq 0 ] && echo "$rel"
  done
}

# units_for <language> : deduplicated unit paths, root first if present
units_for() { "units_$1" | awk 'NF && !seen[$0]++'; }

# list_units : "<language> <path>" per unit for every detected language
list_units() {
  local lang u
  for lang in "${LANGUAGES[@]+"${LANGUAGES[@]}"}"; do
    while IFS= read -r u; do printf '%s %s\n' "$lang" "$u"; done < <(units_for "$lang")
  done
}

if [ "$LIST_UNITS" -eq 1 ]; then
  list_units
  exit 0
fi

# ---------------------------------------------------------------------------
# Workspace integrity: a declared unit whose manifest is missing is reported
# under G-02 (the manifest is the input to the lockfile check) with its path.
# ---------------------------------------------------------------------------
check_workspace_integrity() {
  local u
  while IFS= read -r u; do
    [ -n "$u" ] || continue
    [ "$u" = "." ] && continue
    [ -f "$REPO/$u/go.mod" ] || result G-02 "go:$u" FAIL "listed in go.work but go.mod is missing"
  done < <(go_work_uses)
}

# ---------------------------------------------------------------------------
# JavaScript checks. All repo-level (_root): the lockfile, settings, gate,
# workflow, and hook belong to the workspace, not to one package.
# ---------------------------------------------------------------------------
js_is_pnpm() {
  [ -f "$REPO/pnpm-lock.yaml" ] || [ -f "$REPO/pnpm-workspace.yaml" ] \
    || { [ -f "$REPO/package.json" ] && grep -qE '"packageManager"[[:space:]]*:[[:space:]]*"pnpm@' "$REPO/package.json"; }
}
# yaml_top_value <file> <key> : value of a top-level "key: value" line
yaml_top_value() { sed -nE "s/^$2:[[:space:]]*([^#]*[^#[:space:]])?[[:space:]]*(#.*)?$/\1/p" "$1" | head -1; }
npmrc_has() { [ -f "$REPO/.npmrc" ] && grep -qE "^[[:space:]]*$1[[:space:]]*$" "$REPO/.npmrc"; }

# pnpm_version : the version pinned in packageManager (pnpm@X.Y.Z), or empty
pnpm_version() { [ -f "$REPO/package.json" ] && sed -nE 's/.*"packageManager"[[:space:]]*:[[:space:]]*"pnpm@([0-9][^"+]*).*/\1/p' "$REPO/package.json" | head -1; }
# yaml_block_items <file> <key> : entries of a top-level list, or keys of a
# top-level map whose value is true; block form and one-line flow form.
yaml_block_items() {
  # flow form: key: [a, b]  or  key: { a: true, b: false }
  sed -nE "s/^$2:[[:space:]]*[[{](.*)[]}][[:space:]]*(#.*)?$/\1/p" "$1" | tr ',' '\n' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | awk -F: 'NF == 1 && length($1) { gsub(/^["'"'"']|["'"'"']$/, "", $1); print $1; next } NF >= 2 { v = $2; gsub(/[[:space:]]/, "", v); k = $1; gsub(/^["'"'"']|["'"'"']$/, "", k); if (v == "true") print k }'
  awk -v k="$2" '
    $0 ~ "^" k ":[[:space:]]*(#.*)?$" { inb = 1; next }
    inb && /^[^[:space:]]/ { inb = 0 }
    inb && /^[[:space:]]*-[[:space:]]*/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); sub(/[[:space:]]*(#.*)?$/, ""); gsub(/^["'"'"']|["'"'"']$/, ""); if (length($0)) print; next }
    inb && /^[[:space:]]+[^[:space:]#]+:[[:space:]]*true[[:space:]]*(#.*)?$/ { sub(/^[[:space:]]+/, ""); sub(/:.*$/, ""); gsub(/^["'"'"']|["'"'"']$/, ""); print }
  ' "$1"
}
# js_build_allowlist : every package allowed to run build scripts, one per line
js_build_allowlist() {
  { [ -f "$REPO/pnpm-workspace.yaml" ] && { yaml_block_items "$REPO/pnpm-workspace.yaml" allowBuilds; yaml_block_items "$REPO/pnpm-workspace.yaml" onlyBuiltDependencies; }
    [ -f "$REPO/.npmrc" ] && sed -nE 's/^only-built-dependencies\[\]=(.*)$/\1/p' "$REPO/.npmrc"; } 2>/dev/null | awk 'NF && !seen[$0]++'
}

check_javascript_G01_root() {
  if js_is_pnpm; then
    # pnpm 10 and later run no dependency lifecycle scripts unless the package is
    # allowlisted. The allowlist is the lever, not ignoreScripts, which would also
    # silence this project's own prepare and similar scripts. The checks here are:
    # the pnpm major is known and at least 10, nothing allows every build, and the
    # allowlist is bounded. Its members are reported so they get reviewed.
    local ver major wy="$REPO/pnpm-workspace.yaml" list n note=""
    ver=$(pnpm_version)
    if [ -z "$ver" ]; then result G-01 "$CUR_TAG" FAIL "no packageManager pnpm@<exact version> in root package.json (ranges are not valid there); pin pnpm 10 or later so the no-dependency-scripts default is known"; return; fi
    major="${ver%%.*}"
    if [ "$major" -lt 10 ] 2>/dev/null; then result G-01 "$CUR_TAG" FAIL "packageManager pins pnpm $ver, which runs dependency scripts by default; pin pnpm 10 or later"; return; fi
    if [ -f "$wy" ] && [ "$(yaml_top_value "$wy" dangerouslyAllowAllBuilds)" = "true" ]; then result G-01 "$CUR_TAG" FAIL "dangerouslyAllowAllBuilds: true lets every dependency run build scripts"; return; fi
    list=$(js_build_allowlist)
    if printf '%s\n' "$list" | grep -qxF '*'; then result G-01 "$CUR_TAG" FAIL "build allowlist contains '*', which is unbounded"; return; fi
    [ -f "$wy" ] && [ "$(yaml_top_value "$wy" ignoreScripts)" = "true" ] && note="; ignoreScripts: true also disables this project's own lifecycle scripts"
    n=$(printf '%s\n' "$list" | grep -c .)
    if [ "$n" -eq 0 ]; then result G-01 "$CUR_TAG" PASS "pnpm $ver runs no dependency scripts outside the allowlist; allowlist is empty$note"
    else result G-01 "$CUR_TAG" PASS "pnpm $ver runs no dependency scripts outside the allowlist; allowlist: $(printf '%s\n' "$list" | paste -sd, - | sed 's/,/, /g') (review each)$note"; fi
  else
    if npmrc_has 'ignore-scripts=true'; then result G-01 "$CUR_TAG" PASS ".npmrc ignore-scripts=true (npm)"
    else result G-01 "$CUR_TAG" FAIL "no .npmrc with ignore-scripts=true (npm repo)"; fi
  fi
}

check_javascript_G02_root() {
  local lock
  if js_is_pnpm; then lock="pnpm-lock.yaml"; else lock="package-lock.json"; fi
  [ -f "$REPO/$lock" ] || { result G-02 "$CUR_TAG" FAIL "no $lock at the repo root"; return; }
  if git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 && git -C "$REPO" check-ignore -q "$lock" 2>/dev/null; then
    result G-02 "$CUR_TAG" FAIL "$lock is gitignored; the gate diffs the committed lockfile"; return
  fi
  if js_is_pnpm; then
    [ "$(yaml_top_value "$REPO/pnpm-workspace.yaml" saveExact 2>/dev/null)" = "true" ] \
      || { result G-02 "$CUR_TAG" FAIL "$lock present but saveExact: true missing from pnpm-workspace.yaml"; return; }
  else
    npmrc_has 'save-exact=true' || { result G-02 "$CUR_TAG" FAIL "$lock present but .npmrc lacks save-exact=true"; return; }
  fi
  result G-02 "$CUR_TAG" PASS "$lock present and not ignored; exact versions saved"
}

JS_MIN_RELEASE_AGE=4320   # minutes; the skill default of three days

check_javascript_G03_root() {
  local age excl
  if js_is_pnpm; then
    age=$(yaml_top_value "$REPO/pnpm-workspace.yaml" minimumReleaseAge 2>/dev/null)
    excl=$([ -f "$REPO/pnpm-workspace.yaml" ] && yaml_block_items "$REPO/pnpm-workspace.yaml" minimumReleaseAgeExclude | paste -sd, - | sed 's/,/, /g')
    case "$age" in
      ''|*[!0-9]*) result G-03 "$CUR_TAG" FAIL "pnpm-workspace.yaml has no numeric minimumReleaseAge (minutes; $JS_MIN_RELEASE_AGE = 3 days)" ;;
      *) if [ "$age" -ge "$JS_MIN_RELEASE_AGE" ]; then result G-03 "$CUR_TAG" PASS "minimumReleaseAge: $age minutes${excl:+; minimumReleaseAgeExclude: $excl (review each)}"
         else result G-03 "$CUR_TAG" FAIL "minimumReleaseAge: $age minutes is below $JS_MIN_RELEASE_AGE (the skill default, three days)"; fi ;;
    esac
  else
    result G-03 "$CUR_TAG" FAIL "npm has no native release-age cooldown; only the gate's AGE check applies (pnpm recommended)"
  fi
}

# workflow_with <pattern> : name of the first workflow file containing the pattern
workflow_with() {
  local f
  for f in "$REPO"/.github/workflows/*.yml "$REPO"/.github/workflows/*.yaml; do
    [ -f "$f" ] || continue
    grep -q -- "$1" "$f" && { printf '%s' "${f##*/}"; return 0; }
  done
  return 1
}

# dispatcher_matches : scripts/dep-gate.sh is the skill's dispatcher, byte for byte
dispatcher_matches() { [ -f "$REPO/scripts/dep-gate.sh" ] && cmp -s "$SKILL_ROOT/assets/common/dep-gate.sh" "$REPO/scripts/dep-gate.sh"; }

check_javascript_G04_root() {
  local tmpl="$SKILL_ROOT/assets/javascript/dep-gate-javascript.sh" gate="$REPO/scripts/dep-gate-javascript.sh" wf
  [ -f "$gate" ] || { result G-04 "$CUR_TAG" FAIL "no scripts/dep-gate-javascript.sh (copy assets/javascript/dep-gate-javascript.sh)"; return; }
  [ -x "$gate" ] || { result G-04 "$CUR_TAG" FAIL "scripts/dep-gate-javascript.sh is not executable"; return; }
  if ! cmp -s "$tmpl" "$gate"; then result G-04 "$CUR_TAG" FAIL "scripts/dep-gate-javascript.sh differs from the skill's template; re-copy it or change the template, never the copy"; return; fi
  dispatcher_matches || { result G-04 "$CUR_TAG" FAIL "scripts/dep-gate.sh (dispatcher) is missing or differs from assets/common/dep-gate.sh"; return; }
  [ -f "$REPO/.dep-gate/exceptions" ] || { result G-04 "$CUR_TAG" FAIL "no .dep-gate/exceptions file (copy assets/common/dep-gate/exceptions)"; return; }
  # Any workflow may run the gate (directly or through the dispatcher); an existing CI file counts.
  wf=$(workflow_with 'dep-gate-javascript.sh check') || wf=$(workflow_with 'dep-gate.sh check') || { result G-04 "$CUR_TAG" FAIL "no workflow under .github/workflows runs the JavaScript gate (copy assets/javascript/dep-gate.yml or add the step)"; return; }
  result G-04 "$CUR_TAG" PASS "gate and dispatcher match templates; exceptions file present; $wf runs the gate"
}

check_javascript_G06_root() {
  local wf
  wf=$(workflow_with 'osv-scanner') || { result G-06 "$CUR_TAG" FAIL "no workflow under .github/workflows runs osv-scanner (copy assets/javascript/dep-gate.yml or add the step)"; return; }
  result G-06 "$CUR_TAG" PASS "$wf runs osv-scanner"
}

check_javascript_G08_root() {
  local gate="$REPO/scripts/dep-gate-javascript.sh" tmpl="$SKILL_ROOT/assets/javascript/dep-gate-javascript.sh"
  [ -f "$gate" ] || { result G-08 "$CUR_TAG" FAIL "no scripts/dep-gate-javascript.sh; provenance is verified by the gate"; return; }
  if cmp -s "$tmpl" "$gate"; then result G-08 "$CUR_TAG" PASS "gate verifies registry signatures (openssl) and reports SLSA provenance"
  else result G-08 "$CUR_TAG" FAIL "scripts/dep-gate-javascript.sh differs from the template, so its provenance check cannot be assumed"; fi
}

# ---------------------------------------------------------------------------
# Go checks. G-02 is per unit (each module's go.sum); the rest are repo-level.
# Several IDs are satisfied by toolchain defaults; those checks confirm the
# default has not been disabled and name the setting that would disable it.
# ---------------------------------------------------------------------------
go_env() { command -v go >/dev/null 2>&1 && (cd "$REPO" && go env "$1" 2>/dev/null); }

check_go_G01_root() {
  command -v go >/dev/null 2>&1 || { result G-01 "$CUR_TAG" FAIL "go not found; cannot confirm toolchain defaults"; return; }
  local flags; flags=$(go_env GOFLAGS)
  case " $flags " in
    *" -mod=mod "*) result G-01 "$CUR_TAG" FAIL "GOFLAGS=$flags lets builds add modules silently; remove -mod=mod (default is readonly)" ;;
    *) result G-01 "$CUR_TAG" PASS "Go modules have no install scripts; fetch never executes; GOFLAGS keeps -mod=readonly" ;;
  esac
}

check_go_G02() {  # per unit: $1 is the module directory
  local u="$1" dir sum
  if [ "$u" = "." ]; then dir="$REPO"; sum="go.sum"; else dir="$REPO/$u"; sum="$u/go.sum"; fi
  [ -f "$dir/go.mod" ] || { result G-02 "$CUR_TAG" FAIL "no go.mod in $u"; return; }
  [ -f "$dir/go.sum" ] || { result G-02 "$CUR_TAG" FAIL "no go.sum next to go.mod (run go mod tidy through the gate once, then commit it)"; return; }
  if git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 && git -C "$REPO" check-ignore -q "$sum" 2>/dev/null; then
    result G-02 "$CUR_TAG" FAIL "$sum is gitignored; the gate diffs the committed go.sum"; return
  fi
  result G-02 "$CUR_TAG" PASS "go.sum present and not ignored; versions are exact by construction"
}

go_gate_matches() { [ -f "$REPO/scripts/dep-gate-go.sh" ] && cmp -s "$SKILL_ROOT/assets/go/dep-gate-go.sh" "$REPO/scripts/dep-gate-go.sh"; }

check_go_G03_root() {
  if go_gate_matches; then result G-03 "$CUR_TAG" PASS "no native cooldown in Go; the gate's AGE check enforces it from the proxy publish time"
  else result G-03 "$CUR_TAG" FAIL "Go has no native release-age cooldown and scripts/dep-gate-go.sh is missing or differs from the template"; fi
}

check_go_G04_root() {
  local wf
  [ -f "$REPO/scripts/dep-gate-go.sh" ] || { result G-04 "$CUR_TAG" FAIL "no scripts/dep-gate-go.sh (copy assets/go/dep-gate-go.sh)"; return; }
  [ -x "$REPO/scripts/dep-gate-go.sh" ] || { result G-04 "$CUR_TAG" FAIL "scripts/dep-gate-go.sh is not executable"; return; }
  go_gate_matches || { result G-04 "$CUR_TAG" FAIL "scripts/dep-gate-go.sh differs from the skill's template; re-copy it or change the template, never the copy"; return; }
  dispatcher_matches || { result G-04 "$CUR_TAG" FAIL "scripts/dep-gate.sh (dispatcher) is missing or differs from assets/common/dep-gate.sh"; return; }
  [ -f "$REPO/.dep-gate/exceptions" ] || { result G-04 "$CUR_TAG" FAIL "no .dep-gate/exceptions file (copy assets/common/dep-gate/exceptions)"; return; }
  wf=$(workflow_with 'dep-gate-go.sh check') || wf=$(workflow_with 'dep-gate.sh check') || { result G-04 "$CUR_TAG" FAIL "no workflow under .github/workflows runs the Go gate (copy assets/go/dep-gate-go.yml or add the step)"; return; }
  result G-04 "$CUR_TAG" PASS "gate and dispatcher match templates; exceptions file present; $wf runs the gate"
}

check_go_G06_root() {
  local w1 w2
  w1=$(workflow_with 'govulncheck') || { result G-06 "$CUR_TAG" FAIL "no workflow under .github/workflows runs govulncheck (copy assets/go/dep-gate-go.yml or add the step)"; return; }
  w2=$(workflow_with 'osv-scanner') || { result G-06 "$CUR_TAG" FAIL "no workflow under .github/workflows runs osv-scanner"; return; }
  if [ "$w1" = "$w2" ]; then result G-06 "$CUR_TAG" PASS "$w1 runs govulncheck and osv-scanner"; else result G-06 "$CUR_TAG" PASS "$w1 runs govulncheck and $w2 runs osv-scanner"; fi
}

# go_nosumdb_patterns : prints "<label>|<patterns>" where label is GONOSUMDB when
# set explicitly, or GOPRIVATE when go env derived GONOSUMDB from it (go env
# reports GOPRIVATE's value for an unset GONOSUMDB).
go_nosumdb_patterns() {
  local nosum private
  nosum=$(go_env GONOSUMDB); private=$(go_env GOPRIVATE)
  [ -n "$nosum" ] || return 0
  if [ "$nosum" = "$private" ]; then printf 'GOPRIVATE|%s' "$nosum"; else printf 'GONOSUMDB|%s' "$nosum"; fi
}
# pattern_too_broad <pattern> : a checksum-exclusion pattern that reaches public
# modules: a wildcard, or a public host with nothing narrower than "host" or
# "host/*". "github.com/myorg" is scoped and passes. Literal string compares,
# not case globs, so the pattern text is never expanded.
pattern_too_broad() {
  local p="$1" h
  [ "$p" = '*' ] || [ "$p" = '**' ] || [ "$p" = '*/*' ] && return 0
  for h in github.com gitlab.com bitbucket.org golang.org gopkg.in google.golang.org k8s.io sigs.k8s.io go.uber.org; do
    [ "$p" = "$h" ] || [ "$p" = "$h/*" ] || [ "$p" = "$h/**" ] && return 0
  done
  return 1
}

check_go_G08_root() {
  command -v go >/dev/null 2>&1 || { result G-08 "$CUR_TAG" FAIL "go not found; cannot confirm checksum database settings"; return; }
  local sumdb flags insecure lp label pats p
  sumdb=$(go_env GOSUMDB); flags=$(go_env GOFLAGS); insecure=$(go_env GOINSECURE)
  [ "$sumdb" != "off" ] || { result G-08 "$CUR_TAG" FAIL "GOSUMDB=off disables checksum database verification"; return; }
  case " $flags " in *" -insecure "*|*" -mod=mod "*) result G-08 "$CUR_TAG" FAIL "GOFLAGS=$flags weakens module verification"; return ;; esac
  [ -z "$insecure" ] || { result G-08 "$CUR_TAG" FAIL "GOINSECURE=$insecure allows unverified fetches"; return; }
  lp=$(go_nosumdb_patterns); label="${lp%%|*}"; pats="${lp#*|}"
  if [ -n "$lp" ]; then
    # read, not a for-loop over a word split: a pattern like * must not glob
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      if [ "$p" = '*' ] || [ "$p" = '**' ]; then result G-08 "$CUR_TAG" FAIL "$label=$pats is unbounded: every module is excluded from checksum verification"; return; fi
      if pattern_too_broad "$p"; then result G-08 "$CUR_TAG" FAIL "$label pattern $p excludes public modules from checksum verification; scope it to the private host"; return; fi
    done <<EOF_PATS
$(printf '%s' "$pats" | tr ',' '\n')
EOF_PATS
    result G-08 "$CUR_TAG" PASS "checksum database $sumdb active; $label=$pats excludes only those private paths (the gate fails any module they match)"
  else
    result G-08 "$CUR_TAG" PASS "checksum database $sumdb active for every module; go.sum pins each archive hash"
  fi
}

# ---------------------------------------------------------------------------
# Language-specific IDs: dispatch per the contract in the header, else FAIL
# ---------------------------------------------------------------------------
LANGUAGE_IDS="G-01 G-02 G-03 G-04 G-06 G-08"
CUR_UNIT=""
CUR_TAG=""

if [ -n "${VERIFY_SETUP_CHECKS_FILE:-}" ]; then
  if [ -f "$VERIFY_SETUP_CHECKS_FILE" ]; then
    # shellcheck source=/dev/null
    . "$VERIFY_SETUP_CHECKS_FILE"
  else
    echo "VERIFY_SETUP_CHECKS_FILE not found: $VERIFY_SETUP_CHECKS_FILE" >&2
    exit 2
  fi
fi

run_language_checks() {
  local id fn lang u n
  for id in $LANGUAGE_IDS; do
    if [ ${#LANGUAGES[@]} -eq 0 ]; then
      result "$id" "-" SKIP "no language detected"
      continue
    fi
    for lang in "${LANGUAGES[@]}"; do
      fn="check_${lang}_${id//-/}"
      if declare -F "${fn}_root" >/dev/null; then
        CUR_UNIT="."; CUR_TAG="$lang"
        "${fn}_root" "."
      elif declare -F "$fn" >/dev/null; then
        n=0
        while IFS= read -r u; do
          [ -n "$u" ] || continue
          n=$((n + 1))
          CUR_UNIT="$u"
          if [ "$u" = "." ]; then CUR_TAG="$lang"; else CUR_TAG="$lang:$u"; fi
          "$fn" "$u"
        done < <(units_for "$lang")
        [ "$n" -eq 0 ] && result "$id" "$lang" FAIL "no $lang units found to check"
      else
        result "$id" "$lang" FAIL "no $lang check for $id yet"
      fi
    done
  done
  CUR_UNIT=""; CUR_TAG=""
}

# ---------------------------------------------------------------------------
# G-05 Hipcheck policy directory present; config and cache relocated into the
# repo. Hipcheck's policy references its data files (Orgs.kdl, Binary.kdl,
# Typos.kdl, Langs.kdl) relative to itself, so the policy lives in a
# directory, .hipcheck/, and HC_CONFIG points at it. HC_CACHE holds plugins
# and clones; keeping it inside the repo means no sandbox grant outside the
# repo and no state shared between unrelated projects.
# ---------------------------------------------------------------------------
check_G05() {
  local cfg cache cfgdir
  if [ ! -f "$REPO/.hipcheck/Hipcheck.kdl" ]; then
    result G-05 "-" FAIL "no .hipcheck/Hipcheck.kdl (copy assets/common/hipcheck/ to .hipcheck/)"
    return
  fi
  cfg=$(env_value HC_CONFIG)
  if [ -z "$cfg" ]; then
    result G-05 "-" FAIL ".hipcheck/Hipcheck.kdl present but HC_CONFIG not set in .env (expected HC_CONFIG=.hipcheck)"
    return
  fi
  case "$cfg" in /*) cfgdir="$cfg" ;; *) cfgdir="$REPO/${cfg#./}" ;; esac
  if ! path_in_repo "$cfg" || [ ! -f "$cfgdir/Hipcheck.kdl" ]; then
    result G-05 "-" FAIL "HC_CONFIG=$cfg does not name a directory inside the repo that holds Hipcheck.kdl"
    return
  fi
  cache=$(env_value HC_CACHE)
  if [ -z "$cache" ]; then
    result G-05 "-" FAIL "HC_CACHE not set in .env (expected HC_CACHE=.hipcheck-cache)"
    return
  fi
  if ! path_in_repo "$cache"; then
    result G-05 "-" FAIL "HC_CACHE=$cache resolves outside the repo"
    return
  fi
  result G-05 "-" PASS ".hipcheck/Hipcheck.kdl present, HC_CONFIG=$cfg, HC_CACHE=$cache"
}

# ---------------------------------------------------------------------------
# G-07 Agent install commands routed through the gate
# The harness-specific hook file is checked by name because the hook lives
# there. Add a case per harness as hook templates are added to assets/common/.
# ---------------------------------------------------------------------------
check_G07() {
  local f="$REPO/.claude/settings.json"
  if [ ! -f "$f" ]; then
    result G-07 "-" FAIL "no harness hook file (.claude/settings.json)"
    return
  fi
  if ! grep -q '"PreToolUse"' "$f"; then
    result G-07 "-" FAIL "harness settings have no PreToolUse hook"
    return
  fi
  # Only the PreToolUse block counts: from its key up to (not including) the
  # next hook-event key. Event keys are first moved onto their own lines so a
  # minified single-line file is judged the same as a pretty-printed one. The
  # event-key list is explicit; a hook event added to the harness later must be
  # added here or a block that follows PreToolUse would be read as part of it.
  local block
  block=$(sed -E 's/"(PreToolUse|PostToolUse|Stop|Notification|UserPromptSubmit|SessionStart|SessionEnd|SubagentStop|PreCompact|PermissionRequest)"[[:space:]]*:/\
"\1":/g' "$f" \
    | awk '/"PreToolUse"[[:space:]]*:/ { p = 1; print; next }
           p && /"(PostToolUse|Stop|Notification|UserPromptSubmit|SessionStart|SessionEnd|SubagentStop|PreCompact|PermissionRequest)"[[:space:]]*:/ { p = 0 }
           p { print }')
  if ! printf '%s' "$block" | grep -q 'dep-gate'; then
    result G-07 "-" FAIL "PreToolUse hook present but does not reference dep-gate"
    return
  fi
  result G-07 "-" PASS "PreToolUse hook references dep-gate"
}

# ---------------------------------------------------------------------------
# G-09 Toolchain version pinned, per detected language
# ---------------------------------------------------------------------------
check_G09() {
  local lang
  if [ ${#LANGUAGES[@]} -eq 0 ]; then
    result G-09 "-" SKIP "no language detected; cannot verify a toolchain pin"
    return
  fi
  for lang in "${LANGUAGES[@]}"; do
    case "$lang" in
      javascript)
        # Node pin: a version file, or engines.node in the root package.json.
        # Package manager pin: the packageManager field in the root package.json.
        local pin="" pm=0
        if [ -f "$REPO/.nvmrc" ] || [ -f "$REPO/.node-version" ]; then
          pin=".nvmrc/.node-version"
        elif [ -f "$REPO/package.json" ] && tr -d '\n' < "$REPO/package.json" | grep -qE '"engines"[[:space:]]*:[[:space:]]*\{[^}]*"node"'; then
          pin="engines.node"
        fi
        [ -f "$REPO/package.json" ] && grep -q '"packageManager"' "$REPO/package.json" && pm=1
        if [ -z "$pin" ]; then
          result G-09 javascript FAIL "no .nvmrc, .node-version, or engines.node in root package.json"
        elif [ "$pm" -eq 0 ]; then
          result G-09 javascript FAIL "node pinned ($pin) but root package.json has no packageManager field"
        else
          result G-09 javascript PASS "node pinned ($pin), packageManager set"
        fi ;;
      go)
        # With a workspace, go.work's go or toolchain directive governs every
        # module. Without one, the root go.mod needs a toolchain directive.
        if [ -f "$REPO/go.work" ]; then
          if grep -qE '^(go|toolchain)[[:space:]]+' "$REPO/go.work"; then
            result G-09 go PASS "go.work pins the toolchain ($(grep -E '^(go|toolchain)[[:space:]]+' "$REPO/go.work" | head -1 | tr -s ' '))"
          else
            result G-09 go FAIL "go.work has no go or toolchain directive"
          fi
        elif grep -qE '^toolchain[[:space:]]+go' "$REPO/go.mod"; then
          result G-09 go PASS "go.mod has toolchain directive"
        else
          result G-09 go FAIL "go.mod has no toolchain directive"
        fi ;;
      python)
        if [ -f "$REPO/.python-version" ]; then result G-09 python PASS ".python-version present"; else result G-09 python FAIL "no .python-version"; fi ;;
      ruby)
        if [ -f "$REPO/.ruby-version" ] || [ -f "$REPO/.tool-versions" ]; then result G-09 ruby PASS ".ruby-version or .tool-versions present"; else result G-09 ruby FAIL "no .ruby-version or .tool-versions"; fi ;;
      rust)
        if [ -f "$REPO/rust-toolchain.toml" ] || [ -f "$REPO/rust-toolchain" ]; then result G-09 rust PASS "rust-toolchain present"; else result G-09 rust FAIL "no rust-toolchain.toml"; fi ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# G-10 Repo hygiene files: .gitignore, license, .editorconfig; gitignore covers
# the dependency directory, the Hipcheck cache, and local env files
# ---------------------------------------------------------------------------
check_G10() {
  local missing=() lang
  [ -f "$REPO/.gitignore" ] || missing+=(".gitignore")
  local lic="" f
  for f in "$REPO"/LICENSE* "$REPO"/COPYING*; do [ -e "$f" ] && lic="$f"; done
  [ -n "$lic" ] || missing+=("LICENSE")
  [ -f "$REPO/.editorconfig" ] || missing+=(".editorconfig")
  if [ ${#missing[@]} -gt 0 ]; then
    result G-10 "-" FAIL "missing: ${missing[*]}"
    return
  fi
  gitignore_has '\.env' || missing+=(".env not gitignored")
  gitignore_has '\.hipcheck-cache' || missing+=(".hipcheck-cache not gitignored")
  for lang in "${LANGUAGES[@]+"${LANGUAGES[@]}"}"; do
    case "$lang" in
      javascript) gitignore_has 'node_modules' || missing+=("node_modules not gitignored") ;;
      python) gitignore_has '\.venv' || missing+=(".venv not gitignored") ;;
      rust) gitignore_has 'target' || missing+=("target not gitignored") ;;
    esac
  done
  if [ ${#missing[@]} -gt 0 ]; then
    result G-10 "-" FAIL "${missing[*]}"
    return
  fi
  result G-10 "-" PASS ".gitignore, license, .editorconfig present; env, cache, deps ignored"
}

# ---------------------------------------------------------------------------
# G-11 Agent instructions file points at the verifier
# ---------------------------------------------------------------------------
check_G11() {
  local f found=""
  for f in AGENTS.md CLAUDE.md; do
    [ -f "$REPO/$f" ] && { found="$f"; break; }
  done
  if [ -z "$found" ]; then
    result G-11 "-" FAIL "no AGENTS.md or CLAUDE.md at repo root"
    return
  fi
  if grep -q 'verify-setup' "$REPO/$found"; then
    result G-11 "-" PASS "$found references verify-setup"
  else
    result G-11 "-" FAIL "$found present but does not mention verify-setup"
  fi
}

# ---------------------------------------------------------------------------
# Run everything in ID order
# ---------------------------------------------------------------------------
check_workspace_integrity
run_language_checks
check_G05
check_G07
check_G09
check_G10
check_G11

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

sorted_indices() {
  local i
  for i in "${!RESULT_IDS[@]}"; do printf '%s %s\n' "${RESULT_IDS[$i]}" "$i"; done | sort -k1,1 -s | awk '{print $2}'
}

if [ "$JSON" -eq 1 ]; then
  first=1
  printf '['
  for i in $(sorted_indices); do
    [ "$first" -eq 1 ] || printf ','
    first=0
    lang="${RESULT_LANGS[$i]%%:*}"; path="${RESULT_LANGS[$i]#*:}"; [ "$path" = "${RESULT_LANGS[$i]}" ] && path=""
    printf '\n  {"id": "%s", "language": "%s", "path": "%s", "status": "%s", "reason": "%s"}' \
      "${RESULT_IDS[$i]}" "$lang" "$(json_escape "$path")" "${RESULT_STATUSES[$i]}" "$(json_escape "${RESULT_REASONS[$i]}")"
  done
  printf '\n]\n'
else
  for i in $(sorted_indices); do
    if [ "${RESULT_LANGS[$i]}" = "-" ]; then
      printf '%s %-4s  %s\n' "${RESULT_IDS[$i]}" "${RESULT_STATUSES[$i]}" "${RESULT_REASONS[$i]}"
    else
      printf '%s %-4s  [%s] %s\n' "${RESULT_IDS[$i]}" "${RESULT_STATUSES[$i]}" "${RESULT_LANGS[$i]}" "${RESULT_REASONS[$i]}"
    fi
  done
fi

exit "$ANY_FAIL"
