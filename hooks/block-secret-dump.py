#!/usr/bin/env python3
"""PreToolUse hook: block Bash commands that dump environment variables / secrets to output.

Created 2026-07-21 after a bare `env` in a compound command printed the whole environment
(live API tokens) into the session transcript.

Two-tier detection, mirroring how Claude Code's own permission walker ASTs bash:
  1. PRIMARY — parse the command with bashlex (a real bash AST). This distinguishes `env`
     used as a DUMP (a command node with no program argument) from `env <program>` used to
     run something (safe), and ignores comments / quoted text. Precise, few false positives.
  2. FALLBACK — if bashlex is missing or cannot parse the command, a conservative regex scan
     runs instead. A security hook must never fail open: parse failure => regex still checks.

Blocks: bare `env` (incl. `env |`, `env >`, `env 2>`, `env -i`), `printenv`, bare `set`,
bare `export`, `declare -p` / `typeset -p`, and reads of /proc/*/environ.
Allows: `env <program> ...` (incl. `env curl`), `env VAR=val program`, `set -euo pipefail`,
`export FOO=bar`, and env/printenv appearing as arguments or in comments.
"""
import json
import re
import sys

_ASSIGN = re.compile(r"^[A-Za-z_]\w*=")
_PROC_ENVIRON = re.compile(r"/proc/[^/\s]*/environ")

# ---------------------------------------------------------------------------
# Fallback regex layer (used only when the AST parser is unavailable/failing).
# ---------------------------------------------------------------------------
_B = r"(?:^|[\s;&|(`])"
_REGEX_PATTERNS = [
    (re.compile(_B + r"env(?:\s+-\S+)*\s*(?:\d*[<>]|[|;&)]|$)"),
     "bare `env` prints ALL environment variables (secrets) to output"),
    (re.compile(_B + r"printenv\b"),
     "`printenv` prints environment variables (secrets) to output"),
    (re.compile(_B + r"set\s*(?:\d*[<>]|[|;&)]|$)"),
     "bare `set` dumps all shell variables (secrets) to output"),
    (re.compile(_B + r"export\s*(?:\d*[<>]|[|;&)]|$)"),
     "bare `export` lists all exported variables (secrets) to output"),
    (re.compile(r"\b(?:declare|typeset)\s+-\S*p\b"),
     "`declare -p` / `typeset -p` dump all variables (secrets) to output"),
    (_PROC_ENVIRON,
     "reading /proc/*/environ exposes a process environment (secrets)"),
]


def _regex_verdict(command):
    for pattern, reason in _REGEX_PATTERNS:
        if pattern.search(command):
            return reason
    return None


# ---------------------------------------------------------------------------
# Primary AST layer (bashlex).
# ---------------------------------------------------------------------------
def _ast_verdict(command):
    """Return a block reason, or None. Raises if bashlex is missing or can't parse."""
    import bashlex  # ImportError -> caller falls back to regex

    def is_node(x):
        return isinstance(x, bashlex.ast.node)

    def walk(node):
        yield node
        for value in vars(node).values():
            if is_node(value):
                yield from walk(value)
            elif isinstance(value, (list, tuple)):
                for item in value:
                    if is_node(item):
                        yield from walk(item)

    trees = bashlex.parse(command)  # ParsingError -> caller falls back to regex
    for tree in trees:
        for node in walk(tree):
            if getattr(node, "kind", None) != "command":
                continue
            words = [p.word for p in node.parts if p.kind == "word"]
            for w in words:
                if _PROC_ENVIRON.search(w):
                    return "reading /proc/*/environ exposes a process environment (secrets)"
            if not words:
                continue
            name, args = words[0], words[1:]
            if name == "env":
                runs_program = any(
                    not a.startswith("-") and not _ASSIGN.match(a) for a in args
                )
                if not runs_program:
                    return "bare `env` prints ALL environment variables (secrets) to output"
            elif name == "printenv":
                return "`printenv` prints environment variables (secrets) to output"
            elif name == "set" and not args:
                return "bare `set` dumps all shell variables (secrets) to output"
            elif name == "export" and not args:
                return "bare `export` lists all exported variables (secrets) to output"
            elif name in ("declare", "typeset") and any(
                a.startswith("-") and "p" in a for a in args
            ):
                return "`declare -p` / `typeset -p` dump all variables (secrets) to output"
    return None


def _verdict(command):
    try:
        return _ast_verdict(command)  # precise; trusted when it parses
    except Exception:
        return _regex_verdict(command)  # never fail open


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    if data.get("tool_name") not in (None, "Bash"):
        sys.exit(0)
    command = (data.get("tool_input") or {}).get("command", "")
    if not isinstance(command, str) or not command:
        sys.exit(0)

    reason = _verdict(command)
    if reason:
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"BLOCKED: {reason}. This would leak secrets into the transcript. "
                    "To run a program with env vars use `env VAR=val program ...`; "
                    "to read ONE non-secret var, echo it explicitly and deliberately."
                ),
            },
        }))
    sys.exit(0)


if __name__ == "__main__":
    main()
