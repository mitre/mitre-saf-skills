# Mutation Testing — the mechanical answer to Gate 4

Gate 4 asks: *"would this test still pass if the code were broken?"* Asking
yourself is necessary but weak — the answer arrives as a judgment, from the same
head that wrote the test. Mutation testing answers it as a fact: break the guard,
run the suite, and see whether the test that claims to cover it fails.

Harness: `tools/mutate.py` in this skill. Copy it into the project (`test/`,
`spec/`, wherever test tooling lives), change three constants and fill in the
mutations table.

## Copy it into the REPO, never a scratch directory

This produces acceptance evidence. If it lives in a session scratchpad it
disappears when the session ends, and nobody — not a reviewer, not the author
tomorrow — can re-run the claim to check it. That happened on
docker-trusted-bases 2026-08-09: a card's AC rested on a 22/22 mutation result
produced by a script that was about to evaporate.

**If a tool produces evidence for a card, it belongs in the repo.**

## Only CAUGHT is a pass

`CAUGHT` means *the named test* failed. Every other verdict exists because it was
a real incident where the harness made a confident claim about code it had never
touched:

| verdict | meaning |
|---|---|
| `CAUGHT` | the expected test failed — the only pass |
| `CAUGHT-BY-WRONG-TEST` | something failed, but not the test claiming coverage; the behavior may still be uncovered |
| `ANCHOR-AMBIGUOUS` | the anchor matches >1 site, so `replace` would patch a different function than the verdict names |
| `ANCHOR-MISSING` | the code moved; the mutation silently stopped testing anything |
| `INVALID` | the mutation broke the build, so no test ever ran — a red suite proves nothing |
| `NO-OP` | the replacement equals the original |

`SURVIVED` is deliberately ambiguous: either the test is missing **or** the
mutation changes no behavior. Triage before believing either. Treating SURVIVED
as automatically "missing test" is how effort gets spent writing tests for
mutations that were never valid.

## Four rules that came from real false passes

1. **Name the expected test.** "The suite went red" is not evidence that *this*
   guard is covered. Without an expected test, a mutation that trips some
   unrelated assertion reads as a pass.

2. **The mutation must compile.** A syntax error fails the suite for a reason
   that has nothing to do with coverage. Two mutations were counted as catches
   this way before the build guard existed.

3. **The anchor must be unique.** `str.replace` takes the first match.
   `validateAnchorsPath(anchorsDir)` appeared in two functions; the harness
   mutated one and reported a verdict about the other, "finding" a gap in a guard
   it never touched.

4. **Test the failure path.** A guard that exists to handle failure needs a test
   that *induces* failure. A staging-cleanup `defer` was covered by a
   success-path test only — and on success the directory was consumed by a rename
   anyway, so the test passed with the cleanup deleted entirely.

## Every guard gets a mutation

A guard nobody mutates is a guard nobody has shown to be tested. When you add a
check — a validation, a bounds test, a refusal — add its mutation in the same
change. This is the habit that turns the harness from a one-off audit into a
standing property of the suite.

## Self-test the harness

`tools/mutate_selftest.py` runs four deliberate controls — an ambiguous anchor, a
build breaker, a correct guard attributed to an unrelated test, and a stale
anchor. Every one must come back flagged; if any returns `CAUGHT`, the harness is
lying and its verdicts are worthless. Run it after porting to a new project,
because the failure-name parsing (`FAIL_PATTERN`) differs per test runner and a
wrong pattern silently turns every result into `CAUGHT-BY-WRONG-TEST` or
`SURVIVED`.

## When to use it

- Any card whose ACs include a security or correctness guarantee.
- Before closing a full-mode card, as the evidence for Gate 4 and for any AC
  phrased as "every behavior has a test that fails when the behavior is removed".
- After a refactor. A refactor can move a behavior out from under the test that
  covered it while both still pass — that is exactly what a staging rewrite did
  to a "withdrawn certificate cannot persist" test, which afterwards asserted
  against a helper the production path had stopped calling.

## What it does not replace

TDD ordering, live testing, or independent review. It measures one property:
whether the tests would notice if the code stopped working. That property is
checkable from artifacts, which is why it makes a better AC than "all work via
TDD" — commit ordering can be faked, and a reviewer cannot verify it from a diff.
