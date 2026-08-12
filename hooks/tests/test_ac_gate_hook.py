#!/usr/bin/env python3
"""Runner for the AC-enforcement hook suites. Run this before trusting the gate.

HISTORY — why this file changed shape (2026-08-11). It used to hold twelve behavioral
cases against `ac-gate-human-only.sh`. That hook was REPLACED by `ac-gate-tiered.sh` and
deleted, and nothing updated this file. The harness treats an empty stdout as ALLOW, and
a missing hook produces exactly that — so its five ALLOW cases passed vacuously while its
seven DENY cases failed, and the file reported "11/18 cases pass" to nobody's attention.
Enforcement that is not tested is enforcement you are guessing about: the credit defect
of 2026-08-11 shipped underneath this.

Its cases now live in files that target hooks which exist:

  test_ac_gate_tiered.py       the tiered gate — tiers, credit accounting, fail-closed
  test_ac_review_agent_hook.py the agent block — hand-written reviews denied
  test_ac_audit_ledger.py      credit accounting units — drain, keying, malformed input
  test_validate_bd_create.py   the 12-section card gate — including the /private/tmp
                               regression that reported a complete card as empty

KNOWN GAP, stated rather than implied: no suite covers the stale-hash path or the clean
ALLOW-and-record path, both of which need the canonical generator and a real git tree.
Those are carded, not forgotten.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SUITES = [
    "test_ac_audit_ledger.py",
    "test_ac_gate_tiered.py",
    "test_ac_review_agent_hook.py",
    "test_validate_bd_create.py",
]

failed = []
for suite in SUITES:
    path = os.path.join(HERE, suite)
    if not os.path.isfile(path):
        print(f"MISSING {suite} — a suite that does not exist cannot pass")
        failed.append(suite)
        continue
    print(f"\n=== {suite} " + "=" * (60 - len(suite)))
    p = subprocess.run([sys.executable, path], timeout=600)
    if p.returncode != 0:
        failed.append(suite)

print("\n" + "=" * 68)
if failed:
    print("FAILING SUITES: " + ", ".join(failed))
    sys.exit(1)
print(f"all {len(SUITES)} hook suites pass")
