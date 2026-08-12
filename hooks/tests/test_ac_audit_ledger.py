#!/usr/bin/env python3
"""Unit tests for ac-audit-ledger.sh — the credit accounting behind the AC gate's budget.

WHY THIS FILE EXISTS (2026-08-11). The gate's budget was a plain `wc -l` over a ledger
keyed on the Claude session_id. That measures |emitted|, but the invariant the gate
enforces is |emitted| - |audited| — unaudited self-resolutions OUTSTANDING. With no
drain and a session id whose lifetime is unspecified (and which in practice survives
compaction and calendar rollover), five approvals made on day 1 still blocked work on
day 2, hours after they had been audited. Redis names the counter half of this a leaked
key (INCR without EXPIRE); CWE-613 names the principal half; RFC 9113 §5.2.1 names the
right model — a credit scheme, drained by the receiver, not by the clock.

Each case below states the hole it covers. Cases 5 and 6 are the day-2 bug itself.
"""
import os
import subprocess
import sys
import tempfile

HOOKS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

HELPER = os.path.join(HOOKS_DIR, "ac-audit-ledger.sh")


def sh(*args, state=None):
    env = dict(os.environ)
    if state:
        env["AC_REVIEW_STATE_DIR"] = state
    p = subprocess.run(["bash", HELPER, *args], capture_output=True, text=True,
                       env=env, timeout=30)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def count(state, key):
    rc, out, err = sh("count", key, state=state)
    assert rc == 0, f"count exited {rc}: {err}"
    return int(out)


CASES = []


def case(name):
    def wrap(fn):
        CASES.append((name, fn))
        return fn
    return wrap


@case("1. a key with no ledger counts 0, does not crash")
def _(state):
    assert count(state, "repo@main") == 0


@case("2. each recorded self-resolution increments the outstanding count")
def _(state):
    for i in range(3):
        sh("record", "repo@main", f"gate=g{i} card=c{i}", state=state)
    assert count(state, "repo@main") == 3


@case("3. ack drains the credit — the human audit is what decrements, not time")
def _(state):
    sh("record", "repo@main", "gate=g1 card=c1", state=state)
    sh("record", "repo@main", "gate=g2 card=c2", state=state)
    assert count(state, "repo@main") == 2
    sh("ack", "repo@main", state=state)
    assert count(state, "repo@main") == 0


@case("4. entries recorded after an ack count again")
def _(state):
    sh("record", "repo@main", "gate=g1 card=c1", state=state)
    sh("ack", "repo@main", state=state)
    sh("record", "repo@main", "gate=g2 card=c2", state=state)
    assert count(state, "repo@main") == 1


@case("5. THE DAY-2 BUG: audited entries from a previous day stay drained")
def _(state):
    ledger = os.path.join(state, "ledger-repo@main.log")
    with open(ledger, "w") as fh:
        for i in range(5):
            fh.write(f"2026-08-10T1{i}:00:00Z gate=g{i} card=c{i}\n")
    assert count(state, "repo@main") == 5, "before the ack they are outstanding"
    with open(os.path.join(state, "watermark-repo@main.txt"), "w") as fh:
        fh.write("2026-08-10T23:59:59Z\n")
    assert count(state, "repo@main") == 0, \
        "after the human audited them the budget must be free — this is the bug that wedged 08-11"


@case("6. an ack does NOT forgive work done after it (no time-based forgiveness)")
def _(state):
    ledger = os.path.join(state, "ledger-repo@main.log")
    with open(ledger, "w") as fh:
        fh.write("2026-08-10T10:00:00Z gate=g1 card=c1\n")
        fh.write("2026-08-12T10:00:00Z gate=g2 card=c2\n")
    with open(os.path.join(state, "watermark-repo@main.txt"), "w") as fh:
        fh.write("2026-08-11T00:00:00Z\n")
    assert count(state, "repo@main") == 1, \
        "only the pre-ack entry is drained; the later one is still owed an audit"


@case("7. credits are per key — one repo/branch does not spend another's budget")
def _(state):
    sh("record", "repoA@main", "gate=g1 card=c1", state=state)
    sh("record", "repoA@main", "gate=g2 card=c2", state=state)
    sh("record", "repoB@main", "gate=g3 card=c3", state=state)
    assert count(state, "repoA@main") == 2
    assert count(state, "repoB@main") == 1
    sh("ack", "repoA@main", state=state)
    assert count(state, "repoA@main") == 0
    assert count(state, "repoB@main") == 1, "acking one key must not drain another"


@case("8. the key is derived from repo+branch, and is stable across invocations")
def _(state):
    rc, k1, _e = sh("key", state=state)
    rc2, k2, _e2 = sh("key", state=state)
    assert rc == 0 and k1, "key must be derivable"
    assert k1 == k2, f"key must be stable: {k1!r} vs {k2!r}"
    assert "@" in k1, f"key should be <repo>@<branch>, got {k1!r}"


@case("9. list shows the outstanding entries so the denial can be actionable")
def _(state):
    sh("record", "repo@main", "gate=g1 card=CARD-ONE", state=state)
    sh("ack", "repo@main", state=state)
    sh("record", "repo@main", "gate=g2 card=CARD-TWO", state=state)
    rc, out, _e = sh("list", "repo@main", state=state)
    assert rc == 0
    assert "CARD-TWO" in out, "outstanding entry must be listed"
    assert "CARD-ONE" not in out, "audited entry must not be listed"


@case("11. a key containing '/' (every feature branch) round-trips record/count/ack")
def _(state):
    key = "heimdall2-fips@feature/fips-compliant-password-hashing"
    sh("record", key, "gate=g1 card=c1", state=state)
    sh("record", key, "gate=g2 card=c2", state=state)
    assert count(state, key) == 2, "slashes must not scatter the ledger across directories"
    assert not os.path.isdir(os.path.join(state, "ledger-heimdall2-fips@feature")), \
        "a '/' in the key must be sanitized, not create a directory"
    sh("ack", key, state=state)
    assert count(state, key) == 0
    sh("record", key, "gate=g3 card=c3", state=state)
    assert count(state, key) == 1


@case("12. keys differing only where sanitization applies stay distinct")
def _(state):
    sh("record", "repo@feature/a", "gate=g1 card=c1", state=state)
    sh("record", "repo@feature/b", "gate=g2 card=c2", state=state)
    assert count(state, "repo@feature/a") == 1
    assert count(state, "repo@feature/b") == 1, "sanitization must not merge two branches"


@case("10. a malformed watermark fails CLOSED (counts everything, never crashes)")
def _(state):
    sh("record", "repo@main", "gate=g1 card=c1", state=state)
    with open(os.path.join(state, "watermark-repo@main.txt"), "w") as fh:
        fh.write("not-a-timestamp\n")
    n = count(state, "repo@main")
    assert n == 1, f"garbage must not silently drain the budget, got {n}"


fails = 0
for name, fn in CASES:
    with tempfile.TemporaryDirectory() as tmp:
        try:
            fn(tmp)
            print(f"ok   {name}")
        except AssertionError as exc:
            fails += 1
            print(f"FAIL {name}\n        {exc}")
        except Exception as exc:  # helper missing, bad exit, parse error
            fails += 1
            print(f"FAIL {name}\n        {type(exc).__name__}: {exc}")

print()
print(f"{len(CASES) - fails}/{len(CASES)} cases pass")
sys.exit(1 if fails else 0)
