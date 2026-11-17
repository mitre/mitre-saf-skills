#!/usr/bin/env bash
# dep-gate-hook.sh — agent harness pre-command hook for the dependency gate.
#
# Installed in a repo as scripts/dep-gate-hook.sh and wired as a PreToolUse
# hook on the shell tool (see assets/common/claude-settings-hook.json). The
# harness passes the pending command as JSON on stdin. Any command segment
# that can add or change dependencies is denied (exit 2, reason on stderr);
# the only path to a new dependency is scripts/dep-gate.sh, which resolves,
# evaluates, and only then installs with scripts disabled.
#
# Allowed because they cannot change what is installed beyond the committed
# lockfile, and fail if the lockfile is stale:
#   pnpm install --frozen-lockfile, npm ci, yarn install --immutable,
#   bun install --frozen-lockfile, go mod download, go mod verify,
#   uv sync --locked / --frozen, poetry install.
# Everything else that resolves or fetches packages is denied, including a
# plain "pnpm install" or "npm install", because a hand-edited manifest plus
# a plain install silently adds dependencies the gate never saw.
#
# Each segment is judged by its command word (by basename, so a tool run by
# path counts) after stripping environment assignments and transparent
# prefixes (env, time, nohup, nice, sudo, command, exec, corepack). Deny verbs
# are matched anywhere in the arguments, so global flags before the verb
# (pnpm -r add, pnpm -w add, uv --directory x add) cannot hide it. Shell
# wrappers (bash -c, sh -c, eval) are judged on the string they run; grouping
# and substitution ( ) { } $( ) ` are treated as separators. A frozen or
# locked flag counts only bare or as =true, and not when followed by the
# literal false. Input that cannot be read as a shell command is denied.
#
# Only bash, grep, sed, and tr are used so the hook runs on a bare machine.
set -uo pipefail

input=$(cat)

GATE_HINT="Use: bash scripts/dep-gate.sh add <package>[@version]  (resolves, evaluates with Hipcheck, osv-scanner, release age and provenance, then installs with scripts off). Lockfile-faithful installs are allowed: pnpm install --frozen-lockfile, npm ci, yarn install --immutable, go mod download, uv sync --locked."

deny() {
  printf 'Blocked by the dependency gate: "%s" can add or change dependencies without evaluation.\n%s\n' "$1" "$GATE_HINT" >&2
  exit 2
}

# Only shell commands are judged. If the harness names the tool and it is not
# the shell tool, allow.
tool_name=$(printf '%s' "$input" | sed -En 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' | head -1)
if [ -n "$tool_name" ] && [ "$tool_name" != "Bash" ]; then exit 0; fi

# Extract tool_input.command (a JSON string; unescape \" \\ \n).
cmd=$(printf '%s' "$input" | tr '\n' ' ' | sed -En 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -1)
cmd=$(printf '%s' "$cmd" | sed -e 's/\\n/ ; /g' -e 's/\\t/ /g' -e 's/\\"/"/g' -e 's/\\\\/\\/g')
if [ -z "$cmd" ]; then
  printf 'Blocked by the dependency gate: could not read a shell command from the hook input, so it cannot be evaluated.\n' >&2
  exit 2
fi

# has_flag <flag> <tokens...> : true if the flag appears bare (and is not
# followed by the literal "false", which pnpm's parser consumes) or as =true.
has_flag() {
  local want="$1"; shift
  local -a t=("$@")
  local i found=1 neg="--no-${want#--}"
  for i in "${!t[@]}"; do
    case "${t[$i]}" in
      "$neg"|"$want=false"|"$want=0") return 1 ;;      # a negation anywhere wins (last flag wins in pnpm)
      "$want")
        case "${t[$((i + 1))]:-}" in false|0) return 1 ;; esac
        found=0 ;;
      "$want=true") found=0 ;;
    esac
  done
  return "$found"
}

# has_any <tokens-string> <word...> : true if any word appears as a token
has_any() {
  local toks=" $1 " w
  shift
  for w in "$@"; do
    case "$toks" in *" $w "*) return 0 ;; esac
  done
  return 1
}

# strip_prefix_options <prefix> <rest> : drop the option tokens that belong to
# a transparent prefix. Value-taking options are per prefix; "timeout" also
# takes a duration as its first plain argument.
strip_prefix_options() {
  local prefix="$1" rest="$2" first
  while [ -n "$rest" ]; do
    first="${rest%% *}"
    case "$first" in
      -*)
        rest=$(printf '%s' "${rest#"$first"}" | sed -E 's/^[[:space:]]+//')
        case "$prefix:$first" in
          env:-u|env:-C|env:-S|sudo:-u|sudo:-g|sudo:-h|sudo:-p|sudo:-C|sudo:-D|sudo:-T|sudo:-U|nice:-n|timeout:-s|timeout:-k|timeout:--signal|timeout:--kill-after|doas:-u)
            [ "$rest" = "${rest%% *}" ] && { rest=""; break; }
            rest=$(printf '%s' "${rest#* }" | sed -E 's/^[[:space:]]+//') ;;
        esac ;;
      *) break ;;
    esac
  done
  if [ "$prefix" = "timeout" ] && [ -n "$rest" ]; then
    first="${rest%% *}"
    case "$first" in
      [0-9]*) [ "$first" = "$rest" ] && rest="" || rest=$(printf '%s' "${rest#* }" | sed -E 's/^[[:space:]]+//') ;;
    esac
  fi
  printf '%s' "$rest"
}

# unwrap_shell <line> : if the line is "bash [-flags] -c '...'" (or sh, zsh,
# dash, eval), print the inner string without its quotes; else the line.
unwrap_shell() {
  local line="$1" inner first
  line=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//')
  first="${line%% *}"; first="${first##*/}"
  case "$first" in
    bash|sh|zsh|dash)
      printf '%s' "$line" | grep -qE '(^|[[:space:]])-[a-zA-Z]*c[a-zA-Z]*([[:space:]]|$)' || { printf '%s' "$line"; return; }
      inner=$(printf '%s' "$line" | sed -E 's/^[^[:space:]]+//; s/^([[:space:]]+-[a-zA-Z]+)+[[:space:]]+//; s/^[[:space:]]+//') ;;
    eval)
      inner=$(printf '%s' "$line" | sed -E 's/^eval[[:space:]]+//') ;;
    *) printf '%s' "$line"; return ;;
  esac
  inner=$(printf '%s' "$inner" | sed -E "s/^\"(.*)\"[[:space:]]*$/\1/; s/^'(.*)'[[:space:]]*$/\1/")
  printf '%s' "$inner"
}

# judge_command <line> : unwrap a leading shell wrapper, then split on command
# separators and grouping ( && || ; | & newline ( ) { } backtick $( ) and judge
# every segment. Splitting on grouping and substitution is deliberate: a
# command hidden in a subshell or in $( ) still runs.
judge_command() {
  local line seg
  line=$(unwrap_shell "$1")
  while IFS= read -r seg; do
    judge_segment "$seg"
  done < <(printf '%s\n' "$line" | sed -E 's/(&&|\|\||;|\||&|\$\(|`|[(){}])/\n/g')
}

judge_segment() {
  local seg="$1" tok=() tool rest first
  seg=$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  [ -n "$seg" ] || return 0

  # Strip environment assignments and transparent prefixes, repeatedly. A
  # prefix's own options are dropped too (env -i, sudo -u NAME, nice -5,
  # time -p, timeout -s SIG 5m), so the next real word is what gets judged.
  local prefix
  while [ -n "$seg" ]; do
    first="${seg%% *}"
    case "$first" in
      *=*) prefix="" ;;                            # VAR=value
      env|time|nohup|sudo|command|exec|corepack|builtin|nice|timeout|doas) prefix="$first" ;;
      *) break ;;
    esac
    [ "$first" = "$seg" ] && { seg=""; break; }     # the prefix was the whole segment
    seg=$(printf '%s' "${seg#* }" | sed -E 's/^[[:space:]]+//')
    [ -n "$prefix" ] || continue
    seg=$(strip_prefix_options "$prefix" "$seg")
  done
  [ -n "$seg" ] || return 0

  # Nested wrapper (after a prefix): judge what it runs.
  first="${seg%% *}"; first="${first##*/}"
  case "$first" in
    bash|sh|zsh|dash|eval) judge_command "$seg"; return 0 ;;
  esac

  # Words are judged without stray quotes; the tool is judged by basename and
  # without a corepack-style @version suffix.
  read -ra tok <<< "${seg//[\"\']/}"
  tool="${tok[0]:-}"; tool="${tool##*/}"; tool="${tool%%@*}"
  rest="${tok[*]:1}"
  local -a args=("${tok[@]:1}")

  # Deny verbs are matched anywhere in the arguments, so flag parsing never
  # decides the outcome. A package genuinely named like a verb goes through
  # the gate command, which is what the gate is for.
  case "$tool" in
    pnpm)
      has_any "$rest" add update up import link ln remove rm uninstall un dlx dedupe it install-test && deny "$seg"
      if has_any "$rest" install i; then has_flag --frozen-lockfile "${args[@]+"${args[@]}"}" || deny "$seg"; fi ;;
    npm)
      has_any "$rest" install i in ins inst insta instal isnt isnta isntal isntall add install-test it update up upgrade udpate uninstall un unlink remove rm r link ln exec x dedupe ddp && deny "$seg"
      if has_any "$rest" audit && has_any "$rest" fix; then deny "$seg"; fi ;;
    npx|bunx|uvx) deny "$seg" ;;
    yarn)
      has_any "$rest" add up upgrade upgrade-interactive remove import dlx dedupe && deny "$seg"
      # "yarn" alone or "yarn install" installs; only the immutable form is faithful to the lockfile.
      if has_any "$rest" install || ! printf '%s\n' "${args[@]+"${args[@]}"}" | grep -qvE '^(-|$)'; then
        has_flag --immutable "${args[@]+"${args[@]}"}" || has_flag --frozen-lockfile "${args[@]+"${args[@]}"}" || deny "$seg"
      fi ;;
    bun)
      has_any "$rest" add a update remove rm x && deny "$seg"
      if has_any "$rest" install i; then has_flag --frozen-lockfile "${args[@]+"${args[@]}"}" || deny "$seg"; fi ;;
    go)
      has_any "$rest" get && deny "$seg"
      if has_any "$rest" mod; then has_any "$rest" tidy edit vendor && deny "$seg"; fi
      if has_any "$rest" work; then has_any "$rest" sync && deny "$seg"; fi
      if has_any "$rest" install run; then
        if printf '%s\n' "${args[@]+"${args[@]}"}" | grep -qE '^[^[:space:]-][^[:space:]]*@[^[:space:]]+$'; then deny "$seg"; fi
      fi ;;
    uv)
      has_any "$rest" add remove lock && deny "$seg"
      if has_any "$rest" pip; then has_any "$rest" install sync && deny "$seg"; fi
      if has_any "$rest" tool; then has_any "$rest" install run && deny "$seg"; fi
      if has_any "$rest" run; then has_any "$rest" --with --with-requirements --with-editable && deny "$seg"; fi
      if has_any "$rest" sync; then has_flag --locked "${args[@]+"${args[@]}"}" || has_flag --frozen "${args[@]+"${args[@]}"}" || deny "$seg"; fi ;;
    pip|pip3)
      has_any "$rest" install && deny "$seg" ;;
    pipx)
      has_any "$rest" install run && deny "$seg" ;;
    python|python[0-9]*)
      if has_any "$rest" -m && has_any "$rest" pip && has_any "$rest" install; then deny "$seg"; fi ;;
    poetry)
      has_any "$rest" add remove update lock && deny "$seg" ;;
    pipenv)
      has_any "$rest" install update lock sync && deny "$seg" ;;
    pdm)
      has_any "$rest" add remove update lock sync install && deny "$seg" ;;
  esac
  return 0
}

judge_command "$cmd"
exit 0
