#!/usr/bin/env python3
"""Tests for the four session and compaction hooks.

WHY THIS FILE EXISTS (2026-08-12). These four shipped with no tests at all, and one of
them had already silently regressed: a stale copy of pre-compact-save-state.sh, stored in
a second repository, still contained the ORIGINAL behavior of writing
.beads/recovery-context.md itself. That behavior was deliberately removed — writing
recovery files belongs to the /prepare-compact skill the user invokes, never to a hook
that fires automatically — and an apply from that second copy would have restored it
without a word. Case 9 below is that regression, pinned.

These hooks act on the CURRENT WORKING DIRECTORY (.beads, .claude/settings.local.json),
so every case runs them in a scratch directory. post-compact shells out to `bd`, so a
stub goes on PATH: the tests stay hermetic and never touch a real board.
"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HOOKS_DIR = Path(__file__).resolve().parent.parent

PRE_COMPACT = HOOKS_DIR / "pre-compact-save-state.sh"
POST_COMPACT = HOOKS_DIR / "post-compact-restore-state.sh"
SESSION_RULES = HOOKS_DIR / "session-start-rules.sh"
VALIDATE_SETTINGS = HOOKS_DIR / "validate-settings.sh"

BD_STUB = "#!/usr/bin/env bash\nexit 0\n"


def run(hook, cwd, env_extra=None):
    """Run a hook with cwd set to the scratch dir and a stub bd on PATH."""
    bindir = Path(cwd) / "stubbin"
    bindir.mkdir(exist_ok=True)
    bd = bindir / "bd"
    bd.write_text(BD_STUB)
    bd.chmod(0o755)
    env = dict(os.environ, PATH=f"{bindir}{os.pathsep}{os.environ['PATH']}")
    env.update(env_extra or {})
    p = subprocess.run(["bash", str(hook)], cwd=cwd, capture_output=True,
                       text=True, env=env, timeout=60)
    return p.returncode, p.stdout + p.stderr


CASES = []


def case(name):
    def wrap(fn):
        CASES.append((name, fn))
        return fn
    return wrap


# --- session-start-rules.sh -------------------------------------------------

@case("1. session-start prints the authorship rules verbatim")
def _(d):
    rc, out = run(SESSION_RULES, d)
    assert rc == 0, f"exit {rc}"
    for required in ("Co-Authored-By: Claude",
                     "Authored by: Aaron Lippold",
                     "Human authorship attribution ONLY"):
        assert required in out, f"missing from output: {required!r}"


@case("2. session-start notes a project CLAUDE.md when one is present")
def _(d):
    rc, out = run(SESSION_RULES, d)
    assert "Project CLAUDE.md detected" not in out, "should not claim one without the file"
    (Path(d) / "CLAUDE.md").write_text("# project rules\n")
    rc, out = run(SESSION_RULES, d)
    assert rc == 0 and "Project CLAUDE.md detected" in out


# --- validate-settings.sh ---------------------------------------------------

@case("3. validate-settings is silent and passes when there is no settings file")
def _(d):
    rc, out = run(VALIDATE_SETTINGS, d)
    assert rc == 0, f"exit {rc}"
    assert out.strip() == "", f"expected silence, got: {out[:120]!r}"


@case("4. validate-settings passes on well-formed JSON")
def _(d):
    p = Path(d) / ".claude"
    p.mkdir()
    (p / "settings.local.json").write_text(json.dumps({"permissions": {"allow": ["Bash(ls:*)"]}}))
    rc, out = run(VALIDATE_SETTINGS, d)
    assert rc == 0, f"exit {rc}: {out[:160]}"


@case("5. validate-settings FAILS on corrupt JSON and says so")
def _(d):
    p = Path(d) / ".claude"
    p.mkdir()
    (p / "settings.local.json").write_text('{"permissions": {"allow": [')
    rc, out = run(VALIDATE_SETTINGS, d)
    assert rc == 1, f"corrupt JSON must fail; exit {rc}"
    assert "corrupted" in out, f"must name the problem; got {out[:160]!r}"


@case("6. validate-settings catches the heredoc corruption bd commands can cause")
def _(d):
    # The incident behind this: running bd with a heredoc inline wrote shell text
    # into settings.local.json. Valid JSON is not enough — the content is wrong.
    p = Path(d) / ".claude"
    p.mkdir()
    (p / "settings.local.json").write_text(json.dumps({"note": "cat > /tmp/x <<'EOF'"}))
    rc, out = run(VALIDATE_SETTINGS, d)
    assert rc == 1, f"heredoc contamination must fail; exit {rc}"
    assert "heredoc" in out.lower(), f"must name the cause; got {out[:160]!r}"


# --- pre-compact-save-state.sh ----------------------------------------------

@case("7. pre-compact does nothing outside a beads project")
def _(d):
    rc, out = run(PRE_COMPACT, d)
    assert rc == 0, f"exit {rc}"
    assert out.strip() == "", f"expected silence outside .beads projects, got {out[:120]!r}"


@case("8. pre-compact reminds you to run /prepare-compact")
def _(d):
    (Path(d) / ".beads").mkdir()
    rc, out = run(PRE_COMPACT, d)
    assert rc == 0
    assert "REMINDER" in out and "/prepare-compact" in out


@case("9. REGRESSION: pre-compact must NOT write recovery files itself")
def _(d):
    # The behavior deliberately removed. Writing recovery state is the
    # /prepare-compact SKILL's job, invoked by the user; a hook that fires
    # automatically must never do it. A stale copy of this hook carrying the old
    # behavior was found in a second repo on 2026-08-12 and would have been applied
    # over the corrected one.
    beads = Path(d) / ".beads"
    beads.mkdir()
    rc, out = run(PRE_COMPACT, d)
    assert rc == 0
    written = sorted(p.name for p in beads.iterdir())
    assert written == [], f"the hook must not create files in .beads/, but created: {written}"


@case("10. pre-compact reports a detailed recovery file as good")
def _(d):
    beads = Path(d) / ".beads"
    beads.mkdir()
    (beads / "recovery-context.md").write_text("\n".join(f"line {i}" for i in range(40)))
    rc, out = run(PRE_COMPACT, d)
    assert "Detailed recovery-context.md found" in out, f"got {out[:200]!r}"


@case("11. pre-compact warns when the recovery file is missing or too thin")
def _(d):
    beads = Path(d) / ".beads"
    beads.mkdir()
    rc, out = run(PRE_COMPACT, d)
    assert "No detailed recovery-context.md" in out, "missing file must warn"

    (beads / "recovery-context.md").write_text("too\nshort\n")
    rc, out = run(PRE_COMPACT, d)
    assert "No detailed recovery-context.md" in out, \
        "a stub file must warn too — its presence is not evidence of content"


# --- post-compact-restore-state.sh ------------------------------------------

@case("12. post-compact does nothing outside a beads project")
def _(d):
    rc, out = run(POST_COMPACT, d)
    assert rc == 0, f"exit {rc}"
    assert "Restoring context" not in out


@case("13. post-compact emits the recovery file's contents into context")
def _(d):
    beads = Path(d) / ".beads"
    beads.mkdir()
    (beads / "recovery-context.md").write_text("# RECOVERY\nDISTINCTIVE-MARKER-9137\n")
    rc, out = run(POST_COMPACT, d)
    assert rc == 0
    assert "DISTINCTIVE-MARKER-9137" in out, \
        "the whole point is putting the file into context; got: " + out[:200]


@case("14. post-compact explains itself when there is no recovery file")
def _(d):
    (Path(d) / ".beads").mkdir()
    rc, out = run(POST_COMPACT, d)
    assert rc == 0
    assert "No recovery file found" in out, f"got {out[:200]!r}"


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
