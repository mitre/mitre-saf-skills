# AC-verify hook tests

Run both before changing anything in `../ac-gate-human-only.sh`,
`../ac-review-agent-block.sh`, or `../ac-review-prompt.sh`:

```sh
python3 ~/.claude/hooks/tests/test_ac_gate_hook.py          # 18 cases
python3 ~/.claude/hooks/tests/test_ac_review_agent_hook.py  # 8 cases
```

Both exit non-zero on any failure. The agent-hook suite generates a REAL
canonical prompt, so it must be run from inside a git repo that has a beads
card with acceptance criteria and a non-empty diff against its base
(`docker-trusted-bases` / `dtb-igf.2` at time of writing — change the
constants at the top if that card closes).

## Why these exist

Three separate rounds of this machinery shipped broken because it was changed
without a test, and every failure was silent:

1. **`grep -qF "$(129KB)"`** → `grep: out of memory` → non-zero → the hook
   denied the CORRECT prompt while its own debug line showed both hashes
   identical. Deadlocked every full-mode card. grep's error goes to stderr,
   which nothing reads.
2. **`BASE="${2:-main}"` + unconditional merge-base** → on any repo that
   commits directly to `main`, `merge-base(main, HEAD)` IS HEAD, so the
   reviewer received an EMPTY artifact — 83 bytes instead of 104,149 — and
   would return a confident PASS over no code.
3. **Card id scraped with a `-b7i` regex** → every project except beads-board
   was denied "names no card id".
4. **`mktemp -t name`** (no `X`s) → accepted by BSD, rejected by GNU, returns
   an empty path, and every later read fails silently.

Each of those looked like a working guard. The tests are the only thing that
tells the difference between "enforcing" and "failing closed for the wrong
reason" — a hook that denies everything looks identical to a hook that works
until you try the allow-path.

**The allow-path case is the one that matters.** `canonical prompt, verbatim →
ALLOW` is the case that failed in rounds 1 and 2. A suite that only tests
denials will pass on a completely broken hook.
