# Agent install hook

Read this when fixing G-07 or when an agent reports that an install command was blocked.

## What it does

`scripts/dep-gate-hook.sh` runs before every shell command the agent harness executes. It reads the pending command, splits it on `&&`, `||`, `;`, and `|`, and denies any segment that can add or change dependencies. The denial message names the gate command to use instead. The only path to a new dependency is `scripts/dep-gate.sh`, the dispatcher that routes to the language gate (`scripts/dep-gate-javascript.sh`, `scripts/dep-gate-go.sh`), which resolves, evaluates, and then installs or verifies.

The hook judges each segment by its command word, taken by basename so `/usr/local/bin/pnpm` and `./node_modules/.bin/npm` count, after stripping leading environment assignments and transparent prefixes together with their own options (`env -i`, `env -u NAME`, `time -p`, `nohup`, `nice -5`, `sudo -u NAME`, `doas`, `command`, `exec`, `corepack`, `timeout -s SIG 5m`). Deny verbs are matched anywhere in the arguments rather than at a fixed position, so global flags before the verb (`pnpm -r add`, `pnpm -w add`, `pnpm --filter a add`, `npm --prefix dir install`, `uv --directory x add`) cannot hide it, and flag semantics that differ between tools do not matter. The price is a false positive for a script or package literally named like a verb, such as `pnpm run add`; the message explains it and the gate command still works. Shell wrappers (`bash -c`, `sh -c`, `eval`) are judged on the string they run. Grouping and substitution characters, parentheses, braces, `$( )`, and backticks, are treated as separators, so `(pnpm add x)` and `echo $(pnpm add x)` are judged on the inner command. A frozen or locked flag counts only bare or as `=true`; a `--no-` form, an `=false`, or a following literal `false` anywhere in the command negates it, because pnpm honours the last flag given. If the hook input cannot be read as a shell command the hook denies, so a malformed payload fails closed.

Denied, by tool. pnpm: `add update up import link ln remove rm uninstall un dlx dedupe it install-test`, and `install`/`i` without a true `--frozen-lockfile`. npm: `install` and its abbreviations (`i in ins inst insta instal isnt isnta isntal isntall`), `add install-test it update up upgrade udpate uninstall un unlink remove rm r link ln exec x dedupe ddp`, and `audit fix`; `npx` always. yarn: `add up upgrade upgrade-interactive remove import dlx dedupe`, and `install` or a bare `yarn` without a true `--immutable` or `--frozen-lockfile`. bun: `add a update remove rm x`, and `install`/`i` without a true `--frozen-lockfile`; `bunx` always. go: `get`, `mod tidy|edit|vendor`, `work sync`, and `install` or `run` with a `module@version` argument. uv: `add remove lock`, `pip install|sync`, `tool install|run`, `run` with `--with`, `--with-requirements`, or `--with-editable`, and `sync` without a true `--locked` or `--frozen`; `uvx` always. pip and pip3: `install`; `python -m pip install` for any `python` or `pythonX.Y`; pipx `install run`; pipenv `install update lock sync`; pdm `add remove update lock sync install`. poetry: `add remove update lock`.

The exact lists are the `case` blocks in the script; this paragraph is a summary and the script is the source of truth.

Allowed because they install exactly the committed lockfile and fail if it is stale: `pnpm install --frozen-lockfile`, `npm ci`, `yarn install --immutable`, `bun install --frozen-lockfile`, `go mod download|verify|graph|why`, `go build|test|run` of local packages, `uv sync --locked|--frozen`, `poetry install`.

A plain `pnpm install`, `npm install`, or `uv sync` is denied on purpose. A manifest edited by hand followed by a plain install adds a dependency the gate never evaluated. The frozen or locked forms refuse to run when the manifest and lockfile disagree, which is what makes them safe to allow.

## Installing it

1. Copy `assets/common/dep-gate-hook.sh` to `scripts/dep-gate-hook.sh` in the repo and keep it executable.
2. Merge `assets/common/claude-settings-hook.json` into the harness's project settings file. For Claude Code that file is `.claude/settings.json` at the repo root. The snippet uses `$CLAUDE_PROJECT_DIR`, which the harness sets, so it works from any working directory.
3. Run the verifier; G-07 must PASS.

If the settings file does not exist, copy the snippet as the whole file. If it exists, add the `PreToolUse` entry without disturbing existing hooks. With jq:

```bash
# SNIPPET is this skill's assets/common/claude-settings-hook.json
jq -s '.[0] * {hooks: {PreToolUse: ((.[0].hooks.PreToolUse // []) + .[1].hooks.PreToolUse)}}' \
  .claude/settings.json "$SNIPPET" > .claude/settings.json.new \
  && mv .claude/settings.json.new .claude/settings.json
```

Without jq, open the file and append the object inside the snippet's `PreToolUse` array to the existing `PreToolUse` array, creating the `hooks` and `PreToolUse` keys if they are missing. The verifier checks that the `dep-gate` reference sits inside the `PreToolUse` block specifically; a reference under another hook event does not count.

## Testing it by hand

```bash
printf '{"tool_name":"Bash","tool_input":{"command":"pnpm add left-pad"}}' | bash scripts/dep-gate-hook.sh; echo "exit=$?"
# exit=2 and a message naming scripts/dep-gate.sh
printf '{"tool_name":"Bash","tool_input":{"command":"pnpm install --frozen-lockfile"}}' | bash scripts/dep-gate-hook.sh; echo "exit=$?"
# exit=0
```

Exit 2 is the harness convention for "deny and show the agent the stderr message". Exit 0 allows. The hook never exits 1.

## Limits

- The hook sees the command text, not its effect. An install hidden inside a script file, a Makefile target, a package.json script, or an alias is not caught; the CI gate on the lockfile diff is the layer that catches those.
- Only the command word is judged, so `echo "npm install"` is allowed and `bash -c "npm install"` is denied. Wrappers other than the shells, `eval`, and the prefixes listed above, such as `xargs`, `find -exec`, `script`, or `expect`, are not unwrapped.
- The verb lists are per tool and explicit. A new package manager or a new verb needs a case in the hook and tests in `scripts/tests/run.sh`.
- Some commands change dependencies as a side effect and are not denied: `go build -mod=mod` or `GOFLAGS=-mod=mod` add modules to go.mod, and `uv run <anything>` syncs a hand-edited pyproject unless `--locked`, `--frozen`, or `--no-sync` is given. The Go and Python references close these in their toolchain configuration (`GOFLAGS=-mod=readonly` is the Go default; the gate's CI check catches the lockfile change either way).
- Only harnesses with pre-command hooks can enforce this. For one without, the rule lives in the agent instructions file alone (G-11), which is advisory. Say so in the handoff when setting up such a repo.
- Ruby, Rust, and other ecosystems are not yet in the deny list. Add a case block and tests in `scripts/tests/run.sh` when adding a language reference.
