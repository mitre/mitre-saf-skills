#!/usr/bin/env python3
"""Tests for claude-config-sync.sh — the hook that keeps chezmoi's copy of ~/.claude current.

The properties that matter are as much about what it must NOT do as what it does:
it must never commit, never push, and never be able to block a session. Those are
asserted directly, with a stub chezmoi and a stub git recording every invocation.
"""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HOOKS_DIR = Path(__file__).resolve().parent.parent
HOOK = HOOKS_DIR / "claude-config-sync.sh"

# Stubs record their argv so the test can assert which subcommands ran.
STUB = """#!/usr/bin/env bash
echo "$(basename "$0") $*" >> "$CALL_LOG"
case "$1" in
  source-path) echo "$FAKE_SOURCE" ;;
esac
exit ${STUB_EXIT:-0}
"""


def run(tmp, *args, chezmoi=True, source=None, stub_exit=0, home=None):
    tmp = Path(tmp)
    bindir = tmp / "bin"
    bindir.mkdir(exist_ok=True)
    log = tmp / "calls.log"
    log.touch()
    for name in (["chezmoi"] if chezmoi else []) + ["git"]:
        p = bindir / name
        p.write_text(STUB)
        p.chmod(0o755)
    env = dict(os.environ,
               PATH=f"{bindir}{os.pathsep}/usr/bin:/bin",
               CALL_LOG=str(log),
               FAKE_SOURCE=str(source if source is not None else tmp / "source"),
               STUB_EXIT=str(stub_exit),
               HOME=str(home or tmp))
    p = subprocess.run(["bash", str(HOOK), *args], capture_output=True, text=True,
                       env=env, timeout=60)
    return p.returncode, p.stdout + p.stderr, log.read_text()


CASES = []


def case(name):
    def wrap(fn):
        CASES.append((name, fn))
        return fn
    return wrap


@case("1. no chezmoi installed -> silent success, nothing attempted")
def _(tmp):
    rc, out, calls = run(tmp, chezmoi=False)
    assert rc == 0, f"exit {rc}"
    assert out.strip() == "", f"must stay quiet on machines without chezmoi: {out[:120]!r}"


@case("2. a source dir that does not exist -> silent success")
def _(tmp):
    rc, out, calls = run(tmp, source=Path(tmp) / "nope")
    assert rc == 0 and out.strip() == "", f"got rc={rc} out={out[:120]!r}"


@case("3. capture re-adds modified managed files")
def _(tmp):
    (Path(tmp) / "source").mkdir()
    rc, out, calls = run(tmp, "--capture")
    assert rc == 0
    assert "chezmoi re-add" in calls, f"calls were: {calls!r}"


@case("4. capture ALSO adds memory dirs, so a new project's memory is not missed")
def _(tmp):
    (Path(tmp) / "source").mkdir()
    mem = Path(tmp) / ".claude/projects/-Some-Slug/memory"
    mem.mkdir(parents=True)
    (mem / "MEMORY.md").write_text("x")
    rc, out, calls = run(tmp, "--capture", home=tmp)
    assert "chezmoi add" in calls, f"new memory must be added, calls: {calls!r}"
    assert "-Some-Slug/memory" in calls


@case("5. capture SKIPS symlinked memory dirs (they are stored as links, not copied)")
def _(tmp):
    (Path(tmp) / "source").mkdir()
    projects = Path(tmp) / ".claude/projects"
    real = projects / "-Real/memory"
    real.mkdir(parents=True)
    (projects / "-Linked").mkdir()
    (projects / "-Linked/memory").symlink_to(real)
    rc, out, calls = run(tmp, "--capture", home=tmp)
    assert "-Real/memory" in calls
    assert "-Linked/memory" not in calls, \
        "following the symlink would store a second copy of the same memory"


@case("6. it NEVER commits and NEVER pushes")
def _(tmp):
    (Path(tmp) / "source").mkdir()
    mem = Path(tmp) / ".claude/projects/-S/memory"
    mem.mkdir(parents=True)
    rc, out, calls = run(tmp, home=tmp)
    assert "commit" not in calls, f"a sync hook must not commit; calls: {calls!r}"
    assert "push" not in calls, f"a sync hook must not push; calls: {calls!r}"


@case("7. a failing chezmoi never blocks the session")
def _(tmp):
    (Path(tmp) / "source").mkdir()
    rc, out, calls = run(tmp, stub_exit=1)
    assert rc == 0, f"hook must exit 0 even when chezmoi fails; got {rc}"


@case("8. report is silent when there is nothing to say")
def _(tmp):
    # git stub returns empty status and no ahead count -> nothing to report
    (Path(tmp) / "source").mkdir()
    rc, out, calls = run(tmp, "--report")
    assert rc == 0
    assert "dotfiles" not in out, f"no news should be no output; got {out[:160]!r}"


fails = 0
for name, fn in CASES:
    with tempfile.TemporaryDirectory() as tmp:
        try:
            fn(tmp)
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
