#!/usr/bin/env python3
"""Behavioral tests for ac-gate-tiered.sh — the tiers, exercised against a stub board.

WHY THIS FILE EXISTS (2026-08-11). The committed suite (test_ac_gate_hook.py) pointed at
ac-gate-human-only.sh, which this hook REPLACED and which no longer exists. A missing
hook emits nothing, and the harness reads silence as ALLOW — so its five ALLOW cases
passed vacuously while its seven DENY cases failed unnoticed. The tiered gate itself had
no tests at all. That is how the credit defect shipped and survived.

The gate consults the board (`bd show`, `bd label list`), so these cases put a stub `bd`
on PATH: the tiers become testable without touching the real board, and no case depends
on live card state. Paths that additionally require the canonical generator and a git
tree (stale-hash, and the clean ALLOW-and-record path) are NOT covered here — see the
follow-up card; this file states that gap rather than implying coverage it lacks.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

HOOKS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

HOOK = os.path.join(HOOKS_DIR, "ac-gate-tiered.sh")


def unaudited_budget():
    """Read the budget out of the hook instead of hardcoding it.

    These cases previously seeded a literal 5 entries, so raising
    UNAUDITED_BUDGET turned case 4 red for no reason but the constant moving
    (2026-08-15, 5 -> 10). The BEHAVIOUR under test is "deny at the budget,
    do not deny below it"; the number itself is configuration, so the test
    reads it rather than restating it.
    """
    with open(HOOK) as fh:
        for line in fh:
            if line.startswith("UNAUDITED_BUDGET="):
                return int(line.split("=", 1)[1].split("#", 1)[0].strip())
    raise AssertionError("UNAUDITED_BUDGET not found in the hook")


BUDGET = unaudited_budget()

GATE_DESC = """○ {gid} · Gate: human   [P2 · OPEN]
Type: gate
Reason: AC verification required — run /project-ac-verify {card}
blocking {card}
"""

BD_STUB = """#!/usr/bin/env bash
# Stub board. `bd show GATE-1` describes one AC-verify gate; `bd label list CARD-1`
# returns whatever labels the case asked for; everything else is quiet.
if [ "$1" = "show" ] && [ "$2" = "GATE-1" ]; then
  cat "$BD_STUB_GATE"
elif [ "$1" = "label" ] && [ "$2" = "list" ]; then
  printf '%s\\n' "$BD_STUB_LABELS"
fi
exit 0
"""


def ledger_key(state):
    """The key the hook will derive when run with cwd=state (a non-git temp dir)."""
    return f"norepo@{os.path.basename(state)}"


def run(payload, state, labels="", extra_env=None):
    """Invoke the hook with a stub bd on PATH; return (decision, reason).

    cwd is the scratch state dir, not the developer's repo, so the ledger key the
    hook derives is deterministic and the real ledger is never touched.
    """
    bindir = os.path.join(state, "bin")
    os.makedirs(bindir, exist_ok=True)
    stub = os.path.join(bindir, "bd")
    with open(stub, "w") as fh:
        fh.write(BD_STUB)
    os.chmod(stub, 0o755)

    gate_file = os.path.join(state, "gate.txt")
    with open(gate_file, "w") as fh:
        fh.write(GATE_DESC.format(gid="GATE-1", card="CARD-1"))

    env = dict(os.environ)
    env["PATH"] = bindir + os.pathsep + env["PATH"]
    env["AC_REVIEW_STATE_DIR"] = state
    env["BD_STUB_GATE"] = gate_file
    env["BD_STUB_LABELS"] = labels
    env.update(extra_env or {})

    p = subprocess.run(["bash", HOOK], input=json.dumps(payload),
                       capture_output=True, text=True, env=env, cwd=state, timeout=60)
    out = p.stdout.strip()
    if not out:
        return "ALLOW", ""
    try:
        hso = json.loads(out).get("hookSpecificOutput", {})
        return hso.get("permissionDecision", "ALLOW").upper(), hso.get("permissionDecisionReason", "")
    except json.JSONDecodeError:
        return "PARSE-ERROR", out


def bash(cmd):
    return {"tool_name": "Bash", "tool_input": {"command": cmd}, "session_id": "hooktest"}


CASES = []


def case(name):
    def wrap(fn):
        CASES.append((name, fn))
        return fn
    return wrap


@case("1. the hook under test actually exists (the hole that made the old suite lie)")
def _(state):
    assert os.path.isfile(HOOK), f"{HOOK} missing — a silent-ALLOW suite is worse than none"


@case("2. human-gate label -> Tier 1, denied")
def _(state):
    got, why = run(bash("bd gate resolve GATE-1"), state, labels="human-gate")
    assert got == "DENY", f"got {got}"
    assert "TIER 1" in why


@case("3. flapped card (>= 2 recorded FAILs) -> denied")
def _(state):
    with open(os.path.join(state, "CARD-1.verdicts.log"), "w") as fh:
        fh.write("FAIL abc\nFAIL def\n")
    got, why = run(bash("bd gate resolve GATE-1"), state)
    assert got == "DENY", f"got {got}"
    assert "flap" in why.lower()


@case("4. credit spent -> denied, and the denial is ACTIONABLE (names ack + the entries)")
def _(state):
    key = ledger_key(state)
    with open(os.path.join(state, f"ledger-{key}.log"), "w") as fh:
        for i in range(BUDGET):
            fh.write(f"2026-08-10T{i:02d}:00:00Z gate=g{i} card=OLD-CARD-{i}\n")
    got, why = run(bash("bd gate resolve GATE-1"), state)
    assert got == "DENY", f"got {got}"
    assert "credit" in why.lower(), f"expected the credit tier, got: {why[:160]}"
    assert "ack" in why, "the denial must tell the human how to return credit"
    assert "OLD-CARD-0" in why, "the denial must list what is outstanding"


@case("4b. ONE BELOW the budget is not spent — pins the boundary, not just one point")
def _(state):
    key = ledger_key(state)
    with open(os.path.join(state, f"ledger-{key}.log"), "w") as fh:
        for i in range(BUDGET - 1):
            fh.write(f"2026-08-10T{i:02d}:00:00Z gate=g{i} card=OLD-CARD-{i}\n")
    got, why = run(bash("bd gate resolve GATE-1"), state)
    # Must get PAST the credit tier and stop at the evidence check instead —
    # without this, a budget of 0 or an always-deny bug would still pass case 4.
    assert "credit" not in why.lower(), \
        f"below budget must not block on credit; got: {why[:160]}"


@case("5. audited credit is NOT spent — the day-2 regression, end to end")
def _(state):
    key = ledger_key(state)
    with open(os.path.join(state, f"ledger-{key}.log"), "w") as fh:
        for i in range(BUDGET):
            fh.write(f"2026-08-10T{i:02d}:00:00Z gate=g{i} card=OLD-CARD-{i}\n")
    with open(os.path.join(state, f"watermark-{key}.txt"), "w") as fh:
        fh.write(f"2026-08-10T23:59:59Z count={BUDGET}\n")
    got, why = run(bash("bd gate resolve GATE-1"), state)
    # It must get PAST the credit tier. With no verdict artifact seeded it then
    # stops at the evidence check — which is proof it was not blocked on credit.
    assert "credit" not in why.lower(), \
        f"audited entries must not block; got DENY on credit: {why[:160]}"
    assert got == "DENY" and ("no evidence" in why.lower() or "verdict" in why.lower()), \
        f"expected to reach the evidence check, got {got}: {why[:160]}"


@case("6. no verdict artifact -> denied (fails closed on absent evidence)")
def _(state):
    got, why = run(bash("bd gate resolve GATE-1"), state)
    assert got == "DENY", f"got {got}"
    assert "no evidence" in why.lower() or "verdict" in why.lower()


@case("7. closing an AC gate directly -> denied (resolution is the only path)")
def _(state):
    got, why = run(bash("bd close GATE-1"), state)
    assert got == "DENY", f"got {got}"


@case("8. ALLOW: unrelated command")
def _(state):
    got, _why = run(bash("git status --short"), state)
    assert got == "ALLOW", f"got {got}"


@case("9. ALLOW: the phrase inside a quoted argument (regression, 2026-08-09)")
def _(state):
    got, _why = run(bash('bd remember "the hook denies bd gate resolve without review"'), state)
    assert got == "ALLOW", f"got {got}"


@case("10. missing ledger helper -> fails CLOSED, and denies for THAT reason")
def _(state):
    # Siblings resolve relative to the hook's own directory, so isolate a copy with no
    # siblings. An earlier version of this case faked $HOME; once sibling resolution
    # moved to the script dir that stopped isolating anything, and the case passed on
    # the unrelated "no evidence" denial instead. A test that cannot fail for its
    # stated reason is worse than no test — it is the exact defect this suite exists
    # to catch, reproduced inside the suite.
    global HOOK
    lonely_dir = os.path.join(state, "lonely")
    os.makedirs(lonely_dir, exist_ok=True)
    lonely_hook = os.path.join(lonely_dir, "ac-gate-tiered.sh")
    shutil.copy(HOOK, lonely_hook)

    real, HOOK = HOOK, lonely_hook
    try:
        got, why = run(bash("bd gate resolve GATE-1"), state)
    finally:
        HOOK = real
    assert got == "DENY", f"a gate that cannot count credit must deny; got {got}"
    assert "ledger helper is missing" in why, \
        f"it must deny for the RIGHT reason, not incidentally; got: {why[:160]}"


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
