#!/usr/bin/env python3
"""Tests for scripts/compare-skill-copies.sh — the three-way skill divergence report.

WHY THIS FILE EXISTS (2026-08-12). The skill collection lives in three places that have
drifted apart: the installed copies under ~/.claude/skills, this repository's skills/, and
the public origin/main. Every card in epic mitre-saf-skills-97y ends with a claim of the
form "these two copies now agree", and this repo has no compiler and no linter to check
such a claim — so without this script those cards would close on an eyeball. `--expect-clean
<skill>` is their mechanical Verification command.

The script must also survive being run somewhere that is not the author's laptop: the
installed root is taken from CLAUDE_SKILLS_DIR, the repo root from SKILL_REPO_DIR, and the
upstream ref from SKILL_ORIGIN_REF, each with a sane default. A missing upstream ref
degrades the report to two columns rather than failing, because a fresh clone that has not
fetched is a normal state, not an error.

This script signals with exit codes: 0 = the asserted condition holds, 1 = it does not. The
bare report always exits 0 — divergence is information, not a failure.

A NOTE ON EXIT 1 vs "any non-zero": the first draft of case 1 asserted only `rc != 0`, and
it passed while the script did not exist at all — bash exits 127 for a missing file, which
is also non-zero. That is precisely how this repository's earlier hook suite pointed at a
deleted hook and reported green for weeks. Cases therefore assert the SPECIFIC exit code
the script defines, and the runner refuses to start if the script is missing.
"""
import os
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(REPO_ROOT, "scripts", "compare-skill-copies.sh")

NOT_CLEAN = 1  # the script's "asserted condition does not hold" code; 127 is bash-not-found


def run(args, installed, repo, origin_ref="__no_such_ref__"):
    """Returns (exit_code, stdout, stderr)."""
    env = dict(os.environ)
    env["CLAUDE_SKILLS_DIR"] = installed
    env["SKILL_REPO_DIR"] = repo
    env["SKILL_ORIGIN_REF"] = origin_ref
    p = subprocess.run(["bash", SCRIPT] + args, capture_output=True, text=True,
                       timeout=60, env=env, cwd=REPO_ROOT)
    return p.returncode, p.stdout, p.stderr


def make_skill(root, name, body):
    d = os.path.join(root, name)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "SKILL.md"), "w") as fh:
        fh.write(body)


CASES = []


def case(name):
    def wrap(fn):
        CASES.append((name, fn))
        return fn
    return wrap


@case("1. --expect-clean exits NON-ZERO when the two copies differ")
def _(tmp):
    installed, repo = os.path.join(tmp, "i"), os.path.join(tmp, "r")
    make_skill(installed, "widget", "# Widget\n\nInstalled has an extra line.\n")
    make_skill(repo, "widget", "# Widget\n")
    rc, out, err = run(["--expect-clean", "widget"], installed, repo)
    assert rc == NOT_CLEAN, \
        f"differing copies must exit {NOT_CLEAN}, got {rc} (127 means the script is missing)"
    assert "widget" in (out + err), "the failure must name the skill it checked"


@case("2. --expect-clean exits ZERO when the two copies are byte-identical")
def _(tmp):
    installed, repo = os.path.join(tmp, "i"), os.path.join(tmp, "r")
    body = "# Widget\n\nSame on both sides.\n"
    make_skill(installed, "widget", body)
    make_skill(repo, "widget", body)
    rc, _out, err = run(["--expect-clean", "widget"], installed, repo)
    assert rc == 0, f"identical copies must report clean, got exit {rc}: {err[:300]}"


@case("3. a divergence names BOTH paths, so the operator can diff them")
def _(tmp):
    installed, repo = os.path.join(tmp, "i"), os.path.join(tmp, "r")
    make_skill(installed, "widget", "# Widget\n\nextra\n")
    make_skill(repo, "widget", "# Widget\n")
    _rc, out, err = run(["--expect-clean", "widget"], installed, repo)
    combined = out + err
    assert os.path.join(installed, "widget", "SKILL.md") in combined, \
        "the installed path must be named"
    assert os.path.join(repo, "widget", "SKILL.md") in combined, \
        "the repo path must be named"


@case("4. --expect-clean on a skill missing from a side fails, and says which side")
def _(tmp):
    installed, repo = os.path.join(tmp, "i"), os.path.join(tmp, "r")
    make_skill(repo, "widget", "# Widget\n")
    os.makedirs(installed, exist_ok=True)
    rc, out, err = run(["--expect-clean", "widget"], installed, repo)
    assert rc == NOT_CLEAN, \
        f"a skill present on only one side must exit {NOT_CLEAN}, got {rc}"
    assert "widget" in (out + err), "the failure must name the skill"


@case("5. the bare report lists skills present in ONLY one location, and exits 0")
def _(tmp):
    installed, repo = os.path.join(tmp, "i"), os.path.join(tmp, "r")
    make_skill(installed, "only-installed", "# A\n")
    make_skill(repo, "only-repo", "# B\n")
    rc, out, err = run([], installed, repo)
    assert rc == 0, f"the bare report is information, not a gate; got exit {rc}: {err[:300]}"
    assert "only-installed" in out, "a skill present only installed must still be listed"
    assert "only-repo" in out, "a skill present only in the repo must still be listed"


@case("6. an absent upstream ref degrades to a report, never an error")
def _(tmp):
    installed, repo = os.path.join(tmp, "i"), os.path.join(tmp, "r")
    body = "# Widget\n"
    make_skill(installed, "widget", body)
    make_skill(repo, "widget", body)
    rc, out, err = run([], installed, repo, origin_ref="refs/heads/definitely-not-a-ref")
    assert rc == 0, f"a fresh unfetched clone is normal, not an error: {err[:300]}"
    assert "widget" in out, "the two-column report must still name the skill"


@case("7. the script carries no hardcoded personal path")
def _(tmp):
    with open(SCRIPT) as fh:
        source = fh.read()
    assert "/Users/" not in source, \
        "a public repo must not carry an absolute personal path (standing rule)"


if not os.path.isfile(SCRIPT):
    # Refuse to run rather than let every case pass or fail for the wrong reason. A suite
    # whose subject is absent reports nothing useful, and reporting it as a normal failure
    # is how a missing control gets mistaken for a passing one.
    print(f"FATAL {SCRIPT} does not exist — the suite has no subject")
    sys.exit(1)

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
