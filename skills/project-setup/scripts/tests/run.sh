#!/usr/bin/env bash
# Test runner for verify-setup.sh. Plain bash; no bats required.
# Each fixture under tests/fixtures/ is run through the verifier and the
# status of specific IDs is asserted, along with the exit code.
#
# Fixture dotfiles such as .env and CLAUDE.md match this repo's root .gitignore
# (and in some fixtures their own .gitignore). They are force-tracked with
# `git add -f`. When adding a fixture, check `git check-ignore -v` on its files.
set -uo pipefail

TESTS_DIR=$(cd "$(dirname "$0")" && pwd)
VERIFIER="$TESTS_DIR/../verify-setup.sh"
FIXTURES="$TESTS_DIR/fixtures"
FAILURES=0
CHECKS=0

fail() { FAILURES=$((FAILURES + 1)); printf '  not ok  %s\n' "$1"; }
ok()   { printf '  ok      %s\n' "$1"; }

run_fixture() {
  local name="$1"
  OUTPUT=$(bash "$VERIFIER" "$FIXTURES/$name" 2>&1)
  EXIT=$?
}

# expect_status <ID> <STATUS> : the most recent run_fixture output has a line "<ID> <STATUS> ..."
expect_status() {
  local id="$1" status="$2"
  CHECKS=$((CHECKS + 1))
  if printf '%s\n' "$OUTPUT" | grep -qE "^$id +$status( |$)"; then
    ok "$CURRENT: $id is $status"
  else
    fail "$CURRENT: expected $id $status, got: $(printf '%s\n' "$OUTPUT" | grep -E "^$id " || echo '<no line>')"
  fi
}

# expect_reason <ID> <regex> : the line for ID contains the regex in its reason text
expect_reason() {
  local id="$1" re="$2"
  CHECKS=$((CHECKS + 1))
  if printf '%s\n' "$OUTPUT" | grep -E "^$id " | grep -qE "$re"; then
    ok "$CURRENT: $id reason matches /$re/"
  else
    fail "$CURRENT: $id reason does not match /$re/: $(printf '%s\n' "$OUTPUT" | grep -E "^$id " || echo '<no line>')"
  fi
}

# run_fixture_env <fixture> <VAR=value...> : run the verifier with extra environment
run_fixture_env() { local f="$1"; shift; OUTPUT=$(env "$@" /bin/bash "$VERIFIER" "$FIXTURES/$f" 2>&1); EXIT=$?; }

# run_units <fixture> : capture --list-units output
run_units() { UNITS=$(bash "$VERIFIER" --list-units "$FIXTURES/$1" 2>&1); UNITS_EXIT=$?; }
expect_unit() {
  CHECKS=$((CHECKS + 1))
  if printf '%s\n' "$UNITS" | grep -qxF "$1 $2"; then ok "$CURRENT: unit $1 $2 listed"; else fail "$CURRENT: unit '$1 $2' not listed; got: $(printf '%s' "$UNITS" | tr '\n' ';')"; fi
}
expect_no_unit() {
  CHECKS=$((CHECKS + 1))
  if printf '%s\n' "$UNITS" | grep -qxF "$1 $2"; then fail "$CURRENT: unit '$1 $2' should not be listed"; else ok "$CURRENT: unit $1 $2 not listed"; fi
}

expect_exit() {
  local want="$1"
  CHECKS=$((CHECKS + 1))
  if [ "$EXIT" -eq "$want" ]; then ok "$CURRENT: exit $want"; else fail "$CURRENT: expected exit $want, got $EXIT"; fi
}

expect_no_status() {
  local status="$1"
  CHECKS=$((CHECKS + 1))
  if printf '%s\n' "$OUTPUT" | grep -qE "^G-[0-9]+ +$status( |$)"; then
    fail "$CURRENT: expected no $status lines, got: $(printf '%s\n' "$OUTPUT" | grep -E "^G-[0-9]+ +$status" | tr '\n' ';')"
  else
    ok "$CURRENT: no $status lines"
  fi
}

echo "verify-setup.sh tests"

if [ ! -f "$VERIFIER" ]; then
  echo "  not ok  verifier missing at $VERIFIER"
  echo "1 check, 1 failure"
  exit 1
fi

CURRENT="empty"; run_fixture empty
expect_exit 1
expect_status G-05 FAIL
expect_status G-07 FAIL
expect_status G-10 FAIL
expect_status G-11 FAIL
expect_status G-01 SKIP

CURRENT="global-pass"; run_fixture global-pass
expect_exit 0
expect_no_status FAIL
expect_status G-05 PASS
expect_status G-07 PASS
expect_status G-09 SKIP
expect_status G-10 PASS
expect_status G-11 PASS
expect_status G-01 SKIP

# Every required file exists but with the wrong content: each content check must FAIL.
CURRENT="global-content-fail"; run_fixture global-content-fail
expect_exit 1
expect_status G-05 FAIL   # HC_CACHE points outside the repo
expect_status G-07 FAIL   # PreToolUse present but no dep-gate reference
expect_status G-10 FAIL   # .gitignore lacks .env
expect_status G-11 FAIL   # CLAUDE.md present but no verify-setup mention
expect_reason G-05 'outside the repo'
expect_reason G-07 'does not reference dep-gate'
expect_reason G-10 '\.env not gitignored'
expect_reason G-11 'does not mention verify-setup'

CURRENT="js-nopm"; run_fixture js-nopm
expect_status G-09 FAIL   # .nvmrc present, packageManager missing
expect_reason G-09 'no packageManager'
expect_status G-10 FAIL   # hygiene files present, but node_modules not ignored
expect_reason G-10 'node_modules not gitignored'

CURRENT="js-pinned"; run_fixture js-pinned
expect_exit 1             # language checks do not exist yet: that is a FAIL, not a pass
expect_status G-09 PASS
expect_status G-10 PASS   # env, cache, and node_modules all ignored
expect_status G-01 PASS   # pnpm 10 pinned: dependency scripts are off by default even with no settings file
expect_reason G-01 '\[javascript\] pnpm 10\.0\.0 runs no dependency scripts outside the allowlist; allowlist is empty'
expect_status G-08 FAIL
expect_reason G-08 'no scripts/dep-gate-javascript\.sh'

CURRENT="cache-unignored"; run_fixture cache-unignored
expect_status G-10 FAIL   # .env ignored but .hipcheck-cache is not
expect_reason G-10 'hipcheck-cache not gitignored'

CURRENT="hook-no-pretooluse"; run_fixture hook-no-pretooluse
expect_status G-07 FAIL   # dep-gate referenced, but not under PreToolUse
expect_reason G-07 'no PreToolUse hook'

CURRENT="go-notoolchain"; run_fixture go-notoolchain
expect_status G-09 FAIL
expect_reason G-09 'no toolchain directive'

CURRENT="go-pinned"; run_fixture go-pinned
expect_exit 1
expect_status G-09 PASS
expect_status G-01 PASS
expect_reason G-01 '\[go\] Go modules have no install scripts'

# --- workspaces: detection by go.work / pnpm-workspace.yaml, units, and pins ---
CURRENT="go-workspace"; run_fixture go-workspace          # go.work, no root go.mod
expect_status G-09 PASS
expect_reason G-09 '\[go\] go.work'
expect_status G-01 PASS                                    # Go detected via go.work alone
expect_reason G-01 '\[go\] Go modules have no install scripts'
expect_reason G-02 '\[go:mod-c\] listed in go.work but go.mod is missing'
run_units go-workspace
expect_unit go mod-a
expect_unit go mod-b
expect_no_unit javascript .

CURRENT="pnpm-workspace"; run_fixture pnpm-workspace      # engines.node + packageManager, no .nvmrc
expect_status G-09 PASS
expect_reason G-09 '\[javascript\] node pinned \(engines.node\)'
run_units pnpm-workspace
expect_unit javascript .
expect_unit javascript packages/a
expect_unit javascript packages/b
expect_no_unit javascript packages/ignored                 # negated in pnpm-workspace.yaml
expect_no_unit javascript packages/notapkg                 # no package.json

CURRENT="monorepo-hdf-shape"; run_fixture monorepo-hdf-shape   # both languages, no root go.mod
expect_reason G-09 '\[javascript\] node pinned \(engines.node\)'
expect_reason G-09 '\[go\] go.work'
expect_reason G-01 '\[javascript\] pnpm 10\.0\.0 runs no dependency scripts outside the allowlist'
expect_reason G-01 '\[go\] Go modules have no install scripts'
run_units monorepo-hdf-shape
expect_unit javascript .
expect_unit javascript packages/ts-lib
expect_unit go go/mod-x
expect_unit go go/mod-y
CHECKS=$((CHECKS + 1)); if [ "$UNITS_EXIT" -eq 0 ]; then ok "$CURRENT: --list-units exits 0"; else fail "$CURRENT: --list-units exit $UNITS_EXIT"; fi

CURRENT="js-engines-nopm"; run_fixture js-engines-nopm   # engines.node present, packageManager absent
expect_status G-09 FAIL
expect_reason G-09 'engines.node.*no packageManager'

CURRENT="go-work-toolchain"; run_fixture go-work-toolchain
expect_status G-09 PASS
expect_reason G-09 'toolchain go1.24.2'
run_units go-work-toolchain
expect_unit go m

CURRENT="pnpm-flow"; run_units pnpm-flow                     # flow-style list, ** exclusion
expect_unit javascript libs/x
expect_unit javascript libs/y
expect_no_unit javascript libs/y/test

# Dispatch contract: per-unit functions get each unit path; _root functions run once.
CURRENT="dispatch"; OUTPUT=$(VERIFY_SETUP_CHECKS_FILE="$TESTS_DIR/checks-stub.sh" bash "$VERIFIER" "$FIXTURES/monorepo-hdf-shape" 2>&1); EXIT=$?
expect_reason G-01 '^G-01 PASS +\[go:go/mod-x\] stub unit=go/mod-x'
expect_reason G-01 '^G-01 PASS +\[go:go/mod-y\] stub unit=go/mod-y'
expect_reason G-03 '^G-03 PASS +\[javascript\] stub root=\.'
CHECKS=$((CHECKS + 1))
n=$(printf '%s\n' "$OUTPUT" | grep -cE '^G-03 PASS +\[javascript\]'); if [ "$n" -eq 1 ]; then ok "$CURRENT: root-scoped check ran once"; else fail "$CURRENT: root-scoped check ran $n times"; fi
CHECKS=$((CHECKS + 1))
if printf '%s\n' "$OUTPUT" | grep -qE '^G-01 FAIL +\[go\]'; then fail "$CURRENT: generic 'no go check' line still printed for G-01"; else ok "$CURRENT: no generic G-01 line once a check exists"; fi
CURRENT="dedupe"; UNITS=$(bash "$VERIFIER" --list-units "$FIXTURES/go-root-and-work" 2>&1); UNITS_EXIT=$?
CHECKS=$((CHECKS + 1))
n=$(printf '%s\n' "$UNITS" | grep -cxF 'go .'); if [ "$n" -eq 1 ]; then ok "$CURRENT: root go unit listed once"; else fail "$CURRENT: 'go .' listed $n times: $(printf '%s' "$UNITS" | tr '\n' ';')"; fi
expect_unit go sub

# --- install hook: deny dependency-changing commands, allow lockfile-faithful ones ---
HOOK="$TESTS_DIR/../../assets/common/dep-gate-hook.sh"
hook_case() {  # hook_case <expected exit> <command string>
  local want="$1" c="$2" got
  CHECKS=$((CHECKS + 1))
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$c" | bash "$HOOK" >/dev/null 2>"$TESTS_DIR/.hook.err"; got=$?
  if [ "$got" -eq "$want" ]; then ok "hook: exit $want for: $c"; else fail "hook: expected exit $want, got $got for: $c ($(head -c 120 "$TESTS_DIR/.hook.err"))"; fi
}
CURRENT="hook"
hook_case 2 'pnpm add left-pad'
hook_case 2 'pnpm install'
hook_case 2 'pnpm i'
hook_case 2 'npm install lodash'
hook_case 2 'npm i'
hook_case 2 'npm install'
hook_case 2 'yarn add chalk'
hook_case 2 'yarn install'
hook_case 2 'bun add zod'
hook_case 2 'go get github.com/x/y@v1.2.3'
hook_case 2 'go mod tidy'
hook_case 2 'go install golang.org/x/tools/cmd/goimports@latest'
hook_case 2 'go run github.com/x/tool@latest'
hook_case 2 'uv add requests'
hook_case 2 'uv pip install requests'
hook_case 2 'pip install requests'
hook_case 2 'uv sync'
hook_case 2 'poetry add httpx'
hook_case 2 'cd packages/a && pnpm add left-pad'
hook_case 2 'ls; npm install'
hook_case 2 'NODE_ENV=production npm install'
hook_case 2 'npx create-thing'
hook_case 2 'npm install --ignore-scripts'                 # scripts off is not evaluation
hook_case 2 'pnpm install --frozen-lockfile=false'         # negated flag is a plain install
hook_case 2 'yarn install --immutable=false'
hook_case 2 'uv sync --locked=false'
hook_case 2 'pnpm -r add left-pad'                         # workspace flags before the verb
hook_case 2 'pnpm --filter @ws/a add left-pad'
hook_case 2 'pnpm -F a -r add left-pad'
hook_case 2 'pnpm -C packages/a add left-pad'
hook_case 2 'npm --prefix packages/a install left-pad'
hook_case 2 'npm -w packages/a install left-pad'
hook_case 2 'env pnpm add left-pad'                        # trivial prefixes
hook_case 2 'env CI=1 pnpm add left-pad'
hook_case 2 'time npm install'
hook_case 2 'nohup npm install'
hook_case 2 'nice -n 5 pnpm add x'
hook_case 2 'corepack pnpm add left-pad'
hook_case 2 'bash -c \"pnpm add left-pad\"'              # shell -c wrapper
hook_case 2 'pnpm -w add left-pad'                         # pnpm -w is boolean (workspace root)
hook_case 2 'pnpm -w install'
hook_case 2 'pnpm install --frozen-lockfile false'         # pnpm consumes a trailing false
hook_case 2 'uv --directory a add requests'                # tool globals before the verb
hook_case 2 'uv --project a add requests'
hook_case 2 'poetry --directory a add httpx'
hook_case 2 'pip --timeout 10 install requests'
hook_case 2 'uv run --with requests python -c 1'           # fetches a package
hook_case 2 '(pnpm add left-pad)'                          # grouping
hook_case 2 '{ pnpm add left-pad; }'
hook_case 2 '/usr/local/bin/pnpm add left-pad'             # tool by path
hook_case 2 './node_modules/.bin/npm install'
hook_case 2 'eval \"pnpm add left-pad\"'                   # eval
hook_case 2 'echo $(pnpm add left-pad)'                    # command substitution
hook_case 2 'bash -x -c \"npm install\"'                   # multiple shell flags
hook_case 2 'npm in left-pad'                              # npm abbreviations
hook_case 2 'npm it'
hook_case 2 'npm install-test'
hook_case 2 'npm isntall left-pad'
hook_case 2 'npm dedupe'
hook_case 2 'pnpm ln ../x'
hook_case 2 'corepack pnpm@9 add left-pad'
hook_case 2 'yarn --cwd a add left-pad'
hook_case 2 'env -i pnpm add left-pad'                     # prefixes with options
hook_case 2 'env -u FOO pnpm add left-pad'
hook_case 2 'sudo -u me npm install'
hook_case 2 'nice -5 npm install'
hook_case 2 'time -p npm install'
hook_case 2 'timeout 60 pnpm add left-pad'
hook_case 2 'timeout -s KILL 5m pnpm add left-pad'
hook_case 2 'pnpm dedupe'                                  # more dependency-changing verbs
hook_case 2 'pnpm it'
hook_case 2 'pnpm install-test'
hook_case 2 'npm audit fix'
hook_case 2 'yarn dedupe'
hook_case 2 'pnpm install --frozen-lockfile --no-frozen-lockfile'   # last flag wins in pnpm
hook_case 2 'pnpm\tadd left-pad'                           # JSON tab escape (single backslash in the JSON string)
hook_case 2 "sh -c 'cd a && npm install'"
hook_case 0 'pnpm install --frozen-lockfile'
hook_case 0 'npm ci'
hook_case 0 'npm ci --ignore-scripts'
hook_case 0 'yarn install --immutable'
hook_case 0 'bun install --frozen-lockfile'
hook_case 0 'go mod download'
hook_case 0 'go build ./...'
hook_case 0 'go test ./...'
hook_case 0 'go install ./cmd/tool'
hook_case 0 'go run ./cmd/server'
hook_case 0 'uv sync --locked'
hook_case 0 'poetry install'
hook_case 0 'npm test'
hook_case 0 'npm run build'
hook_case 0 'pnpm -r test'
hook_case 0 'ls -la'
hook_case 0 'bash scripts/dep-gate.sh add left-pad'
hook_case 0 'git status'
hook_case 0 'pnpm -r install --frozen-lockfile'
hook_case 0 'pnpm --filter @ws/a test'
hook_case 0 'pnpm -r run build'
hook_case 0 'echo "npm install"'                           # the command word is echo
hook_case 0 'npm --prefix packages/a ci'
hook_case 0 'pnpm -w install --frozen-lockfile'
hook_case 0 'uv run python -c 1'                           # run without --with fetches nothing new
hook_case 0 'uv sync --frozen'
hook_case 0 '(npm test)'
hook_case 0 '/usr/local/bin/pnpm -r test'
hook_case 0 'timeout 60 npm test'
hook_case 0 'sudo -u me npm ci'
hook_case 0 'npm audit'                                    # report only
CHECKS=$((CHECKS + 1))
printf '{"session_id":"abc","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"pnpm add x","description":"install x"}}' | bash "$HOOK" >/dev/null 2>&1; got=$?; if [ "$got" -eq 2 ]; then ok "hook: realistic payload shape denied"; else fail "hook: realistic payload exit $got"; fi
CHECKS=$((CHECKS + 1))
printf 'not json at all' | bash "$HOOK" >/dev/null 2>&1; got=$?; if [ "$got" -eq 2 ]; then ok "hook: malformed input is denied (fail closed)"; else fail "hook: malformed input exit $got, expected 2"; fi
CHECKS=$((CHECKS + 1))
printf '{"tool_name":"Bash","tool_input":{}}' | bash "$HOOK" >/dev/null 2>&1; got=$?; if [ "$got" -eq 2 ]; then ok "hook: Bash input without command is denied"; else fail "hook: Bash input without command exit $got, expected 2"; fi
CHECKS=$((CHECKS + 1))
printf '{"tool_name":"Read","tool_input":{"file_path":"npm install"}}' | bash "$HOOK" >/dev/null 2>&1 && ok "hook: non-shell tool allowed" || fail "hook: non-shell tool denied"
CHECKS=$((CHECKS + 1))
msg=$(printf '{"tool_name":"Bash","tool_input":{"command":"pnpm add x"}}' | bash "$HOOK" 2>&1 >/dev/null); if printf '%s' "$msg" | grep -q 'dep-gate.sh add'; then ok "hook: deny message names the gate"; else fail "hook: deny message missing gate hint: $msg"; fi
rm -f "$TESTS_DIR/.hook.err"

# --- G-05 layout: .hipcheck/ directory with HC_CONFIG and HC_CACHE inside the repo ---
CURRENT="global-pass"; run_fixture global-pass
expect_reason G-05 '\.hipcheck/Hipcheck\.kdl present, HC_CONFIG=\.hipcheck, HC_CACHE=\.hipcheck-cache'
CURRENT="hc-noconfig"; run_fixture hc-noconfig
expect_status G-05 FAIL
expect_reason G-05 'HC_CONFIG not set'
CURRENT="hc-root-policy"; run_fixture hc-root-policy
expect_status G-05 FAIL
expect_reason G-05 'no \.hipcheck/Hipcheck\.kdl'
# --- G-07: dep-gate must be referenced inside the PreToolUse block, not elsewhere ---
CURRENT="hook-dep-gate-elsewhere"; run_fixture hook-dep-gate-elsewhere
expect_status G-07 FAIL
expect_reason G-07 'does not reference dep-gate'
CURRENT="hook-minified"; run_fixture hook-minified                 # same content on one line
expect_status G-07 FAIL
expect_reason G-07 'does not reference dep-gate'
CURRENT="hc-config-outside"; run_fixture hc-config-outside         # HC_CONFIG points outside the repo
expect_status G-05 FAIL
expect_reason G-05 'HC_CONFIG=~/.config/hipcheck does not name a directory inside the repo'
CURRENT="hc-config-nopolicy"; run_fixture hc-config-nopolicy       # HC_CONFIG names a dir without Hipcheck.kdl
expect_status G-05 FAIL
expect_reason G-05 'HC_CONFIG=\. does not name a directory inside the repo that holds Hipcheck\.kdl'

# --- the JavaScript gate itself, without network: check mode lists what it would evaluate ---
GATE="$TESTS_DIR/../../assets/javascript/dep-gate-javascript.sh"
GREPO=$(mktemp -d "${TMPDIR:-/tmp}/dep-gate-test.XXXXXX")
( cd "$GREPO" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  printf '{"name":"t","private":true,"packageManager":"pnpm@11.18.0"}\n' > package.json
  printf "lockfileVersion: '9.0'\n\nimporters:\n\n  .:\n    dependencies:\n      chalk:\n        specifier: 6.0.1\n        version: 6.0.1\n\npackages:\n\n  chalk@6.0.1:\n    resolution: {integrity: sha512-x}\n\nsnapshots:\n\n  chalk@6.0.1: {}\n" > pnpm-lock.yaml
  git add -A && git -c user.email=t@t -c user.name=t commit -q -m base
  printf "lockfileVersion: '9.0'\n\nimporters:\n\n  .:\n    dependencies:\n      chalk:\n        specifier: 6.0.1\n        version: 6.0.1\n      '@scope/pkg':\n        specifier: 1.2.3\n        version: 1.2.3\n\npackages:\n\n  chalk@6.0.1:\n    resolution: {integrity: sha512-x}\n\n  '@scope/pkg@1.2.3':\n    resolution: {integrity: sha512-y}\n\nsnapshots:\n\n  chalk@6.0.1: {}\n\n  '@scope/pkg@1.2.3': {}\n" > pnpm-lock.yaml )
CURRENT="gate-check"; OUTPUT=$(cd "$GREPO" && DEP_GATE_LIST_ONLY=1 /bin/bash "$GATE" check HEAD 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1)); if [ "$EXIT" -eq 0 ] && printf '%s\n' "$OUTPUT" | grep -qxF '@scope/pkg@1.2.3'; then ok "$CURRENT: check HEAD lists the new scoped package (list-only, no network)"; else fail "$CURRENT: exit $EXIT output: $(printf '%s' "$OUTPUT" | tr '\n' ';')"; fi
CHECKS=$((CHECKS + 1)); if printf '%s\n' "$OUTPUT" | grep -qxF 'chalk@6.0.1'; then fail "$CURRENT: unchanged package listed as new"; else ok "$CURRENT: unchanged package not listed"; fi
( cd "$GREPO" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m add && printf "lockfileVersion: '9.0'\n\nimporters:\n\n  .: {}\n\npackages:\n\n  chalk@6.0.1:\n    resolution: {integrity: sha512-x}\n\nsnapshots:\n\n  chalk@6.0.1: {}\n" > pnpm-lock.yaml )
CURRENT="gate-check-removal"; OUTPUT=$(cd "$GREPO" && DEP_GATE_LIST_ONLY=1 /bin/bash "$GATE" check HEAD 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1)); if [ "$EXIT" -eq 0 ] && printf '%s\n' "$OUTPUT" | grep -q 'nothing new'; then ok "$CURRENT: a removal-only change is not a failure"; else fail "$CURRENT: exit $EXIT output: $(printf '%s' "$OUTPUT" | tr '\n' ';')"; fi
( cd "$GREPO" && printf "lockfileVersion: '9.0'\n\nimporters:\n\n  .: {}\n\npackages:\n\n  chalk@6.0.1\n    resolution: {integrity: sha512-x}\n\nsnapshots:\n\n  chalk@6.0.1: {}\n" > pnpm-lock.yaml )
CURRENT="gate-parser-selfcheck"; OUTPUT=$(cd "$GREPO" && DEP_GATE_LIST_ONLY=1 /bin/bash "$GATE" check HEAD 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1)); if [ "$EXIT" -eq 2 ] && printf '%s\n' "$OUTPUT" | grep -qi 'parser'; then ok "$CURRENT: a packages section the parser cannot read aborts (fail closed)"; else fail "$CURRENT: exit $EXIT output: $(printf '%s' "$OUTPUT" | tr '\n' ';')"; fi
CURRENT="gate-listonly-add"; OUTPUT=$(cd "$GREPO" && git checkout -q -- pnpm-lock.yaml 2>/dev/null; DEP_GATE_LIST_ONLY=1 /bin/bash "$GATE" add left-pad 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1)); if [ "$EXIT" -eq 2 ] && printf '%s' "$OUTPUT" | grep -q 'DEP_GATE_LIST_ONLY' && ! grep -q left-pad "$GREPO/package.json"; then ok "$CURRENT: add refuses DEP_GATE_LIST_ONLY (nothing added)"; else fail "$CURRENT: exit $EXIT output: $(printf '%s' "$OUTPUT" | tr '\n' ';' | cut -c1-160)"; fi
CURRENT="gate-help"; OUTPUT=$(/bin/bash "$GATE" --help 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1)); if [ "$EXIT" -eq 0 ] && printf '%s\n' "$OUTPUT" | grep -q 'Usage' && ! printf '%s\n' "$OUTPUT" | grep -qE 'set -uo pipefail|rev-parse'; then ok "$CURRENT: --help prints only the header"; else fail "$CURRENT: --help exit $EXIT or prints code"; fi
rm -rf "$GREPO"

CURRENT="js-nopin"; run_fixture js-nopin                  # npm-style repo: package.json only
expect_exit 1
expect_status G-09 FAIL
expect_status G-01 FAIL
expect_reason G-01 'no \.npmrc with ignore-scripts=true'
expect_reason G-02 'no package-lock\.json'
expect_reason G-03 'npm has no native release-age cooldown'
expect_reason G-04 'no scripts/dep-gate-javascript\.sh'
expect_status G-10 FAIL

# --- a fully hardened JavaScript repo: every ID passes, exit 0 ---
CURRENT="js-pass"; run_fixture js-pass
expect_exit 0
expect_no_status FAIL
expect_reason G-01 'pnpm 11.18.0 runs no dependency scripts outside the allowlist; allowlist is empty'
expect_reason G-02 'pnpm-lock\.yaml present and not ignored; exact versions saved'
expect_reason G-03 'minimumReleaseAge: 4320 minutes'
expect_reason G-04 'gate and dispatcher match templates; exceptions file present; dep-gate\.yml runs the gate'
expect_reason G-06 'runs osv-scanner'
expect_reason G-08 'verifies registry signatures'
expect_status G-05 PASS
expect_status G-07 PASS
expect_status G-09 PASS
expect_status G-10 PASS
expect_status G-11 PASS

# --- G-01 on pnpm 10+: the allowlist is the lever, not ignoreScripts ---
CURRENT="js-allowbuilds"; run_fixture js-allowbuilds           # allowBuilds map, no ignoreScripts, 7-day cooldown with excludes
expect_status G-01 PASS
expect_reason G-01 'allowlist: esbuild, sharp'
expect_status G-03 PASS
expect_reason G-03 'minimumReleaseAge: 10080 minutes.*minimumReleaseAgeExclude'
CURRENT="js-inline-allowbuilds"; run_fixture js-inline-allowbuilds   # flow-style map on one line
expect_status G-01 PASS
expect_reason G-01 'allowlist: esbuild \(review each\)'
CURRENT="js-dangerous"; run_fixture js-dangerous               # all builds allowed: the allowlist is unbounded
expect_status G-01 FAIL
expect_reason G-01 'dangerouslyAllowAllBuilds'
CURRENT="js-old-pnpm"; run_fixture js-old-pnpm                 # pnpm 9 runs dependency scripts by default
expect_status G-01 FAIL
expect_reason G-01 'pnpm 9\.15\.0.*pin pnpm 10'
CURRENT="js-age-low"; run_fixture js-age-low                   # cooldown below the skill default
expect_status G-03 FAIL
expect_reason G-03 'minimumReleaseAge: 60 minutes is below 4320'
CURRENT="js-ci-elsewhere"; run_fixture js-ci-elsewhere         # gate and scanner live in an existing workflow
expect_status G-04 PASS
expect_reason G-04 'ci\.yml'
expect_status G-06 PASS
expect_reason G-06 'ci\.yml'

# --- same repo with a locally edited gate script: copied-not-regenerated is enforced ---
CURRENT="js-drift"; run_fixture js-drift
expect_exit 1
expect_status G-04 FAIL
expect_reason G-04 'dep-gate-javascript\.sh differs from the skill.s template'
expect_status G-08 FAIL

# --- Go: a fully hardened workspace passes every ID; toolchain defaults are checked, not assumed ---
CURRENT="go-pass"; run_fixture go-pass
expect_exit 0
expect_no_status FAIL
expect_reason G-01 '\[go\] Go modules have no install scripts'
expect_reason G-02 '\[go:mod-a\] go\.sum present'
expect_reason G-02 '\[go:mod-b\] go\.sum present'
expect_reason G-03 '\[go\] no native cooldown in Go; the gate'
expect_reason G-04 '\[go\] gate and dispatcher match templates'
expect_reason G-06 '\[go\] .*govulncheck and osv-scanner'
expect_reason G-08 '\[go\] checksum database sum\.golang\.org active'
expect_reason G-09 '\[go\] go\.work pins the toolchain'
run_units go-pass
expect_unit go mod-a
expect_unit go mod-b

# Go toolchain defaults are checked from the environment, not assumed
CURRENT="go-pass GOSUMDB=off"; run_fixture_env go-pass GOSUMDB=off
expect_status G-08 FAIL
expect_reason G-08 'GOSUMDB=off'
CURRENT="go-pass GOFLAGS=-mod=mod"; run_fixture_env go-pass GOFLAGS=-mod=mod
expect_status G-01 FAIL
expect_reason G-01 'GOFLAGS=-mod=mod'
CURRENT="go-pass GONOSUMDB=github.com"; run_fixture_env go-pass GONOSUMDB=github.com
expect_status G-08 FAIL
expect_reason G-08 'github\.com.*public'
CURRENT="go-pass GOPRIVATE=example.internal"; run_fixture_env go-pass GOPRIVATE=example.internal   # scoped private host is legitimate
expect_status G-08 PASS
expect_reason G-08 'GOPRIVATE=example\.internal'
CURRENT="go-pass GOPRIVATE=*"; run_fixture_env go-pass 'GOPRIVATE=*'
expect_status G-08 FAIL
expect_reason G-08 'unbounded'
CURRENT="go-pass GOPRIVATE=github.com/myorg"; run_fixture_env go-pass GOPRIVATE=github.com/myorg   # an org on a public host is scoped
expect_status G-08 PASS
expect_reason G-08 'GOPRIVATE=github\.com/myorg'
CURRENT="go-pass GOPRIVATE=github.com/*"; run_fixture_env go-pass 'GOPRIVATE=github.com/*'       # the whole host is not
expect_status G-08 FAIL
expect_reason G-08 'public'

CURRENT="go-pinned"; run_fixture go-pinned                     # bare module, no gate
expect_status G-01 PASS
expect_status G-02 PASS
expect_status G-03 FAIL
expect_reason G-03 'dep-gate-go\.sh is missing'
expect_status G-04 FAIL
expect_reason G-04 'no scripts/dep-gate-go\.sh'
expect_status G-06 FAIL
expect_status G-08 PASS

CURRENT="go-workspace"; run_fixture go-workspace               # mod-c has no go.mod
expect_reason G-02 '\[go:mod-c\] no go\.mod'

# --- polyglot: both languages, both gates, all IDs PASS ---
CURRENT="polyglot-pass"; run_fixture polyglot-pass
expect_exit 0
expect_no_status FAIL
expect_reason G-01 '\[javascript\] pnpm 11\.18\.0'
expect_reason G-01 '\[go\] Go modules have no install scripts'
expect_reason G-04 '\[javascript\] gate and dispatcher match'
expect_reason G-04 '\[go\] gate and dispatcher match'
run_units polyglot-pass
expect_unit javascript .
expect_unit go mod-a

# --- the Go gate itself, without network: check mode lists what it would evaluate; unreadable go.sum aborts ---
GOGATE="$TESTS_DIR/../../assets/go/dep-gate-go.sh"
GR=$(mktemp -d "${TMPDIR:-/tmp}/dep-gate-go-test.XXXXXX")
( cd "$GR" && git init -q && printf 'module example.com/t\n\ngo 1.24\n' > go.mod && printf 'golang.org/x/text v0.3.0 h1:abc=\ngolang.org/x/text v0.3.0/go.mod h1:def=\n' > go.sum
  git add -A && git -c user.email=t@t -c user.name=t commit -q -m base
  printf 'golang.org/x/text v0.3.0 h1:abc=\ngolang.org/x/text v0.3.0/go.mod h1:def=\ngithub.com/stretchr/testify v1.9.0 h1:ghi=\ngithub.com/stretchr/testify v1.9.0/go.mod h1:jkl=\ngopkg.in/yaml.v3 v3.0.1/go.mod h1:mno=\n' > go.sum )
CURRENT="go-gate-check"; OUTPUT=$(cd "$GR" && DEP_GATE_LIST_ONLY=1 /bin/bash "$GOGATE" check HEAD 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1)); if [ "$EXIT" -eq 0 ] && printf '%s\n' "$OUTPUT" | grep -qxF 'github.com/stretchr/testify@v1.9.0'; then ok "$CURRENT: check HEAD lists the new module (list-only, no network)"; else fail "$CURRENT: exit $EXIT output: $(printf '%s' "$OUTPUT" | tr '\n' ';' | cut -c1-200)"; fi
CHECKS=$((CHECKS + 1)); if printf '%s\n' "$OUTPUT" | grep -qE 'yaml\.v3|x/text@'; then fail "$CURRENT: go.mod-only or unchanged entries listed as new"; else ok "$CURRENT: /go.mod-only and unchanged entries not listed"; fi
( cd "$GR" && printf 'golang.org/x/text v0.3.0 h1:abc=\nnot a go.sum line at all\n' > go.sum )
CURRENT="go-gate-parser-selfcheck"; OUTPUT=$(cd "$GR" && DEP_GATE_LIST_ONLY=1 /bin/bash "$GOGATE" check HEAD 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1)); if [ "$EXIT" -eq 2 ] && printf '%s\n' "$OUTPUT" | grep -qi 'parser'; then ok "$CURRENT: a go.sum with lines the parser cannot read aborts (fail closed)"; else fail "$CURRENT: exit $EXIT output: $(printf '%s' "$OUTPUT" | tr '\n' ';' | cut -c1-200)"; fi
CURRENT="go-gate-listonly-add"; OUTPUT=$(cd "$GR" && git checkout -q -- go.sum && DEP_GATE_LIST_ONLY=1 /bin/bash "$GOGATE" add github.com/google/uuid@v1.6.0 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1)); if [ "$EXIT" -eq 2 ] && printf '%s' "$OUTPUT" | grep -q 'DEP_GATE_LIST_ONLY' && ! grep -q uuid "$GR/go.mod"; then ok "$CURRENT: add refuses DEP_GATE_LIST_ONLY (nothing added, nothing fetched)"; else fail "$CURRENT: exit $EXIT, go.mod has uuid: $(grep -c uuid "$GR/go.mod")"; fi
CURRENT="go-gate-escape"; OUTPUT=$( sed -n '/^proxy_escape()/,/^}/p' "$GOGATE" > "$GR/esc.sh" && . "$GR/esc.sh" && proxy_escape github.com/BurntSushi/toml )
CHECKS=$((CHECKS + 1)); if [ "$OUTPUT" = 'github.com/!burnt!sushi/toml' ]; then ok "$CURRENT: uppercase module path escaped per the proxy protocol"; else fail "$CURRENT: got '$OUTPUT'"; fi
CURRENT="go-gate-help"; OUTPUT=$(/bin/bash "$GOGATE" --help 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1)); if [ "$EXIT" -eq 0 ] && printf '%s\n' "$OUTPUT" | grep -q 'Usage' && ! printf '%s\n' "$OUTPUT" | grep -qE 'set -uo pipefail|rev-parse'; then ok "$CURRENT: --help prints only the header"; else fail "$CURRENT: --help exit $EXIT or prints code"; fi
rm -rf "$GR"

# --- dispatcher identity is enforced like the gates' ---
CURRENT="dispatcher-drift"; run_fixture dispatcher-drift
expect_exit 1
expect_status G-04 FAIL
expect_reason G-04 'dispatcher.*differs'

# --- dispatcher routing (stub gates, no network) ---
DISPATCH="$TESTS_DIR/../../assets/common/dep-gate.sh"
DT=$(mktemp -d "${TMPDIR:-/tmp}/dispatch-test.XXXXXX")
cp "$DISPATCH" "$DT/dep-gate.sh"
printf '#!/usr/bin/env bash\necho "JS gate: $*"\n' > "$DT/dep-gate-javascript.sh"; printf '#!/usr/bin/env bash\necho "GO gate: $*"\n' > "$DT/dep-gate-go.sh"
dispatch_case() {  # dispatch_case <expected substring or exit:N> <args...>
  local want="$1"; shift; local out rc
  out=$(/bin/bash "$DT/dep-gate.sh" "$@" 2>&1); rc=$?
  CHECKS=$((CHECKS + 1))
  case "$want" in
    exit:*) if [ "$rc" -eq "${want#exit:}" ]; then ok "dispatch: exit ${want#exit:} for: $*"; else fail "dispatch: expected exit ${want#exit:} got $rc for: $* ($out)"; fi ;;
    *) if printf '%s' "$out" | grep -qF -- "$want"; then ok "dispatch: '$want' for: $*"; else fail "dispatch: expected '$want' for: $* got: $out"; fi ;;
  esac
}
CURRENT="dispatch"
dispatch_case 'JS gate: add left-pad' add left-pad
dispatch_case 'JS gate: add @types/node@22' add @types/node@22
dispatch_case 'GO gate: add github.com/x/y@v1' add github.com/x/y@v1
dispatch_case 'GO gate: evaluate golang.org/x/text@v0.3.0' evaluate golang.org/x/text@v0.3.0
dispatch_case 'GO gate: evaluate x' --lang go evaluate x
dispatch_case 'JS gate: check origin/main' check origin/main
dispatch_case 'GO gate: check origin/main' check origin/main
dispatch_case 'exit:2' add
dispatch_case 'exit:2' --lang rust add x
dispatch_case 'JS gate: add socket.io' add socket.io                 # a dot in an npm name is not a host
dispatch_case 'JS gate: add lodash.merge@4' add lodash.merge@4
dispatch_case 'JS gate: add -D left-pad' add -D left-pad               # leading flag: look past it
dispatch_case 'GO gate: add -C mod-a github.com/x/y@v1' add -C mod-a github.com/x/y@v1
dispatch_case 'Usage' --help                                            # usage, not an ambiguity error
dispatch_case 'JS gate: add ./packages/local' add ./packages/local       # a local path is a pnpm link, not a module host
dispatch_case 'exit:0' --help
rm "$DT/dep-gate-go.sh"
dispatch_case 'JS gate: add github.com/x/y' add github.com/x/y        # a single gate takes everything
rm "$DT/dep-gate-javascript.sh"
dispatch_case 'exit:2' add left-pad
rm -rf "$DT"

CURRENT="json"; OUTPUT=$(bash "$VERIFIER" --json "$FIXTURES/global-pass" 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1))
if printf '%s' "$OUTPUT" | grep -q '^\[' && printf '%s' "$OUTPUT" | grep -q '"id": *"G-05"' && printf '%s' "$OUTPUT" | grep -q '"status": *"PASS"'; then
  ok "$CURRENT: --json emits an array with id and status fields"
else
  fail "$CURRENT: --json output malformed: $(printf '%s' "$OUTPUT" | head -c 200)"
fi
CHECKS=$((CHECKS + 1))
if command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$OUTPUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then ok "$CURRENT: --json parses as JSON"; else fail "$CURRENT: --json does not parse"; fi
else
  ok "$CURRENT: --json parse check skipped (no python3)"
fi

CURRENT="help"; OUTPUT=$(bash "$VERIFIER" --help 2>&1); EXIT=$?
CHECKS=$((CHECKS + 1))
if [ "$EXIT" -eq 0 ] && printf '%s' "$OUTPUT" | grep -qi 'usage'; then ok "$CURRENT: --help exits 0 with usage"; else fail "$CURRENT: --help exit $EXIT"; fi

echo "$CHECKS checks, $FAILURES failures"
[ "$FAILURES" -eq 0 ]
