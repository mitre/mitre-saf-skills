# Hooks

Enforcement that does not depend on an agent remembering to check something.

A workflow document can only work if it is consulted. Some failures are
precisely the failure to consult it — the agent never questioned the thing the
document would have told it to question, so no instruction was ever reached.
For that class, prose is not a control. A hook is.

These are agent-harness hooks, not git hooks. They are installed once, globally,
and apply to every session and every skill — including sessions where no skill
is running at all. That is deliberate: putting a guard inside one skill only
protects the code path that runs that skill.

## write-target-guard.sh

**Enforces:** no file may be mutated inside a git working tree, and no mutating
git command may run in one, until that tree has been declared a **write
target** for the current session. A write target is a `(root path, branch)`
pair, rendered everywhere as `<path> @ <branch>`.

*(Formerly `worktree-target-guard.sh`. Renamed 2026-08-10: "write target" names
the function — where writes may land — and stays true for a plain clone, a git
worktree, or a CI runner's detached checkout. The target is the checkout ROOT,
so two worktrees of one repository are two distinct targets — that distinction
is the original reason this guard exists.)*

**The problem it solves.** A shell's working directory is not a statement of
intent. It drifts — a subshell, a tool that resets it, a session resumed
elsewhere — and an agent that reads its location as its assignment will do
careful, correct work on the wrong branch. Repositories with multiple checkouts
make this sharper: several directories share one history, each sitting on a
different branch, and nothing in a task description says which one the task
belongs to. The work looks right, passes its tests, and lands somewhere it does
not belong.

**How it behaves.** On the first write into any git working tree, the guard
denies and reports the resolved target, then applies a two-case contract
(revised 2026-08-10) decided by what the user actually said:

- **Case 1 — the user named this tree in the current exchange** ("put it in
  `<dir>`", "fix the hook", "card it there"): the agent declares the target
  itself, citing the user's words via `--cite`. The banner and the session's
  declaration log are the audit trail.
- **Case 2 — nothing the user said names this tree** (shell location,
  precedent, inference): the agent states the target in one line and WAITS for
  the user's answer before declaring.

The asymmetry is what makes case 1 safe: the incident this guard exists for —
work landing in the wrong checkout because the shell happened to be there —
cannot produce a citation, because nobody said it. Once declared, a target is
unblocked for the rest of the session. Any other checkout, or the same checkout
on a different branch, is still blocked.

```
BLOCKED — undeclared write target.

About to write: /path/to/repo/src/thing.ts
  target : /path/to/repo @ feature/something

This session's declared write targets: (nothing declared in this session)
...
```

To clear a denial:

```bash
# case 1 — the user named the tree; cite their words:
bash hooks/declare-write-target.sh --session <id> --cite "put it in path/to/repo" /path/to/repo
# case 2 — after the user answers the stated ask:
bash hooks/declare-write-target.sh --session <id> /path/to/repo
bash hooks/declare-write-target.sh --session <id> --list
```

The session id is supplied by the denial message rather than guessed, so a
declaration cannot land in a different concurrently running session. The script
prints a banner to stdout — every declaration is visible, citations are shown
in it and appended to `<session>.log`, and the banner says so explicitly when a
second distinct repository joins a session, because that is the shape
accidental drift takes.

### What it covers

| Surface | Enforced | Why |
|---|---|---|
| `Write`, `Edit`, `NotebookEdit` | Yes | The file path is a structured field — the target is resolved exactly, never parsed out of text. |
| `Bash`, mutating git verbs | Yes | `commit`, `add`, `push`, `checkout`, `switch`, `rebase`, `reset`, `revert`, `cherry-pick`, `restore`, `merge`, `am`, `apply`, `clean`, `rm`, `mv`, `stash` (except `stash list`/`show`). An explicit `-C <path>` is honoured. |
| `Bash`, read-only git | No | `status`, `log`, `diff`, `branch`, `rev-parse`, `stash list` are never blocked. Checking where you are must always be possible. |
| Paths outside any git tree | No | Temp directories, scratch space, and agent configuration are out of scope. |

Symlinked directories resolve to the real repository, so editing a symlinked
skill inside a checkout is guarded as an edit to that checkout.

### What it does not cover

Stated plainly, because a guard believed to cover more than it does is worse
than no guard.

- **In-place edits through a shell** — `perl -i`, `tee`, output redirection.
  Catching those means parsing arbitrary shell, which produces false denials,
  and a guard that blocks legitimate work gets switched off.
- **Whether the task belongs on the declared branch.** The guard enforces that a
  target was chosen *deliberately*, not that it was chosen *correctly*. Work
  from an unrelated subsystem, done on a branch that was legitimately declared
  for other work, passes. Only a per-task target check catches that.
- **Case classification.** Whether the user "named this tree" is judged by the
  agent from conversation the hook cannot see. The control on that judgment is
  the visible banner plus the citation log — misuse is detectable, not
  impossible.

### Failure posture

Fails **open** on infrastructure problems — no `jq`, no `git`, unparseable
input. A guard that blocks every write because of its own bug is worse than the
drift it prevents. It fails **closed** only on the check itself.

## The AC-verify enforcement set

Four hooks implement the acceptance-criteria gate: the model may close its own
card only against evidence it could not have forged, and only so often before a
human looks. They arrived here on 2026-08-11 from `~/.claude/hooks`, where they
had lived untracked — the enforcement layer for a review process was the one
thing under no review.

**Installation model: copy, with provenance and verification — not symlinks.**
The agent's hook directory holds real files installed from a known ref of this
repository. Symlinking the installed path at a working tree was tried and
rejected the same day: it makes the *checked-out branch* the running
enforcement, so an ordinary `git switch` silently changes — or, for a branch
that does not track these files, removes — the live control plane, and a missing
gate hook prints nothing, which the harness reads as ALLOW. It also cannot
survive versioned releases, where the thing you install is a release artifact
rather than somebody's working tree.

Copies alone are not the answer either: two copies with no comparison is the
divergence this move was meant to end. The completed model is the one packaging
systems already use — install a copy, record a manifest of source ref plus
per-file SHA-256, and verify installed-against-source on demand (`rpm -V`,
`debsums`, and `pre-commit`'s self-reinstall are the same idea). **The install
script and its verify command are card `mitre-saf-skills-ed8`; until it lands,
the installed copies were placed by hand and confirmed byte-identical to this
directory on 2026-08-11.** Re-verify at any time with:

```bash
for f in hooks/ac-*.sh; do cmp -s "$f" ~/.claude/hooks/"$(basename $f)" \
  || echo "DRIFT: $f"; done
```

### ac-review-prompt.sh

Generates the reviewer's prompt mechanically from the card: the acceptance
criteria, the anti-patterns, every card note, and a diff scoped to the paths the
card's own Files section names — working-tree inclusive, so staged-versus-worktree
divergence is visible to the reviewer. Criteria and diff are written to disk and
pinned by SHA-256. **The implementing agent chooses neither what the reviewer
reads nor what it is asked.**

### ac-review-agent-block.sh

Denies any review the agent hand-wrote. A spawn that looks like an AC review must
contain the canonical prompt **verbatim** — containment is checked by regenerating
it and comparing on collapsed whitespace. Passing the prompt *by file reference*
is denied too, which is not over-strictness: indirection is indistinguishable
from substitution at the point of the check.

### ac-gate-tiered.sh

The gate itself, on `bd gate resolve`. **Tier 2** allows self-resolution only when
a verdict artifact exists, names this card, says PASS, and its embedded hashes
match hashes the hook **re-derives from the current tree** — so any edit after the
review makes the PASS stale. **Tier 1** reserves the human's key for: the
`human-gate` label, a card that flapped (≥2 recorded FAIL verdicts), spent credit,
and anything it cannot positively verify. `bd close --force` is always denied, and
closing a gate directly is denied because resolution is where the checks live.

### ac-audit-ledger.sh

The credit accounting the budget rests on — `key`, `count`, `list`, `record`,
`ack`. The quantity is self-resolutions **outstanding**, `|emitted| − |audited|`,
and only the human's `ack` returns capacity:

```bash
ac-audit-ledger.sh list "$(ac-audit-ledger.sh key)"   # what am I owed a look at?
ac-audit-ledger.sh ack  "$(ac-audit-ledger.sh key)"   # reviewed — restore credit
```

Keyed on `<repo>@<branch>`, never on a session id. Until 2026-08-11 this was a
bare `wc -l` over a session-keyed ledger with **no drain at all**, so an audited
budget stayed spent and blocked the next day's work; time-based fixes were
rejected because the clock cannot discharge an audit obligation. Full rationale,
prior art and rejected designs are in that script's header.

### Tests

`tests/test_ac_gate_hook.py` runs all three suites (30 cases). They target hooks
that exist — a point worth stating, because the suite this replaced pointed at a
hook that had been deleted, and since a missing hook prints nothing and the
harness reads silence as ALLOW, its DENY cases failed unnoticed for weeks.

```bash
python3 hooks/tests/test_ac_gate_hook.py
```

## Installation

Register in the agent's global settings so the guard applies everywhere, not
only in the repository that holds it:

```jsonc
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash",
        "hooks": [{ "type": "command",
                    "command": "bash /path/to/mitre-saf-skills/hooks/write-target-guard.sh",
                    "timeout": 10000 }] },
      { "matcher": "Write|Edit|NotebookEdit",
        "hooks": [{ "type": "command",
                    "command": "bash /path/to/mitre-saf-skills/hooks/write-target-guard.sh",
                    "timeout": 10000 }] }
    ]
  }
}
```

Session state is written to `~/.claude/state/write-target/<session-id>.tsv` —
one tab-separated `root<TAB>branch` line per approved target — with a
companion `<session-id>.log` recording each declaration's timestamp and
citation. Nothing is written inside any repository.

## Requirements

`bash`, `git`, `jq`, `perl`. All are present by default on macOS and on common
Linux images.
