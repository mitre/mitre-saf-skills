#!/usr/bin/env python3
"""Tests for validate-bd-create.sh — the 12-section card gate.

WHY THIS FILE EXISTS (2026-08-11). The hook reads the description out of a file when the
command passes it by substitution (`--description="$(cat /path/card.md)"`), because that is
the flow project-card mandates — a card body must never travel through a shell heredoc,
where backticks in card prose execute and safety tooling matches ordinary English inside
the text. The path pattern accepted only a literal `/tmp/...`. On macOS the per-session
scratchpad is `/private/tmp/...` (and `/tmp` is merely a symlink to it), so the file was
never read, and the hook reported all twelve sections missing on a card that had all
twelve. The failure pushed the author toward exactly the two things the rules forbid: an
inline heredoc, or hard-coding a directory.

This hook signals with exit codes, not JSON: 0 allows, 2 blocks with the reason on stderr.
"""
import json
import os
import subprocess
import sys
import tempfile

HOOKS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

HOOK = os.path.join(HOOKS_DIR, "validate-bd-create.sh")

SECTIONS = """Title: Do the thing — context

Description:
Two sentences about the thing.

Files:
- Create: none

First failing test:
`1. it fails first`

Acceptance criteria:
- [ ] it works

Verification:
`make test`

Decision points:
- none

Anti-patterns:
- Do NOT optimize for card-close velocity or speed

NOT in scope:
- everything else

Before closing:
- [ ] evidence pasted

Story points: sp:1
Estimate: 5 minutes
"""


def run(command):
    """Returns (exit_code, stderr). 0 = allow, 2 = block."""
    payload = {"tool_name": "Bash", "tool_input": {"command": command},
               "session_id": "hooktest"}
    p = subprocess.run(["bash", HOOK], input=json.dumps(payload),
                       capture_output=True, text=True, timeout=30)
    return p.returncode, p.stderr


CASES = []


def case(name):
    def wrap(fn):
        CASES.append((name, fn))
        return fn
    return wrap


@case("1. a card with all twelve sections inline is allowed")
def _(tmp):
    rc, _err = run(f'bd create --title="t" --description="{SECTIONS}" --type=task')
    assert rc == 0, f"expected allow, got exit {rc}"


@case("2. REGRESSION: a description read from /private/tmp is found and allowed")
def _(tmp):
    # The bug: the path pattern matched only a literal /tmp/, so this file — a real,
    # complete card body — was never opened and every section reported missing.
    path = os.path.join(tmp, "card-desc.md")
    with open(path, "w") as fh:
        fh.write(SECTIONS)
    rc, err = run(f'bd create --title="t" --description="$(cat {path})" --type=task')
    assert rc == 0, f"a complete card body at {path} must be read, not ignored: {err[:200]}"


@case("3. a card missing sections is blocked, and says which")
def _(tmp):
    rc, err = run('bd create --title="t" --description="just a sentence" --type=task')
    assert rc == 2, f"expected block, got exit {rc}"
    assert "Acceptance criteria:" in err, "the block must name what is missing"


@case("4. a substitution pointing at a MISSING file fails CLOSED")
def _(tmp):
    missing = os.path.join(tmp, "not-here.md")
    rc, _err = run(f'bd create --title="t" --description="$(cat {missing})" --type=task')
    assert rc == 2, "an unreadable body must block, never pass as empty"


@case("5. unrelated commands are not touched")
def _(tmp):
    for cmd in ("git status --short", "bd list --status open",
                "bd update x --append-notes hello"):
        rc, _err = run(cmd)
        assert rc == 0, f"{cmd!r} should be allowed, got exit {rc}"


fails = 0
for name, fn in CASES:
    with tempfile.TemporaryDirectory() as tmpdir:
        try:
            fn(tmpdir)
            print(f"ok   {name}")
        except AssertionError as exc:
            fails += 1
            print(f"FAIL {name}\n        {exc}")
        except Exception as exc:
            fails += 1
            print(f"FAIL {name}\n        {type(exc).__name__}: {exc}")

print()
print(f"{len(CASES) - fails}/{len(CASES)} cases pass")
sys.exit(1 if fails else 0)
